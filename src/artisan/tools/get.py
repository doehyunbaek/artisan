"""Lightweight dataset/artifact fetch helper.

Usage patterns:
  artisan get <url> [-o output_path]

Supports:
    - Plain HTTP(S) URLs (stream to single file)
    - Zenodo record URLs (downloads ALL files in the record into current or specified directory)
    - Figshare article URLs (downloads ALL files in the article into current or specified directory)
    - GitHub repository URLs (clones repo)

No heavy deps: uses urllib + tqdm-like simple progress.
"""

# TODO: automate
# id=action; image=islemdockerdev/github-workflow-resource-study:v1.1; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=artisan; image=doehyunbaek1/artisan:latest; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=bazel-python; image=malfadel/python-pandas; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=bazel-rstudio; image=malfadel/rstudio-ggplot; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=bcia-analysis; image=mattienejati/bcia_analysis:ASE2024; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=bcia-buiscout; image=mattienejati/buiscout:ASE2024; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=flashsyn; image=zhiychen597/flashsyn:latest; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=fuzzslice; image=noblemathews/fuzzslice-icse; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=llm; image=jupyter/r-notebook; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=ppt4j; image=zhiyuanpan/ppt4j; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=provenfix; image=yahuuuuui/fse24-prove_n_fix:ubuntu; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=pythonic; image=mdipenta/rexp:latest; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=sctype; image=icse24sctype/full:latest; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image
# id=trace2inv; image=zhiychen597/trace2inv-artifact-fse2024:latest; docker pull $image; sudo docker save -o ~/.cache/artisan/docker/$id.tar $image

# TODO: consider pushing images to ghcr as it doesn't have pull limit

from __future__ import annotations

import argparse
import sys
import json
import re
import urllib.parse
from pathlib import Path
from dataclasses import dataclass
import tarfile
import zipfile
import gzip
import shutil
import subprocess
import os

import httpx
import artisan


class HttpxResponseAdapter:
    """Adapts httpx stream to a file-like object with .read(n) support."""

    def __init__(self, client, stream_context):
        self.client = client
        self.stream_context = stream_context
        self.response = None
        self.iterator = None
        self._buffer = b""

    def __enter__(self):
        self.response = self.stream_context.__enter__()
        if self.response.status_code >= 400:
            self.stream_context.__exit__(None, None, None)
            self.client.close()
            # If the response is not success, we might want to check for validation errors
            # but httpx should have raised already if verify=False wasn't respected
            self.response.raise_for_status()
        self.iterator = self.response.iter_bytes()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.stream_context.__exit__(exc_type, exc_val, exc_tb)
        self.client.close()

    @property
    def headers(self):
        return self.response.headers

    def read(self, n=-1):
        if n == -1:
            rest = b"".join(self.iterator)
            if self._buffer:
                retval = self._buffer + rest
                self._buffer = b""
                return retval
            return rest

        while len(self._buffer) < n:
            try:
                chunk = next(self.iterator)
                self._buffer += chunk
            except StopIteration:
                break

        result = self._buffer[:n]
        self._buffer = self._buffer[n:]
        return result


class CachedResponse:
    def __init__(self, stream, size):
        self.stream = stream
        self.headers = {"Content-Length": str(size)}

    def read(self, n=-1):
        return self.stream.read(n)

    def close(self):
        self.stream.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


_CACHE_INSTANCE = None


def _get_cache():
    """Return an optional local mitm flow-cache reader.

    Disabled by default so `artisan get` performs direct downloads unless the
    caller explicitly enables cache lookup. The usual full-reproduction cache
    path is `ARTISAN_MITM_URL` + a running `artisan mitm` proxy; this helper is
    only for manual/offline flow-cache reads.
    """
    if not (os.environ.get("ARTISAN_GET_CACHE") or os.environ.get("ARTISAN_MITM_CACHE_PATH")):
        return None

    global _CACHE_INSTANCE
    if _CACHE_INSTANCE is None:
        try:
            from artisan.mitm import LazyLiveCache

            c = LazyLiveCache()
            c._load_cache_data()
            _CACHE_INSTANCE = c
        except Exception:
            pass
    return _CACHE_INSTANCE


