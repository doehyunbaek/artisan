#!/usr/bin/env python3
"""Outcome-level efficiency distributions for ReproBench runs.

This script addresses the concern that Table 2 reports only per-task averages,
which can be skewed by long-running outliers. It recomputes the same corrected
per-instance data used by analyze_results.py, then reports cost/time
(distribution) metrics by final outcome.

Outputs:
  analysis/outcome_efficiency_distribution.csv
  analysis/outcome_efficiency_distribution.md
  analysis/outcome_efficiency_overall.csv
  analysis/outcome_efficiency_overall.md
"""
from __future__ import annotations

import csv
import json
import math
import statistics
from pathlib import Path
from typing import Any, Iterable

from correct_effectiveness import correct_effectiveness_from_manual_md
from correct_time import correct_time_from_logs

BASE_DIR = Path(__file__).resolve().parent
MANUAL_ANALYSIS_ROOT = BASE_DIR / "manual_analysis"
OUT_DIR = BASE_DIR / "analysis"

STATUSES = [
    "FULL_REPRO",
    "LASTMILE_REPRO",
    "COPY_REPRO",
    "MISMATCH_ERROR",
    "RUNTIME_ERROR",
    "STATIC_ERROR",
]
SUCCESS_STATUSES = {"FULL_REPRO", "LASTMILE_REPRO"}
FAIL_STATUSES = {"COPY_REPRO", "MISMATCH_ERROR", "RUNTIME_ERROR", "STATIC_ERROR"}

RUNS = [
    # Baseline runs (Table 2)
    {"table": "baseline", "approach": "SWE-agent", "model": "DeepSeek", "run": "sweagent-deepseek-reasoner-4bdc"},
    {"table": "baseline", "approach": "SWE-agent", "model": "gpt-5-mini", "run": "sweagent-gpt5mini-5d98"},
    {"table": "baseline", "approach": "SWE-agent", "model": "gpt-5.1", "run": "sweagent-gpt5.1-ebe4"},
    {"table": "baseline", "approach": "OpenHands", "model": "DeepSeek", "run": "openhands-deepseek-reasoner-bd34"},
    {"table": "baseline", "approach": "OpenHands", "model": "gpt-5-mini", "run": "openhands-gpt5mini-a4eb"},
    {"table": "baseline", "approach": "OpenHands", "model": "gpt-5.1", "run": "openhands-gpt5.1-41ec"},
    {"table": "baseline", "approach": "mini-swe-agent", "model": "DeepSeek", "run": "minisweagent-deepseek-reasoner-e5a7"},
    {"table": "baseline", "approach": "mini-swe-agent", "model": "gpt-5-mini", "run": "minisweagent-gpt5mini-a830"},
    {"table": "baseline", "approach": "mini-swe-agent", "model": "gpt-5.1", "run": "minisweagent-gpt5.1-301b"},
    {"table": "baseline", "approach": "Artisan", "model": "DeepSeek", "run": "artisan-deepseek-reasoner-6f4b"},
    {"table": "baseline", "approach": "Artisan", "model": "gpt-5-mini", "run": "artisan-gpt5mini-845b"},
    {"table": "baseline", "approach": "Artisan", "model": "gpt-5.1", "run": "artisan-gpt5.1-dbe0"},
    # Ablations (useful companion to the baseline table)
    {"table": "ablation", "approach": "Artisan", "model": "gpt-5.1", "ablation": "w/o Output Judge", "run": "artisan-gpt5.1-3ee0-without_output"},
    {"table": "ablation", "approach": "Artisan", "model": "gpt-5.1", "ablation": "w/o Method Judge", "run": "artisan-gpt5.1-7a04-without_method"},
    {"table": "ablation", "approach": "Artisan", "model": "gpt-5.1", "ablation": "w/o Format", "run": "artisan-gpt5.1-9223-without_format"},
]


def is_number(x: Any) -> bool:
    return isinstance(x, (int, float)) and math.isfinite(float(x))


def read_status(entry: dict[str, Any]) -> str:
    for key in ("exit_status", "status", "result", "judge_status"):
        value = entry.get(key)
        if isinstance(value, str) and value:
            return value
    return "UNKNOWN"


