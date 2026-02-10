import collections
import json
import time
from collections.abc import Callable
from datetime import timedelta
from pathlib import Path
from threading import Lock

import yaml
from rich.console import Group
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TaskID,
    TaskProgressColumn,
    TextColumn,
    TimeElapsedColumn,
)
from rich.table import Table


def _shorten_str(s: str, max_len: int, shorten_left: bool = False) -> str:
    if not shorten_left:
        s = s[: max_len - 3] + "..." if len(s) > max_len else s
    else:
        s = "..." + s[-max_len + 3 :] if len(s) > max_len else s
    return f"{s:<{max_len}}"


class RunBatchProgressManager:
    def __init__(
        self,
        num_instances: int,
        report_path: Path | None = None,
        metadata: dict | None = None,
        total_cost_getter: Callable[[], float] | None = None,
    ):
        self._spinner_tasks: dict[str, TaskID] = {}
        self._lock = Lock()
        self._start_time = time.time()
        self._total_instances = num_instances
        self._metadata = metadata or {}
        self._total_cost_getter = total_cost_getter

        self._instances_by_exit_status = collections.defaultdict(list)
        self._instance_stats = {}
        self._main_progress_bar = Progress(
            SpinnerColumn(spinner_name="dots2"),
            TextColumn("[progress.description]{task.description} (${task.fields[total_cost]})"),
            BarColumn(),
            MofNCompleteColumn(),
            TaskProgressColumn(),
            TimeElapsedColumn(),
            TextColumn("[cyan]{task.fields[eta]}[/cyan]"),
            speed_estimate_period=60 * 5,
        )
        self._task_progress_bar = Progress(
            SpinnerColumn(spinner_name="dots2"),
            TextColumn("{task.fields[instance_id]}"),
            TextColumn("{task.fields[status]}"),
            TimeElapsedColumn(),
        )

        self._main_task_id = self._main_progress_bar.add_task(
            "[cyan]Overall Progress", total=num_instances, total_cost="0.00", eta=""
        )

        self.render_group = Group(Table(), self._task_progress_bar, self._main_progress_bar)
        self._report_path = report_path

    @property
    def n_completed(self) -> int:
        return sum(len(instances) for instances in self._instances_by_exit_status.values())

    def _get_eta_text(self) -> str:
        try:
            estimated_remaining = (
                (time.time() - self._start_time) / self.n_completed * (self._total_instances - self.n_completed)
            )
            return f"eta: {timedelta(seconds=int(estimated_remaining))}"
        except ZeroDivisionError:
            return ""

    def update_exit_status_table(self) -> None:
        t = Table()
        t.add_column("Exit Status")
        t.add_column("Count", justify="right", style="bold cyan")
        t.add_column("Most recent instances")
        t.show_header = False
        with self._lock:
            t.show_header = True
            sorted_items = sorted(self._instances_by_exit_status.items(), key=lambda x: len(x[1]), reverse=True)
            for status, instances in sorted_items:
                instances_str = _shorten_str(", ".join(reversed(instances)), 55)
                t.add_row(status, str(len(instances)), instances_str)
        self.render_group.renderables[0] = t

    def _update_total_costs(self) -> None:
        with self._lock:
            self._main_progress_bar.update(
                self._main_task_id,
                total_cost=f"{self._get_total_cost():.2f}",
                eta=self._get_eta_text(),
            )

    def _get_total_cost(self) -> float:
        if self._total_cost_getter is not None:
            try:
                return float(self._total_cost_getter())
            except Exception:
                pass

        total_cost = 0.0
        for stats in self._instance_stats.values():
            total_cost += stats.get("cost", 0.0)
        return total_cost

    def update_instance_status(self, instance_id: str, message: str) -> None:
        with self._lock:
            self._task_progress_bar.update(
                self._spinner_tasks[instance_id],
                status=_shorten_str(message, 30),
                instance_id=_shorten_str(instance_id, 25, shorten_left=True),
            )
        self._update_total_costs()

    def on_instance_start(self, instance_id: str) -> None:
        with self._lock:
            self._spinner_tasks[instance_id] = self._task_progress_bar.add_task(
                description=f"Task {instance_id}",
                status="Task initialized",
                total=None,
                instance_id=instance_id,
            )

    def on_instance_end(self, instance_id: str, exit_status: str | None, stats: dict | None = None) -> None:
        self._instances_by_exit_status[exit_status].append(instance_id)
        if stats is None:
            stats = {}
        final_stats = {"exit_status": exit_status}
        final_stats.update(stats)
        self._instance_stats[instance_id] = final_stats
        with self._lock:
            try:
                self._task_progress_bar.remove_task(self._spinner_tasks[instance_id])
            except KeyError:
                pass
            self._main_progress_bar.update(TaskID(0), advance=1, eta=self._get_eta_text())
        self.update_exit_status_table()
        self._update_total_costs()
        if self._report_path is not None:
            self.save_report(self._report_path)

    def on_uncaught_exception(self, instance_id: str, exception: Exception) -> None:
        self.on_instance_end(instance_id, f"Uncaught {type(exception).__name__}")

    def print_report(self) -> None:
        for status, instances in self._instances_by_exit_status.items():
            print(f"{status}: {len(instances)}")
            for instance in instances:
                print(f"  {instance}")

    def _get_overview_data(self) -> dict:
        total_full_repro = len(self._instances_by_exit_status.get("FULL_REPRO", [])) + len(
            self._instances_by_exit_status.get("Success", [])
        )
        total_lastmile_repro = len(self._instances_by_exit_status.get("LASTMILE_REPRO", []))
        total_copy_repro = len(self._instances_by_exit_status.get("COPY_REPRO", []))
        total_mismatch_error = len(self._instances_by_exit_status.get("MISMATCH_ERROR", []))
        total_runtime_error = len(self._instances_by_exit_status.get("RUNTIME_ERROR", []))
        total_static_error = len(self._instances_by_exit_status.get("STATIC_ERROR", []))

        agent_cost = 0.0
        for stats in self._instance_stats.values():
            agent_cost += stats.get("cost", 0.0)

        total_time = 0.0
        total_llm_time = 0.0
        total_format_time = 0.0
        total_llmjudge_time = 0.0
        total_exec_time = 0.0

        for stats in self._instance_stats.values():
            total_time += stats.get("time", 0.0)
            total_llm_time += stats.get("llm_time", 0.0)
            total_format_time += stats.get("format_time", 0.0)
            total_llmjudge_time += stats.get("llmjudge_time", 0.0)
            total_exec_time += stats.get("exec_time", 0.0)

        format_cost = 0.0
        for stats in self._instance_stats.values():
            for fmt in stats.get("format", []):
                format_cost += fmt.get("cost_usd", 0.0)
        speedometer_cost = 0.0
        for stats in self._instance_stats.values():
            for spd in stats.get("speedometer", []):
                speedometer_cost += spd.get("cost_usd", 0.0)
        total_cost = agent_cost + format_cost + speedometer_cost

        n_completed = self.n_completed
        cost_per_instance = total_cost / n_completed if n_completed > 0 else 0.0
        time_per_instance = total_time / n_completed if n_completed > 0 else 0.0

        return {
            "metadata": self._metadata,
            "total": {
                "total_full_repro": total_full_repro,
                "total_lastmile_repro": total_lastmile_repro,
                "total_copy_repro": total_copy_repro,
                "total_mismatch_error": total_mismatch_error,
                "total_runtime_error": total_runtime_error,
                "total_static_error": total_static_error,
                "total_cost": total_cost,
                "format_cost": format_cost,
                "speedometer_cost": speedometer_cost,
                "total_time": total_time,
                "total_llm_time": total_llm_time,
                "total_format_time": total_format_time,
                "total_llmjudge_time": total_llmjudge_time,
                "total_exec_time": total_exec_time,
                "cost_per_instance": cost_per_instance,
                "time_per_instance": time_per_instance,
            },
            "instance": self._instance_stats,
        }

    def save_report(self, path: Path) -> None:
        data = self._get_overview_data()
        with self._lock:
            if path.suffix == ".json":
                path.write_text(json.dumps(data, indent=4))
            else:
                path.write_text(yaml.dump(data, indent=4))
