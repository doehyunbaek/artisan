import argparse
import concurrent.futures
import datetime
import json
import logging
import os
import re
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Callable, Sequence

from rich.live import Live

# Ensure repository root is on sys.path so package imports work when
# executing this file directly.
_REPO_ROOT = Path(__file__).resolve().parents[1]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from artisanbench.runner import RunBatchProgressManager

import artisan
from artisan import handle_paper, judge, util, speedometer
from artisan.tools import format

from artisanbench.agents import artisan as artisan_agent
from artisanbench.agents import minisweagent as miniswe_agent
from artisanbench.agents import sweagent as swe_agent
from artisanbench.agents import openhands as openhands_agent

logger = logging.getLogger("artisan.benchmark")

_REPROBENCH_DESCRIPTION = (
    "Batch runner equivalent to 'python artisanbench/benchmark.py'. Each instance maps to one 'artisan run'."
)
_AGENT_RUNNERS: dict[str, Callable] = {
    "artisan": artisan_agent.run_with_artisan,
    "minisweagent": miniswe_agent.run_with_minisweagent,
    "sweagent": swe_agent.run_with_sweagent,
    "openhands": openhands_agent.run_with_openhands,
}

_MODEL_MAPPING = {
    "gpt-5-nano": "gpt-5-nano-2025-08-07",
    "gpt-5-mini": "gpt-5-mini-2025-08-07",
    "gpt-5.1": "gpt-5.1-2025-11-13",
    "gpt-5": "gpt-5-2025-08-07",
    "gpt-5.2": "gpt-5.2-2025-12-11",
    "deepseek-reasoner": "deepseek/deepseek-reasoner",
}

simple_model_names = {
    "gpt-5.1": "gpt5.1",
    "gpt-5.1-2025-11-13": "gpt5.1",
    "gpt-5-mini": "gpt5mini",
    "gpt-5-mini-2025-08-07": "gpt5mini",
    "gpt-5-nano": "gpt5nano",
    "gpt-5-nano-2025-08-07": "gpt5nano",
    "gpt-5": "gpt5",
    "gpt-5-2025-08-07": "gpt5",
    "gpt-5.2": "gpt5.2",
    "gpt-5.2-2025-12-11": "gpt5.2",
    "deepseek/deepseek-reasoner": "deepseek-reasoner",
}


def _load_instances(path: Path, repeat: int = 1) -> list[dict]:
    """Load reprobench instances from JSON"""
    with open(path, "r") as f:
        data = json.load(f)
    normd: list[dict] = []
    try:
        for paper in data:
            id = paper.get("id")
            tables = paper.get("tables") or {}
            for tidx, table in tables.items():
                should_exclude = (
                    table.get("non-result")
                    or table.get("missing")
                    or table.get("non-deterministic")
                    or table.get("exceed-hardware")
                )
                if should_exclude is True:
                    continue
                for r in range(1, repeat + 1):
                    rid = f"{id}-t{tidx}-r{r}"
                    table_path = f"{util.find_repo_root()}/artisanbench/tables/{id}_table_{tidx}.md"
                    paper_path = f"{util.find_repo_root()}/artisanbench/papers/{id}.pdf"
                    normd.append(
                        {
                            "instance_id": rid,
                            "artifact": paper["artifact_url"],
                            "paper_path": paper_path,
                            "table_path": table_path,
                            "paper_id": id,
                            "table_idx": tidx,
                        }
                    )
    except Exception as e:
        print(f"Error paper: {paper}, table_path: {table_path}, tidx: {tidx}")
    return normd


def filter_instances(instances: list[dict], *, filter_spec: str) -> list[dict]:
    """Filter a list of instances by instance_id."""
    instances = [instance for instance in instances if re.match(filter_spec, instance["instance_id"])]
    return instances


