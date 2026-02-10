import json
import logging
import os
import re
import pathlib
import threading
import time
from datetime import UTC, datetime
from urllib.parse import urlparse

import docker
import pymupdf4llm
import requests
from playwright.sync_api import sync_playwright

logger = logging.getLogger(__name__)

from pathlib import Path
from typing import Any, Tuple

# my results:
# "model": "gpt-5-2025-08-07"
# "cost_usd": 0.04081125,
# "tokens": {
#       "input": 3617,
#       "cached_input": 0,
#       "output": 3629,
#       "reasoning_output": 3520,
#       "total": 7246
#     }

# platform.openai.com/usage groundtruth:
# input: $0.005 total
# cached input: $0 total
# output: $0.036 total


def _estimate_cost_usd(
    model: str,
    input_tokens: int | None,
    output_tokens: int | None,
    cached_tokens: int | None = None,
) -> float | None:
    """
    Best-effort cost estimate in USD based on OpenAI pricing.
    """
    if model == "cached":
        return 0.0
    if input_tokens is None or output_tokens is None:
        return None

    # Base model name without date/suffixes
    base = model.split(":", 1)[0]
    base = base.removesuffix("-latest")

    family = base
    if family.startswith("gpt-5.1"):
        family = "gpt-5.1"
    elif family.startswith("gpt-5-mini"):
        family = "gpt-5-mini"
    elif family.startswith("gpt-5-nano"):
        family = "gpt-5-nano"
    elif family.startswith("gpt-5"):
        family = "gpt-5"
    elif family.startswith("gpt-4o"):
        family = "gpt-4o"

    # Approximate pricing (fallback to GPT-4o if unknown, or update as needed)
    pricing_per_million: dict[str, dict[str, float]] = {
        "gpt-5.1": {"input": 1.25, "cached_input": 0.125, "output": 10.0},
        "gpt-5": {"input": 1.25, "cached_input": 0.125, "output": 10.0},
        "gpt-5-mini": {"input": 0.25, "cached_input": 0.025, "output": 2.0},
        "gpt-5-nano": {"input": 0.05, "cached_input": 0.005, "output": 0.4},
        "gpt-4o": {"input": 2.50, "cached_input": 1.25, "output": 10.0},
    }

    price = pricing_per_million.get(family, pricing_per_million.get("gpt-4o"))
    if not price:
        return None

    cached = cached_tokens or 0
    if cached > input_tokens:
        cached = input_tokens

    billed_regular = input_tokens - cached
    p_in = price["input"]
    p_cached = price.get("cached_input", p_in)
    p_out = price["output"]

    cost_input = (billed_regular * p_in) / 1_000_000.0 + (cached * p_cached) / 1_000_000.0
    cost_output = (output_tokens * p_out) / 1_000_000.0
    return cost_input + cost_output


def _log_invocation_to_file(
    *,
    model: str,
    input: str,
    output: dict[str, Any],
    duration_s: float,
    usage: Any | None,
    log_path: Path,
    reason: str | None,
) -> None:
    """
    Append a single invocation record to SPEEDOMETER_LOG_PATH as JSON.
    """
    timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    input_tokens = None
    output_tokens = None
    total_tokens = None
    cached_tokens = None
    reasoning_tokens = None

    if usage is not None:
        input_tokens = getattr(usage, "input_tokens", None)
        output_tokens = getattr(usage, "output_tokens", None)
        total_tokens = getattr(usage, "total_tokens", None)

        input_details = getattr(usage, "input_tokens_details", None)
        if input_details is not None:
            cached_tokens = getattr(input_details, "cached_tokens", None)

        output_details = getattr(usage, "output_tokens_details", None)
        if output_details is not None:
            reasoning_tokens = getattr(output_details, "reasoning_tokens", None)

    record: dict[str, Any] = {
        "timestamp": timestamp,
        "model": model,
        "input": input,
        "output": output,
        "duration_seconds": duration_s,
        "cost_usd": _estimate_cost_usd(model, input_tokens, output_tokens, cached_tokens),
        "tokens": {
            "input": input_tokens,
            "cached_input": cached_tokens,
            "output": output_tokens,
            "reasoning_output": reasoning_tokens,
            "total": total_tokens,
        },
        "reason": reason,
    }

    try:
        if log_path.exists():
            try:
                with log_path.open("r", encoding="utf-8") as f:
                    existing = json.load(f)
            except Exception:
                existing = []
        else:
            existing = []

        if not isinstance(existing, list):
            existing = [existing]

        existing.append(record)

        tmp_path = log_path.with_suffix(".json.tmp")
        with tmp_path.open("w", encoding="utf-8") as f:
            json.dump(existing, f, ensure_ascii=False, indent=2)
        tmp_path.replace(log_path)
    except Exception:
        pass


