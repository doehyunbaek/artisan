#!/usr/bin/env python3
"""Download and restore Artisan log files under data/logs.

This script downloads the v0.0.1 release archive and extracts only the
large log artifacts (.traj, .json, .log) under the logs directory.
"""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
import urllib.request
from pathlib import Path
from zipfile import ZipFile

URL = "https://github.com/doehyunbaek/artisan/releases/download/v0.0.1/artisan_2602_logs.zip"
ARCHIVE_PREFIX = "artisan-logs/"
EXTENSIONS = {".traj", ".json", ".log"}
DATA_DIR = Path(__file__).resolve().parent
LOGS_DIR = DATA_DIR / "logs"


def is_target_member(name: str) -> bool:
    return Path(name).suffix in EXTENSIONS


def safe_destination(member_name: str, dest_root: Path) -> Path:
    """Map a zip member to a safe path under dest_root."""
    rel = member_name[len(ARCHIVE_PREFIX) :] if member_name.startswith(ARCHIVE_PREFIX) else member_name
    rel_path = Path(rel)

    if rel_path.is_absolute() or ".." in rel_path.parts:
        raise ValueError(f"unsafe archive path: {member_name!r}")

    dest = (dest_root / rel_path).resolve()
    root = dest_root.resolve()
    if root not in dest.parents and dest != root:
        raise ValueError(f"archive path escapes destination: {member_name!r}")
    return dest


def download(url: str, out_path: Path) -> None:
    print(f"Downloading {url}")
    print(f" -> {out_path}")
    with urllib.request.urlopen(url) as response, out_path.open("wb") as out:
        shutil.copyfileobj(response, out)


def extract_targets(zip_path: Path, dest_root: Path, *, dry_run: bool = False) -> tuple[int, int]:
    files = 0
    bytes_written = 0

    with ZipFile(zip_path) as zf:
        for info in zf.infolist():
            if info.is_dir() or not is_target_member(info.filename):
                continue

            dest = safe_destination(info.filename, dest_root)
            files += 1
            bytes_written += info.file_size

            if dry_run:
                print(dest)
                continue

            dest.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(info) as src, dest.open("wb") as dst:
                shutil.copyfileobj(src, dst)

    return files, bytes_written


def main() -> int:
    parser = argparse.ArgumentParser(description="Restore .traj, .json, and .log files under ~/artisan/data/logs")
    parser.add_argument("--url", default=URL, help="zip archive URL")
    parser.add_argument("--dest", type=Path, default=LOGS_DIR, help="destination logs directory")
    parser.add_argument("--zip", dest="zip_path", type=Path, help="use an existing zip instead of downloading")
    parser.add_argument("--keep-zip", action="store_true", help="keep the downloaded zip file")
    parser.add_argument("--dry-run", action="store_true", help="list files that would be restored without writing them")
    args = parser.parse_args()

    dest = args.dest.expanduser().resolve()

    if args.zip_path:
        zip_path = args.zip_path.expanduser().resolve()
        cleanup_dir = None
    else:
        cleanup_dir = tempfile.TemporaryDirectory(prefix="artisan-logs-")
        zip_path = Path(cleanup_dir.name) / "artisan_2602_logs.zip"
        download(args.url, zip_path)

    try:
        count, total = extract_targets(zip_path, dest, dry_run=args.dry_run)
        action = "Would restore" if args.dry_run else "Restored"
        print(f"{action} {count} files ({total / 1024 / 1024:.2f} MiB) into {dest}")

        if args.keep_zip and cleanup_dir is not None:
            kept = dest / zip_path.name
            shutil.move(str(zip_path), kept)
            print(f"Kept archive at {kept}")
    finally:
        if cleanup_dir is not None:
            cleanup_dir.cleanup()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