def process_instance(
    instance: dict,
    progress_manager: RunBatchProgressManager,
    agent_name: str,
    model_name: str | None = None,
    log_root: Path | None = None,
    ablation: str | None = None,
) -> None:
    """Process a single reprobench instance as one `artisan run`."""
    instance_id = instance["instance_id"]
    progress_manager.on_instance_start(instance_id)
    progress_manager.update_instance_status(instance_id, "Starting run")

    exit_status = "NEED_TRIAGE"
    exit_reason = "Unknown"
    start_time = time.time()
    agent_time = 0.0
    cost = 0.0
    llm_time = 0.0
    exec_time = 0.0
    format_logs = []
    speedometer_logs = []
    try:
        traj_path, _ = _run_instance_with_agent(instance, agent_name, model_name, log_root, ablation)
        agent_time = time.time() - start_time
        workspace_dir = Path(traj_path).parent
        progress_manager.update_instance_status(instance_id, "Submitting to judge")
        exit_status, exit_reason, judge_format_logs, judge_speedometer_logs = _submit_workspace_result(
            workspace_dir, instance, ablation
        )
        if traj_path.exists():
            try:
                data = json.loads(traj_path.read_text())
                cost = data.get("info", {}).get("model_stats", {}).get("instance_cost", 0.0)
                llm_time = data.get("info", {}).get("model_stats", {}).get("llm_time", 0.0)

                # Calculate exec_time from messages
                for msg in data.get("messages", []):
                    if msg.get("role") == "user":
                        exec_time += msg.get("exec_time", 0.0)

                format_logs = data.get("info", {}).get("format", [])
                speedometer_logs = data.get("info", {}).get("speedometer", [])
            except Exception:
                pass

        # Deduplicate logs (artisan agent saves judge result to trajectory, causing duplication)
        seen_format = set()
        merged_format_logs = []
        for log in format_logs + judge_format_logs:
            key = (log.get("timestamp"), log.get("reason"), log.get("model"))
            if key not in seen_format:
                seen_format.add(key)
                merged_format_logs.append(log)
        format_logs = merged_format_logs

        seen_speedometer = set()
        merged_speedometer_logs = []
        for log in speedometer_logs + judge_speedometer_logs:
            key = (log.get("timestamp"), log.get("reason"), log.get("model"))
            if key not in seen_speedometer:
                seen_speedometer.add(key)
                merged_speedometer_logs.append(log)
        speedometer_logs = merged_speedometer_logs
    except Exception as e:
        logger.error(f"Error processing instance {instance_id}: {e}", exc_info=True)
        exit_status = type(e).__name__
        exit_reason = str(e)
    finally:
        for log in format_logs:
            log.pop("input", None)
            log.pop("output", None)
            log.pop("tokens", None)
        for log in speedometer_logs:
            log.pop("input", None)
            log.pop("output", None)
            log.pop("tokens", None)

        total_time = time.time() - start_time
        format_time = sum(log.get("duration_seconds", 0.0) for log in format_logs)
        llmjudge_time = sum(log.get("duration_seconds", 0.0) for log in speedometer_logs)

        stats = {
            "exit_reason": exit_reason,
            "time": total_time,
            "agent_time": agent_time,
            "llm_time": llm_time,
            "exec_time": exec_time,
            "format_time": format_time,
            "llmjudge_time": llmjudge_time,
            "cost": cost,
            "format": format_logs,
            "speedometer": speedometer_logs,
        }
        progress_manager.on_instance_end(instance_id, exit_status, stats)


def get_paper(instance):
    repo_root = Path(util.find_repo_root())
    paper_path = (
        repo_root
        / "artisanbench"
        / "papers"
        / "obfuscated"
        / f"{instance['paper_id']}_paper_{instance['table_idx']}.md"
    )
    if paper_path.is_file():
        return Path(paper_path)
    else:
        paper_data = handle_paper.process_paper(instance["paper_path"])
        paper_path = Path(paper_data["md_path"])
        print(f"Using converted paper at: {paper_path}")
        return paper_path


def _run_instance_with_agent(
    instance: dict,
    agent_name: str,
    model_name: str | None = None,
    log_root: Path | None = None,
    ablation: str | None = None,
) -> tuple[Path, str]:
    """Replicate artisan.run pipeline but call the selected agent runner directly."""
    if ablation:
        if agent_name != "artisan":
            logger.info("Forcing agent to 'artisan' for ablation study '%s'", ablation)
        agent_name = "artisan"

    table_path = instance["table_path"]
    task_name = Path(table_path).stem if table_path else "run"
    _, workspace_dir, _ = util.setup_logging(task_name, log_root=log_root)

    runner = _AGENT_RUNNERS.get(agent_name)
    if runner is None:  # pragma: no cover - defensive guard
        raise ValueError(f"Unknown agent '{agent_name}'")

    prompt_path = None
    if ablation == "without_format":
        prompt_path = str(Path(util.find_repo_root()) / "artisanbench" / "prompts" / "artisan_without_format.yaml")

    kwargs = {
        "workspace_dir": str(workspace_dir),
        "table_path": table_path,
        "paper_path": get_paper(instance),
        "artifact_url": instance["artifact"],
        "interactive": bool(instance.get("interactive", False)),
        "model_name": model_name,
        "prompt_path": prompt_path,
    }

    if agent_name == "artisan":
        kwargs["ablation"] = ablation

    traj_path, exit_status = runner(**kwargs)
    return traj_path, exit_status


