#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Dict, List, Tuple


INSTANCE_KEY_RE = re.compile(r"^(?P<artifact>.+)-t(?P<table>\d+)-r(?P<run>\d+)$")
TABLE_DIR_RE = re.compile(r"^table_(?P<table>\d+)$")


@dataclass(frozen=True)
class RunFolder:
    path: Path
    artifact: str
    table_index: int
    run_id: str  # e.g. 130122-420914

    @property
    def key_prefix(self) -> str:
        return f"{self.artifact}-t{self.table_index}-r"


# -------------------------
# JSON helpers
# -------------------------
def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def get_expected_costs(reprobench_path: Path) -> Dict[str, float]:
    """
    Returns mapping: instance_key -> expected_cost
    instance_key is like: 'action-t1-r1'
    """
    data = load_json(reprobench_path)
    inst = data.get("instance", {})
    if not isinstance(inst, dict):
        raise ValueError(f"Unexpected format: {reprobench_path} has no dict field 'instance'")

    expected: Dict[str, float] = {}
    for k, v in inst.items():
        if not isinstance(v, dict):
            continue
        cost = v.get("cost", None)
        if isinstance(cost, (int, float)) and not math.isnan(float(cost)):
            expected[k] = float(cost)
    return expected


def extract_instance_cost_from_mini(mini_path: Path) -> Optional[float]:
    """
    mini.json format:
      {
        "info": {
          "model_stats": { "instance_cost": ... }
        }
      }
    """
    try:
        d = load_json(mini_path)
    except Exception:
        return None

    info = d.get("info", {})
    if not isinstance(info, dict):
        return None
    ms = info.get("model_stats", {})
    if not isinstance(ms, dict):
        return None

    val = ms.get("instance_cost", None)
    if isinstance(val, (int, float)):
        x = float(val)
        if not math.isnan(x):
            return x

    return None


# -------------------------
# Scan folders
# -------------------------
def iter_run_folders(root: Path) -> List[RunFolder]:
    """
    Finds run folders:
      root/<artifact>/table_<k>/<run_id>/
    """
    runs: List[RunFolder] = []

    for table_dir in root.rglob("table_*"):
        if not table_dir.is_dir():
            continue
        m = TABLE_DIR_RE.match(table_dir.name)
        if not m:
            continue

        table_index = int(m.group("table"))
        artifact_dir = table_dir.parent
        if not artifact_dir.is_dir():
            continue
        artifact = artifact_dir.name

        for run_dir in table_dir.iterdir():
            if not run_dir.is_dir():
                continue
            runs.append(RunFolder(path=run_dir, artifact=artifact, table_index=table_index, run_id=run_dir.name))

    return runs


def find_best_expected_key(expected_costs: Dict[str, float], artifact: str, table_index: int) -> Optional[str]:
    """
    Prefer r1 key, else choose smallest run number available.
    """
    r1_key = f"{artifact}-t{table_index}-r1"
    if r1_key in expected_costs:
        return r1_key

    prefix = f"{artifact}-t{table_index}-r"
    candidates: List[Tuple[int, str]] = []
    for k in expected_costs.keys():
        if not k.startswith(prefix):
            continue
        m = INSTANCE_KEY_RE.match(k)
        if not m:
            continue
        r = int(m.group("run"))
        candidates.append((r, k))

    if not candidates:
        return None

    candidates.sort(key=lambda x: x[0])
    return candidates[0][1]


def parse_instance_key(key: str) -> Optional[Tuple[str, int, int]]:
    """
    Parse: artifact-t<table>-r<run>
      crossover-t4-r1 -> ("crossover", 4, 1)
    """
    if "-t" not in key or "-r" not in key:
        return None
    try:
        artifact, rest = key.split("-t", 1)
        t_str, r_str = rest.split("-r", 1)
        t = int(t_str)
        r = int(r_str)
        return artifact, t, r
    except Exception:
        return None


def find_candidate_mini_paths(root: Path, artifact: str, table_index: int) -> List[Path]:
    """
    root/<artifact>/table_<table_index>/*/mini.json
    """
    table_dir = root / artifact / f"table_{table_index}"
    if not table_dir.is_dir():
        return []
    out: List[Path] = []
    for run_dir in table_dir.iterdir():
        if not run_dir.is_dir():
            continue
        mini = run_dir / "mini.json"
        if mini.exists():
            out.append(mini)
    return out


