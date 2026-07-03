#!/usr/bin/env python3
# %%
from __future__ import annotations

from pathlib import Path
import json
import logging
import math
import re
from typing import Any, Optional
import matplotlib.pyplot as plt
import numpy as np
from correct_effectiveness import correct_effectiveness_from_manual_md
from correct_time import correct_time_from_logs

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------

log_base_path = "/Users/doehyunbaek/artisan-logs"
log_base = Path(log_base_path)

sweagent_deepseek_name = "sweagent-deepseek-reasoner-4bdc"
sweagent_gpt5mini_name = "sweagent-gpt5mini-5d98"
sweagent_gpt51_name = "sweagent-gpt5.1-ebe4"

openhands_deepseek_name = "openhands-deepseek-reasoner-bd34"
openhands_gpt5mini_name = "openhands-gpt5mini-a4eb"
openhands_gpt51_name = "openhands-gpt5.1-41ec"

minisweagent_deepseek_name = "minisweagent-deepseek-reasoner-e5a7"
minisweagent_gpt5mini_name = "minisweagent-gpt5mini-a830"
minisweagent_gpt51_name = "minisweagent-gpt5.1-301b"

artisan_deepseek_name = "artisan-deepseek-reasoner-6f4b"
artisan_gpt5mini_name = "artisan-gpt5mini-845b"
artisan_gpt51_name = "artisan-gpt5.1-dbe0"

ablation_wooutput_name = "artisan-gpt5.1-3ee0-without_output"
ablation_womethod_name = "artisan-gpt5.1-7a04-without_method"
ablation_format_name = "artisan-gpt5.1-9223-without_format"

# cache
_DATA_CACHE: dict[tuple[str, bool, bool, str], tuple[dict[str, Any], dict[str, Any]] | None] = {}

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

def infer_run_name_from_json_path(json_path: Path) -> str:
    """
    For /.../<run_name>/reprobench.json -> run_name
    """
    return json_path.parent.name


def _safe_int(x: Any, default: int = 0) -> int:
    try:
        if isinstance(x, bool):
            return default
        if isinstance(x, (int, float)) and not math.isnan(float(x)):
            return int(x)
    except Exception:
        pass
    return default


# -----------------------------------------------------------------------------
# load_data (applies correct_time + correct_effectiveness)
# -----------------------------------------------------------------------------

def load_data(
    json_path: str | Path,
    *,
    correct_time: bool = True,
    correct_effectiveness: bool = True,
    manual_analysis_root: str | Path | None = None,
) -> Optional[tuple[dict[str, Any], dict[str, Any]]]:
    path = Path(json_path)

    manual_root_str = str(Path(manual_analysis_root).resolve()) if manual_analysis_root else ""
    cache_key = (str(path), correct_time, correct_effectiveness, manual_root_str)
    if cache_key in _DATA_CACHE:
        return _DATA_CACHE[cache_key]

    if not path.exists():
        logger.error("Error: JSON file not found at %s", path)
        _DATA_CACHE[cache_key] = None
        return None

    try:
        data = json.loads(path.read_text("utf-8"))
    except Exception as e:
        logger.error("Error reading JSON %s: %s", path, e)
        _DATA_CACHE[cache_key] = None
        return None

    instances = data.get("instance", {})
    total_stats = data.get("total", {})

    if not isinstance(instances, dict) or not isinstance(total_stats, dict):
        logger.error("Malformed json: expected dict at instance/total in %s", path)
        _DATA_CACHE[cache_key] = None
        return None

    # 1) time correction (NOW: from artisan.log via correct_time.py)
    if correct_time:
        n_fill, n_fill_judge_wait, n_shrink = correct_time_from_logs(
            instances,
            path.parent,
            fill_agent_time=True,
            shrink_time=True,
        )
        if n_fill or n_fill_judge_wait or n_shrink:
            logger.info(
                "[correct_time] filled agent_time=%d, filled judge_wait=%d, shrunk time=%d under %s",
                n_fill,
                n_fill_judge_wait,
                n_shrink,
                path.parent,
            )

    # 2) effectiveness correction (manual analysis)
    if correct_effectiveness:
        if manual_analysis_root is None:
            logger.error("[correct_effectiveness] manual_analysis_root is required")
        else:
            run_name = infer_run_name_from_json_path(path)
            manual_md_path = Path(manual_analysis_root) / f"{run_name}.md"
            applied = correct_effectiveness_from_manual_md(instances, total_stats, manual_md_path)
            if applied:
                logger.info("[correct_effectiveness] applied %d overrides from %s", applied, manual_md_path)

    result = (instances, total_stats)
    _DATA_CACHE[cache_key] = result
    return result


# -----------------------------------------------------------------------------
# Table summaries
# -----------------------------------------------------------------------------