def load_instances(run_name: str) -> dict[str, Any]:
    json_path = BASE_DIR / run_name / "reprobench.json"
    with json_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    instances = data.get("instance", {})
    total_stats = data.get("total", {})
    if not isinstance(instances, dict) or not isinstance(total_stats, dict):
        raise ValueError(f"Malformed JSON at {json_path}")

    # Match analyze_results.py: correct times from logs and manual status overrides.
    correct_time_from_logs(instances, json_path.parent, fill_agent_time=True, shrink_time=True)
    correct_effectiveness_from_manual_md(
        instances,
        total_stats,
        MANUAL_ANALYSIS_ROOT / f"{run_name}.md",
    )
    return instances


def percentile(values: list[float], pct: float) -> float | None:
    """Linear-interpolated percentile, where pct is in [0, 100]."""
    if not values:
        return None
    if len(values) == 1:
        return values[0]
    xs = sorted(values)
    k = (len(xs) - 1) * (pct / 100.0)
    lo = math.floor(k)
    hi = math.ceil(k)
    if lo == hi:
        return xs[int(k)]
    return xs[lo] * (hi - k) + xs[hi] * (k - lo)


def metric_summary(values: Iterable[float]) -> dict[str, float | None]:
    xs = [float(v) for v in values if math.isfinite(float(v))]
    if not xs:
        return {"mean": None, "median": None, "sd": None, "p90": None, "max": None}
    return {
        "mean": statistics.fmean(xs),
        "median": statistics.median(xs),
        # Sample standard deviation; undefined for n=1.
        "sd": statistics.stdev(xs) if len(xs) > 1 else None,
        "p90": percentile(xs, 90),
        "max": max(xs),
    }


def row_for_group(meta: dict[str, str], outcome: str, items: list[tuple[str, dict[str, Any]]]) -> dict[str, Any]:
    costs: list[float] = []
    times_min: list[float] = []
    max_cost_instance = ""
    max_time_instance = ""
    max_cost = -math.inf
    max_time_min = -math.inf

    for iid, entry in items:
        if is_number(entry.get("cost")):
            c = float(entry["cost"])
            costs.append(c)
            if c > max_cost:
                max_cost = c
                max_cost_instance = iid
        if is_number(entry.get("time")):
            t_min = float(entry["time"]) / 60.0
            times_min.append(t_min)
            if t_min > max_time_min:
                max_time_min = t_min
                max_time_instance = iid

    csum = metric_summary(costs)
    tsum = metric_summary(times_min)

    return {
        "table": meta.get("table", ""),
        "approach": meta.get("approach", ""),
        "model": meta.get("model", ""),
        "ablation": meta.get("ablation", ""),
        "run": meta.get("run", ""),
        "outcome": outcome,
        "n": len(items),
        "n_cost": len(costs),
        "cost_mean_usd": csum["mean"],
        "cost_median_usd": csum["median"],
        "cost_sd_usd": csum["sd"],
        "cost_p90_usd": csum["p90"],
        "cost_max_usd": csum["max"],
        "max_cost_instance": max_cost_instance,
        "n_time": len(times_min),
        "time_mean_min": tsum["mean"],
        "time_median_min": tsum["median"],
        "time_sd_min": tsum["sd"],
        "time_p90_min": tsum["p90"],
        "time_max_min": tsum["max"],
        "max_time_instance": max_time_instance,
    }


def collect_rows() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    detail_rows: list[dict[str, Any]] = []
    overall_rows: list[dict[str, Any]] = []

    for meta in RUNS:
        instances = load_instances(meta["run"])
        typed_items = [(iid, entry) for iid, entry in instances.items() if isinstance(entry, dict)]
        by_status: dict[str, list[tuple[str, dict[str, Any]]]] = {s: [] for s in STATUSES}
        by_status["UNKNOWN"] = []

        for iid, entry in typed_items:
            status = read_status(entry)
            by_status.setdefault(status, []).append((iid, entry))

        # Overall rows for quick comparison with Table 2 averages.
        all_row = row_for_group(meta, "ALL", typed_items)
        success_items = [(iid, e) for iid, e in typed_items if read_status(e) in SUCCESS_STATUSES]
        failure_items = [(iid, e) for iid, e in typed_items if read_status(e) in FAIL_STATUSES]
        overall_rows.extend([
            all_row,
            row_for_group(meta, "SUCCESS", success_items),
            row_for_group(meta, "FAILURE", failure_items),
        ])

        # Granular outcome rows.
        for status in STATUSES:
            items = by_status.get(status, [])
            if items:
                detail_rows.append(row_for_group(meta, status, items))

        if by_status.get("UNKNOWN"):
            detail_rows.append(row_for_group(meta, "UNKNOWN", by_status["UNKNOWN"]))

    return detail_rows, overall_rows