# ---------------------------
# URL patterns
# ---------------------------

ZENODO_REC_RE = re.compile(r"https?://zenodo\.org/records/(\d+)")
# Matches .../articles/<anything>/<ARTICLE_ID>[/...]
FIGSHARE_ART_RE = re.compile(r"https?://figshare\.com/articles/(?:[^/]+/)*(\d+)(?:/)?(?:\?.*)?$")


# ---------------------------
# URL sanitization & request helper
# ---------------------------


def _sanitize_url(u: str) -> str:
    """
    Percent-encode the path and query portions so urlopen accepts URLs with spaces
    or other control characters returned by providers (e.g., Zenodo).
    """
    parts = urllib.parse.urlsplit(u)
    # Encode path, keep "/" and already-escaped "%" intact
    path = urllib.parse.quote(parts.path, safe="/%")
    # Encode query but preserve common separators and percent signs
    query = urllib.parse.quote(parts.query, safe="=&%+,:;")
    return urllib.parse.urlunsplit((parts.scheme, parts.netloc, path, query, parts.fragment))


def _user_agent() -> str:
    """Return a descriptive User-Agent for all outbound HTTP requests.

    Follows Zenodo's recommendation: "<tool>/<version> (https://github.com/my/tool)".
    Attempts to read the installed Artisan version, falling back gracefully.
    """
    version = "unknown"
    try:
        from importlib import metadata as importlib_metadata  # type: ignore[import]

        try:
            version = importlib_metadata.version("artisan")
        except Exception:
            # If package metadata isn't available, fall back to module attribute if present
            version = getattr(artisan, "__version__", version)
    except Exception:
        # Very old Python or unexpected import failure; leave version as "unknown"
        version = getattr(artisan, "__version__", version)

    return f"artisan/{version} (https://github.com/doehyunbaek/artisan)"


def _open(u: str):
    """Wrapper over httpx with URL sanitization and custom User-Agent.

    Attempts to use mitmproxy CA cert if available to support caching via proxy.
    The User-Agent is set to identify Artisan to providers like Zenodo.
    """
    url = _sanitize_url(u)

    # Try cache
    cache = _get_cache()
    if cache:
        try:
            res = cache.get_stream(url)
            if res:
                stream, size = res
                return CachedResponse(stream, size)
        except Exception:
            pass

    # If mitmproxy CA cert is available, use it to verify SSL connections.
    # This allows us to use trust_env=True (so traffic goes through the proxy and populates cache)
    # without crashing on self-signed certificate errors.
    verify: bool | str = True
    mitm_cert = Path.home() / ".mitmproxy" / "mitmproxy-ca-cert.pem"

    proxies = None
    if os.environ.get("ARTISAN_MITM_URL"):
        proxies = os.environ["ARTISAN_MITM_URL"]

    if mitm_cert.exists():
        verify = str(mitm_cert)
    elif proxies or os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy"):
        # If proxy is set but no cert found, likely a dev setup.
        # Fallback to insecure to ensure 'artisan get' works.
        verify = False

    # Temporarily set proxy env vars if ARTISAN_MITM_URL is set, so httpx picks it up via trust_env=True
    # This avoids using the 'proxies' kwarg which might not be supported in some httpx versions
    old_env = {}
    if proxies:
        for k in ["http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY"]:
            old_env[k] = os.environ.get(k)
            os.environ[k] = proxies

    try:
        client = httpx.Client(
            trust_env=True,
            verify=verify,
            follow_redirects=True,
            headers={"User-Agent": _user_agent()},
            timeout=30.0,
        )
    finally:
        if proxies:
            for k, v in old_env.items():
                if v is None:
                    os.environ.pop(k, None)
                else:
                    os.environ[k] = v

    return HttpxResponseAdapter(client, client.stream("GET", url))


