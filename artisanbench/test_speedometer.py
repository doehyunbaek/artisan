import argparse
import concurrent.futures
import json
import logging
import re
import subprocess
import threading
import time
import traceback
import platform
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from rich.live import Live

# Ensure repository root is on sys.path so package imports work when
# executing this file directly (e.g., `uv run artisanbench/test_speedometer.py`).
_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from artisanbench.runner import RunBatchProgressManager
from artisan import speedometer

logger = logging.getLogger("artisan.test_speedometer")

# Avoid importing `artisan` at module import time because it requires an
# OPENAI_API_KEY in the environment. Compute repository root relative to this
# file instead of relying on artisan.util.
_BENCHMARK_LOCK = threading.Lock()
_DUMP_LOCK = threading.Lock()

# Pre-load benchmark mapping: paper_id -> tables
_BENCH_PATH = _REPO_ROOT / "artisanbench" / "metadata.json"
_BENCH_DATA = json.loads(_BENCH_PATH.read_text(encoding="utf-8"))
_PAPER_TABLES: dict[str, dict] = {entry.get("id"): entry.get("tables", {}) for entry in _BENCH_DATA}


def _checked_tables() -> set[tuple[str, str]]:
    # Use the pre-loaded benchmark data
    data = _BENCH_DATA
    checked: set[tuple[str, str]] = set()
    for paper in data:
        paper_id = paper.get("id")
        if not paper_id:
            continue
        for idx, meta in (paper.get("tables") or {}).items():
            if isinstance(meta, dict) and meta.get("ground-truth-checked"):
                checked.add((paper_id, str(idx)))
    return checked


_SCRIPT_NAME_RE = re.compile(r"(?P<paper>.+)_table_(?P<idx>\d+)$")


def _iter_sh_scripts(root: Path) -> list[Path]:
    if not root.exists() or not root.is_dir():
        return []
    return sorted(root.rglob("*.sh"))


def _parse_script_identity(script: Path) -> tuple[str, str] | None:
    """Return (paper_id, table_idx) parsed from '<paper>_table_<idx>.sh'."""
    m = _SCRIPT_NAME_RE.match(script.stem)
    if not m:
        return None
    return m.group("paper"), m.group("idx")


def _load_instances(repeat: int = 1, *, skip_checked: bool = False) -> list[dict]:
    """Load reprobench instances.

    Behavior:
    - Non-copy scripts: `artisanbench/scripts/**/*.sh`
        * expected kind from metadata.json ('repro-kind')
    - Copy scripts: `artisanbench/copy_scripts/**/*.sh`
        * expected kind is always 'copy'
    """
    scripts_dir = _REPO_ROOT / "artisanbench" / "scripts"
    copy_scripts_dir = _REPO_ROOT / "artisanbench" / "copy_scripts"

    normd: list[dict] = []
    checked = _checked_tables() if skip_checked else set()

    # -------------------------------------------------------------------------
    # Non-copy instances from evaluation/scripts
    # -------------------------------------------------------------------------
    for script in _iter_sh_scripts(scripts_dir):
        parsed = _parse_script_identity(script)
        if not parsed:
            continue
        paper, tidx = parsed

        if skip_checked and (paper, str(tidx)) in checked:
            continue

        tables = _PAPER_TABLES.get(paper) or {}
        meta = tables.get(str(int(tidx))) if tidx.isdigit() else None
        expected = meta.get("repro-kind") if isinstance(meta, dict) else None

        # If a script exists but no expected kind exists, skip (same as before)
        if expected is None:
            continue

        for r in range(1, repeat + 1):
            rid = f"{expected}:{paper}-t{tidx}-r{r}"
            normd.append(
                {
                    "instance_id": rid,
                    "paper_id": paper,
                    "table_idx": tidx,
                    "script_path": str(script),
                    "expected": expected,
                }
            )

    # -------------------------------------------------------------------------
    # Copy instances from evaluation/copy_scripts
    # -------------------------------------------------------------------------
    for script in _iter_sh_scripts(copy_scripts_dir):
        parsed = _parse_script_identity(script)
        if not parsed:
            continue
        paper, tidx = parsed

        if skip_checked and (paper, str(tidx)) in checked:
            continue

        expected = "copy"
        for r in range(1, repeat + 1):
            rid = f"{expected}:{paper}-t{tidx}-r{r}"
            normd.append(
                {
                    "instance_id": rid,
                    "paper_id": paper,
                    "table_idx": tidx,
                    "script_path": str(script),
                    "expected": expected,
                }
            )

    return normd


def filter_instances(instances: list[dict], *, filter_spec: str) -> list[dict]:
    """Filter a list of instances by instance_id."""
    instances = [instance for instance in instances if re.match(filter_spec, instance["instance_id"])]
    return instances