def _summarize_folder(json_path: str | Path):
    """
    Returns:
      (c_full, c_last, c_copy, c_mis, c_run, c_stat, avg_cost, avg_time)
    or None if load fails / no instances.
    """
    loaded = load_data(
        json_path,
        correct_time=True,
        correct_effectiveness=True,
        manual_analysis_root=log_base / "manual_analysis",
    )
    if not loaded:
        return None

    instances, total_stats = loaded
    if not instances:
        return None

    c_full = c_last = c_copy = c_mis = c_run = c_stat = 0
    costs: list[float] = []
    times: list[float] = []

    for _, data in instances.items():
        if not isinstance(data, dict):
            continue

        status = (
            data.get("exit_status")
            or data.get("status")
            or data.get("result")
            or data.get("judge_status")
            or ""
        )

        if status == "FULL_REPRO":
            c_full += 1
        elif status == "LASTMILE_REPRO":
            c_last += 1
        elif status == "COPY_REPRO":
            c_copy += 1
        elif status == "MISMATCH_ERROR":
            c_mis += 1
        elif status == "RUNTIME_ERROR":
            c_run += 1
        elif status == "STATIC_ERROR":
            c_stat += 1

        cost = data.get("cost", 0.0)
        if isinstance(cost, (int, float)) and not (isinstance(cost, float) and math.isnan(cost)):
            costs.append(float(cost))

        time_val = data.get("time", 0.0)
        if isinstance(time_val, (int, float)) and not (isinstance(time_val, float) and math.isnan(time_val)):
            times.append(float(time_val))

    avg_cost = (sum(costs) / len(costs)) if costs else 0.0
    avg_time = (sum(times) / len(times)) if times else 0.0

    # Prefer totals if per-instance counts mismatch
    t_full = _safe_int(total_stats.get("total_full_repro"), 0)
    t_last = _safe_int(total_stats.get("total_lastmile_repro"), 0)
    t_copy = _safe_int(total_stats.get("total_copy_repro"), 0)
    t_mis = _safe_int(total_stats.get("total_mismatch_error"), 0)
    t_run = _safe_int(total_stats.get("total_runtime_error"), 0)
    t_stat = _safe_int(total_stats.get("total_static_error"), 0)

    if (c_full, c_last, c_copy, c_mis, c_run, c_stat) != (t_full, t_last, t_copy, t_mis, t_run, t_stat):
        c_full, c_last, c_copy, c_mis, c_run, c_stat = t_full, t_last, t_copy, t_mis, t_run, t_stat

    # Prefer total's cost_per_instance if present
    t_cost_per_instance = total_stats.get("cost_per_instance")
    if t_cost_per_instance is None and "total_cost" in total_stats:
        total_count = t_full + t_last + t_copy + t_mis + t_run + t_stat
        if total_count > 0:
            try:
                t_cost_per_instance = float(total_stats["total_cost"]) / float(total_count)
            except Exception:
                t_cost_per_instance = None

    if isinstance(t_cost_per_instance, (int, float)) and not (isinstance(t_cost_per_instance, float) and math.isnan(t_cost_per_instance)):
        avg_cost = float(t_cost_per_instance)

    return (c_full, c_last, c_copy, c_mis, c_run, c_stat, avg_cost, avg_time)


# -----------------------------------------------------------------------------
# LaTeX table writers
# -----------------------------------------------------------------------------