# ---------------------------
# Data structures
# ---------------------------


@dataclass
class DownloadResult:
    url: str  # Final resolved download URL
    path: Path  # Path to downloaded file
    size: int  # Size in bytes of the downloaded file
    extracted_dir: Path | None = None  # Extraction directory if archive
    readme: Path | None = None  # Path to discovered README (inside extracted tree)


# ---------------------------
# Zenodo helpers
# ---------------------------


def _list_zenodo_files(url: str) -> list[dict]:
    """Return list of file metadata dicts for a Zenodo record URL using the public API.

    Each dict contains at least: key, size, links.self
    Returns empty list if URL isn't a Zenodo record ID form.
    """
    m = ZENODO_REC_RE.match(url)
    if not m:
        return []
    rec_id = m.group(1)
    api = f"https://zenodo.org/api/records/{rec_id}"

    with _open(api) as r:  # nosec B310
        meta = json.loads(r.read().decode())

    return meta.get("files") or []


def _resolve_zenodo(url: str) -> tuple[str, str]:
    """Pick the 'best' single file to download from a Zenodo record URL."""
    m = ZENODO_REC_RE.match(url)
    if not m:
        return url, ""
    rec_id = m.group(1)
    api = f"https://zenodo.org/api/records/{rec_id}"
    with _open(api) as r:  # nosec B310
        meta = json.loads(r.read().decode())
    files = meta.get("files") or []
    if not files:
        return url, ""

    def _score(f: dict) -> tuple[int, int]:
        """Return a sort key (higher is better)."""
        name = (f.get("key") or "").lower()
        size = int(f.get("size") or 0)
        is_meta = int(name.startswith("license") or name.startswith("readme") or name.startswith("citation"))
        is_archive = int(
            name.endswith(".zip") or name.endswith(".tar") or name.endswith(".tar.gz") or name.endswith(".tgz")
        )
        return (is_archive, 1 - is_meta, size)

    chosen = max(files, key=_score)
    return chosen.get("links", {}).get("self", url), chosen.get("key", "")


# ---------------------------
# Figshare helpers
# ---------------------------


def _list_figshare_files(url: str) -> list[dict]:
    """Return list of file metadata dicts for a Figshare article URL.

    Normalizes into: {'key': <name>, 'size': <int>, 'links': {'self': <download_url>}}
    """
    m = FIGSHARE_ART_RE.match(url)
    if not m:
        return []
    art_id = m.group(1)
    api = f"https://api.figshare.com/v2/articles/{art_id}"

    with _open(api) as r:  # nosec B310
        meta = json.loads(r.read().decode())
    files = meta.get("files") or []
    norm: list[dict] = []
    for f in files:
        norm.append(
            {
                "key": f.get("name") or "",
                "size": int(f.get("size") or 0),
                "links": {"self": f.get("download_url") or ""},
            }
        )

    return norm


def _resolve_figshare(url: str) -> tuple[str, str]:
    """For a Figshare article URL, pick the 'best' file (archive preferred, non-metadata, largest)."""
    files = _list_figshare_files(url)
    if not files:
        return url, ""

    def _score(f: dict) -> tuple[int, int]:
        name = (f.get("key") or "").lower()
        size = int(f.get("size") or 0)
        is_meta = int(name.startswith("license") or name.startswith("readme") or name.startswith("citation"))
        is_archive = int(
            name.endswith(".zip") or name.endswith(".tar") or name.endswith(".tar.gz") or name.endswith(".tgz")
        )
        return (is_archive, 1 - is_meta, size)

    chosen = max(files, key=_score)
    return chosen.get("links", {}).get("self", url), chosen.get("key", "")