def _submit_workspace_result(
    workspace_dir: Path,
    instance: dict,
    ablation: str | None = None,
) -> tuple[str, str, list[dict], list[dict]]:
    """Submit the generated reproduction script to the judge and map the outcome."""
    artifact_name = util.table_to_artifact(instance["table_path"])
    table_index = util.table_to_index(instance["table_path"])
    script_name = f"repro_{artifact_name}_table_{table_index}.sh"
    script_path = workspace_dir / script_name

    judge_result_path = workspace_dir / "judge_result.json"
    if judge_result_path.exists():
        try:
            cached = json.loads(judge_result_path.read_text())
            if cached.get("status") in [judge.STATUS_FULL_REPRO, judge.STATUS_LASTMILE_REPRO]:
                logger.info("Using cached judge result for %s", script_name)
                return cached["status"], cached["reason"], cached["format_logs"], cached["speedometer_logs"]
        except Exception as e:
            logger.warning("Failed to read cached judge result: %s", e)

    logger.info("Submitting %s to judge for validation", script_path)
    result = judge.check_submission_file(script_path)
    if result.format_logs:
        for log in result.format_logs:
            log["reason"] = format.REASON_FINAL_VALIDATION
    if result.speedometer_logs:
        for log in result.speedometer_logs:
            log["reason"] = speedometer.REASON_FINAL_VALIDATION

    if result.return_code != 0:
        logger.warning("Judge rejected %s with code %s, status %s", script_name, result.return_code, result.status)

    return result.status, result.reason, result.format_logs, result.speedometer_logs


def get_git_hash(path: Path) -> str:
    try:
        hash_str = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=path, text=True).strip()
        if subprocess.check_output(["git", "status", "--porcelain"], cwd=path, text=True).strip():
            hash_str += "-dirty"
        return hash_str
    except Exception:
        return "unknown"


def get_docker_hash(image_name: str) -> str:
    try:
        return subprocess.check_output(["docker", "inspect", "--format={{.Id}}", image_name], text=True).strip()
    except Exception:
        return "unknown"


def cmd_reprobench(
    filter_spec: str = "",
    workers: int = 1,
    repeat: int = 1,
    agent_name: str = "artisan",
    model_name: str | None = None,
    log_per_config: bool = False,
    ablation: str | None = None,
    continue_run: str | None = None,
    log_root_override: str | None = None,
) -> None:
    instances_path = Path(f"{util.find_repo_root()}/artisanbench/metadata.json")

    completed_instances = {}
    report_path = Path("logs/artisan_report.json")
    log_root: Path | None = None
    instances_to_run_ids = None

    if continue_run:
        print(f"Continuing run from {continue_run}")
        run_path = Path(continue_run)
        if not run_path.exists():
            raise FileNotFoundError(f"Run file {continue_run} not found")

        with open(run_path) as f:
            data = json.load(f)

        metadata = data.get("metadata", {})
        agent_name = metadata.get("agent", agent_name)
        model_name = metadata.get("model", model_name)
        ablation = metadata.get("ablation", ablation)

        log_root = run_path.parent
        report_path = run_path

        # Determine instances to run
        existing_instances = data.get("instance", {})
        instances_to_run_ids = []

        # Max repeat count in the file to ensure we load enough instances
        max_repeat_in_file = 0
        for iid in existing_instances.keys():
            match = re.search(r"-r(\d+)$", iid)
            if match:
                max_repeat_in_file = max(max_repeat_in_file, int(match.group(1)))

        if max_repeat_in_file > repeat:
            repeat = max_repeat_in_file

        successful_statuses = [
            "FULL_REPRO",
            "LASTMILE_REPRO",
            "COPY_REPRO",
            "MISMATCH_ERROR",
            "RUNTIME_ERROR",
            "STATIC_ERROR",
        ]

        for iid, stats in existing_instances.items():
            if stats["exit_status"] in successful_statuses:
                completed_instances[iid] = stats
            else:
                instances_to_run_ids.append(iid)

        print(
            f"Found {len(completed_instances)} successful instances and {len(instances_to_run_ids)} unsuccessful instances to rerun."
        )

    print(f"Loading instances from {instances_path}...")
    instances = _load_instances(instances_path, repeat)
    print(f"Loaded {len(instances)} tasks.")

    if continue_run:
        missing_count = sum(1 for inst in instances if inst["instance_id"] not in existing_instances)
        print(f"Found {missing_count} missing instances to run.")
        instances = [
            inst
            for inst in instances
            if inst["instance_id"] in instances_to_run_ids or inst["instance_id"] not in existing_instances
        ]

    instances = filter_instances(instances, filter_spec=filter_spec)
    print(f"Running on {len(instances)} tasks...")

    if model_name:
        model_name = _MODEL_MAPPING.get(model_name, model_name)
        print(f"Using model: {model_name}")

    if not continue_run:
        if log_root_override:
            log_root = Path(log_root_override).expanduser().resolve()
            print(f"Logging to {log_root}")
            report_path = log_root / "reprobench.json"
            log_root.mkdir(parents=True, exist_ok=True)
        elif log_per_config:
            run_id = uuid.uuid4().hex[:4]
            model_str = simple_model_names.get(model_name, model_name.replace("-", "")) if model_name else "default"
            log_root_name = f"{agent_name}-{model_str}-{run_id}"
            if ablation:
                log_root_name += f"-{ablation}"
            log_root = util.find_repo_root() / "data" / "logs" / log_root_name
            print(f"Logging to {log_root}")
            report_path = log_root / "reprobench.json"
            # Ensure directory exists for report
            log_root.mkdir(parents=True, exist_ok=True)

    repo_root = util.find_repo_root()
    metadata = {
        "date": datetime.datetime.now().isoformat(),
        "host": os.uname().nodename,
        "agent": agent_name,
        "model": model_name or "default",
        "ablation": ablation,
        "artisan_hash": get_git_hash(repo_root),
        "minisweagent_hash": get_git_hash(repo_root / "agents" / "mini-swe-agent"),
        "sweagent_hash": get_git_hash(repo_root / "agents" / "SWE-agent"),
        "artisan_docker_hash": get_docker_hash(artisan.BASE_IMAGE),
    }

    total_instances_count = len(instances) + len(completed_instances)
    progress_manager = RunBatchProgressManager(total_instances_count, report_path=report_path, metadata=metadata)

    # Pre-populate completed instances
    for iid, stats in completed_instances.items():
        progress_manager._instance_stats[iid] = stats
        progress_manager._instances_by_exit_status[stats["exit_status"]].append(iid)

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
        # Update progress bar for completed instances
        if completed_instances:
            progress_manager._main_progress_bar.update(progress_manager._main_task_id, advance=len(completed_instances))

        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(
                    process_instance, instance, progress_manager, agent_name, model_name, log_root, ablation
                ): instance["instance_id"]
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
            finally:
                progress_manager.save_report(report_path)


