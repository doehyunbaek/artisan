#!/usr/bin/env python3
"""
extract_manual_analysis_template.py

Given a reprobench JSON summary (like reprobench.json), output a Markdown template
grouped by exit_status (FULL_REPRO / LASTMILE_REPRO) for manual analysis.

Usage:
  python extract_manual_analysis_template.py reprobench.json > output.md
  python extract_manual_analysis_template.py reprobench.json -o output.md
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple


def _load_json(path: Path) -> Dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        raise SystemExit(f"ERROR: File not found: {path}")
    except json.JSONDecodeError as e:
        raise SystemExit(f"ERROR: Invalid JSON in {path}: {e}")


def _collect_instances(data: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    inst = data.get("instance")
    if not isinstance(inst, dict):
        raise SystemExit("ERROR: JSON does not contain an 'instance' object.")
    return inst


def _group_instances(instances: Dict[str, Dict[str, Any]]) -> Tuple[List[str], List[str], List[str]]:
    full: List[str] = []
    lastmile: List[str] = []
    copy: List[str] = []

    for instance_id, info in instances.items():
        if not isinstance(info, dict):
            continue
        status = info.get("exit_status")
        if status == "FULL_REPRO":
            full.append(instance_id)
        elif status == "LASTMILE_REPRO":
            lastmile.append(instance_id)
        elif status == "COPY_REPRO":
            copy.append(instance_id)

    full.sort()
    lastmile.sort()
    copy.sort()
    return full, lastmile, copy


def _render_markdown(full: List[str], lastmile: List[str], copy: List[str]) -> str:
    lines: List[str] = []

    lines.append("Full")
    for iid in full:
        lines.append(f'- "{iid}": ')
    lines.append("")  # blank line between sections

    lines.append("Lastmile")
    for iid in lastmile:
        lines.append(f'- "{iid}": ')

    lines.append("")

    lines.append("Copy")
    for iid in copy:
        lines.append(f'- "{iid}": ')

    lines.append("")  # trailing newline
    return "\n".join(lines)


# Note: copy-template functionality removed; COPY_REPRO is now grouped and
# rendered in the main Markdown output.


def main(argv: List[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="Extract a manual analysis Markdown template from a reprobench JSON summary."
    )
    p.add_argument("json_path", type=Path, help="Path to reprobench.json")
    p.add_argument("-o", "--output", type=Path, default=None, help="Write output Markdown to this file")
    args = p.parse_args(argv)

    data = _load_json(args.json_path)
    instances = _collect_instances(data)
    full, lastmile, copy = _group_instances(instances)
    md = _render_markdown(full, lastmile, copy)

    if args.output is None:
        sys.stdout.write(md)
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(md, encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
