#!/usr/bin/env python3
"""Write the paper tables as LaTeX files."""

from __future__ import annotations

import json
import math
import re
from pathlib import Path
from typing import Any

DATA_ROOT = Path(__file__).resolve().parent
BUGS_PATH = DATA_ROOT / "bugs" / "bugs.json"
METHOD_JUDGE_EVAL_PATH = DATA_ROOT / "method_judge_eval.jsonl"
LOGS_ROOT = DATA_ROOT / "logs"
MANUAL_ANALYSIS_ROOT = DATA_ROOT / "manual_analysis"
TEX_DIR = DATA_ROOT / "tex"

TABLE_1 = r"""\begin{table}[t]
\caption{Comparison of existing approaches and~\approach.}
\label{t:sota_comparison}
\footnotesize
\centering
\setlength{\tabcolsep}{3pt}
\begin{tabular}{@{}lccc@{}}
\toprule
 & \shortstack[c]{Rating-based\\agents~\cite{reprobench,heye}}
 & \shortstack[c]{Result-based\\agents~\cite{super, corebench}}
 & \shortstack[c]{\textbf{\approach{}}\\\textbf{(our work)}} \\
\midrule
Fine-grained assessment       &            & \checkmark & \checkmark \\
Executable evidence           &            &            & \checkmark \\
Detects~\fastpath             &            &            & \checkmark \\
\bottomrule
\end{tabular}
\end{table}"""

TABLE_2_RUNS = [
    ("sweagent_deepseek", "sweagent-deepseek-reasoner-4bdc"),
    ("sweagent_gpt5mini", "sweagent-gpt5mini-5d98"),
    ("sweagent_gpt51", "sweagent-gpt5.1-ebe4"),
    ("openhands_deepseek", "openhands-deepseek-reasoner-bd34"),
    ("openhands_gpt5mini", "openhands-gpt5mini-a4eb"),
    ("openhands_gpt51", "openhands-gpt5.1-41ec"),
    ("minisweagent_deepseek", "minisweagent-deepseek-reasoner-e5a7"),
    ("minisweagent_gpt5mini", "minisweagent-gpt5mini-a830"),
    ("minisweagent_gpt51", "minisweagent-gpt5.1-301b"),
    ("artisan_deepseek", "artisan-deepseek-reasoner-6f4b"),
    ("artisan_gpt5mini", "artisan-gpt5mini-845b"),
    ("artisan_gpt51", "artisan-gpt5.1-dbe0"),
    ("ablation_output", "artisan-gpt5.1-3ee0-without_output"),
    ("ablation_method", "artisan-gpt5.1-7a04-without_method"),
    ("ablation_format", "artisan-gpt5.1-9223-without_format"),
]