def search_in_file(path: str | Path, needle: str) -> list[Tuple[int, str]]:
    """
    Return [(line_number, line_text), ...] for lines in `path` that contain `needle`.
    Case-sensitive, UTF-8 by default.
    """
    p = Path(path)
    matches: list[Tuple[int, str]] = []
    with p.open("r", encoding="utf-8", errors="replace") as f:
        for i, line in enumerate(f, start=1):
            if needle in line:
                return True
    return False


def get_input_table(paper: str, table_index: str) -> str:
    base = f"{paper}_table_{table_index}"

    rel = Path("artisanbench") / "tables" / f"{base}.md"
    repo_root = find_repo_root()
    inconsistent_rel = Path("artisanbench") / "tables" / "inconsistencies" / f"{base}.md"
    inconsistent_path = repo_root / inconsistent_rel
    if inconsistent_path.exists():
        return inconsistent_path.read_text(encoding="utf-8")
    partial_rel = Path("artisanbench") / "tables" / "partial" / f"{base}.md"
    partial_path = repo_root / partial_rel
    if partial_path.exists():
        return partial_path.read_text(encoding="utf-8")
    normal_path = Path(repo_root) / rel
    return normal_path.read_text(encoding="utf-8")


def get_original_table(paper: str, table_index: str) -> str:
    """Return canonical (non-obfuscated) table markdown for a paper/table index.

    Resolution order matches the evaluation dataset conventions:
    1) inconsistencies/
    2) partial/
    3) restricted/
    4) tables/
    """
    base = f"{paper}_table_{table_index}"
    repo_root = find_repo_root()

    candidates = [
        repo_root / "artisanbench" / "tables" / "inconsistencies" / f"{base}.md",
        repo_root / "artisanbench" / "tables" / "partial" / f"{base}.md",
        repo_root / "artisanbench" / "tables" / "restricted" / f"{base}.md",
        repo_root / "artisanbench" / "tables" / f"{base}.md",
    ]

    for candidate in candidates:
        if candidate.exists():
            return candidate.read_text(encoding="utf-8")

    raise FileNotFoundError(
        f"Could not find original table for {paper} table {table_index}. Tried: {', '.join(str(p) for p in candidates)}"
    )


def get_obfuscated_table(paper: str, table_index: str) -> str:
    """Obfuscate table values in the given Markdown file."""
    repo_root = find_repo_root()
    obfuscated_path = repo_root / "artisanbench" / "tables" / "obfuscated" / f"{paper}_table_{table_index}.md"
    if obfuscated_path.exists():
        return obfuscated_path.read_text(encoding="utf-8")
    inconsistent_path = repo_root / "artisanbench" / "tables" / "inconsistencies" / f"{paper}_table_{table_index}.md"
    partial_path = repo_root / "artisanbench" / "tables" / "partial" / f"{paper}_table_{table_index}.md"
    if inconsistent_path.exists():
        text = inconsistent_path.read_text(encoding="utf-8")
    elif partial_path.exists():
        text = partial_path.read_text(encoding="utf-8")
    else:
        path = repo_root / "artisanbench" / "tables" / f"{paper}_table_{table_index}.md"
        text = path.read_text(encoding="utf-8")

    lines = text.splitlines()

    def is_table_line(s: str) -> bool:
        return s.strip().startswith("|")

    def is_alignment_line(s: str) -> bool:
        if not is_table_line(s):
            return False
        cells = [c.strip() for c in s.strip().strip("|").split("|")]
        cells = [c for c in cells if c]
        return bool(cells) and all(c == "---" for c in cells)

    out_lines: list[str] = []
    n = len(lines)
    for i, ln in enumerate(lines):
        if not is_table_line(ln):
            out_lines.append(ln)
            continue
        nxt = lines[i + 1] if i + 1 < n else ""
        if is_alignment_line(nxt):
            out_lines.append(ln)
            continue
        if is_alignment_line(ln):
            out_lines.append(ln)
            continue
        out_lines.append(re.sub(r"\d", "?", ln))
    result = "\n".join(out_lines)
    if text.endswith("\n"):
        result += "\n"
    return result