def _apply_shared_arguments(parser: argparse.ArgumentParser) -> None:
    """Attach the shared reprobench CLI arguments to a parser."""
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
        default=1,
        help="Number of parallel worker threads",
    )
    parser.add_argument(
        "-r",
        "--repeat",
        type=int,
        default=1,
        help="Repeat each instance N times (adds -rN suffix)",
    )
    parser.add_argument(
        "-a",
        "--agent",
        choices=sorted(_AGENT_RUNNERS.keys()),
        default="artisan",
        help="Agent implementation to execute (default: artisan)",
    )
    parser.add_argument(
        "--model",
        default=None,
        help="LLM model to use (e.g., gpt-5-nano, gpt-5-mini, gpt-5.1)",
    )
    parser.add_argument(
        "--log-per-config",
        action="store_true",
        help="Use {agent}-{model}-{hash} directory for logs instead of date-based",
    )
    parser.add_argument(
        "--ablation",
        choices=["without_format", "without_output", "without_method"],
        default=None,
        help="Ablation study configuration",
    )
    parser.add_argument(
        "--network-host",
        action="store_true",
        help="Use Docker host networking for agent and judge containers (adds '--network host')",
    )
    parser.add_argument(
        "--continue-run",
        default=None,
        help="Path to previous reprobench.json to continue from (reruns unsuccessful instances)",
    )
    parser.add_argument(
        "--log-root",
        default=None,
        help="Directory for this run's logs and reprobench.json",
    )


def _reprobench_from_cli(args: argparse.Namespace) -> int:
    """Adapter so argparse dispatch can invoke the batch runner."""
    if getattr(args, "network_host", False):
        os.environ["ARTISAN_DOCKER_NETWORK"] = "host"
    cmd_reprobench(
        args.filter,
        args.workers,
        args.repeat,
        args.agent,
        args.model,
        args.log_per_config,
        args.ablation,
        args.continue_run,
        args.log_root,
    )
    return 0


def register_subparser(subparsers: argparse._SubParsersAction) -> None:
    """Register the `artisan reprobench` subparser with the shared CLI."""
    rb_p = subparsers.add_parser(
        "reprobench",
        help="Run multiple reproduction benchmark instances (batch mode)",
        description=_REPROBENCH_DESCRIPTION,
    )
    _apply_shared_arguments(rb_p)
    rb_p.set_defaults(func=_reprobench_from_cli)


def _create_standalone_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="reprobench",
        description=_REPROBENCH_DESCRIPTION,
    )
    _apply_shared_arguments(parser)
    return parser


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse standalone CLI arguments."""
    return _create_standalone_parser().parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    """Entry point for running reprobench as a standalone script."""
    args = parse_args(argv)
    return _reprobench_from_cli(args)


if __name__ == "__main__":
    raise SystemExit(main())