TABLE_2_TEMPLATE = r"""{{\setlength{{\tabcolsep}}{{3pt}}
\begin{{tabular}}{{llccccccccc}}
\toprule
\multirow{{2}}{{*}}{{}} & \multirow{{2}}{{*}}{{}} & \multicolumn{{2}}{{c}}{{Success}} & \multicolumn{{4}}{{c}}{{Failure}} & \multirow{{2}}{{*}}{{\shortstack{{Cost}}}} & \multirow{{2}}{{*}}{{\shortstack{{Tokens}}}} & \multirow{{2}}{{*}}{{\shortstack{{Time}}}} \\
\cmidrule(lr){{3-4}} \cmidrule(lr){{5-8}}
 & & Full reprod. & Last-mile reprod. & Copied-result & Mismatch & Runtime err. & Static err. & & & \\
\midrule
SWE-agent & w/ DeepSeek-3.2-Reas. & {sweagent_deepseek_full} & {sweagent_deepseek_lastmile} & {sweagent_deepseek_copy} & {sweagent_deepseek_mismatch} & {sweagent_deepseek_runtime} & {sweagent_deepseek_static} & {sweagent_deepseek_cost} & {sweagent_deepseek_tokens} & {sweagent_deepseek_time} \\
& w/ GPT-5-mini & {sweagent_gpt5mini_full} & {sweagent_gpt5mini_lastmile} & {sweagent_gpt5mini_copy} & {sweagent_gpt5mini_mismatch} & {sweagent_gpt5mini_runtime} & {sweagent_gpt5mini_static} & {sweagent_gpt5mini_cost} & {sweagent_gpt5mini_tokens} & {sweagent_gpt5mini_time} \\
& w/ GPT-5.1 & {sweagent_gpt51_full} & {sweagent_gpt51_lastmile} & {sweagent_gpt51_copy} & {sweagent_gpt51_mismatch} & {sweagent_gpt51_runtime} & {sweagent_gpt51_static} & {sweagent_gpt51_cost} & {sweagent_gpt51_tokens} & {sweagent_gpt51_time} \\
OpenHands & w/ DeepSeek-3.2-Reas. & {openhands_deepseek_full} & {openhands_deepseek_lastmile} & {openhands_deepseek_copy} & {openhands_deepseek_mismatch} & {openhands_deepseek_runtime} & {openhands_deepseek_static} & {openhands_deepseek_cost} & {openhands_deepseek_tokens} & {openhands_deepseek_time} \\
& w/ GPT-5-mini & {openhands_gpt5mini_full} & {openhands_gpt5mini_lastmile} & {openhands_gpt5mini_copy} & {openhands_gpt5mini_mismatch} & {openhands_gpt5mini_runtime} & {openhands_gpt5mini_static} & {openhands_gpt5mini_cost} & {openhands_gpt5mini_tokens} & {openhands_gpt5mini_time} \\
& w/ GPT-5.1 & {openhands_gpt51_full} & {openhands_gpt51_lastmile} & {openhands_gpt51_copy} & {openhands_gpt51_mismatch} & {openhands_gpt51_runtime} & {openhands_gpt51_static} & {openhands_gpt51_cost} & {openhands_gpt51_tokens} & {openhands_gpt51_time} \\
mini-swe-agent & w/ DeepSeek-3.2-Reas. & {minisweagent_deepseek_full} & {minisweagent_deepseek_lastmile} & {minisweagent_deepseek_copy} & {minisweagent_deepseek_mismatch} & {minisweagent_deepseek_runtime} & {minisweagent_deepseek_static} & {minisweagent_deepseek_cost} & {minisweagent_deepseek_tokens} & {minisweagent_deepseek_time} \\
& w/ GPT-5-mini & {minisweagent_gpt5mini_full} & {minisweagent_gpt5mini_lastmile} & {minisweagent_gpt5mini_copy} & {minisweagent_gpt5mini_mismatch} & {minisweagent_gpt5mini_runtime} & {minisweagent_gpt5mini_static} & {minisweagent_gpt5mini_cost} & {minisweagent_gpt5mini_tokens} & {minisweagent_gpt5mini_time} \\
& w/ GPT-5.1 & {minisweagent_gpt51_full} & {minisweagent_gpt51_lastmile} & {minisweagent_gpt51_copy} & {minisweagent_gpt51_mismatch} & {minisweagent_gpt51_runtime} & {minisweagent_gpt51_static} & {minisweagent_gpt51_cost} & {minisweagent_gpt51_tokens} & {minisweagent_gpt51_time} \\
\midrule
Artisan & w/ DeepSeek-3.2-Reas. & {artisan_deepseek_full} & {artisan_deepseek_lastmile} & {artisan_deepseek_copy} & {artisan_deepseek_mismatch} & {artisan_deepseek_runtime} & {artisan_deepseek_static} & {artisan_deepseek_cost} & {artisan_deepseek_tokens} & {artisan_deepseek_time} \\
& w/ GPT-5-mini & {artisan_gpt5mini_full} & {artisan_gpt5mini_lastmile} & {artisan_gpt5mini_copy} & {artisan_gpt5mini_mismatch} & {artisan_gpt5mini_runtime} & {artisan_gpt5mini_static} & {artisan_gpt5mini_cost} & {artisan_gpt5mini_tokens} & {artisan_gpt5mini_time} \\
& w/ GPT-5.1 & {artisan_gpt51_full} & {artisan_gpt51_lastmile} & {artisan_gpt51_copy} & {artisan_gpt51_mismatch} & {artisan_gpt51_runtime} & {artisan_gpt51_static} & {artisan_gpt51_cost} & {artisan_gpt51_tokens} & {artisan_gpt51_time} \\
\midrule
Ablations & \shortstack{{w/o Output Judge}} & {ablation_output_full} & {ablation_output_lastmile} & {ablation_output_copy} & {ablation_output_mismatch} & {ablation_output_runtime} & {ablation_output_static} & {ablation_output_cost} & {ablation_output_tokens} & {ablation_output_time} \\
& \shortstack{{w/o Method Judge}} & {ablation_method_full} & {ablation_method_lastmile} & {ablation_method_copy} & {ablation_method_mismatch} & {ablation_method_runtime} & {ablation_method_static} & {ablation_method_cost} & {ablation_method_tokens} & {ablation_method_time} \\
& \shortstack{{w/o Format Tool}} & {ablation_format_full} & {ablation_format_lastmile} & {ablation_format_copy} & {ablation_format_mismatch} & {ablation_format_runtime} & {ablation_format_static} & {ablation_format_cost} & {ablation_format_tokens} & {ablation_format_time} \\
\bottomrule
\end{{tabular}}
}}"""