def download_figshare(article_url: str, out: str | None = None) -> tuple[list[DownloadResult], Path | None]:
    """Download all files from a Figshare article.

    Returns (list_of_download_results, readme_path_if_found).
    Detects README either as a direct file or inside extracted archives.
    """
    files = _list_figshare_files(article_url)
    if not files:
        raise RuntimeError("No files found in Figshare article API response.")
    # Prepare output directory
    if out:
        out_dir = Path(out)
        if out_dir.exists() and not out_dir.is_dir():
            raise RuntimeError(f"Output path {out_dir} exists and is not a directory.")
        out_dir.mkdir(parents=True, exist_ok=True)
    else:
        out_dir = Path(".")
    results: list[DownloadResult] = []
    readme_path: Path | None = None
    for fmeta in files:
        dl_url = fmeta.get("links", {}).get("self")
        if not dl_url:
            continue
        key = fmeta.get("key") or "download.bin"
        safe_name = Path(key).name
        target = out_dir / safe_name
        res = download(dl_url, str(target))
        print(f"Saved to {res.path} ({res.size} bytes)\n")
        if not readme_path:
            if res.path.name.lower().startswith("readme"):
                readme_path = res.path
            elif res.readme:
                readme_path = res.readme
        results.append(res)
    return results, readme_path


# ---------------------------
# Extraction & README helpers
# ---------------------------


def _is_single_file_gzip(p: Path) -> bool:
    # Heuristic: .gz but not tar.*; treat as single-file gzip
    return p.suffix == ".gz" and not any(s in p.name for s in [".tar.gz", ".tgz"]) and not p.name.endswith(".tar.gz")


def _safe_extract_tar(tf: tarfile.TarFile, dest: Path):
    """Extract tar file safely preventing path traversal."""
    for m in tf.getmembers():
        mpath = dest / m.name
        if not str(mpath.resolve()).startswith(str(dest.resolve())):
            raise RuntimeError(f"Blocked path traversal attempt in tar member: {m.name}")
    tf.extractall(dest)  # nosec B202 (paths already validated)


README_CANDIDATES = [
    "README.md",
    "README.MD",
    "readme.md",
    "README.txt",
    "readme.txt",
    "README",
    "readme",
]


def _find_readme(root: Path) -> Path | None:
    # Breadth-first search to prefer higher-level READMEs
    queue = [root]
    visited: set[Path] = set()
    while queue:
        cur = queue.pop(0)
        if cur in visited:
            continue
        visited.add(cur)
        try:
            for child in cur.iterdir():
                if child.is_file():
                    if child.name in README_CANDIDATES:
                        return child
                elif child.is_dir():
                    # Skip very deep or hidden directories to avoid huge walks
                    if len(child.relative_to(root).parts) <= 6 and not child.name.startswith("."):
                        queue.append(child)
        except PermissionError:
            continue
    return None


def _maybe_extract(artifact: Path) -> tuple[Path | None, Path | None]:
    """Extract archive if recognized; return (extracted_dir, readme_path)."""
    extracted_dir: Path | None = None
    readme: Path | None = None

    try:
        if zipfile.is_zipfile(artifact):
            extracted_dir = artifact.with_suffix("")
            extracted_dir.mkdir(exist_ok=True)
            with zipfile.ZipFile(artifact) as zf:
                # Prevent zip-slip
                for m in zf.namelist():
                    dest_path = extracted_dir / m
                    if not str(dest_path.resolve()).startswith(str(extracted_dir.resolve())):
                        raise RuntimeError(f"Blocked path traversal attempt in zip member: {m}")
                zf.extractall(extracted_dir)
        elif tarfile.is_tarfile(artifact):
            extracted_dir = artifact.with_suffix("")
            extracted_dir.mkdir(exist_ok=True)
            with tarfile.open(artifact) as tf:
                _safe_extract_tar(tf, extracted_dir)
        elif _is_single_file_gzip(artifact):
            # Decompress single-file gzip to same stem sans .gz
            target = artifact.with_suffix("")
            with gzip.open(artifact, "rb") as src, open(target, "wb") as dst:
                dst.write(src.read())
            extracted_dir = target.parent
        # If extracted, attempt to locate README
        if extracted_dir and extracted_dir.exists():
            readme = _find_readme(extracted_dir)
    except Exception as e:  # pragma: no cover - extraction is best-effort
        print(f"Extraction warning: {e}\n")
    return extracted_dir, readme