# -------------------------
# Match logic
# -------------------------
def nearly_equal(a: float, b: float, rel: float = 1e-12, abs_: float = 1e-12) -> bool:
    return abs(a - b) <= max(abs_, rel * max(abs(a), abs(b)))


def cost_matches(expected_cost: float, mini_cost: float, tolerance: float) -> bool:
    if tolerance > 0:
        return abs(mini_cost - expected_cost) <= tolerance
    return nearly_equal(mini_cost, expected_cost)


def delete_dir(path: Path, apply: bool) -> None:
    if apply:
        shutil.rmtree(path)


# -------------------------
# Mapping print
# -------------------------
def print_reprobench_to_mini_mapping(root: Path, expected_costs: Dict[str, float], tolerance: float) -> None:
    """
    Prints:
      key --> artifact/table_k/run_id/mini.json (mini_cost)
    based on remaining folders on disk.
    """
    mapping: Dict[str, Tuple[Path, float]] = {}
    missing: List[str] = []
    ambiguous: List[str] = []

    for key, expected_cost in sorted(expected_costs.items()):
        parsed = parse_instance_key(key)
        if parsed is None:
            missing.append(key)
            continue

        artifact, t, _r = parsed
        candidates = find_candidate_mini_paths(root, artifact, t)
        if not candidates:
            missing.append(key)
            continue

        matches: List[Tuple[Path, float]] = []
        for mini_path in candidates:
            mini_cost = extract_instance_cost_from_mini(mini_path)
            if mini_cost is None:
                continue
            if cost_matches(expected_cost, mini_cost, tolerance):
                matches.append((mini_path, mini_cost))

        if not matches:
            missing.append(key)
            continue

        if len(matches) > 1:
            ambiguous.append(key)
            matches.sort(key=lambda x: x[0].stat().st_mtime, reverse=True)

        mapping[key] = matches[0]

    # Print mapping
    for key in sorted(mapping.keys()):
        mini_path, mini_cost = mapping[key]
        rel = mini_path.relative_to(root)
        print(f"{key} --> {rel} ({mini_cost})")

    # Summary
    if ambiguous:
        print()
        print("[warn] multiple matching mini.json remain for these keys (duplicates not fully cleaned):")
        for k in ambiguous:
            print(f"  - {k}")

    if missing:
        print()
        print("[warn] no matching mini.json found for these keys:")
        for k in missing:
            print(f"  - {k}")