TABLE_2_STATUS_FIELDS = [
    "total_full_repro",
    "total_lastmile_repro",
    "total_copy_repro",
    "total_mismatch_error",
    "total_runtime_error",
    "total_static_error",
]

TABLE_3_TEMPLATE = r"""\begin{{tabular}}{{lccc}}
  \toprule
  & \multicolumn{{3}}{{c}}{{\textbf{{Predicted}}}} \\
  \cmidrule(lr){{2-4}}
  \textbf{{Actual}} & \textbf{{Full}} & \textbf{{Last}} & \textbf{{Copy}} \\
  \midrule
  \textbf{{Full}}      & {full_full} & {full_lastmile}  & {full_copy}  \\
  \textbf{{Last-Mile}} & {lastmile_full} & {lastmile_lastmile} & {lastmile_copy}  \\
  \textbf{{Copy}}      & {copy_full}  & {copy_lastmile}  & {copy_copy} \\
  \bottomrule
\end{{tabular}}"""

METHOD_JUDGE_LABELS = ("full", "lastmile", "copy")

TABLE_4_TEMPLATE = """\\begin{{tabular}}{{l r r r r r}}
\\toprule
\\textbf{{Paper}} & \\textbf{{TI}} & \\textbf{{\\#DE}} & \\textbf{{Paper Value}} & \\textbf{{Artifact Value}} &\\textbf{{Reason}} \\\\
\\midrule
{action_t1_paper} \\cite{{{action_t1_paper}}} & {action_t1_ti} & {action_t1_de} & {action_t1_paper_value} & {action_t1_artifact_value} & {action_t1_reason} \\\\
{action_t2_paper} \\cite{{{action_t2_paper}}} & {action_t2_ti} & {action_t2_de} & {action_t2_paper_value} & {action_t2_artifact_value} & {action_t2_reason} \\\\
{action_t3_paper} \\cite{{{action_t3_paper}}} & {action_t3_ti} & {action_t3_de} & {action_t3_paper_value} & {action_t3_artifact_value} & {action_t3_reason} \\\\
{action_t4_paper} \\cite{{{action_t4_paper}}} & {action_t4_ti} & {action_t4_de} & {action_t4_paper_value} & {action_t4_artifact_value} & {action_t4_reason} \\\\
{action_t5_paper} \\cite{{{action_t5_paper}}} & {action_t5_ti} & {action_t5_de} & {action_t5_paper_value} & {action_t5_artifact_value} & {action_t5_reason} \\\\
{axa_t1_paper} \\cite{{{axa_t1_paper}}} & {axa_t1_ti} & {axa_t1_de} & {axa_t1_paper_value} & {axa_t1_artifact_value} & {axa_t1_reason} \\\\
{bazel_t5_paper} \\cite{{{bazel_t5_paper}}} & {bazel_t5_ti} & {bazel_t5_de} & {bazel_t5_paper_value} & {bazel_t5_artifact_value} & {bazel_t5_reason} \\\\
{dypybench_t3_paper} \\cite{{{dypybench_t3_paper}}} & {dypybench_t3_ti} & {dypybench_t3_de} & {dypybench_t3_paper_value} & {dypybench_t3_artifact_value} & {dypybench_t3_reason} \\\\
{interference_t2_paper} \\cite{{{interference_t2_paper}}} & {interference_t2_ti} & {interference_t2_de} & {interference_t2_paper_value} & {interference_t2_artifact_value} & {interference_t2_reason} \\\\
{lasapp_t1_paper} \\cite{{{lasapp_t1_paper}}} & {lasapp_t1_ti} & {lasapp_t1_de} & {lasapp_t1_paper_value} & {lasapp_t1_artifact_value} & {lasapp_t1_reason} \\\\
{llm_t3_paper} \\cite{{{llm_t3_paper}}} & {llm_t3_ti} & {llm_t3_de} & {llm_t3_paper_value} & {llm_t3_artifact_value} & {llm_t3_reason} \\\\
{npetest_t2_paper} \\cite{{{npetest_t2_paper}}} & {npetest_t2_ti} & {npetest_t2_de} & {npetest_t2_paper_value} & {npetest_t2_artifact_value} & {npetest_t2_reason} \\\\
{npetest_t3_paper} \\cite{{{npetest_t3_paper}}} & {npetest_t3_ti} & {npetest_t3_de} & {npetest_t3_paper_value} & {npetest_t3_artifact_value} & {npetest_t3_reason} \\\\
{pmsat_t3_paper} \\cite{{{pmsat_t3_paper}}} & {pmsat_t3_ti} & {pmsat_t3_de} & {pmsat_t3_paper_value} & {pmsat_t3_artifact_value} & {pmsat_t3_reason} \\\\
{pmsat_t5_paper} \\cite{{{pmsat_t5_paper}}} & {pmsat_t5_ti} & {pmsat_t5_de} & {pmsat_t5_paper_value} & {pmsat_t5_artifact_value} & {pmsat_t5_reason} \\\\
{pythonic_t3_paper} \\cite{{{pythonic_t3_paper}}} & {pythonic_t3_ti} & {pythonic_t3_de} & {pythonic_t3_paper_value} & {pythonic_t3_artifact_value} & {pythonic_t3_reason} \\\\
{pythonic_t9_paper} \\cite{{{pythonic_t9_paper}}} & {pythonic_t9_ti} & {pythonic_t9_de} & {pythonic_t9_paper_value} & {pythonic_t9_artifact_value} & {pythonic_t9_reason} \\\\
{rust_t1_paper} \\cite{{{rust_t1_paper}}} & {rust_t1_ti} & {rust_t1_de} & {rust_t1_paper_value} & {rust_t1_artifact_value} & {rust_t1_reason} \\\\
{sctype_t3_paper} \\cite{{{sctype_t3_paper}}} & {sctype_t3_ti} & {sctype_t3_de} & {sctype_t3_paper_value} & {sctype_t3_artifact_value} & {sctype_t3_reason} \\\\
{urcrat_t1_paper} \\cite{{{urcrat_t1_paper}}} & {urcrat_t1_ti} & {urcrat_t1_de} & {urcrat_t1_paper_value} & {urcrat_t1_artifact_value} & {urcrat_t1_reason} \\\\
\\bottomrule
\\end{{tabular}}
{footnotes}"""