def _append_jsonl(path: Path, record: dict) -> None:
    """Thread-safe append of one JSON record to a JSONL file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(record, ensure_ascii=False, sort_keys=True)
    with _DUMP_LOCK:
        with path.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
            f.flush()


def process_instance(
    instance: dict,
    progress_manager: RunBatchProgressManager,
    agentic: bool = False,
    dump_json: Path | None = None,
) -> tuple[str, str] | None:
    """Process a single reprobench instance as one `artisan run`."""
    instance_id = instance["instance_id"]
    expected = instance.get("expected")
    script_path = Path(instance["script_path"])

    if expected is None:
        raise RuntimeError(f"Missing expected repro-kind for {instance_id}")

    progress_manager.on_instance_start(instance_id)
    progress_manager.update_instance_status(instance_id, "Starting run")

    exit_status = "NEED_TRIAGE"
    speed = None
    script_text = None
    res: dict | None = None
    err: BaseException | None = None
    started_at = datetime.now(timezone.utc).isoformat()
    t0 = time.time()

    try:
        # Read script text
        script_text = script_path.read_text(encoding="utf-8")

        # Run the LLM-powered speedometer
        if agentic:
            res = speedometer.analyze_script_agentic(script_text, script_path)
        else:
            res = speedometer.analyze_script(script_text)

        speed = res.get("speed")
        if not isinstance(speed, str):
            raise RuntimeError("speedometer returned invalid result")

        from minisweagent.models import GLOBAL_MODEL_STATS

        # cost is recorded for metrics and also emitted into dump-json if enabled
        GLOBAL_MODEL_STATS.add(float(res["cost"]))

        # Normalize exit status: use concise labels for the report.
        if speed == expected:
            exit_status = "Match"
            progress_manager.update_instance_status(instance_id, f"Match: {speed}")
        else:
            # Format: Mismatch-<ground> --> <pred>
            exit_status = f"Mismatch:{expected} --> {speed}"
            progress_manager.update_instance_status(instance_id, f"Predicted: {speed} (expected {expected})")

    except Exception as e:
        err = e
        logger.error(
            f"Error processing instance {instance_id}: {e}",
            exc_info=True,
        )
        # Record the error as the exit status
        exit_status = type(e).__name__

    finally:
        t1 = time.time()
        ended_at = datetime.now(timezone.utc).isoformat()

        # Crucial: always mark the instance as finished with *some* status
        progress_manager.on_instance_end(instance_id, exit_status)

        # Optional: dump full input/output for reproducibility
        if dump_json is not None:
            record = {
                "schema_version": 1,
                "type": "instance_record",
                "run": {
                    "started_at_utc": started_at,
                    "ended_at_utc": ended_at,
                    "duration_sec": round(t1 - t0, 6),
                    "agentic": bool(agentic),
                    "python": sys.version,
                    "platform": platform.platform(),
                    "argv": sys.argv,
                },
                "instance": {
                    "instance_id": instance_id,
                    "paper_id": instance.get("paper_id"),
                    "table_idx": instance.get("table_idx"),
                    "script_path": str(script_path),
                },
                "io": {
                    "script_text": script_text,
                    "expected": expected,
                    "predicted": speed,
                    "exit_status": exit_status,
                    "speedometer_result": res,
                },
            }
            if err is not None:
                record["error"] = {
                    "type": type(err).__name__,
                    "message": str(err),
                    "traceback": traceback.format_exc(),
                }
            _append_jsonl(dump_json, record)

        if speed is not None:
            return expected, speed
        return None


def check_scripts(
    filter_spec: str = "",
    workers: int = 1,
    repeat: int = 1,
    skip_checked: bool = False,
    agentic: bool = False,
    dump_json: str | None = None,
) -> None:
    instances = _load_instances(repeat, skip_checked=skip_checked)
    print(f"Loaded {len(instances)} tasks.")
    instances = filter_instances(instances, filter_spec=filter_spec)
    print(f"Running on {len(instances)} tasks...")

    dump_path = Path(dump_json) if dump_json else None
    if dump_path is not None:
        dump_path.parent.mkdir(parents=True, exist_ok=True)
        # Write a "run header" record for provenance (JSONL)
        header = {
            "schema_version": 1,
            "type": "run_header",
            "created_at_utc": datetime.now(timezone.utc).isoformat(),
            "repo_root": str(_REPO_ROOT),
            "bench_path": str(_BENCH_PATH),
            "args": {
                "filter": filter_spec,
                "workers": workers,
                "repeat": repeat,
                "skip_checked": skip_checked,
                "agentic": agentic,
            },
        }
        _append_jsonl(dump_path, header)

    progress_manager = RunBatchProgressManager(len(instances))
    results: list[tuple[str, str]] = []

    # Aggregates (include errors and cancellations; results only captures successful preds)
    agg_total = len(instances)
    agg_done = 0
    agg_errors = 0
    agg_matches = 0
    agg_mismatches = 0
    agg_exit_status_counts: Counter[str] = Counter()

    def process_futures(futures: dict[concurrent.futures.Future, str]):
        nonlocal agg_done, agg_errors, agg_matches, agg_mismatches
        for future in concurrent.futures.as_completed(futures):
            instance_id = futures[future]
            try:
                res = future.result()
                agg_done += 1
                if res:
                    results.append(res)
                    exp, pred = res
                    if exp == pred:
                        agg_matches += 1
                    else:
                        agg_mismatches += 1
                else:
                    agg_errors += 1
                    agg_exit_status_counts["ErrorOrNoPrediction"] += 1
            except concurrent.futures.CancelledError:
                agg_exit_status_counts["CancelledError"] += 1
            except Exception as e:
                agg_done += 1
                agg_errors += 1
                agg_exit_status_counts[type(e).__name__] += 1
                logger.error(f"Error in future for instance {instance_id}: {e}", exc_info=True)
                progress_manager.on_uncaught_exception(instance_id, e)

    with Live(progress_manager.render_group, refresh_per_second=4):
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(process_instance, instance, progress_manager, agentic, dump_path): instance[
                    "instance_id"
                ]
                for instance in instances
            }
            try:
                process_futures(futures)
            except KeyboardInterrupt:
                print("Cancelling all pending jobs. Press ^C again to exit immediately.")
                for future in futures:
                    if not future.running() and not future.done():
                        future.cancel()
                process_futures(futures)

    # Confusion matrix
    kinds = ["full", "lastmile", "copy"]
    matrix = {k: {p: 0 for p in kinds} for k in kinds}
    for exp, pred in results:
        if exp in kinds and pred in kinds:
            matrix[exp][pred] += 1

    # Print LaTeX table
    print("\nConfusion Matrix (LaTeX):")
    print(r"\begin{tabular}{l|ccc}")
    print(r"            \toprule")
    print(r"            \textbf{Actual} $\backslash$ \textbf{Pred} & \textbf{Full} & \textbf{Last} & \textbf{Copy} \\")
    print(r"            \midrule")

    row_labels = {"full": "Full", "lastmile": "Last-Mile", "copy": "Copy"}
    for k in kinds:
        row = [str(matrix[k][p]) for p in kinds]
        print(f"            \\textbf{{{row_labels[k]}}} & {' & '.join(row)} \\\\")

    print(r"            \bottomrule")
    print(r"        \end{tabular}")

    # Dump aggregated stats at end (JSONL)
    if dump_path is not None:
        # Precision/recall per kind
        recall: dict[str, float | None] = {}
        precision: dict[str, float | None] = {}
        for k in kinds:
            row_sum = sum(matrix[k][p] for p in kinds)
            col_sum = sum(matrix[a][k] for a in kinds)
            tp = matrix[k][k]
            recall[k] = (tp / row_sum) if row_sum else None
            precision[k] = (tp / col_sum) if col_sum else None

        summary = {
            "schema_version": 1,
            "type": "run_summary",
            "created_at_utc": datetime.now(timezone.utc).isoformat(),
            "args": {
                "filter": filter_spec,
                "workers": workers,
                "repeat": repeat,
                "skip_checked": skip_checked,
                "agentic": agentic,
            },
            "counts": {
                "instances_total": agg_total,
                "instances_done": agg_done,
                "matches": agg_matches,
                "mismatches": agg_mismatches,
                "errors": agg_errors,
                "exit_status_counts": dict(agg_exit_status_counts),
            },
            "confusion_matrix": matrix,
            "metrics": {
                "precision": precision,
                "recall": recall,
            },
        }
        _append_jsonl(dump_path, summary)


def main() -> int:
    """Standalone CLI entrypoint for batch reprobench runner.

    Example:
      python artisanbench/check_scripts.py --filter "^paper1" --workers 4 --repeat 2
      python artisanbench/check_scripts.py --dump-json runs/speedometer_io.jsonl
    """
    parser = argparse.ArgumentParser(description="Run multiple reproduction benchmark instances (batch mode).")
    parser.add_argument(
        "-f",
        "--filter",
        default="",
        help="Regex to filter instance IDs",
    )
    parser.add_argument(
        "-w",
        "--workers",
        type=int,
        default=8,
        help="Number of parallel worker threads",
    )
    parser.add_argument(
        "-r",
        "--repeat",
        type=int,
        default=1,
        help="Repeat count for each table instance",
    )
    parser.add_argument(
        "--skip-checked",
        action="store_true",
        help="Skip instances already marked ground_truth_checked in metadata.json",
    )
    parser.add_argument(
        "--agentic",
        action="store_true",
        help="Use agentic mode for speedometer",
    )
    parser.add_argument(
        "--dump-json",
        metavar="PATH",
        default=None,
        help="Append JSONL records of per-instance input/output for reproducibility (e.g., runs/speedometer_io.jsonl)",
    )
    args = parser.parse_args()
    check_scripts(args.filter, args.workers, args.repeat, args.skip_checked, args.agentic, args.dump_json)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