# ---------------------------
# Core download
# ---------------------------


def download(url: str, out: str | None = None) -> DownloadResult:
    # Choose resolver depending on host
    if ZENODO_REC_RE.match(url):
        resolved_url, suggested_name = _resolve_zenodo(url)
    elif FIGSHARE_ART_RE.match(url):
        resolved_url, suggested_name = _resolve_figshare(url)
    else:
        resolved_url, suggested_name = url, ""

    # Derive output path if not provided
    if out:
        out_path = Path(out)
    else:
        raw_name = suggested_name or Path(urllib.parse.urlparse(resolved_url).path).name or "download.bin"
        name = Path(raw_name).name  # strip any directory components for safety
        out_path = Path(name)

    # Ensure parent directory exists
    if out_path.parent and not out_path.parent.exists():  # pragma: no cover
        out_path.parent.mkdir(parents=True, exist_ok=True)

    tmp_path = out_path.with_suffix(out_path.suffix + ".part")
    with _open(resolved_url) as resp:  # nosec B310
        total = int(resp.headers.get("Content-Length", 0))
        chunk = 1024 * 64
        downloaded = 0
        with open(tmp_path, "wb") as f:
            while True:
                buf = resp.read(chunk)
                if not buf:
                    break
                f.write(buf)
                downloaded += len(buf)
                if total:
                    pct = downloaded * 100 // total
                    sys.stderr.write(f"\rDownloading {out_path.name} {pct}% ({downloaded}/{total} bytes)")
                else:
                    sys.stderr.write(f"\rDownloading {out_path.name} {downloaded} bytes")
        sys.stderr.write("\n")
    tmp_path.replace(out_path)

    extracted_dir, readme = _maybe_extract(out_path)
    return DownloadResult(
        url=resolved_url,
        path=out_path,
        size=out_path.stat().st_size,
        extracted_dir=extracted_dir,
        readme=readme,
    )


def download_zenodo(record_url: str, out: str | None = None) -> tuple[list[DownloadResult], Path | None]:
    """Download all files in a Zenodo record.

    Returns (list_of_download_results, readme_path_if_found).
    Detects README either as a direct file or inside extracted archives.
    """
    files = _list_zenodo_files(record_url)
    if not files:
        raise RuntimeError("No files found in Zenodo record API response.")
    # Prepare output directory
    if out:
        out_dir = Path(out)
        if out_dir.exists() and not out_dir.is_dir():
            raise RuntimeError(f"Output path {out_dir} exists and is not a directory.")
        out_dir.mkdir(parents=True, exist_ok=True)
    else:
        out_dir = Path(".")
    results: list[DownloadResult] = []
    readme_path: Path | None = None
    for fmeta in files:
        dl_url = fmeta.get("links", {}).get("self")
        if not dl_url:
            continue
        key = fmeta.get("key") or "download.bin"
        safe_name = Path(key).name
        target = out_dir / safe_name
        res = download(dl_url, str(target))
        print(f"Saved to {res.path} ({res.size} bytes)\n")
        if not readme_path:
            if res.path.name.lower().startswith("readme"):
                readme_path = res.path
            elif res.readme:
                readme_path = res.readme
        results.append(res)
    return results, readme_path