# -------------------------
# Main cleanup
# -------------------------
def main() -> int:
    ap = argparse.ArgumentParser(
        description="Keep only run folders whose mini.json instance_cost matches reprobench.json cost; print mapping at end."
    )
    ap.add_argument(
        "root",
        nargs="?",
        default="~/artisan-logs/minisweagent-gpt5.1-301b",
        help="Root folder for the run (default: %(default)s)",
    )
    ap.add_argument(
        "--reprobench",
        default=None,
        help="Path to reprobench.json (default: <root>/reprobench.json)",
    )
    ap.add_argument(
        "--apply",
        action="store_true",
        help="Actually delete folders (otherwise dry-run).",
    )
    ap.add_argument(
        "--tolerance",
        type=float,
        default=0.0,
        help="Absolute tolerance for cost match (default: 0.0 uses exact-ish float compare).",
    )
    ap.add_argument(
        "--verbose",
        action="store_true",
        help="Print per-folder deletion decisions.",
    )

    args = ap.parse_args()

    root = Path(os.path.expanduser(args.root)).resolve()
    reprobench_path = (
        Path(os.path.expanduser(args.reprobench)).resolve()
        if args.reprobench
        else (root / "reprobench.json")
    )

    if not root.exists():
        print(f"[error] root does not exist: {root}", file=sys.stderr)
        return 2
    if not reprobench_path.exists():
        print(f"[error] reprobench.json not found: {reprobench_path}", file=sys.stderr)
        return 2

    expected_costs = get_expected_costs(reprobench_path)
    expected_count = len(expected_costs)

    runs = iter_run_folders(root)

    # Group by (artifact, table_index): duplicates correspond to multiple run_id folders under same instance
    by_instance: Dict[Tuple[str, int], List[RunFolder]] = {}
    for r in runs:
        by_instance.setdefault((r.artifact, r.table_index), []).append(r)

    deletions: List[Tuple[Path, str]] = []
    kept: List[RunFolder] = []

    for (artifact, table_index), group in sorted(by_instance.items()):
        expected_key = find_best_expected_key(expected_costs, artifact, table_index)
        if expected_key is None:
            for rf in group:
                deletions.append((rf.path, f"no_expected_key_for_{artifact}_table_{table_index}"))
            continue

        expected_cost = expected_costs[expected_key]

        good_candidates: List[RunFolder] = []
        bad_candidates: List[Tuple[RunFolder, str]] = []

        for rf in group:
            artisan_log = rf.path / "artisan.log"
            mini_json = rf.path / "mini.json"

            if not artisan_log.exists():
                bad_candidates.append((rf, "missing_artisan.log"))
                continue
            if not mini_json.exists():
                bad_candidates.append((rf, "missing_mini.json"))
                continue

            mini_cost = extract_instance_cost_from_mini(mini_json)
            if mini_cost is None:
                bad_candidates.append((rf, "mini.json_missing_instance_cost"))
                continue

            if not cost_matches(expected_cost, mini_cost, args.tolerance):
                bad_candidates.append((rf, f"cost_mismatch expected={expected_cost} mini={mini_cost}"))
                continue

            good_candidates.append(rf)

        for rf, reason in bad_candidates:
            deletions.append((rf.path, reason))

        if not good_candidates:
            continue

        # Keep exactly one good candidate.
        # Prefer most recent mini.json mtime, tie-breaker: lexicographically largest run_id.
        def score(rf: RunFolder) -> Tuple[float, str]:
            return ((rf.path / "mini.json").stat().st_mtime, rf.run_id)

        good_candidates.sort(key=score, reverse=True)
        best = good_candidates[0]
        kept.append(best)

        for rf in good_candidates[1:]:
            deletions.append((rf.path, "duplicate_good_run_kept_another"))

    # Print header
    if args.verbose:
        print(f"[info] root={root}")
        print(f"[info] reprobench={reprobench_path}")
        print(f"[info] expected_instances_in_reprobench={expected_count}")
        print(f"[info] discovered_run_folders={len(runs)}")
        print(f"[info] instance_groups={len(by_instance)}")
        print()

    # Execute deletions
    for p, reason in deletions:
        if args.verbose:
            print(f"[delete]{' (dry-run)' if not args.apply else ''} {p}  reason={reason}")
        delete_dir(p, apply=args.apply)

    # Recount after deletion (if apply)
    remaining_runs = iter_run_folders(root)
    remaining_with_both = 0
    artisan_logs = 0
    mini_jsons = 0

    for rf in remaining_runs:
        if (rf.path / "artisan.log").exists():
            artisan_logs += 1
        if (rf.path / "mini.json").exists():
            mini_jsons += 1
        if (rf.path / "artisan.log").exists() and (rf.path / "mini.json").exists():
            remaining_with_both += 1

    print("[summary]")
    print(f"  expected_instances_in_reprobench : {expected_count}")
    print(f"  discovered_run_folders_before    : {len(runs)}")
    print(f"  kept_run_folders_target          : {len(kept)}")
    print(f"  folders_marked_for_deletion      : {len(deletions)}")
    print(f"  actually_deleted                 : {len(deletions) if args.apply else 0} (apply={args.apply})")
    print(f"  remaining_run_folders_now        : {len(remaining_runs)}")
    print(f"  remaining_artisan.log_count      : {artisan_logs}")
    print(f"  remaining_mini.json_count        : {mini_jsons}")
    print(f"  remaining_folders_with_both      : {remaining_with_both}")
    print()

    # Always print the reprobench-key -> mini.json mapping at the end
    print("[mapping: reprobench key -> mini.json]")
    print_reprobench_to_mini_mapping(root=root, expected_costs=expected_costs, tolerance=args.tolerance)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