FOOTNOTE_TEMPLATE = "\\scriptsize \\textsuperscript{{{index}}}Fixed by {url}"


def get_table_1() -> str:
    return TABLE_1


def is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and math.isfinite(float(value))


def safe_int(value: Any) -> int:
    if isinstance(value, bool):
        return 0
    try:
        if is_number(value):
            return int(value)
        if isinstance(value, str) and value.strip():
            return int(float(value.replace(",", "")))
    except (TypeError, ValueError):
        pass
    return 0


SUCCESS_STATUSES = {"FULL_REPRO", "LASTMILE_REPRO"}
FAIL_STATUSES = {"COPY_REPRO", "MISMATCH_ERROR", "RUNTIME_ERROR", "STATIC_ERROR"}
STATUS_TO_TOTAL_FIELD = {
    "FULL_REPRO": "total_full_repro",
    "LASTMILE_REPRO": "total_lastmile_repro",
    "COPY_REPRO": "total_copy_repro",
    "MISMATCH_ERROR": "total_mismatch_error",
    "RUNTIME_ERROR": "total_runtime_error",
    "STATIC_ERROR": "total_static_error",
}
MANUAL_LINE = re.compile(r'^\s*-\s*"(?P<iid>[^"]+)"\s*:\s*(?P<val>.*)\s*$')
ARTISAN_LOG_TS = re.compile(r"^(\d{2}):(\d{2}):(\d{2})\s+-\s+artisan:")
JUDGE_WAIT_START_MARKERS = ("Validating submission:",)
JUDGE_WAIT_END_MARKERS = ("Info status:", "Submission failed validation:")


