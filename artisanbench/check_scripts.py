import argparse
import concurrent.futures
import json
import logging
import re
import subprocess
import sys
import threading
from pathlib import Path

from rich.live import Live

# Ensure repository root is on sys.path so package imports work when
# executing this file directly.
_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from artisanbench.runner import RunBatchProgressManager

import artisan
from artisan import util

logger = logging.getLogger("artisan.check_scripts")

_BENCHMARK_LOCK = threading.Lock()


def _checked_tables() -> set[tuple[str, str]]:
    benchmark_path = Path(util.find_repo_root()) / "artisanbench" / "metadata.json"
    data = json.loads(benchmark_path.read_text(encoding="utf-8"))
    checked: set[tuple[str, str]] = set()
    for paper in data:
        paper_id = paper.get("id")
        if not paper_id:
            continue
        for idx, meta in (paper.get("tables") or {}).items():
            if isinstance(meta, dict) and meta.get("ground-truth-checked"):
                checked.add((paper_id, str(idx)))
    return checked


def _mark_ground_truth_checked(paper_id: str, table_idx: str) -> None:
    benchmark_path = Path(util.find_repo_root()) / "artisanbench" / "metadata.json"
    with _BENCHMARK_LOCK:
        data = json.loads(benchmark_path.read_text(encoding="utf-8"))
        for paper in data:
            if paper.get("id") != paper_id:
                continue
            tables = paper.setdefault("tables", {})
            entry = tables.setdefault(str(table_idx), {})
            entry["ground-truth-checked"] = True
            benchmark_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            return


def _load_instances(repeat: int = 1, *, skip_checked: bool = False) -> list[dict]:
    """Load reprobench instances.

    Behavior:
    - If an `evaluation/scripts/` directory exists in the repo root, use each
      `*.sh` file (recursively) as one instance.
    - Otherwise, fall back to the original JSON benchmark format `path`.
    """
    repo_root = Path(util.find_repo_root())
    scripts_dir = repo_root / "artisanbench" / "scripts"
    copy_dir = scripts_dir / "copy"

    normd: list[dict] = []

    checked = _checked_tables() if skip_checked else set()

    if scripts_dir.exists() and scripts_dir.is_dir():
        for script in sorted(scripts_dir.rglob("*.sh")):
            try:
                script.relative_to(copy_dir)
            except ValueError:
                pass
            else:
                continue

            script_name = script.stem  # e.g. pythonic_table_3
            match = re.match(r"(?P<paper>.+)_table_(?P<idx>\d+)$", script_name)
            paper = match.group("paper")
            tidx = match.group("idx")
            if skip_checked and (paper, str(tidx)) in checked:
                continue
            for r in range(1, repeat + 1):
                rid = f"{paper}-t{tidx}-r{r}"
                normd.append(
                    {
                        "instance_id": rid,
                        "paper_id": paper,
                        "table_idx": tidx,
                        "script_path": str(script),
                    }
                )
        return normd


def filter_instances(instances: list[dict], *, filter_spec: str) -> list[dict]:
    """Filter a list of instances by instance_id."""
    instances = [instance for instance in instances if re.match(filter_spec, instance["instance_id"])]
    return instances


def process_instance(
    instance: dict,
    progress_manager: RunBatchProgressManager,
) -> None:
    """Process a single reprobench instance as one `artisan run`."""
    instance_id = instance["instance_id"]

    progress_manager.on_instance_start(instance_id)
    progress_manager.update_instance_status(instance_id, "Starting run")

    exit_status = "NEED_TRIAGE"

    try:
        stdout_text = subprocess.getoutput(f"uv run artisan submit {instance['script_path']}")
        print(stdout_text)

        m = re.search(artisan.SUCCESS_STRING, stdout_text)
        if m:
            exit_status = "Success"
            _mark_ground_truth_checked(instance["paper_id"], instance["table_idx"])
        else:
            m = re.search(r"Partial mismatch \(score:\s*([0-9]*\.?[0-9]+)\)", stdout_text)
            if m:
                score = float(m.group(1))
                percent = int(score * 100)
                threshold = (percent // 10) * 10
                exit_status = f"Partial (>{threshold}%)"

    except Exception as e:
        logger.error(
            f"Error processing instance {instance_id}: {e}",
            exc_info=True,
        )
        # You can choose whatever label you like for errors:
        exit_status = type(e).__name__

    finally:
        # Crucial: always mark the instance as finished with *some* status
        progress_manager.on_instance_end(instance_id, exit_status)


def check_scripts(filter_spec: str = "", workers: int = 1, repeat: int = 1, skip_checked: bool = False) -> None:
    instances = _load_instances(repeat, skip_checked=skip_checked)
    print(f"Loaded {len(instances)} tasks.")
    instances = filter_instances(instances, filter_spec=filter_spec)
    print(f"Running on {len(instances)} tasks...")
    # print(instances)

    progress_manager = RunBatchProgressManager(len(instances))

    def process_futures(futures: dict[concurrent.futures.Future, str]):
        for future in concurrent.futures.as_completed(futures):
            try:
                future.result()
            except concurrent.futures.CancelledError:
                pass
            except Exception as e:
                instance_id = futures[future]
                logger.error(f"Error in future for instance {instance_id}: {e}", exc_info=True)
                progress_manager.on_uncaught_exception(instance_id, e)

    with Live(progress_manager.render_group, refresh_per_second=4):
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(process_instance, instance, progress_manager): instance["instance_id"]
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


def main() -> int:
    """Standalone CLI entrypoint for batch reprobench runner.

    Example:
      python evaluation/check_scripts.py --filter "^paper1" --workers 4 --repeat 2
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
    args = parser.parse_args()
    check_scripts(args.filter, args.workers, args.repeat, args.skip_checked)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
