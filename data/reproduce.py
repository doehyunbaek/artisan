#!/usr/bin/env python3
"""Run last-mile artifact reproduction end to end.

This script regenerates the abstract, restores logs, regenerates tables and
figures, builds the compact ASE wrapper PDF, and writes ase-artisan.pdf.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

DATA_ROOT = Path(__file__).resolve().parent
REPO_ROOT = DATA_ROOT.parent
TEX_DIR = DATA_ROOT / "tex"
LOGS_DIR = DATA_ROOT / "logs"
ASE_TEX = TEX_DIR / "ase.tex"
ASE_PDF = TEX_DIR / "ase.pdf"
OUTPUT_NAME = "ase-artisan.pdf"


def run(argv: list[str], cwd: Path) -> None:
    print(f"\n$ {' '.join(argv)}", flush=True)
    subprocess.run(argv, cwd=cwd, check=True)


def logs_present() -> bool:
    if not LOGS_DIR.exists():
        return False
    return any(LOGS_DIR.iterdir())


def copy_output_pdf(output_dir: Path | None = None) -> list[Path]:
    if not ASE_PDF.exists():
        raise FileNotFoundError(f"expected PDF was not produced: {ASE_PDF}")

    destinations = [TEX_DIR / OUTPUT_NAME, REPO_ROOT / OUTPUT_NAME]
    if output_dir is not None:
        output_dir.mkdir(parents=True, exist_ok=True)
        destinations.append(output_dir / OUTPUT_NAME)

    written: list[Path] = []
    for destination in destinations:
        shutil.copy2(ASE_PDF, destination)
        written.append(destination)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Artisan last-mile reproduction end to end")
    parser.add_argument(
        "--force-download",
        action="store_true",
        help="download and restore logs even if data/logs is already present",
    )
    default_output_dir = os.environ.get("ARTISAN_OUTPUT_DIR")
    if default_output_dir is None and Path("/output").exists():
        default_output_dir = "/output"
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(default_output_dir) if default_output_dir else None,
        help="directory where ase-artisan.pdf should also be copied; defaults to /output when mounted",
    )
    args = parser.parse_args()

    os.environ.setdefault("MPLBACKEND", "Agg")

    if not ASE_TEX.exists():
        raise FileNotFoundError(f"missing LaTeX wrapper: {ASE_TEX}")

    print("== Step 1: Restore logs ==", flush=True)
    if logs_present() and not args.force_download:
        print(f"Logs already present at {LOGS_DIR}; skipping download.", flush=True)
    else:
        run([sys.executable, "download_logs.py"], DATA_ROOT)

    print("\n== Step 2: Regenerate the abstract ==", flush=True)
    run([sys.executable, "abstract.py"], DATA_ROOT)

    print("\n== Step 3: Regenerate tables ==", flush=True)
    run([sys.executable, "table.py"], DATA_ROOT)

    print("\n== Step 4: Regenerate figures ==", flush=True)
    run([sys.executable, "figure.py"], DATA_ROOT)

    print("\n== Step 5: Build the compact ASE wrapper PDF ==", flush=True)
    pdflatex = ["pdflatex", "-shell-escape", "-interaction=nonstopmode", "-halt-on-error", "ase.tex"]
    run(pdflatex, TEX_DIR)
    run(["bibtex", "ase"], TEX_DIR)
    run(pdflatex, TEX_DIR)
    run(pdflatex, TEX_DIR)

    output_dir = args.output_dir if args.output_dir else None
    written = copy_output_pdf(output_dir)
    print("\n== Done ==", flush=True)
    for path in written:
        print(f"Wrote {path}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