def parse_manual_analysis_md(md_text: str) -> dict[str, str]:
    overrides: dict[str, str] = {}
    for line in md_text.splitlines():
        match = MANUAL_LINE.match(line)
        if not match:
            continue
        iid = match.group("iid").strip()
        raw_value = (match.group("val") or "").strip()
        if not raw_value or raw_value.upper().startswith("OK"):
            continue
        status = raw_value.split(",")[0].strip().split()[0].strip()
        if status in SUCCESS_STATUSES or status in FAIL_STATUSES:
            overrides[iid] = status
    return overrides


def get_instance_status(entry: dict[str, Any]) -> str | None:
    for key in ("exit_status", "status", "result", "judge_status"):
        value = entry.get(key)
        if isinstance(value, str) and value:
            return value
    return None


def get_instance_status_field(entry: dict[str, Any]) -> str:
    for key in ("exit_status", "status", "result", "judge_status"):
        value = entry.get(key)
        if isinstance(value, str) and value:
            return key
    return "exit_status"


def ensure_total_fields(total_stats: dict[str, Any]) -> None:
    for key in STATUS_TO_TOTAL_FIELD.values():
        total_stats.setdefault(key, 0)
    total_stats.setdefault("total_success", 0)
    total_stats.setdefault("total_fail", 0)
    total_stats.setdefault("total_instances", 0)


def bump_total(total_stats: dict[str, Any], status: str, delta: int) -> None:
    key = STATUS_TO_TOTAL_FIELD.get(status)
    if key is None:
        return
    total_stats[key] = safe_int(total_stats.get(key)) + delta
    if status in SUCCESS_STATUSES:
        total_stats["total_success"] = safe_int(total_stats.get("total_success")) + delta
    elif status in FAIL_STATUSES:
        total_stats["total_fail"] = safe_int(total_stats.get("total_fail")) + delta


def correct_effectiveness_from_manual_md(
    instances: dict[str, Any],
    total_stats: dict[str, Any],
    manual_md_path: Path,
) -> int:
    if not manual_md_path.exists():
        return 0
    overrides = parse_manual_analysis_md(manual_md_path.read_text("utf-8", errors="replace"))
    if not overrides:
        return 0

    ensure_total_fields(total_stats)
    applied = 0
    for iid, new_status in overrides.items():
        entry = instances.get(iid)
        if not isinstance(entry, dict):
            continue
        old_status = get_instance_status(entry)
        if old_status == new_status:
            continue
        entry[get_instance_status_field(entry)] = new_status
        applied += 1
        if isinstance(old_status, str) and old_status:
            bump_total(total_stats, old_status, -1)
        bump_total(total_stats, new_status, +1)

    if safe_int(total_stats.get("total_instances")) <= 0:
        total_stats["total_instances"] = sum(1 for entry in instances.values() if isinstance(entry, dict))
    return applied


def hhmmss_to_seconds(hour: int, minute: int, second: int) -> int:
    return hour * 3600 + minute * 60 + second


def delta_seconds_with_midnight_wrap(start: int, end: int) -> int:
    if end < start:
        end += 24 * 3600
    return end - start


def infer_agent_time_from_artisan_log(artisan_log_path: Path) -> float | None:
    times: list[int] = []
    start_marker: int | None = None
    try:
        with artisan_log_path.open("r", errors="ignore") as f:
            for line in f:
                match = ARTISAN_LOG_TS.match(line)
                if not match:
                    continue
                timestamp = hhmmss_to_seconds(*map(int, match.groups()))
                times.append(timestamp)
                if start_marker is None and "Running DefaultAgent" in line:
                    start_marker = timestamp
    except FileNotFoundError:
        return None

    if not times:
        return None
    start = start_marker if start_marker is not None else times[0]
    end = times[-1]
    return float(delta_seconds_with_midnight_wrap(start, end))


def infer_judge_wait_from_artisan_log(artisan_log_path: Path) -> float | None:
    current_start: int | None = None
    total_wait = 0
    saw_complete_attempt = False
    try:
        with artisan_log_path.open("r", errors="ignore") as f:
            for line in f:
                match = ARTISAN_LOG_TS.match(line)
                if not match:
                    continue
                timestamp = hhmmss_to_seconds(*map(int, match.groups()))
                if any(marker in line for marker in JUDGE_WAIT_START_MARKERS):
                    current_start = timestamp
                    continue
                if current_start is not None and any(marker in line for marker in JUDGE_WAIT_END_MARKERS):
                    total_wait += delta_seconds_with_midnight_wrap(current_start, timestamp)
                    saw_complete_attempt = True
                    current_start = None
    except FileNotFoundError:
        return None
    return float(total_wait) if saw_complete_attempt else None