def table_to_artifact(table_path: str) -> str:
    """Extracts artifact name from table path
    e.g. evaluation/tables/bloat_table_2.md --> bloat
    e.g. evaluation/tables/restricted/bloat_table_2.md --> bloat

    """
    match = re.search(r"tables/(?:restricted/)?([a-zA-Z0-9_-]+)_table_\d+\.md$", table_path)
    if match:
        return match.group(1)
    else:
        raise ValueError(f"Invalid table path format: {table_path}")


def table_to_index(table_path: str) -> str:
    """Extracts table index from table path
    e.g. evaluation/tables/bloat_table_2.md --> 2
    e.g. evaluation/tables/restricted/bloat_table_2.md --> 2

    """
    match = re.search(r"_(\d+)\.md$", table_path)
    if match:
        return match.group(1)
    else:
        raise ValueError(f"Invalid table path format: {table_path}")


def table_to_paper(table_path: str) -> str:
    """Extracts paper name from table path
    e.g. ./evaluation/tables/bloat_table_2.md --> bloat
    e.g. ./evaluation/tables/restricted/bloat_table_2.md --> bloat
    """
    match = re.search(r"tables/(?:restricted/)?([a-zA-Z0-9_-]+)_table_\d+\.md$", table_path)
    if match:
        return match.group(1)
    else:
        raise ValueError(f"Invalid table path format: {table_path}")


_LOG_SETUP_LOCK = threading.Lock()
_LOG_TLS = threading.local()


def _make_unique_workspace(base_dir: pathlib.Path) -> pathlib.Path:
    """Create a unique workspace directory under base_dir.

    Uses time (to seconds + microseconds), PID, and thread ident to avoid
    collisions when called concurrently (e.g., reprobench workers).
    """
    now = datetime.now(UTC)
    stamp = now.strftime("%H%M%S")
    # Include microseconds + a fast monotonic component to be extra safe
    suffix = f"{now.microsecond:06d}"
    ws = base_dir / f"{stamp}-{suffix}"
    ws.mkdir(parents=True, exist_ok=True)
    return ws


class _ThreadTokenFilter(logging.Filter):
    """Filter that only allows records emitted while the current thread-local
    token matches the handler's token. Prevents cross-talk between concurrent
    runs that share the same logger.
    """

    def __init__(self, token: str):
        super().__init__()
        self._token = token

    def filter(self, record: logging.LogRecord) -> bool:  # type: ignore[override]
        return getattr(_LOG_TLS, "token", None) == self._token


