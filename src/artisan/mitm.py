"""artisan.mitm

Single-file implementation for:

1) A mitmproxy addon implementing a simple record/replay cache.
2) The `artisan mitm` CLI subcommand that launches mitmproxy/mitmdump with this addon.

This module is intended to be loaded by mitmproxy/mitmdump via `-s`.

Configuration is supported via environment variables:
- `ARTISAN_MITM_CACHE_PATH`: path to the flow cache file (default: zenodo_cache.mitm)
- `ARTISAN_MITM_HOSTS`: comma-separated host substrings to intercept (default: zenodo.org)
- `ARTISAN_MITM_MAX_CACHE_BYTES`: max response size to store in the flowfile/in-memory cache (default: 1g)
- `ARTISAN_MITM_STREAM_THRESHOLD_BYTES`: max response size eligible for disk blob caching (default: 10g)
- `ARTISAN_MITM_BLOB_DIR`: directory for large response blobs (default: alongside the flow cache)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import threading
import io as sys_io
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import BinaryIO, Any
from urllib.parse import quote, unquote, urlparse

from mitmproxy import ctx, http, io
import artisan


def normalize_zenodo(url: str) -> str:
    """Normalize Zenodo file-download URLs to a canonical form.

    Canonical form:
        https://zenodo.org/records/{id}/files/{file_name}?download=1

    Supported inputs include:
    - https://zenodo.org/records/{id}/files/{file_name}?download=1
    - https://zenodo.org/records/{id}/files/{file_name}
    - https://zenodo.org/api/records/{id}/files/{file_name}/content

    If the URL does not look like a Zenodo file URL, it is returned unchanged.
    """

    try:
        parsed = urlparse(url)
    except Exception:
        return url

    host = (parsed.hostname or "").lower()
    if host not in {"zenodo.org", "www.zenodo.org"}:
        return url

    # Split path into segments and match known forms.
    segments = [s for s in (parsed.path or "").split("/") if s]

    record_id: str | None = None
    file_name: str | None = None

    # /records/{id}/files/{file}
    if len(segments) >= 4 and segments[0] == "records" and segments[2] == "files":
        record_id = segments[1]
        file_name = segments[3]

    # /api/records/{id}/files/{file}/content
    if (
        record_id is None
        and len(segments) >= 6
        and segments[0] == "api"
        and segments[1] == "records"
        and segments[3] == "files"
        and segments[5] == "content"
    ):
        record_id = segments[2]
        file_name = segments[4]

    if not record_id or not file_name:
        return url

    # Preserve any percent-encoding semantics but normalize to a consistent encoding.
    normalized_file_name = quote(unquote(file_name), safe="")

    return f"https://zenodo.org/records/{record_id}/files/{normalized_file_name}?download=1"


def _parse_size_bytes(value: str | None, *, default: int) -> int:
    """Parse a human-friendly byte size.

    Supports plain integers (bytes) or suffixes: k, m, g (base-1024).
    Examples: "1048576", "10m", "2g".
    """

    if value is None:
        return default
    s = value.strip().lower()
    if not s:
        return default
    multipliers = {"k": 1024, "m": 1024**2, "g": 1024**3}
    try:
        if s[-1] in multipliers:
            return int(float(s[:-1]) * multipliers[s[-1]])
        return int(s)
    except Exception:
        return default


def _safe_int_header(value: str | None) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except Exception:
        return None


class LazyLiveCache:
    def __init__(self):
        self.file_path = os.environ.get("ARTISAN_MITM_CACHE_PATH", "zenodo_cache.mitm")
        raw_hosts = os.environ.get("ARTISAN_MITM_HOSTS", "zenodo.org")
        self.host_substrings = [s.strip() for s in raw_hosts.split(",") if s.strip()]
        self.cache = {}

        # Small-cache (flowfile + in-memory) limits.
        # For larger responses we switch to a disk-backed "blob" cache that is streamed.
        self.max_cache_bytes = _parse_size_bytes(
            os.environ.get("ARTISAN_MITM_MAX_CACHE_BYTES"),
            default=1 * 1024 * 1024 * 1024,
        )
        self.stream_threshold_bytes = _parse_size_bytes(
            os.environ.get("ARTISAN_MITM_STREAM_THRESHOLD_BYTES"),
            default=10 * 1024 * 1024 * 1024,
        )

        cache_path = Path(self.file_path)
        self.blob_dir = Path(
            os.environ.get(
                "ARTISAN_MITM_BLOB_DIR",
                str(cache_path.parent / "artisan_mitm_blobs"),
            )
        )
        self.blob_index_path = self.blob_dir / "index.json"
        self.blob_index: dict[str, dict[str, Any]] = {}

        self._blob_server: ThreadingHTTPServer | None = None
        self._blob_server_thread: threading.Thread | None = None
        self._blob_server_port: int | None = None

    def _cache_path(self) -> Path:
        return Path(self.file_path)

    def _blob_id(self, key: str) -> str:
        return hashlib.sha256(key.encode("utf-8")).hexdigest()

    def _blob_path(self, blob_id: str) -> Path:
        return self.blob_dir / blob_id

    def _load_blob_index(self) -> None:
        try:
            if self.blob_index_path.exists():
                self.blob_index = json.loads(self.blob_index_path.read_text(encoding="utf-8"))
        except Exception as e:
            ctx.log.warn(f"Could not read blob index: {e}")
            self.blob_index = {}

    def _save_blob_index(self) -> None:
        self.blob_dir.mkdir(parents=True, exist_ok=True)
        tmp = self.blob_index_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.blob_index, indent=2, sort_keys=True), encoding="utf-8")
        tmp.replace(self.blob_index_path)

    def _ensure_blob_server(self) -> None:
        if self._blob_server is not None:
            return

        self.blob_dir.mkdir(parents=True, exist_ok=True)

        class _QuietBlobHTTPServer(ThreadingHTTPServer):
            def handle_error(self, request, client_address):  # type: ignore[override]
                exc_type, exc, _ = sys.exc_info()
                if exc is None:
                    return

                # Expected when the client aborts a download or writes binary to a TTY and exits.
                if isinstance(exc, (BrokenPipeError, ConnectionResetError, ConnectionAbortedError)):
                    return
                if isinstance(exc, OSError) and getattr(exc, "errno", None) in {32, 103, 104}:
                    return

                # Keep unexpected errors visible, but avoid a full socketserver traceback.
                ctx.log.info(f"[LiveCache] Blob server error from {client_address}: {exc_type.__name__}: {exc}")

        class _QuietBlobRequestHandler(SimpleHTTPRequestHandler):
            def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
                # Avoid noisy stderr logs from the local blob server.
                # (mitmproxy has its own logging; this server is an internal implementation detail.)
                return

        def handler(*args, **kwargs):
            return _QuietBlobRequestHandler(*args, directory=str(self.blob_dir), **kwargs)

        server = _QuietBlobHTTPServer(("127.0.0.1", 0), handler)
        self._blob_server = server
        self._blob_server_port = server.server_address[1]
        t = threading.Thread(target=server.serve_forever, name="artisan-mitm-blob-server", daemon=True)
        t.start()
        self._blob_server_thread = t
        ctx.log.info(f"[LiveCache] Blob server listening on 127.0.0.1:{self._blob_server_port}")

    def _matches_host(self, host: str) -> bool:
        return any(sub in host for sub in self.host_substrings)

    def _load_cache_data(self) -> None:
        self._load_blob_index()
        cache_path = self._cache_path()
        if cache_path.exists():
            with cache_path.open("rb") as f:
                reader = io.FlowReader(f)
                try:
                    for flow in reader.stream():
                        if isinstance(flow, http.HTTPFlow) and flow.response:
                            # Skip very large cached responses to avoid huge memory usage.
                            content_length = _safe_int_header(flow.response.headers.get("content-length"))
                            if content_length is not None and content_length > self.max_cache_bytes:
                                continue
                            raw = flow.response.raw_content
                            if raw is not None and len(raw) > self.max_cache_bytes:
                                continue
                            self.cache[self.get_key(flow.request)] = flow.response
                except Exception as e:
                    ctx.log.warn(f"Could not read some flows: {e}")

    def load(self, loader):
        self._load_cache_data()
        self._ensure_blob_server()

    def get_stream(self, url: str) -> tuple[BinaryIO, int] | None:
        """Retrieve cached content for a URL (GET request) if available.

        Returns (stream, content_length).
        """
        try:
            normalized_url = normalize_zenodo(url)
        except Exception:
            normalized_url = url
        key = f"GET {normalized_url}"

        # 1. Check blob
        blob = self.blob_index.get(key)
        if blob:
            path_str = blob.get("path") or str(self._blob_path(blob.get("id") or self._blob_id(key)))
            p = Path(path_str)
            if p.exists():
                _log_info(f"[LiveCache] Hit (Blob) for get.py: {key}")
                size = blob.get("size", 0)
                if not size:
                    try:
                        size = p.stat().st_size
                    except Exception:
                        pass
                return open(p, "rb"), size

        # 2. Check memory cache
        if key in self.cache:
            resp = self.cache[key]
            content = resp.content
            if content:
                _log_info(f"[LiveCache] Hit (Memory) for get.py: {key}")
                return sys_io.BytesIO(content), len(content)

        return None

    def get_key(self, request):
        url = request.url
        try:
            url = normalize_zenodo(url)
        except Exception:
            url = request.url
        return f"{request.method} {url}"

    # --- NEW: Intercept the Handshake ---
    def http_connect(self, flow: Any):
        # If the client wants to tunnel to a cached host, say "OK" immediately
        # without actually connecting to the real server yet.
        if self._matches_host(flow.request.pretty_host):
            flow.response = http.Response.make(200)

    def request(self, flow: Any):
        if not self._matches_host(flow.request.pretty_host):
            return

        key = self.get_key(flow.request)

        blob = self.blob_index.get(key)
        if blob:
            blob_id = blob.get("id") or self._blob_id(key)
            blob_path = Path(blob.get("path") or self._blob_path(blob_id))
            if blob_path.exists():
                self._ensure_blob_server()
                assert self._blob_server_port is not None
                ctx.log.info(f"[LiveCache] Hit (Blob): {key}")
                flow.request.url = f"http://127.0.0.1:{self._blob_server_port}/{blob_id}"
                return

        if key in self.cache:
            ctx.log.info(f"[LiveCache] Hit (Offline): {key}")
            flow.response = self.cache[key].copy()
            # Since we provide a response, Mitmproxy never opens the upstream connection.

    def responseheaders(self, flow: Any):
        """Stream very large responses to avoid buffering them in memory."""
        if not self._matches_host(flow.request.pretty_host):
            return
        if not getattr(flow, "response", None):
            return

        content_length = _safe_int_header(flow.response.headers.get("content-length"))
        # If the response is too large for the flowfile cache, we stream it.
        # If it is also below the blob max size, we stream it into a disk blob for replay.
        if content_length is not None and content_length > self.max_cache_bytes:
            if content_length > self.stream_threshold_bytes:
                flow.metadata["artisan_skip_flowfile"] = True
                flow.response.stream = True
                ctx.log.info(
                    f"[LiveCache] Large response ({content_length} bytes): streaming (NOT blob-cached, exceeds blob max): {self.get_key(flow.request)}"
                )
                return

            key = self.get_key(flow.request)
            blob_id = self._blob_id(key)
            blob_path = self._blob_path(blob_id)
            tmp_path = blob_path.with_suffix(".part")

            self.blob_dir.mkdir(parents=True, exist_ok=True)
            tmp_f = tmp_path.open("wb")

            flow.metadata["artisan_skip_flowfile"] = True

            def _stream_and_cache(chunk: bytes):
                # Called with upstream chunks; called once with b"" when upstream ends.
                if chunk:
                    tmp_f.write(chunk)
                    return chunk

                tmp_f.flush()
                tmp_f.close()

                try:
                    tmp_path.replace(blob_path)
                except Exception:
                    # If the blob already exists (concurrent downloads), keep existing.
                    if tmp_path.exists() and not blob_path.exists():
                        tmp_path.replace(blob_path)
                    elif tmp_path.exists():
                        tmp_path.unlink(missing_ok=True)

                self.blob_index[key] = {
                    "id": blob_id,
                    "path": str(blob_path),
                    "size": content_length,
                    "status_code": int(getattr(flow.response, "status_code", 200)),
                }
                try:
                    self._save_blob_index()
                except Exception as e:
                    ctx.log.warn(f"Could not save blob index: {e}")

                return b""

            # Stream bytes through to the client without buffering the full body.
            flow.response.stream = _stream_and_cache
            ctx.log.info(f"[LiveCache] Large response ({content_length} bytes): streaming and caching as blob: {key}")

    def response(self, flow: Any):
        if not self._matches_host(flow.request.pretty_host):
            return

        if flow.metadata.get("artisan_skip_flowfile"):
            return

        key = self.get_key(flow.request)
        if key not in self.cache and flow.response:
            # Guard against caching huge responses (can crash mitmproxy or exhaust RAM/disk).
            content_length = _safe_int_header(flow.response.headers.get("content-length"))
            if content_length is not None and content_length > self.max_cache_bytes:
                ctx.log.info(f"[LiveCache] Miss: Large response exceeds flowfile cache limit: {key}")
                return
            raw = flow.response.raw_content
            if raw is not None and len(raw) > self.max_cache_bytes:
                ctx.log.info(f"[LiveCache] Miss: NOT caching large response ({len(raw)} bytes): {key}")
                return

            ctx.log.info(f"[LiveCache] Miss: Saving {key}")
            self.cache[key] = flow.response
            cache_path = self._cache_path()
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            with cache_path.open("ab") as f:
                writer = io.FlowWriter(f)
                writer.add(flow)


addons = [LazyLiveCache()]


def _addon_script_path() -> Path:
    # This module is loaded by mitmproxy with `-s <path>`.
    return Path(__file__)


def cmd_mitm(args: argparse.Namespace) -> int:
    addon_path = _addon_script_path()
    if not addon_path.exists():
        print(f"[artisan mitm] ERROR: addon script not found: {addon_path}", file=sys.stderr)
        return 2

    # Pick which mitmproxy frontend to run.
    if args.bin:
        bin_name = args.bin
    elif args.web:
        bin_name = "mitmweb"
    elif args.ui:
        bin_name = "mitmproxy"
    else:
        bin_name = "mitmdump"

    exe = shutil.which(bin_name)
    if exe is None:
        print(
            "[artisan mitm] ERROR: mitmproxy executable not found.\n"
            f"  Tried: {bin_name}\n"
            "  Install mitmproxy (so `mitmdump` / `mitmproxy` / `mitmweb` are on PATH) and retry.",
            file=sys.stderr,
        )
        return 127

    env = os.environ.copy()
    if args.cache is not None:
        env["ARTISAN_MITM_CACHE_PATH"] = str(args.cache)
    if args.hosts is not None:
        env["ARTISAN_MITM_HOSTS"] = args.hosts
    if getattr(args, "max_cache_bytes", None) is not None:
        env["ARTISAN_MITM_MAX_CACHE_BYTES"] = str(args.max_cache_bytes)
    if getattr(args, "stream_threshold_bytes", None) is not None:
        env["ARTISAN_MITM_STREAM_THRESHOLD_BYTES"] = str(args.stream_threshold_bytes)

    # Ensure cache directory exists (mitmproxy will append to this file).
    cache_path = Path(env.get("ARTISAN_MITM_CACHE_PATH", "zenodo_cache.mitm"))
    if cache_path.parent and str(cache_path.parent) not in (".", ""):
        cache_path.parent.mkdir(parents=True, exist_ok=True)

    cmd: list[str] = [exe, "-s", str(addon_path)]

    if args.listen_host is not None:
        cmd += ["--listen-host", args.listen_host]
    if args.listen_port is not None:
        cmd += ["--listen-port", str(args.listen_port)]

    # Default safety: stream large bodies so mitmproxy doesn't buffer multi-GB responses.
    # Users can override by explicitly passing their own --set stream_large_bodies=... in mitm_args.
    # Keep mitmproxy streaming threshold small/safe by default.
    # Blob caching max size is controlled separately by ARTISAN_MITM_STREAM_THRESHOLD_BYTES.
    threshold_default = env.get("ARTISAN_MITM_MAX_CACHE_BYTES")
    if threshold_default is None:
        threshold_default = "1g"

    user_args = list(args.mitm_args) if args.mitm_args else []
    has_stream_large_bodies = any((a == "--set" or a.startswith("--set")) for a in user_args) and any(
        "stream_large_bodies" in a for a in user_args
    )

    if not has_stream_large_bodies:
        cmd += ["--set", f"stream_large_bodies={threshold_default}"]

    if user_args:
        cmd += user_args

    print("[artisan mitm] Starting mitmproxy:", flush=True)
    print("  " + " ".join(shlex.quote(c) for c in cmd), flush=True)
    print("[artisan mitm] Cache file:", env.get("ARTISAN_MITM_CACHE_PATH", "zenodo_cache.mitm"), flush=True)
    print("[artisan mitm] Host filter:", env.get("ARTISAN_MITM_HOSTS", "zenodo.org"), flush=True)
    print("[artisan mitm] Max flowfile cache:", env.get("ARTISAN_MITM_MAX_CACHE_BYTES", "1g"), flush=True)
    print(
        "[artisan mitm] Max blob cache:",
        env.get("ARTISAN_MITM_STREAM_THRESHOLD_BYTES", "10g"),
        flush=True,
    )

    try:
        completed = subprocess.run(cmd, env=env)
    except KeyboardInterrupt:
        return 0
    except FileNotFoundError:
        return 127
    return int(completed.returncode)


def _mitm_from_cli(args: argparse.Namespace) -> int:
    return cmd_mitm(args)


def register_subparser(subparsers: argparse._SubParsersAction) -> None:
    mitm_p = subparsers.add_parser(
        "mitm",
        help="Run mitmproxy with Artisan's record/replay addon (Zenodo cache)",
    )

    mitm_p.add_argument(
        "--cache",
        type=Path,
        default=Path(artisan.ARTISAN_CACHE_DIR) / "artisan" / "artisan.mitm",
        help=("Path to the mitmproxy flow cache file (.mitm). Defaults to ARTISAN_CACHE_DIR/artisan/artisan.mitm."),
    )

    mitm_p.add_argument(
        "--max-cache-bytes",
        default=None,
        help=(
            "Max response size to store in the .mitm flowfile/in-memory cache (bytes or with k/m/g suffix). "
            "Larger responses are streamed and cached as disk-backed blobs. "
            "Default: 1g (can also be set via ARTISAN_MITM_MAX_CACHE_BYTES)."
        ),
    )

    mitm_p.add_argument(
        "--stream-threshold-bytes",
        default=None,
        help=(
            "Max response size eligible for disk blob caching (bytes or with k/m/g suffix). "
            "Responses larger than --max-cache-bytes are streamed; if they also fit under this limit, "
            "they are cached as disk-backed blobs (suitable for multi-GB downloads). "
            "Default: 10g (can also be set via ARTISAN_MITM_STREAM_THRESHOLD_BYTES)."
        ),
    )
    mitm_p.add_argument(
        "--hosts",
        default=None,
        help=("Comma-separated host substrings to intercept (default: 'zenodo.org'). Example: --hosts zenodo.org"),
    )

    mode_g = mitm_p.add_mutually_exclusive_group()
    mode_g.add_argument("--ui", action="store_true", help="Run interactive TUI (mitmproxy)")
    mode_g.add_argument("--web", action="store_true", help="Run web UI (mitmweb)")

    mitm_p.add_argument(
        "--bin",
        default=None,
        help=(
            "Override which executable to run (e.g. 'mitmdump', 'mitmproxy', 'mitmweb', or a full path). "
            "If set, it overrides --ui/--web."
        ),
    )

    mitm_p.add_argument("--listen-host", default=None, help="mitmproxy listen host")
    mitm_p.add_argument("--listen-port", type=int, default=8082, help="mitmproxy listen port")

    mitm_p.add_argument(
        "mitm_args",
        nargs=argparse.REMAINDER,
        help="Extra args passed to mitmproxy after '--' (example: artisan mitm -- --set block_global=false)",
    )

    mitm_p.set_defaults(func=_mitm_from_cli)