def fmt_csv_value(value: Any) -> Any:
    if isinstance(value, float):
        if not math.isfinite(value):
            return ""
        return f"{value:.6f}"
    if value is None:
        return ""
    return value


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    fieldnames = list(rows[0].keys())
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: fmt_csv_value(v) for k, v in row.items()})


def fmt_num(value: Any, digits: int = 1) -> str:
    if value is None:
        return "--"
    if isinstance(value, float):
        if not math.isfinite(value):
            return "--"
        return f"{value:.{digits}f}"
    return str(value)


def markdown_table(rows: list[dict[str, Any]], *, detail: bool) -> str:
    if detail:
        headers = [
            "Table", "Approach", "Model", "Ablation", "Outcome", "n",
            "Cost mean", "Cost median", "Cost SD", "Cost max",
            "Time mean", "Time median", "Time SD", "Time p90", "Time max", "Worst-time instance",
        ]
        align = [":--", ":--", ":--", ":--", ":--", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", ":--"]
    else:
        headers = [
            "Table", "Approach", "Model", "Ablation", "Group", "n",
            "Cost mean", "Cost median", "Cost SD", "Cost max",
            "Time mean", "Time median", "Time SD", "Time p90", "Time max", "Worst-time instance",
        ]
        align = [":--", ":--", ":--", ":--", ":--", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", ":--"]

    lines = []
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("| " + " | ".join(align) + " |")

    for r in rows:
        cells = [
            r["table"],
            r["approach"],
            r["model"],
            r.get("ablation", ""),
            r["outcome"],
            str(r["n"]),
            fmt_num(r["cost_mean_usd"], 3),
            fmt_num(r["cost_median_usd"], 3),
            fmt_num(r["cost_sd_usd"], 3),
            fmt_num(r["cost_max_usd"], 3),
            fmt_num(r["time_mean_min"], 1),
            fmt_num(r["time_median_min"], 1),
            fmt_num(r["time_sd_min"], 1),
            fmt_num(r["time_p90_min"], 1),
            fmt_num(r["time_max_min"], 1),
            r["max_time_instance"],
        ]
        lines.append("| " + " | ".join(str(c) for c in cells) + " |")
    return "\n".join(lines) + "\n"


def write_markdown(path: Path, rows: list[dict[str, Any]], *, detail: bool) -> None:
    title = "Outcome-level efficiency distributions" if detail else "Overall efficiency distributions"
    units = (
        "Cost values are in USD per instance. Time values are minutes per instance. "
        "SD is the sample standard deviation and is shown as `--` for n=1. "
        "Rows use corrected times/statuses (manual effectiveness overrides and artisan.log time correction)."
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"# {title}\n\n{units}\n\n" + markdown_table(rows, detail=detail), encoding="utf-8")


def main() -> None:
    detail_rows, overall_rows = collect_rows()

    # Stable, paper-like ordering.
    order = {status: i for i, status in enumerate(["ALL", "SUCCESS", "FAILURE"] + STATUSES + ["UNKNOWN"])}
    detail_rows.sort(key=lambda r: (r["table"], r["approach"], r["model"], r.get("ablation", ""), order.get(r["outcome"], 99)))
    overall_rows.sort(key=lambda r: (r["table"], r["approach"], r["model"], r.get("ablation", ""), order.get(r["outcome"], 99)))

    write_csv(OUT_DIR / "outcome_efficiency_distribution.csv", detail_rows)
    write_csv(OUT_DIR / "outcome_efficiency_overall.csv", overall_rows)
    write_markdown(OUT_DIR / "outcome_efficiency_distribution.md", detail_rows, detail=True)
    write_markdown(OUT_DIR / "outcome_efficiency_overall.md", overall_rows, detail=False)

    print(f"Wrote {len(detail_rows)} outcome rows to {OUT_DIR / 'outcome_efficiency_distribution.csv'}")
    print(f"Wrote {len(overall_rows)} overall rows to {OUT_DIR / 'outcome_efficiency_overall.csv'}")


if __name__ == "__main__":
    main()