def parse_instance_id_from_log_path(log_path: Path) -> str | None:
    parts = list(log_path.parts)
    for index, part in enumerate(parts):
        match = re.match(r"table_(\d+)$", part)
        if match and index > 0:
            return f"{parts[index - 1]}-t{match.group(1)}-r1"
    return None


def inferred_time_map(run_root: Path, infer_func: Any) -> dict[str, float]:
    mapping: dict[str, float] = {}
    for log_path in sorted(run_root.rglob("artisan.log")):
        instance_id = parse_instance_id_from_log_path(log_path)
        if instance_id is None:
            continue
        inferred = infer_func(log_path)
        if inferred is not None:
            mapping[instance_id] = inferred
    return mapping


def fill_agent_time_from_artisan_logs(instances: dict[str, Any], run_root: Path) -> int:
    mapping = inferred_time_map(run_root, infer_agent_time_from_artisan_log)
    filled = 0
    for instance_id, entry in instances.items():
        if not isinstance(entry, dict) or is_number(entry.get("agent_time")):
            continue
        inferred = mapping.get(instance_id)
        if inferred is None:
            continue
        entry["agent_time"] = inferred
        filled += 1
    return filled


def fill_judge_wait_from_artisan_logs(instances: dict[str, Any], run_root: Path) -> int:
    mapping = inferred_time_map(run_root, infer_judge_wait_from_artisan_log)
    filled = 0
    for instance_id, entry in instances.items():
        if not isinstance(entry, dict) or is_number(entry.get("judge_wait")):
            continue
        inferred = mapping.get(instance_id)
        if inferred is None:
            continue
        entry["judge_wait"] = inferred
        filled += 1
    return filled


def shrink_time_using_agent_time(instances: dict[str, Any]) -> int:
    updates = 0
    for entry in instances.values():
        if not isinstance(entry, dict) or not is_number(entry.get("agent_time")):
            continue
        agent_time = float(entry["agent_time"])
        if not is_number(entry.get("time")) or 0 < agent_time < float(entry["time"]):
            entry["time"] = agent_time
            updates += 1
    return updates


def correct_time_from_logs(
    instances: dict[str, Any],
    run_root: Path,
    *,
    fill_agent_time: bool = True,
    fill_judge_wait: bool = True,
    shrink_time: bool = True,
) -> tuple[int, int, int]:
    n_agent_time = fill_agent_time_from_artisan_logs(instances, run_root) if fill_agent_time else 0
    n_judge_wait = fill_judge_wait_from_artisan_logs(instances, run_root) if fill_judge_wait else 0
    n_shrink = shrink_time_using_agent_time(instances) if shrink_time else 0
    return n_agent_time, n_judge_wait, n_shrink


def load_run_summary(run_name: str) -> tuple[dict[str, Any], dict[str, Any]]:
    json_path = LOGS_ROOT / run_name / "reprobench.json"
    if not json_path.exists():
        raise FileNotFoundError(f"Missing {json_path}; run data/download_logs.py to restore logs")
    with json_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    instances = data["instance"]
    total_stats = data["total"]
    correct_time_from_logs(instances, json_path.parent, fill_agent_time=True, shrink_time=True)
    correct_effectiveness_from_manual_md(
        instances,
        total_stats,
        MANUAL_ANALYSIS_ROOT / f"{run_name}.md",
    )
    return instances, total_stats


def usage_tokens_from_mini_json(path: Path) -> int:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    total = 0
    for message in data.get("messages", []):
        if not isinstance(message, dict):
            continue
        usage = (((message.get("extra") or {}).get("response") or {}).get("usage") or {})
        if isinstance(usage, dict):
            total += safe_int(usage.get("total_tokens"))
    return total


def usage_tokens_from_openhands_json(path: Path) -> int:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    tokens = (((data.get("info") or {}).get("model_stats") or {}).get("tokens") or {})
    if not isinstance(tokens, dict):
        return 0
    return safe_int(tokens.get("prompt_tokens")) + safe_int(tokens.get("completion_tokens"))


def usage_tokens_from_traj(path: Path) -> int:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    stats = ((data.get("info") or {}).get("model_stats") or {})
    if not isinstance(stats, dict):
        return 0
    return safe_int(stats.get("tokens_sent")) + safe_int(stats.get("tokens_received"))