def write_baseline_table(out_path: str | Path | None = None) -> None:
    rows = [
        (
            "SWE-agent",
            [
                ("-- w/ DeepSeek", sweagent_deepseek_name),
                ("-- w/ gpt-5-mini", sweagent_gpt5mini_name),
                ("-- w/ gpt-5.1", sweagent_gpt51_name),
            ],
        ),
        (
            "OpenHands",
            [
                ("-- w/ DeepSeek", openhands_deepseek_name),
                ("-- w/ gpt-5-mini", openhands_gpt5mini_name),
                ("-- w/ gpt-5.1", openhands_gpt51_name),
            ],
        ),
        (
            "mini-swe-agent",
            [
                ("-- w/ DeepSeek", minisweagent_deepseek_name),
                ("-- w/ gpt-5-mini", minisweagent_gpt5mini_name),
                ("-- w/ gpt-5.1", minisweagent_gpt51_name),
            ],
        ),
        (
            "Artisan",
            [
                ("-- w/ DeepSeek", artisan_deepseek_name),
                ("-- w/ gpt-5-mini", artisan_gpt5mini_name),
                ("-- w/ gpt-5.1", artisan_gpt51_name),
            ],
        ),
    ]

    lines: list[str] = []
    lines.append(r"{\setlength{\tabcolsep}{3pt}")
    lines.append(r"\begin{tabular}{lcccccccc}")
    lines.append(r"\toprule")
    lines.append(
        r"\multirow{2}{*}{ID} & \multicolumn{2}{c}{Success} & \multicolumn{4}{c}{Failure} & \multirow{2}{*}{\shortstack{Cost}} & \multirow{2}{*}{\shortstack{Time}} \\"
    )
    lines.append(r"\cmidrule(lr){2-3} \cmidrule(lr){4-7}")
    lines.append(r" & Full Rep. & Last. Rep. & Copy Res. & Mis. Res. & Run. Err. & Stat. Err. & & \\")
    lines.append(r"\midrule")

    for section_name, subsections in rows:
        lines.append(f"{section_name} & & & & & & & & \\\\")
        for sub_name, folder_name in subsections:
            if not folder_name:
                lines.append(f"{sub_name} & & & & & & & & \\\\")
                continue

            json_path = log_base / folder_name / "reprobench.json"
            summary = _summarize_folder(json_path)
            if summary is None:
                lines.append(f"{sub_name} & - & - & - & - & - & - & - & - \\\\")
                continue

            c_full, c_last, c_copy, c_mis, c_run, c_stat, avg_cost, avg_time = summary
            cost_str = f"\\${avg_cost:.2f}"

            avg_time_min = avg_time / 60.0
            time_str = f"{avg_time_min:.1f} min"

            lines.append(
                f"{sub_name} & {c_full} & {c_last} & {c_copy} & {c_mis} & {c_run} & {c_stat} & {cost_str} & {time_str} \\\\"
            )

        if section_name == "mini-swe-agent":
            lines.append(r"\midrule")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"}")

    for line in lines:
        print(line)

    if out_path is not None:
        out_path = Path(out_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_ablation_table(out_path: str | Path | None = None) -> None:
    rows = [
        ("\\shortstack{-- w/o Output Judge}", ablation_wooutput_name),
        ("\\shortstack{-- w/o Method Judge}", ablation_womethod_name),
        ("\\shortstack{-- w/o Format}", ablation_format_name),
        ("\\shortstack{-- Full}", artisan_gpt51_name),
    ]

    lines: list[str] = []
    lines.append(r"{\setlength{\tabcolsep}{2pt}")
    lines.append(r"\begin{tabular}{lcccccccc}")
    lines.append(r"\toprule")
    lines.append(
        r"\multirow{2}{*}{ID} & \multicolumn{2}{c}{Success} & \multicolumn{4}{c}{Failure} & \multirow{2}{*}{\shortstack{Cost}} & \multirow{2}{*}{\shortstack{Time}} \\"
    )
    lines.append(r"\cmidrule(lr){2-3} \cmidrule(lr){4-7}")
    lines.append(r" & Full Rep. & Last. Rep. & Copy Res. & Mis. Res. & Run. Err. & Stat. Err. & & \\")
    lines.append(r"\midrule")

    lines.append(r"Artisan      & & & & & & & & \\")
    for label, folder_name in rows:
        if not folder_name:
            lines.append(f"{label} & - & - & - & - & - & - & - & - \\\\")
            continue

        json_path = log_base / folder_name / "reprobench.json"
        summary = _summarize_folder(json_path)

        if summary is None:
            lines.append(f"{label} & - & - & - & - & - & - & - & - \\\\")
            continue

        c_full, c_last, c_copy, c_mis, c_run, c_stat, avg_cost, avg_time = summary
        cost_str = f"\\${avg_cost:.2f}"

        avg_time_min = avg_time / 60.0
        time_str = f"{avg_time_min:.1f} min"

        lines.append(
            f"{label} & {c_full} & {c_last} & {c_copy} & {c_mis} & {c_run} & {c_stat} & {cost_str} & {time_str} \\\\"
        )

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"}")

    for line in lines:
        print(line)

    if out_path is not None:
        out_path = Path(out_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

def plot_pareto_front(
    save_path=None,
    correct_time=True,
):
    """
    Pareto front plot (NO ablations):
      X = #successes (FULL_REPRO + LASTMILE_REPRO)
      Y = tasks per dollar = 1 / cost_per_instance

    Encoding:
      - Color = approach family (SWE-agent, OpenHands, mini-swe-agent, Artisan)
      - Marker = model (gpt-5.1, gpt-5-mini, DeepSeek)

    Layout:
      - Two vertical legends stacked on the right:
        Approach (top), Model (below)

    Paper tweak:
      - NARROWER figure, BIGGER fonts for readability in a ~0.48\\linewidth minipage
    """
    # -----------------------
    # What to include (NO ablations)
    # -----------------------
    runs = [
        ("SWE-agent", "DeepSeek", sweagent_deepseek_name, "SWE-agent (DeepSeek)"),
        ("SWE-agent", "gpt-5-mini", sweagent_gpt5mini_name, "SWE-agent (gpt-5-mini)"),
        ("SWE-agent", "gpt-5.1", sweagent_gpt51_name, "SWE-agent (gpt-5.1)"),
        ("OpenHands", "DeepSeek", openhands_deepseek_name, "OpenHands (DeepSeek)"),
        ("OpenHands", "gpt-5-mini", openhands_gpt5mini_name, "OpenHands (gpt-5-mini)"),
        ("OpenHands", "gpt-5.1", openhands_gpt51_name, "OpenHands (gpt-5.1)"),
        ("mini-swe-agent", "DeepSeek", minisweagent_deepseek_name, "mini-swe-agent (DeepSeek)"),
        ("mini-swe-agent", "gpt-5-mini", minisweagent_gpt5mini_name, "mini-swe-agent (gpt-5-mini)"),
        ("mini-swe-agent", "gpt-5.1", minisweagent_gpt51_name, "mini-swe-agent (gpt-5.1)"),
        ("Artisan", "DeepSeek", artisan_deepseek_name, "Artisan (DeepSeek)"),
        ("Artisan", "gpt-5-mini", artisan_gpt5mini_name, "Artisan (gpt-5-mini)"),
        ("Artisan", "gpt-5.1", artisan_gpt51_name, "Artisan (gpt-5.1)"),
    ]

    # -----------------------
    # Visual encodings
    # -----------------------
    approach_to_color = {
        "SWE-agent": "#1f77b4",
        "OpenHands": "#ff7f0e",
        "mini-swe-agent": "#2ca02c",
        "Artisan": "#d62728",
    }

    model_to_marker = {
        "gpt-5.1": "o",
        "gpt-5-mini": "s",
        "DeepSeek": "D",
    }

    # -----------------------
    # Extract metrics per run
    # -----------------------
    def compute_metrics(folder_name: str):
        json_path = log_base / folder_name / "reprobench.json"
        loaded = load_data(
            json_path,
            correct_time=correct_time,
            correct_effectiveness=True,
            manual_analysis_root=log_base / "manual_analysis",
        )
        if not loaded:
            return None

        instances, total_stats = loaded
        if not instances:
            return None

        # --- Success count ---
        t_full = total_stats.get("total_full_repro")
        t_last = total_stats.get("total_lastmile_repro")
        if isinstance(t_full, int) and isinstance(t_last, int):
            success_count = t_full + t_last
        else:
            return None  # can't define X without these

        # --- cost_per_instance ---
        cpi = total_stats.get("cost_per_instance", None)

        if cpi is None and "total_cost" in total_stats:
            totals = [
                total_stats.get("total_full_repro", 0),
                total_stats.get("total_lastmile_repro", 0),
                total_stats.get("total_copy_repro", 0),
                total_stats.get("total_mismatch_error", 0),
                total_stats.get("total_runtime_error", 0),
                total_stats.get("total_static_error", 0),
            ]
            total_count = sum(int(x) for x in totals if isinstance(x, int))
            if total_count <= 0:
                total_count = len(instances)
            if total_count > 0:
                try:
                    cpi = float(total_stats["total_cost"]) / float(total_count)
                except Exception:
                    cpi = None

        if cpi is None:
            costs = []
            for _, d in instances.items():
                if not isinstance(d, dict):
                    continue
                c = d.get("cost", None)
                if isinstance(c, (int, float)):
                    costs.append(float(c))
            if costs:
                cpi = sum(costs) / len(costs)

        if cpi is None or not isinstance(cpi, (int, float)) or cpi <= 0:
            tasks_per_dollar = None
        else:
            tasks_per_dollar = 1.0 / float(cpi)

        return {
            "success": int(success_count),
            "cost_per_instance": float(cpi) if cpi is not None else None,
            "tasks_per_dollar": tasks_per_dollar,
        }

    points = []
    for approach, model, folder, label in runs:
        m = compute_metrics(folder)
        if not m or m["tasks_per_dollar"] is None:
            logger.info(f"Skipping (missing cost): {label}")
            continue
        points.append(
            dict(
                approach=approach,
                model=model,
                folder=folder,
                label=label,
                x=m["success"],
                y=m["tasks_per_dollar"],
                cpi=m["cost_per_instance"],
            )
        )

    if not points:
        print("No valid points found (check reprobench.json totals / costs).")
        return

    # -----------------------
    # Plot: narrower + larger fonts (good for ~0.48\linewidth)
    # -----------------------
    import matplotlib as mpl
    from matplotlib.lines import Line2D

    # Larger fonts + slightly thicker lines; keep this local via rc_context
    paper_rc = {
        "font.size": 12,
        "axes.titlesize": 13,
        "axes.labelsize": 12,
        "xtick.labelsize": 11,
        "ytick.labelsize": 11,
        "legend.fontsize": 11,
        "legend.title_fontsize": 11,
        "axes.linewidth": 1.0,
        "grid.linewidth": 0.8,
    }

    with mpl.rc_context(paper_rc):
        # narrower width, still enough height for legends + labels
        fig, ax = plt.subplots(figsize=(6.1, 4.4), dpi=170)

        for p in points:
            ax.scatter(
                p["x"],
                p["y"],
                s=95,  # a bit larger markers for print
                c=approach_to_color.get(p["approach"], "gray"),
                marker=model_to_marker.get(p["model"], "o"),
                edgecolor="black",
                linewidths=0.8,
                alpha=0.95,
                zorder=3,
            )

        ax.set_xlabel("# Successful reproductions (FULL + LASTMILE)")
        ax.set_ylabel("Tasks per dollar (1/Cost per task)")
        ax.grid(True, linestyle="--", alpha=0.5)
        ax.margins(x=0.05, y=0.08)

        approach_handles = [
            Line2D([0],[0], marker="o", linestyle="",
                markerfacecolor=approach_to_color[a],
                markeredgecolor="black", markersize=9, label=a)
            for a in ["SWE-agent","OpenHands","mini-swe-agent","Artisan"]
        ]

        model_handles = [
            Line2D([0],[0], marker=model_to_marker[m], linestyle="",
                markerfacecolor="white", markeredgecolor="black",
                markersize=9, label=m)
            for m in ["gpt-5.1","gpt-5-mini","DeepSeek"]
        ]

        # --- Legends INSIDE the plot (top-right), stacked ---
        leg1 = ax.legend(
            handles=approach_handles,
            title="Approach (color)",
            loc="upper right",
            bbox_to_anchor=(0.98, 0.98),   # inside top-right
            borderaxespad=0.0,
            framealpha=0.95,
            ncol=1,
        )
        ax.add_artist(leg1)

        ax.legend(
            handles=model_handles,
            title="Model (shape)",
            loc="upper right",
            bbox_to_anchor=(0.98, 0.6),   # directly below leg1
            borderaxespad=0.0,
            framealpha=0.95,
            ncol=1,
        )


        # Leave room on the right for the legends
        fig.subplots_adjust(right=0.73)
        plt.show()

        if save_path:
            fig.savefig(save_path, dpi=300, bbox_inches="tight")
            logger.info(f"Saved: {save_path}")

def plot_time_breakdown(
    save_path=None,
    num_outliers=0,
    show_additional_metrics=False,
    y_cap=12_000,
    draw_waves=True,
):
    """
    Time breakdown stacked bar plot for Artisan (gpt-5.1).

    Fixes applied (minimal, per request):
      - Keep legend/text boxes behavior & styling (do NOT change placement logic)
      - Remove hard-coded "rust-t2" label; show true max-key + max-total in SAME text box style/pos
      - Slightly larger fonts, SAME canvas size
      - Robustness: handle missing load_data / instances
      - Clamp times to non-negative to avoid odd logs breaking stacks
      - Ensure wave line isn't clipped and draws on top
    """
    import numpy as np
    import matplotlib.pyplot as plt
    import matplotlib as mpl

    json_path = log_base / artisan_gpt51_name / "reprobench.json"
    loaded = load_data(
        json_path,
        correct_time=True,
        correct_effectiveness=True,
        manual_analysis_root=log_base / "manual_analysis",
    )
    if not loaded:
        print(f"Could not load: {json_path}")
        return

    instances, _ = loaded
    if not instances:
        print(f"No instances in: {json_path}")
        return

    entries = []
    for key, val in instances.items():
        if not (isinstance(val, dict) and isinstance(val.get("time"), (int, float))):
            continue

        total_time = max(0.0, float(val["time"]))
        llm_time = max(0.0, float(val.get("llm_time", 0.0)))
        exec_time = max(0.0, float(val.get("exec_time", 0.0)) + float(val.get("judge_wait", 0.0)))

        if show_additional_metrics:
            format_time = max(0.0, float(val.get("format_time", 0.0)))
            llmjudge_time = max(0.0, float(val.get("llmjudge_time", 0.0)))
        else:
            format_time = 0.0
            llmjudge_time = 0.0

        rest_time = max(0.0, total_time - llm_time - exec_time - format_time - llmjudge_time)

        entries.append(
            {
                "key": key,
                "total": total_time,
                "llm": llm_time,
                "exec": exec_time,
                "rest": rest_time,
                "format": format_time,
                "llmjudge": llmjudge_time,
            }
        )

    if not entries:
        print("No valid timing entries found.")
        return

    # Remove outliers (largest totals), then sort ascending for plotting
    entries.sort(key=lambda x: x["total"], reverse=True)
    if num_outliers > 0:
        entries = entries[num_outliers:]
    entries.sort(key=lambda x: x["total"])


    def strip_run_suffix(s: str) -> str:
        # removes trailing "-r<number>" (e.g., "rust-t2-r1" -> "rust-t2")
        return re.sub(r"-r\d+$", "", s)
    labels = [strip_run_suffix(e["key"]) for e in entries]

    # True (untruncated) values
    v_rest_true = [e["rest"] for e in entries]
    v_llm_true = [e["llm"] for e in entries]
    v_exec_true = [e["exec"] for e in entries]
    v_format_true = [e["format"] for e in entries]
    v_llmjudge_true = [e["llmjudge"] for e in entries]
    v_total_true = [e["total"] for e in entries]

    # Truncate stacked segments so stack never exceeds y_cap.
    # IMPORTANT: order matches stacking order: rest -> llm -> exec -> format -> llmjudge
    def truncate_stack(rest, llm, exec_, fmt, judge, cap):
        shown_rest, shown_llm, shown_exec, shown_fmt, shown_judge = [], [], [], [], []
        for r, l, e, f, j in zip(rest, llm, exec_, fmt, judge):
            remaining = cap

            sr = min(r, remaining)
            remaining -= sr
            sl = min(l, remaining)
            remaining -= sl
            se = min(e, remaining)
            remaining -= se
            sf = min(f, remaining)
            remaining -= sf
            sj = min(j, remaining)
            remaining -= sj

            shown_rest.append(sr)
            shown_llm.append(sl)
            shown_exec.append(se)
            shown_fmt.append(sf)
            shown_judge.append(sj)

        return shown_rest, shown_llm, shown_exec, shown_fmt, shown_judge

    v_rest, v_llm, v_exec, v_format, v_llmjudge = truncate_stack(
        v_rest_true, v_llm_true, v_exec_true, v_format_true, v_llmjudge_true, y_cap
    )

    # SAME canvas size as before; slightly larger fonts only
    paper_rc = {
        "font.size": 14,
        "axes.labelsize": 14,
        "xtick.labelsize": 11,
        "ytick.labelsize": 13,
        "legend.fontsize": 13,
        "legend.title_fontsize": 13,
        "axes.linewidth": 1.0,
        "grid.linewidth": 0.8,
    }

    width_in = max(12.0, 0.25 * len(entries))

    with mpl.rc_context(paper_rc):
        fig, ax = plt.subplots(figsize=(width_in, 6), dpi=120)

        indices = np.arange(len(entries))
        bar_w = 0.8

        # Stacked bars (truncated) — preserve original semantics
        ax.bar(indices, v_llm, width=bar_w, bottom=v_rest, align="center", alpha=0.8, label="LLM Time")
        bottom_exec = [r + l for r, l in zip(v_rest, v_llm)]
        ax.bar(indices, v_exec, width=bar_w, bottom=bottom_exec, align="center", alpha=0.8, label="Execution Time")

        current_bottom = [b + e for b, e in zip(bottom_exec, v_exec)]

        if show_additional_metrics:
            ax.bar(indices, v_format, width=bar_w, bottom=current_bottom, align="center", alpha=0.8, label="Format Time")
            current_bottom = [b + f for b, f in zip(current_bottom, v_format)]

            ax.bar(
                indices,
                v_llmjudge,
                width=bar_w,
                bottom=current_bottom,
                align="center",
                alpha=0.8,
                label="LLM Judge Time",
            )

        # ----------------------------
        # Mark and annotate capped bars
        # Keep text-box style/placement; remove hard-coded label
        # ----------------------------
        capped_idxs = [i for i, t in enumerate(v_total_true) if t > y_cap]

        if capped_idxs:
            ax.axhline(y_cap, linestyle="--", alpha=0.6)

            max_i = int(np.argmax(v_total_true))
            max_total = float(v_total_true[max_i])
            max_key = labels[max_i]

            ax.text(
                0.99,
                0.98,
                f"{max_key}: {max_total:.1f}s",
                transform=ax.transAxes,
                ha="right",
                va="top",
                fontsize=9,
                bbox=dict(boxstyle="round,pad=0.35", facecolor="white", edgecolor="black", alpha=0.9),
            )

        # Draw "wave cut" on bars exceeding the cap
        if draw_waves and capped_idxs:
            amp = max(20.0, y_cap * 0.005)  # wave amplitude
            cycles = 2.0                    # number of wave cycles across bar width

            for i in capped_idxs:
                left = indices[i] - bar_w / 2
                right = indices[i] + bar_w / 2
                xs = np.linspace(left, right, 80)
                ys = y_cap + amp * np.sin(2 * np.pi * cycles * (xs - left) / (right - left))
                ax.plot(xs, ys, linewidth=1.5, zorder=5)

        ax.set_xticks(indices)
        ax.set_xticklabels(labels, rotation=60, ha="right")

        ax.set_ylabel("Time (seconds)")
        ax.grid(axis="y", linestyle="--", alpha=0.6)

        # Keep legend behavior unchanged
        ax.legend()

        # Give headroom so the wave isn't clipped
        ax.set_ylim(0, y_cap * 1.08)

        plt.tight_layout()
        plt.show()

        if save_path:
            fig.savefig(save_path, dpi=300, bbox_inches="tight")
   

# -----------------------------------------------------------------------------
# Success set computations (approach-wide union + common/only/fail)
# -----------------------------------------------------------------------------

SUCCESS_STATUSES = {"FULL_REPRO", "LASTMILE_REPRO"}


def _get_success_set(json_path: str | Path) -> set[str]:
    """
    Success set = instance keys whose final status is FULL_REPRO or LASTMILE_REPRO.
    Uses load_data(), so it respects correct_time + correct_effectiveness.
    """
    loaded = load_data(
        json_path,
        correct_time=True,
        correct_effectiveness=True,
        manual_analysis_root=log_base / "manual_analysis",
    )
    if not loaded:
        return set()

    instances, _ = loaded
    if not isinstance(instances, dict) or not instances:
        return set()

    s: set[str] = set()
    for key, data in instances.items():
        if not isinstance(data, dict):
            continue

        status = (
            data.get("exit_status")
            or data.get("status")
            or data.get("result")
            or data.get("judge_status")
            or ""
        )

        if status in SUCCESS_STATUSES:
            s.add(str(key))

    return s


def _get_universe_keys(json_paths: list[Path]) -> set[str]:
    """
    Universe = all instance keys that appear in ANY of the runs.
    (Safer than hardcoding 60.)
    """
    universe: set[str] = set()
    for p in json_paths:
        loaded = load_data(
            p,
            correct_time=True,
            correct_effectiveness=True,
            manual_analysis_root=log_base / "manual_analysis",
        )
        if not loaded:
            continue
        instances, _ = loaded
        if isinstance(instances, dict):
            universe |= {str(k) for k in instances.keys()}
    return universe


def compute_and_print_success_sets(print_examples: int = 10) -> dict[str, Any]:
    """
    Computes:
      1) approach-wide success sets = union over 3 models for each approach
      2) common_success = successes that ALL approaches get right (excluding SWE-agent)
      3) only_success[approach] = successes only that approach gets right
      4) fail_set = instances that NONE of the approaches get right

    Returns a dict with all sets (as sorted lists) + counts.
    """
    approach_to_runs: dict[str, list[str]] = {
        "SWE-agent": [sweagent_deepseek_name, sweagent_gpt5mini_name, sweagent_gpt51_name],
        "OpenHands": [openhands_deepseek_name, openhands_gpt5mini_name, openhands_gpt51_name],
        "mini-swe-agent": [minisweagent_deepseek_name, minisweagent_gpt5mini_name, minisweagent_gpt51_name],
        "Artisan": [artisan_deepseek_name, artisan_gpt5mini_name, artisan_gpt51_name, ],

    }

    # All baseline reprobench.json paths (for universe + debugging)
    all_json_paths: list[Path] = []
    for run_list in approach_to_runs.values():
        for folder in run_list:
            all_json_paths.append(log_base / folder / "reprobench.json")

    universe = _get_universe_keys(all_json_paths)

    # 1) Approach-wide union success sets
    approach_success: dict[str, set[str]] = {}
    for approach, run_list in approach_to_runs.items():
        s_union: set[str] = set()
        for folder in run_list:
            json_path = log_base / folder / "reprobench.json"
            s_union |= _get_success_set(json_path)
        approach_success[approach] = s_union

    # 2) common_success = intersection across all approaches excluding SWE-agent
    if approach_success:
        except_sweagent = {k: v for k, v in approach_success.items() if k != "SWE-agent"}
        common_success = set.intersection(*except_sweagent.values())
    else:
        common_success = set()

    # 3) only_success[approach] = approach_set - union(other_sets)
    only_success: dict[str, set[str]] = {}
    for approach, s in approach_success.items():
        others_union = set()
        for other_a, other_s in approach_success.items():
            if other_a == approach:
                continue
            others_union |= other_s
        only_success[approach] = s - others_union

    

    # 4) fail_set = universe - union(all approach success sets)
    all_success_union = set()
    for s in approach_success.values():
        all_success_union |= s
    fail_set = universe - all_success_union

    # -----------------------
    # Print summary
    # -----------------------
    def _fmt_some(xs: set[str]) -> str:
        xs_sorted = sorted(xs)
        if not xs_sorted:
            return "(empty)"
        if len(xs_sorted) <= print_examples:
            return ", ".join(xs_sorted)
        return ", ".join(xs_sorted[:print_examples]) + f", ... (+{len(xs_sorted) - print_examples} more)"

    logger.info("")
    logger.info("============================================================")
    logger.info("Approach-wide success sets (union over 3 models)")
    logger.info("Success = {FULL_REPRO, LASTMILE_REPRO}")
    logger.info("Universe size = %d", len(universe))
    logger.info("------------------------------------------------------------")

    for approach in ["SWE-agent", "OpenHands", "mini-swe-agent", "Artisan"]:
        s = approach_success.get(approach, set())
        logger.info("%-13s | success=%3d | examples: %s", approach, len(s), _fmt_some(s))

    logger.info("------------------------------------------------------------")
    logger.info("common_success (ALL approaches succeed excluding SWE-agent) = %d", len(common_success))
    logger.info("examples: %s", _fmt_some(common_success))
    logger.info("------------------------------------------------------------")

    for approach in ["SWE-agent", "OpenHands", "mini-swe-agent", "Artisan"]:
        s_only = only_success.get(approach, set())
        logger.info("only_%s = %d", approach.replace("-", "_"), len(s_only))
        logger.info("examples: %s", _fmt_some(s_only))

    logger.info("------------------------------------------------------------")
    logger.info("fail_set (NONE succeed) = %d", len(fail_set))
    logger.info("examples: %s", _fmt_some(fail_set))
    logger.info("============================================================")
    logger.info("")

    # Return machine-usable result
    return {
        "universe": sorted(universe),
        "approach_success": {k: sorted(v) for k, v in approach_success.items()},
        "common_success": sorted(common_success),
        "only_success": {k: sorted(v) for k, v in only_success.items()},
        "fail_set": sorted(fail_set),
        "counts": {
            "universe": len(universe),
            "approach_success": {k: len(v) for k, v in approach_success.items()},
            "common_success": len(common_success),
            "only_success": {k: len(v) for k, v in only_success.items()},
            "fail_set": len(fail_set),
        },
    }

# -----------------------------------------------------------------------------
# Step-limit (30) analysis
# -----------------------------------------------------------------------------

_STEP_LIMIT_MARKERS = {
    # Artisan / mini-swe-agent (often recorded as "LimitsExceeded" when hitting max-steps)
    "LimitsExceeded",
    # OpenHands
    "MaxIterationsReached",
    # SWE-agent
    "API calls 31 exceeds limit 30"
}


def _table_dir_to_tnum(table_dir_name: str) -> Optional[int]:
    # "table_3" -> 3
    if not table_dir_name.startswith("table_"):
        return None
    try:
        return int(table_dir_name.split("_", 1)[1])
    except Exception:
        return None


def _instance_dir_to_key(instance_dir: Path) -> Optional[str]:
    """
    Given:
      <run_root>/<benchmark>/<table_k>/<seed>/<...>
    Return:
      "<benchmark>-t<k>-r1"
    """
    try:
        # seed dir's parent is table_k, its parent is benchmark
        seed = instance_dir.name
        table_dir = instance_dir.parent
        bench_dir = table_dir.parent

        tnum = _table_dir_to_tnum(table_dir.name)
        if tnum is None:
            return None

        bench = bench_dir.name
        # Your keys elsewhere look like "<bench>-t<num>-r1"
        return f"{bench}-t{tnum}-r1"
    except Exception:
        return None


def _read_text_if_exists(p: Path, max_bytes: int = 10_000_000) -> str:
    try:
        if p.exists() and p.is_file():
            # Avoid loading huge traj files into memory.
            with p.open("rb") as f:
                b = f.read(max_bytes)
            return b.decode("utf-8", errors="ignore")
    except Exception:
        pass
    return ""


def _instance_hit_step_limit(instance_dir: Path) -> bool:
    """
    Heuristic detection per instance directory.

    Checks (in order):
      - openhands.json contains MaxIterationsReached
      - mini.json contains exit_status == LimitsExceeded (or marker string)
      - artisan.log contains marker string
      - *.traj contains marker string (bounded read)
    """
    # 1) OpenHands
    oh_json = instance_dir / "openhands.json"
    if oh_json.exists():
        txt = _read_text_if_exists(oh_json)
        if any(m in txt for m in _STEP_LIMIT_MARKERS):
            return True

    # 2) mini.json (common for mini-swe-agent; sometimes also present for Artisan-derived logging)
    mini_json = instance_dir / "mini.json"
    if mini_json.exists():
        try:
            obj = json.loads(mini_json.read_text("utf-8"))
            # Most direct signal:
            if isinstance(obj, dict) and obj.get("exit_status") == "LimitsExceeded":
                return True
        except Exception:
            pass

        txt = _read_text_if_exists(mini_json)
        if any(m in txt for m in _STEP_LIMIT_MARKERS):
            return True

    # 3) artisan.log (common for Artisan + mini-swe-agent)
    alog = instance_dir / "artisan.log"
    if alog.exists():
        txt = _read_text_if_exists(alog)
        if any(m in txt for m in _STEP_LIMIT_MARKERS):
            return True

    # 4) traj files (SWE-agent etc.)
    # Keep conservative: only count if explicit step-limit markers appear.
    alog = instance_dir / "sweagent_driver.log"
    if alog.exists():
        txt = _read_text_if_exists(alog)
        if any(m in txt for m in _STEP_LIMIT_MARKERS):
            return True

    return False


def analyze_step_limit_for_run(
    run_folder_name: str,
    *,
    expected_total: int = 60,
) -> dict[str, Any]:
    """
    Returns:
      {
        "run": <run_folder_name>,
        "total": <num_instances_seen>,
        "hits": <count_step_limit>,
        "rate": <hits/total>,
        "hit_keys": [<instance keys> ...]  # keys like axa-t2-r1
      }

    We walk the filesystem under:
      log_base / run_folder_name / <bench> / table_k / <seed> / ...
    and treat each <seed> directory as one instance.
    """
    run_root = log_base / run_folder_name
    hit_keys: list[str] = []
    total = 0
    hits = 0

    if not run_root.exists():
        return {
            "run": run_folder_name,
            "total": 0,
            "hits": 0,
            "rate": 0.0,
            "hit_keys": [],
            "error": f"missing run folder: {run_root}",
        }

    # Expect exactly depth-3 for instances: <bench>/<table_k>/<seed>
    for bench_dir in run_root.iterdir():
        if not bench_dir.is_dir():
            continue
        for table_dir in bench_dir.iterdir():
            if not table_dir.is_dir():
                continue
            if not table_dir.name.startswith("table_"):
                continue
            for seed_dir in table_dir.iterdir():
                if not seed_dir.is_dir():
                    continue

                total += 1
                if _instance_hit_step_limit(seed_dir):
                    hits += 1
                    k = _instance_dir_to_key(seed_dir)
                    if k is None:
                        # fallback, still keep something debuggable
                        k = f"{bench_dir.name}/{table_dir.name}/{seed_dir.name}"
                    hit_keys.append(k)

    denom = total if total > 0 else expected_total
    rate = (hits / denom) if denom > 0 else 0.0

    return {
        "run": run_folder_name,
        "total": total,
        "hits": hits,
        "rate": rate,
        "hit_keys": sorted(set(hit_keys)),
    }


def analyze_step_limit_by_approach(
    *,
    print_examples: int = 10,
    include_ablations: bool = False,
    expected_total: int = 60,
) -> dict[str, Any]:
    """
    Computes per-run and per-approach step-limit hit rates.

    Approach aggregation:
      - "mean_rate" = mean over runs of (hits/total)
      - also reports "sum_hits" and "sum_total" across runs.
    """
    approach_to_runs: dict[str, list[str]] = {
        "SWE-agent": [sweagent_deepseek_name, sweagent_gpt5mini_name, sweagent_gpt51_name],
        "OpenHands": [openhands_deepseek_name, openhands_gpt5mini_name, openhands_gpt51_name],
        "mini-swe-agent": [minisweagent_deepseek_name, minisweagent_gpt5mini_name, minisweagent_gpt51_name],
        "Artisan": [artisan_deepseek_name, artisan_gpt5mini_name, artisan_gpt51_name],
    }

    if include_ablations:
        approach_to_runs["Artisan(ablation)"] = [
            ablation_wooutput_name,
            ablation_womethod_name,
            ablation_format_name,
        ]

    per_run: dict[str, dict[str, Any]] = {}
    per_approach: dict[str, dict[str, Any]] = {}

    for approach, runs in approach_to_runs.items():
        run_results = []
        sum_hits = 0
        sum_total = 0
        rates = []

        for run in runs:
            r = analyze_step_limit_for_run(run, expected_total=expected_total)
            per_run[run] = r
            run_results.append(r)

            sum_hits += int(r.get("hits", 0))
            sum_total += int(r.get("total", 0))
            rates.append(float(r.get("rate", 0.0)))

        mean_rate = (sum(rates) / len(rates)) if rates else 0.0
        pooled_rate = (sum_hits / sum_total) if sum_total > 0 else 0.0

        per_approach[approach] = {
            "runs": runs,
            "mean_rate": mean_rate,
            "pooled_rate": pooled_rate,
            "sum_hits": sum_hits,
            "sum_total": sum_total,
            "run_results": run_results,
        }

    # -----------------------
    # Pretty print
    # -----------------------
    def _fmt_some(xs: list[str]) -> str:
        if not xs:
            return "(empty)"
        xs = sorted(xs)
        if len(xs) <= print_examples:
            return ", ".join(xs)
        return ", ".join(xs[:print_examples]) + f", ... (+{len(xs) - print_examples} more)"

    logger.info("")
    logger.info("============================================================")
    logger.info("Step-limit (30) analysis")
    logger.info("Markers: %s", ", ".join(sorted(_STEP_LIMIT_MARKERS)))
    logger.info("------------------------------------------------------------")

    for approach, info in per_approach.items():
        logger.info(
            "%-16s | mean=%5.1f%% | pooled=%5.1f%% | hits=%3d / total=%3d",
            approach,
            100.0 * float(info["mean_rate"]),
            100.0 * float(info["pooled_rate"]),
            int(info["sum_hits"]),
            int(info["sum_total"]),
        )
        for rr in info["run_results"]:
            logger.info(
                "  - %-35s hits=%2d / total=%2d  (%5.1f%%)",
                rr["run"],
                int(rr["hits"]),
                int(rr["total"]),
                100.0 * float(rr["rate"]),
            )

    logger.info("------------------------------------------------------------")
    # Also show top examples per run (useful for sanity checks)
    for run, rr in per_run.items():
        if int(rr.get("hits", 0)) <= 0:
            continue
        logger.info("[examples] %-35s hit_keys=%s", run, _fmt_some(rr.get("hit_keys", [])))

    logger.info("============================================================")
    logger.info("")

    return {
        "per_run": per_run,
        "per_approach": per_approach,
        "markers": sorted(_STEP_LIMIT_MARKERS),
    }

write_baseline_table("/Users/doehyunbaek/artisan-paper/tables/baseline.tex")
write_ablation_table("/Users/doehyunbaek/artisan-paper/tables/ablation.tex")
plot_pareto_front('/Users/doehyunbaek/artisan-paper/figures/pareto_front.png')
plot_time_breakdown(save_path="/Users/doehyunbaek/artisan-paper/figures/artisan_time_breakdown.png")
compute_and_print_success_sets(print_examples=10)
analyze_step_limit_by_approach(print_examples=0)