def download_github(url: str, out: str | None = None) -> tuple[Path, Path | None]:
    """Clone a GitHub repository.

    Returns (repo_dir, readme_path_if_found).
    Honors provided output path; otherwise derives directory name from URL.
    """
    if shutil.which("git") is None:
        raise RuntimeError("git executable not found in PATH.")
    if out:
        repo_dir = Path(out)
    else:
        # Extract repo name from URL path
        parts = url.split("github.com/", 1)[-1].split("/")
        repo_name = parts[1] if len(parts) >= 2 else (parts[-1] if parts else "repo")
        if repo_name.endswith(".git"):
            repo_name = repo_name[:-4]
        repo_dir = Path(repo_name or "repo")
    if repo_dir.exists():
        if repo_dir.is_dir():
            if any(repo_dir.iterdir()):
                print(f"Removing existing directory {repo_dir} (force overwrite)\n")
            shutil.rmtree(repo_dir)
        else:
            raise RuntimeError(f"Target path {repo_dir} exists and is not a directory.")
    args = ["git", "clone", "-c", "http.proxy=", "-c", "https.proxy=", "--depth", "1", url, str(repo_dir)]
    subprocess.run(args, check=True)
    readme_path: Path | None = None
    for cand in ["README.md", "README.MD", "Readme.md", "readme.md", "README", "readme"]:
        p = repo_dir / cand
        if p.exists():
            readme_path = p
            break
    print(f"Cloned repository into {repo_dir}\n")
    return repo_dir, readme_path


def print_artifact_summary(out: str | None):
    """
    Print full paths of the downloaded artifact contents.
    Equivalent to: find "$(realpath <out or .>)"
    """
    base_dir = Path(out).resolve() if out else Path(".").resolve()
    if not base_dir.exists():
        print(f"Output path {base_dir} does not exist.")
        return
    if base_dir.is_file():
        print(str(base_dir))
        return
    # Directory: print directory itself, then all entries (full paths)
    for root, dirs, files in os.walk(base_dir):
        root_path = Path(root)
        print(str(root_path))
        for f in files:
            print(str(root_path / f))


def cmd_get(url: str, out: str | None = None, except_glob_list: str | None = None) -> int:
    readme_path: Path | None = None  # ensure defined
    base_dir: Path | None = None
    try:
        if ZENODO_REC_RE.match(url):
            results, readme_path = download_zenodo(url, out)
            base_dir = Path(out) if out else Path(".")
        elif FIGSHARE_ART_RE.match(url):
            results, readme_path = download_figshare(url, out)
            base_dir = Path(out) if out else Path(".")
        elif "github.com" in url.lower():
            repo_dir, readme_path = download_github(url, out)
            base_dir = repo_dir
        else:
            # Plain URL: single download to file or to 'suggested' name
            res = download(url, out)
            readme_path = (
                res.readme if res.readme else (res.path if res.path.name.lower().startswith("readme") else None)
            )
            base_dir = res.path.parent

        print(f"README PATH: {str(readme_path) if readme_path else 'None'}\n")

        if except_glob_list and base_dir and base_dir.exists():
            for except_glob in except_glob_list:
                for p in base_dir.rglob(except_glob):
                    try:
                        if p.is_file():
                            p.unlink()
                            print(f"Deleted excluded file: {p}")
                    except Exception as e:
                        print(f"Warning: failed to delete excluded file {p}: {e}")

        # print_artifact_summary(out)
        return 0
    except Exception as e:  # pragma: no cover
        print(f"Error: {e}\n")
        return 2


def _get_from_cli(args: argparse.Namespace) -> int:
    """Adapter so argparse dispatch can call cmd_get with parsed args."""
    return cmd_get(args.url, args.out, args.except_glob)


def register_subparser(subparsers: argparse._SubParsersAction) -> None:
    """Register the `artisan get` subparser with the shared CLI."""
    get_p = subparsers.add_parser(
        "get",
        help="Download an artifact/dataset (supports Zenodo records)",
    )
    get_p.add_argument("url", help="URL (e.g., https://zenodo.org/records/<id>)")
    get_p.add_argument("-o", "--out", help="Output file path", default=None)
    get_p.add_argument("--except-glob", action="append", help="Exclude files (can be repeated)")
    get_p.set_defaults(func=_get_from_cli)
