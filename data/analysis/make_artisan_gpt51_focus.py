#!/usr/bin/env python3
from __future__ import annotations

import csv
import math
import statistics
from pathlib import Path
from typing import Any

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from analyze_outcome_efficiency import load_instances, read_status, SUCCESS_STATUSES, FAIL_STATUSES, STATUSES, percentile, metric_summary

OUT = Path(__file__).resolve().parent
RUN = "artisan-gpt5.1-dbe0"
LABEL = "Artisan / gpt-5.1"


def fmt(value: Any, digits: int = 1) -> str:
    if value is None:
        return "--"
    if isinstance(value, float):
        if not math.isfinite(value):
            return "--"
        return f"{value:.{digits}f}"
    return str(value)


def numeric(x: Any) -> bool:
    return isinstance(x, (int, float)) and math.isfinite(float(x))


def summarize(items: list[dict[str, Any]]) -> dict[str, Any]:
    costs = [float(x["cost_usd"]) for x in items if numeric(x.get("cost_usd"))]
    times = [float(x["time_min"]) for x in items if numeric(x.get("time_min"))]
    c = metric_summary(costs)
    t = metric_summary(times)
    return {
        "n": len(items),
        "cost_mean": c["mean"], "cost_median": c["median"], "cost_sd": c["sd"], "cost_p90": c["p90"], "cost_max": c["max"],
        "time_mean": t["mean"], "time_median": t["median"], "time_sd": t["sd"], "time_p90": t["p90"], "time_p95": percentile(times, 95), "time_max": t["max"],
    }


def md_table(headers: list[str], rows: list[list[str]], aligns: list[str] | None = None) -> str:
    if aligns is None:
        aligns = [":--"] * len(headers)
    lines = ["| " + " | ".join(headers) + " |", "| " + " | ".join(aligns) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines) + "\n"