def setup_logging(task, *, console: bool = True, log_root: Path | None = None):
    """Configure logging for a single run and return logger + workspace info.

    Concurrency-safe:
    - Creates a unique workspace per call (even when called in parallel).
    - Adds a per-call FileHandler gated by a thread-local token so that log
      records from other concurrent runs do not leak into this file.
    - Avoids clearing global handlers to prevent races with other workers.
    """
    if log_root:
        base_log_dir = log_root
    else:
        datestamp = datetime.now(UTC).strftime("%y%m%d")
        base_log_dir = find_repo_root() / "logs" / datestamp

    # If task is pythonic_table_2. seprate to pythonic and table_2
    if "_" in task:
        tid = task.split("_")[0]
        table_index = task.split("_")[2]
        base_dir = base_log_dir / tid / f"table_{table_index}"
    else:
        base_dir = base_log_dir / task

    base_dir.mkdir(parents=True, exist_ok=True)
    workspace_dir = _make_unique_workspace(base_dir)
    log_file_path = workspace_dir / "artisan.log"

    log_level = os.getenv("LOG", "DEBUG").upper()

    # Get shared parent logger for this package hierarchy
    pkg_logger = logging.getLogger("artisan")
    with _LOG_SETUP_LOCK:
        pkg_logger.setLevel(log_level)
        # Child loggers under 'artisan.*' should bubble up to this one
        pkg_logger.propagate = False

        # Set up formatter once
        formatter = logging.Formatter(
            fmt="%(asctime)s - artisan:%(levelname)s - %(filename)s:%(lineno)d - %(message)s",
            datefmt="%H:%M:%S",
        )

        # Ensure at most one console handler (for CLI runs)
        if console:
            has_console = any(
                isinstance(h, logging.StreamHandler) and not isinstance(h, logging.FileHandler)
                for h in pkg_logger.handlers
            )
            if not has_console:
                console_handler = logging.StreamHandler()
                console_handler.setLevel(logging.INFO)
                console_handler.setFormatter(formatter)
                pkg_logger.addHandler(console_handler)

        # Create a unique token for this run and store in TLS
        token = f"{time.time_ns()}-{os.getpid()}-{threading.get_ident()}"
        _LOG_TLS.token = token

        # File handler dedicated to this run (DEBUG+)
        file_handler = logging.FileHandler(log_file_path, encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(formatter)
        # Attach identifying attributes for discovery and filtering
        file_handler.artisan_token = token  # type: ignore[attr-defined]
        file_handler.artisan_task = str(task)  # type: ignore[attr-defined]
        file_handler.addFilter(_ThreadTokenFilter(token))
        pkg_logger.addHandler(file_handler)

    pkg_logger.info(f"Logging into {log_file_path}")
    return pkg_logger, workspace_dir, log_file_path


def find_artisan_log_dir(log: logging.Logger) -> str:
    """Return the current run's log directory if possible; else first file handler; else CWD.

    When multiple concurrent runs attach multiple FileHandlers to the shared
    'artisan' logger, we select the handler whose token matches the current
    thread-local token set in setup_logging.
    """
    tls_token = getattr(_LOG_TLS, "token", None)
    # First pass: find handler matching current token
    seen = set()
    cur = log
    while cur and cur not in seen:
        seen.add(cur)
        for h in getattr(cur, "handlers", []):
            if isinstance(h, logging.FileHandler):
                try:
                    if getattr(h, "artisan_token", None) and getattr(h, "artisan_token") == tls_token:
                        return os.path.dirname(h.baseFilename)
                except Exception:
                    pass
        cur = cur.parent if cur.propagate else None
    # Second pass: any file handler
    seen.clear()
    cur = log
    while cur and cur not in seen:
        seen.add(cur)
        for h in getattr(cur, "handlers", []):
            if isinstance(h, logging.FileHandler):
                try:
                    return os.path.dirname(h.baseFilename)
                except Exception:
                    pass
        cur = cur.parent if cur.propagate else None
    return os.getcwd()


def find_repo_root(start: Path | None = None) -> Path:
    """
    Find the repository/project root.

    Priority:
    1) Walk upward until a .git folder is found.
    2) Walk upward until a pyproject.toml is found.
    3) If ARTISAN_DIR env var is set, use it.
    4) If running from a typical layout /.../src/artisan, return parent of 'src'.
    5) Fallback to two-level parent of this file.
    """
    here = (start or Path(__file__)).resolve()

    # 1) Prefer real VCS root
    for candidate in (here, *here.parents):
        if (candidate / ".git").exists():
            return candidate

    # 2) Project root indicated by pyproject.toml
    for candidate in (here, *here.parents):
        if (candidate / "pyproject.toml").exists():
            return candidate

    # 3) Explicit override
    env_root = os.getenv("ARTISAN_DIR")
    if env_root:
        return Path(env_root).resolve()

    # 4) Typical src/ layout
    for candidate in (here, *here.parents):
        if candidate.name == "src" and (candidate / "artisan").exists():
            return candidate.parent

    # 5) Best-effort fallback
    return here.parent.parent


def docker_id_to_name(image_id):
    # Look up image name from Docker
    try:
        client = docker.from_env()
        image = client.images.get(image_id)
        image_name = image.tags[0] if image.tags else f"<untagged:{image_id[:12]}>"
    except:
        image_name = f"<unknown:{image_id[:12]}>"
    return image_name


def is_url(path):
    """Checks if a given path is a URL."""
    try:
        result = urlparse(path)
        return all([result.scheme, result.netloc])
    except ValueError:
        return False


# TODO: try to find alternative to pymupdf4llm
_PDF_CONVERT_LOCK = threading.Lock()


def convert_pdf_to_markdown(input_pdf_path, output_md_path):
    """Converts a PDF file to a Markdown file.

    Notes:
        PyMuPDF / pymupdf4llm table extraction is not thread-safe. Concurrent
        calls (as in reprobench with multiple workers) occasionally raise
        ValueError("not a textpage of this page") due to internal object reuse.
        We serialize conversion with a global lock and retry once on failure.
    """
    attempt = 0
    last_err: Exception | None = None
    while attempt < 2:  # at most one retry
        attempt += 1
        try:
            with _PDF_CONVERT_LOCK:
                md_text = pymupdf4llm.to_markdown(input_pdf_path)
            pathlib.Path(output_md_path).write_bytes(md_text.encode())
            return
        except Exception as e:  # broad to ensure retry on ValueError race
            last_err = e
            logger.warning(
                f"PDF->Markdown conversion failed on attempt {attempt} for {input_pdf_path}: {e}."
                + (" Retrying..." if attempt < 2 else "")
            )
    # If we exhausted retries, re-raise the last error
    if last_err:
        raise last_err


# TODO: support dl.acm.org/doi/pdf. Currently works only with arxiv paper with strat 1
def download_file_with_playwright(url: str, output_dir: str) -> str:
    """
    Download a file using multiple strategies: direct download first, then Playwright.
    """

    # Strategy 1: Try direct download first (works for ArXiv, many academic sites)
    try:
        print(f"Attempting direct download from: {url}")

        # Add headers to mimic a real browser
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }

        response = requests.get(url, headers=headers, timeout=30, allow_redirects=True)
        response.raise_for_status()

        # Check if we got a PDF
        content_type = response.headers.get("content-type", "").lower()
        if "application/pdf" in content_type or url.endswith(".pdf"):
            # Extract filename from URL or use default
            parsed_url = urlparse(url)
            filename = os.path.basename(parsed_url.path)
            if not filename or not filename.endswith(".pdf"):
                filename = "paper.pdf"

            filepath = os.path.join(output_dir, filename)

            with open(filepath, "wb") as f:
                f.write(response.content)

            print(f"Successfully downloaded via direct request: {filepath}")
            return filepath

    except Exception as e:
        print(f"Direct download failed: {e}")
        print("Falling back to Playwright...")

    # Strategy 2: Use Playwright (for sites requiring interaction)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Set a user agent
        page.set_extra_http_headers(
            {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
            }
        )

        try:
            print(f"Using Playwright to navigate to: {url}")

            # Navigate with longer timeout and error handling
            try:
                page.goto(url, timeout=60000, wait_until="domcontentloaded")
            except Exception as nav_error:
                print(f"Navigation failed: {nav_error}")
                # Try without waiting for domcontentloaded
                page.goto(url, timeout=60000, wait_until="load")

            # Wait a moment for any redirects
            page.wait_for_timeout(2000)

            print(f"Page loaded. Title: {page.title()}")
            print(f"Final URL: {page.url}")

            # Strategy 2a: Check if current page is already a PDF
            current_url = page.url
            if current_url.endswith(".pdf"):
                # The redirect took us to a PDF, download it directly
                response = requests.get(current_url, timeout=30)
                response.raise_for_status()

                filename = os.path.basename(urlparse(current_url).path) or "paper.pdf"
                filepath = os.path.join(output_dir, filename)

                with open(filepath, "wb") as f:
                    f.write(response.content)

                print(f"Downloaded PDF from redirected URL: {filepath}")
                return filepath

            # Strategy 2b: Wait for automatic download
            try:
                with page.expect_download(timeout=15000) as download_info:
                    # Sometimes just waiting triggers the download
                    page.wait_for_timeout(1000)

                download = download_info.value
                suggested_name = download.suggested_filename or "paper.pdf"
                download_path = os.path.join(output_dir, suggested_name)
                download.save_as(download_path)

                print(f"Download completed via Playwright: {download_path}")
                return download_path

            except Exception as download_error:
                print(f"Automatic download failed: {download_error}")

            # Strategy 2c: Look for download links/buttons
            selectors_to_try = [
                'a[href*=".pdf"]',
                'a[href*="pdf"]',
                'a:has-text("PDF")',
                'a:has-text("Download")',
                'button:has-text("Download")',
                ".download-btn",
                '[data-testid*="download"]',
                'a[title*="PDF"]',
            ]

            for selector in selectors_to_try:
                try:
                    elements = page.locator(selector).all()
                    print(f"Found {len(elements)} elements for selector: {selector}")

                    for element in elements:
                        try:
                            href = element.get_attribute("href")
                            if href and ".pdf" in href:
                                print(f"Clicking element with href: {href}")

                                with page.expect_download(timeout=10000) as download_info:
                                    element.click()

                                download = download_info.value
                                suggested_name = download.suggested_filename or "paper.pdf"
                                download_path = os.path.join(output_dir, suggested_name)
                                download.save_as(download_path)

                                print(f"Download completed by clicking: {download_path}")
                                return download_path

                        except Exception as click_error:
                            print(f"Click attempt failed: {click_error}")
                            continue

                except Exception as selector_error:
                    print(f"Selector {selector} failed: {selector_error}")
                    continue

            raise Exception(f"Could not download file from {url} using any strategy")

        finally:
            browser.close()