def mean_tokens_for_run(run_name: str) -> float:
    run_root = LOGS_ROOT / run_name
    if run_name.startswith("openhands-"):
        paths = sorted(run_root.rglob("openhands.json"))
        values = [usage_tokens_from_openhands_json(path) for path in paths]
    elif run_name.startswith("sweagent-"):
        paths = sorted(run_root.rglob("*.traj"))
        values = [usage_tokens_from_traj(path) for path in paths]
    else:
        paths = sorted(run_root.rglob("mini.json"))
        values = [usage_tokens_from_mini_json(path) for path in paths]

    values = [value for value in values if value > 0]
    if not values:
        raise ValueError(f"No token usage logs found for {run_name}")
    return sum(values) / len(values)


def mean_time_seconds(instances: dict[str, Any]) -> float:
    times = [
        float(entry["time"])
        for entry in instances.values()
        if isinstance(entry, dict) and is_number(entry.get("time"))
    ]
    if not times:
        return 0.0
    return sum(times) / len(times)


def format_cost(cost: float) -> str:
    return f"\\${cost:.2f}"


def format_tokens(tokens: float) -> str:
    return f"{tokens / 1000:.1f}k"


def format_time(seconds: float) -> str:
    return f"{seconds / 60:.1f} min"


TABLE_2_VALUE_SUFFIXES = [
    "full",
    "lastmile",
    "copy",
    "mismatch",
    "runtime",
    "static",
    "cost",
    "tokens",
    "time",
]


def table_2_row_values(run_name: str) -> dict[str, str]:
    instances, total_stats = load_run_summary(run_name)
    counts = [str(safe_int(total_stats.get(field))) for field in TABLE_2_STATUS_FIELDS]

    cost = total_stats.get("cost_per_instance")
    if not is_number(cost):
        costs = [
            float(entry["cost"])
            for entry in instances.values()
            if isinstance(entry, dict) and is_number(entry.get("cost"))
        ]
        cost = sum(costs) / len(costs) if costs else 0.0

    row = [
        *counts,
        format_cost(float(cost)),
        format_tokens(mean_tokens_for_run(run_name)),
        format_time(mean_time_seconds(instances)),
    ]
    return dict(zip(TABLE_2_VALUE_SUFFIXES, row, strict=True))


def add_table_2_values(values: dict[str, str], prefix: str, run_name: str) -> None:
    for suffix, value in table_2_row_values(run_name).items():
        values[f"{prefix}_{suffix}"] = value


def get_table_2() -> str:
    values: dict[str, str] = {}
    for prefix, run_name in TABLE_2_RUNS:
        add_table_2_values(values, prefix, run_name)
    return TABLE_2_TEMPLATE.format(**values)


