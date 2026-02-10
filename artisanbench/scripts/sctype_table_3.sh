#!/usr/bin/bash
docker pull icse24sctype/full:latest
docker run -d --name sctype --entrypoint /bin/sh icse24sctype/full:latest -c "sleep infinity"
docker exec sctype sh -c './test_benchmark_final.sh' > /workspace/repro.txt

echo '<artisan_submit>'
python3 - <<'PY'
#!/usr/bin/env python3
"""
Parse /workspace/repro.txt and print the markdown table shown in the prompt.

Usage:
  python3 format_eval_table.py /workspace/repro.txt
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from typing import Dict, List, Optional


@dataclass
class Row:
    project: str
    summary: str
    annotations: int
    warnings: int


# --- Expected table metadata (names + summaries + order) ----------------------

EXPECTED: List[tuple[str, str]] = [
    ("MarginSwap", "Dex project for margin trading on Uniswap and Sushiswap"),
    ("Vader Protocol", "Yield project for a collateralized stablecoin"),
    ("PoolTogether", "Gaming service on yield interest"),
    ("Tracer", "Derivative project that supports perpetual markets"),
    ("Yield Micro", "Lending project supporting borrowing, lending, and liquidity"),
    ("Sushi Trident", "Dex project for deploying personalized liquidity markets"),
    ("yAxis", "Yield project where users’ aggregated funds are used in strategies for yield"),
    ("Badger Dao", "Yield project"),
    ("Wild Credit", "Lending project relying on pairs of assets instead of a pool"),
    ("PoolTogether v4", "Gaming service on yield interest"),
    ("Sushi Trident p2", "Dex project for deploying personalized liquidity markets"),
    ("Swell", "Yield project that uses set orders for Yield claiming"),
    ("Covalent", "Users delegate commissions to a Validators, which stakes the funds for interest"),
    ("yAxis p2", "Yield project where users’ aggregated funds are used in strategies for yield"),
    ("Perennial", "Derivative project supporting synthetic token perpetual markets"),
    ("Yeti Finance", "Lending project made against a contract specific token"),
    ("Vader Protocol p3", "Yield project for a collateralized stablecoin"),
    ("InsureDao", "Insurance markets where buyers pay premium for protection against losses"),
    ("Rocket Joe", "Dex project where users exchange funds in return for new project liquidity"),
    ("Concur Finance", "Yield project"),
    ("Biconomy Hyphen", "Cross Chain project where users can deposit and withdraw for pools on different chains"),
    ("Volt", "Dex project which conserves the value of user funds against inflation"),
    ("Badger Dao p3", "Yield project"),
    ("Tigris Trade", "Dex project utilizing off-chain oracles to provide real-time prices"),
]
SUMMARY_BY_PROJECT: Dict[str, str] = dict(EXPECTED)
EXPECTED_ORDER: List[str] = [p for p, _ in EXPECTED]


# --- Normalization of project names found in the raw log ----------------------

NAME_MAP = {
    # typos / formatting
    "Sushi Tridnet": "Sushi Trident",
    "Pool Together v4": "PoolTogether v4",
    "BadgerDao": "Badger Dao",
    "Vader Protocol P1": "Vader Protocol",
    "Sushi Trident": "Sushi Trident",  # keep as-is
    "Sushi Trident p2": "Sushi Trident p2",
    "Vader Protocol p3": "Vader Protocol p3",
    # In the provided expected table, "Swell" corresponds to the log entry "Swivel"
    "Swivel": "Swell",
}

def normalize_project_name(raw: str) -> str:
    raw = raw.strip()
    raw = re.sub(r"\s+", " ", raw)
    return NAME_MAP.get(raw, raw)


# --- Parser ------------------------------------------------------------------

ANN_RE = re.compile(r"^\s*Annotation count:\s*(\d+)\s*$")
TEST_RE = re.compile(r"^\s*\[\*\]\s*Tested\s*(\d+)\s*warnings?\s*(?:total\s*)?for\s*(.+?)\s*$")

def pick_project_slot(project: str, out: Dict[str, Row]) -> str:
    """
    If we see the same project name multiple times in the log, and the expected
    table has a '<name> p2' slot, put the 2nd occurrence there.
    """
    if project in out:
        p2 = f"{project} p2"
        if p2 in SUMMARY_BY_PROJECT and p2 not in out:
            return p2
    return project


def parse_rows(path: str) -> Dict[str, Row]:
    latest_ann: Optional[int] = None
    out: Dict[str, Row] = {}

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            m = ANN_RE.match(line)
            if m:
                latest_ann = int(m.group(1))
                continue

            m = TEST_RE.match(line)
            if m:
                warnings = int(m.group(1))
                proj_raw = m.group(2)
                project_norm = normalize_project_name(proj_raw)

                # Only keep projects that exist in the expected table
                # (but allow routing duplicates to "<name> p2")
                project = pick_project_slot(project_norm, out)
                if project not in SUMMARY_BY_PROJECT:
                    continue

                if latest_ann is None:
                    latest_ann = 0

                out[project] = Row(
                    project=project,
                    summary=SUMMARY_BY_PROJECT[project],
                    annotations=latest_ann,
                    warnings=warnings,
                )
                continue

    return out

# --- Markdown table writer ----------------------------------------------------

def md_escape(s: str) -> str:
    return s.replace("|", "\\|")

def print_table(rows_by_project: Dict[str, Row]) -> None:
    # Build rows in expected order; error if any are missing (so you notice drift)
    missing = [p for p in EXPECTED_ORDER if p not in rows_by_project]
    if missing:
        raise SystemExit(f"Missing projects in parsed output: {missing}")

    total_warnings = sum(rows_by_project[p].warnings for p in EXPECTED_ORDER)

    print("**Table 3: Evaluation Results**\n")
    print("| Project Name          | Summary                                                                                | Annotations | Total Warnings |")
    print("| --------------------- | -------------------------------------------------------------------------------------- | ----------: | -------------: |")

    for p in EXPECTED_ORDER:
        r = rows_by_project[p]
        print(
            f"| {md_escape(r.project):<21} "
            f"| {md_escape(r.summary):<86} "
            f"| {r.annotations:>10} "
            f"| {r.warnings:>13} |"
        )

    print(f"| **Total**             |                                                                                        |             | {total_warnings:>13} |")


def main(argv: List[str]) -> int:
    path = argv[1] if len(argv) > 1 else "/workspace/repro.txt"
    rows = parse_rows(path)
    print_table(rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
PY
echo '</artisan_submit>'