def main() -> None:
    instances = load_instances(RUN)
    rows: list[dict[str, Any]] = []
    for iid, entry in instances.items():
        if not isinstance(entry, dict):
            continue
        status = read_status(entry)
        time_min = float(entry["time"]) / 60.0 if numeric(entry.get("time")) else None
        cost = float(entry["cost"]) if numeric(entry.get("cost")) else None
        rows.append({
            "instance": iid,
            "status": status,
            "group": "SUCCESS" if status in SUCCESS_STATUSES else ("FAILURE" if status in FAIL_STATUSES else "UNKNOWN"),
            "time_min": time_min,
            "cost_usd": cost,
            "llm_time_min": float(entry.get("llm_time", 0.0)) / 60.0 if numeric(entry.get("llm_time")) else 0.0,
            "exec_time_min": float(entry.get("exec_time", 0.0)) / 60.0 if numeric(entry.get("exec_time")) else 0.0,
            "judge_wait_min": float(entry.get("judge_wait", 0.0)) / 60.0 if numeric(entry.get("judge_wait")) else 0.0,
            "format_time_min": float(entry.get("format_time", 0.0)) / 60.0 if numeric(entry.get("format_time")) else 0.0,
            "llmjudge_time_min": float(entry.get("llmjudge_time", 0.0)) / 60.0 if numeric(entry.get("llmjudge_time")) else 0.0,
        })
    rows.sort(key=lambda r: r["instance"])

    # Per-instance CSV for auditability.
    csv_path = OUT / "artisan_gpt51_instances.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        for r in rows:
            writer.writerow(r)

    groups = {
        "ALL": rows,
        "SUCCESS": [r for r in rows if r["group"] == "SUCCESS"],
        "FAILURE": [r for r in rows if r["group"] == "FAILURE"],
    }
    group_rows = []
    for name, items in groups.items():
        s = summarize(items)
        group_rows.append([
            name, str(s["n"]), fmt(s["cost_mean"], 3), fmt(s["cost_median"], 3), fmt(s["cost_sd"], 3), fmt(s["cost_p90"], 3), fmt(s["cost_max"], 3),
            fmt(s["time_mean"], 1), fmt(s["time_median"], 1), fmt(s["time_sd"], 1), fmt(s["time_p90"], 1), fmt(s["time_p95"], 1), fmt(s["time_max"], 1),
        ])

    outcome_rows = []
    for st in STATUSES:
        items = [r for r in rows if r["status"] == st]
        if not items:
            continue
        s = summarize(items)
        worst_time = max(items, key=lambda r: r["time_min"] if numeric(r.get("time_min")) else -1)
        worst_cost = max(items, key=lambda r: r["cost_usd"] if numeric(r.get("cost_usd")) else -1)
        outcome_rows.append([
            st, str(s["n"]), fmt(s["cost_mean"], 3), fmt(s["cost_median"], 3), fmt(s["cost_sd"], 3), fmt(s["cost_p90"], 3), fmt(s["cost_max"], 3),
            fmt(s["time_mean"], 1), fmt(s["time_median"], 1), fmt(s["time_sd"], 1), fmt(s["time_p90"], 1), fmt(s["time_p95"], 1), fmt(s["time_max"], 1),
            worst_time["instance"], worst_cost["instance"],
        ])

    slowest = sorted(rows, key=lambda r: r["time_min"] if numeric(r.get("time_min")) else -1, reverse=True)[:10]
    slow_rows = [[
        str(i + 1), r["instance"], r["status"], fmt(r["time_min"], 1), fmt(r["cost_usd"], 3),
        fmt(r["llm_time_min"], 1), fmt(r["exec_time_min"], 1), fmt(r["judge_wait_min"], 1), fmt(r["format_time_min"], 1), fmt(r["llmjudge_time_min"], 1),
    ] for i, r in enumerate(slowest)]

    expensive = sorted(rows, key=lambda r: r["cost_usd"] if numeric(r.get("cost_usd")) else -1, reverse=True)[:10]
    cost_rows = [[
        str(i + 1), r["instance"], r["status"], fmt(r["cost_usd"], 3), fmt(r["time_min"], 1),
    ] for i, r in enumerate(expensive)]

    # Sensitivity to removing the longest-running outliers.
    sorted_by_time = sorted(rows, key=lambda r: r["time_min"] if numeric(r.get("time_min")) else -1, reverse=True)
    sensitivity_rows = []
    for k in [0, 1, 2, 3, 5, 10]:
        kept = sorted_by_time[k:]
        s = summarize(kept)
        sensitivity_rows.append([
            f"exclude top {k}" if k else "all 60",
            str(s["n"]), fmt(s["time_mean"], 1), fmt(s["time_median"], 1), fmt(s["time_sd"], 1), fmt(s["time_p90"], 1), fmt(s["time_max"], 1),
            fmt(s["cost_mean"], 3), fmt(s["cost_median"], 3),
        ])

    # How much the single worst outlier contributes.
    total_time = sum(r["time_min"] for r in rows if numeric(r.get("time_min")))
    total_cost = sum(r["cost_usd"] for r in rows if numeric(r.get("cost_usd")))
    worst_time = slowest[0]
    worst_cost = expensive[0]

    md = []
    md.append(f"# Focused efficiency analysis: {LABEL}\n")
    md.append("Run: `artisan-gpt5.1-dbe0`\n")
    md.append("All times are minutes per instance; costs are USD per instance. Statuses/times use the same manual-effectiveness and artisan.log time corrections as the main analysis. SD is sample standard deviation.\n")
    md.append("## Overall and success/failure distribution\n")
    md.append(md_table(
        ["Group", "n", "Cost mean", "Cost median", "Cost SD", "Cost p90", "Cost max", "Time mean", "Time median", "Time SD", "Time p90", "Time p95", "Time max"],
        group_rows,
        [":--", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:"],
    ))
    md.append("## Outcome-level distribution\n")
    md.append(md_table(
        ["Outcome", "n", "Cost mean", "Cost median", "Cost SD", "Cost p90", "Cost max", "Time mean", "Time median", "Time SD", "Time p90", "Time p95", "Time max", "Worst-time instance", "Worst-cost instance"],
        outcome_rows,
        [":--", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", ":--", ":--"],
    ))
    md.append("## Longest-running instances\n")
    md.append(md_table(
        ["Rank", "Instance", "Outcome", "Time", "Cost", "LLM", "Exec", "Judge wait", "Format", "LLM judge"],
        slow_rows,
        ["--:", ":--", ":--", "--:", "--:", "--:", "--:", "--:", "--:", "--:"],
    ))
    md.append("## Most expensive instances\n")
    md.append(md_table(
        ["Rank", "Instance", "Outcome", "Cost", "Time"],
        cost_rows,
        ["--:", ":--", ":--", "--:", "--:"],
    ))
    md.append("## Sensitivity to longest-running outliers\n")
    md.append(md_table(
        ["Subset", "n", "Time mean", "Time median", "Time SD", "Time p90", "Time max", "Cost mean", "Cost median"],
        sensitivity_rows,
        [":--", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:"],
    ))
    md.append("## Outlier contribution\n")
    md.append(f"- Slowest instance: `{worst_time['instance']}` ({worst_time['status']}), {worst_time['time_min']:.1f} min, {100.0 * worst_time['time_min'] / total_time:.1f}% of aggregate per-instance runtime.\n")
    md.append(f"- Most expensive instance: `{worst_cost['instance']}` ({worst_cost['status']}), ${worst_cost['cost_usd']:.3f}, {100.0 * worst_cost['cost_usd'] / total_cost:.1f}% of total cost.\n")

    report_path = OUT / "artisan_gpt51_focus.md"
    report_path.write_text("\n".join(md), encoding="utf-8")
    print(f"Wrote {report_path}")
    print(f"Wrote {csv_path}")

if __name__ == "__main__":
    main()