def method_judge_confusion() -> dict[str, dict[str, int]]:
    matrix = {
        actual: {predicted: 0 for predicted in METHOD_JUDGE_LABELS}
        for actual in METHOD_JUDGE_LABELS
    }
    n_records = 0

    with METHOD_JUDGE_EVAL_PATH.open("r", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            record = json.loads(line)
            if record.get("type") != "instance_record":
                continue
            io = record.get("io")
            if not isinstance(io, dict):
                continue
            actual = io.get("expected")
            predicted = io.get("predicted")
            if actual not in matrix or predicted not in matrix[actual]:
                raise ValueError(f"Unexpected method-judge labels: expected={actual!r}, predicted={predicted!r}")
            matrix[actual][predicted] += 1
            n_records += 1

    if n_records == 0:
        raise ValueError(f"No method-judge instance records found in {METHOD_JUDGE_EVAL_PATH}")
    return matrix


def table_3_values() -> dict[str, str]:
    matrix = method_judge_confusion()
    values: dict[str, str] = {}
    for actual in METHOD_JUDGE_LABELS:
        for predicted in METHOD_JUDGE_LABELS:
            values[f"{actual}_{predicted}"] = str(matrix[actual][predicted])
    return values


def get_table_3() -> str:
    return TABLE_3_TEMPLATE.format(**table_3_values())


def latex_value(value: str) -> str:
    value = str(value)
    match = re.fullmatch("(.+?)\\s*×\\s*10\\^(\\d+)", value)
    if match:
        return f"${match.group(1)} \\times 10^{{{match.group(2)}}}$"
    return value.replace("%", "\\%")


def latex_reason(bug: dict, fixed_url_indices: dict[str, int]) -> str:
    reason = bug["reason_code"]
    if bug.get("confirmed_by_authors"):
        reason += "\\textsuperscript{\\S}"
    if bug.get("fixed_url"):
        reason += f"\\textsuperscript{{{fixed_url_indices[bug['fixed_url']]}}}"
    return reason


def add_row_values(values: dict[str, object], prefix: str, bug: dict, fixed_url_indices: dict[str, int]) -> None:
    values[f"{prefix}_paper"] = bug["paper"]
    values[f"{prefix}_ti"] = bug["table_index"]
    values[f"{prefix}_de"] = bug["different_entries"]
    values[f"{prefix}_paper_value"] = latex_value(bug["paper_value"])
    values[f"{prefix}_artifact_value"] = latex_value(bug["artifact_value"])
    values[f"{prefix}_reason"] = latex_reason(bug, fixed_url_indices)


def get_table_4() -> str:
    with BUGS_PATH.open("r", encoding="utf-8") as f:
        bugs = json.load(f)["bugs"]

    bugs_by_key = {
        (bug["paper"], bug["table_index"]): bug
        for bug in bugs
    }

    fixed_url_indices: dict[str, int] = {}
    for bug in bugs:
        fixed_url = bug.get("fixed_url")
        if fixed_url and fixed_url not in fixed_url_indices:
            fixed_url_indices[fixed_url] = len(fixed_url_indices) + 1

    values: dict[str, object] = {}
    add_row_values(values, "action_t1", bugs_by_key[("action", 1)], fixed_url_indices)
    add_row_values(values, "action_t2", bugs_by_key[("action", 2)], fixed_url_indices)
    add_row_values(values, "action_t3", bugs_by_key[("action", 3)], fixed_url_indices)
    add_row_values(values, "action_t4", bugs_by_key[("action", 4)], fixed_url_indices)
    add_row_values(values, "action_t5", bugs_by_key[("action", 5)], fixed_url_indices)
    add_row_values(values, "axa_t1", bugs_by_key[("axa", 1)], fixed_url_indices)
    add_row_values(values, "bazel_t5", bugs_by_key[("bazel", 5)], fixed_url_indices)
    add_row_values(values, "dypybench_t3", bugs_by_key[("dypybench", 3)], fixed_url_indices)
    add_row_values(values, "interference_t2", bugs_by_key[("interference", 2)], fixed_url_indices)
    add_row_values(values, "lasapp_t1", bugs_by_key[("lasapp", 1)], fixed_url_indices)
    add_row_values(values, "llm_t3", bugs_by_key[("llm", 3)], fixed_url_indices)
    add_row_values(values, "npetest_t2", bugs_by_key[("npetest", 2)], fixed_url_indices)
    add_row_values(values, "npetest_t3", bugs_by_key[("npetest", 3)], fixed_url_indices)
    add_row_values(values, "pmsat_t3", bugs_by_key[("pmsat", 3)], fixed_url_indices)
    add_row_values(values, "pmsat_t5", bugs_by_key[("pmsat", 5)], fixed_url_indices)
    add_row_values(values, "pythonic_t3", bugs_by_key[("pythonic", 3)], fixed_url_indices)
    add_row_values(values, "pythonic_t9", bugs_by_key[("pythonic", 9)], fixed_url_indices)
    add_row_values(values, "rust_t1", bugs_by_key[("rust", 1)], fixed_url_indices)
    add_row_values(values, "sctype_t3", bugs_by_key[("sctype", 3)], fixed_url_indices)
    add_row_values(values, "urcrat_t1", bugs_by_key[("urcrat", 1)], fixed_url_indices)

    values["footnotes"] = "\n\n".join(
        FOOTNOTE_TEMPLATE.format(index=index, url=url)
        for url, index in fixed_url_indices.items()
    )

    return TABLE_4_TEMPLATE.format(**values)


def write_tables(output_dir: Path = TEX_DIR) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    tables = [
        ("table_1.tex", get_table_1()),
        ("table_2.tex", get_table_2()),
        ("table_3.tex", get_table_3()),
        ("table_4.tex", get_table_4()),
    ]

    written_paths: list[Path] = []
    for filename, table in tables:
        if filename == "table_1.tex":
            print("NOTE: no real computation is needed for table_1")
        path = output_dir / filename
        path.write_text(table.rstrip() + "\n", encoding="utf-8")
        print(f"Wrote {path}")
        written_paths.append(path)
    return written_paths


def main() -> None:
    write_tables()


if __name__ == "__main__":
    main()
