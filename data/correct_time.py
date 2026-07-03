#!/usr/bin/env python3
from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any, Dict, Optional, Tuple


# -------------------------
# artisan.log inference
# -------------------------

# Example line:
# 07:51:58 - artisan:INFO - util.py:415 - Logging into ...
_ARTISAN_LOG_TS = re.compile(r"^(\d{2}):(\d{2}):(\d{2})\s+-\s+artisan:")


def _hhmmss_to_seconds(h: int, m: int, s: int) -> int:
    return h * 3600 + m * 60 + s


def infer_agent_time_from_artisan_log(artisan_log_path: str | Path) -> Optional[float]:
    """
    Infer an agent_time-like duration (seconds) from an Artisan run log.

    Start = timestamp of "Running DefaultAgent" if present, else first timestamp line.
    End   = last timestamp line.
    Handle midnight wrap.
    """
    artisan_log_path = Path(artisan_log_path)
    times: list[int] = []
    start_marker: Optional[int] = None

    try:
        with artisan_log_path.open("r", errors="ignore") as f:
            for line in f:
                m = _ARTISAN_LOG_TS.match(line)
                if not m:
                    continue
                hh, mm, ss = map(int, m.groups())
                t = _hhmmss_to_seconds(hh, mm, ss)
                times.append(t)
                if start_marker is None and "Running DefaultAgent" in line:
                    start_marker = t
    except FileNotFoundError:
        return None

    if not times:
        return None

    start = start_marker if start_marker is not None else times[0]
    end = times[-1]
    if end < start:
        end += 24 * 3600
    return float(end - start)


# -------------------------
# Judge wait inference
# -------------------------

# We treat judge_wait as "time spent in the submission/validation pipeline",
# starting at "Validating submission:" and ending at:
#   - "Info status: Submitted" (accepted)
#   - OR "Submission failed validation: <REASON>" (rejected)
#
# Runs can contain multiple validation attempts; we SUM all attempt durations.
_JUDGE_WAIT_START_MARKERS = (
    "Validating submission:",
)

_JUDGE_WAIT_END_MARKERS = (
    # Success (judge pipeline accepted the submission)
    "Info status:",
    # Failure modes after validation
    "Submission failed validation:",
)


def _delta_seconds_with_midnight_wrap(start: int, end: int) -> int:
    if end < start:
        end += 24 * 3600
    return end - start


def infer_judge_wait_from_artisan_log(artisan_log_path: str | Path) -> Optional[float]:
    """
    Infer judge_wait duration (seconds) from artisan.log.

    Definition:
      Sum over ALL validation attempts:
        attempt_start = timestamp of "Validating submission:"
        attempt_end   = first timestamp line AFTER start matching one of:
                          - "Info status:" (success path)
                          - "Submission failed validation:" (fail path)

    This intentionally counts BOTH successful submissions and failed validation attempts,
    because both consume wall-clock time and show up as "rest" for the run.

    Returns:
        total seconds as float, or None if no complete attempt is found.
    """
    artisan_log_path = Path(artisan_log_path)

    current_start: Optional[int] = None
    total_wait: int = 0
    saw_any_complete_attempt = False

    try:
        with artisan_log_path.open("r", errors="ignore") as f:
            for line in f:
                m = _ARTISAN_LOG_TS.match(line)
                if not m:
                    continue

                hh, mm, ss = map(int, m.groups())
                t = _hhmmss_to_seconds(hh, mm, ss)

                # Start a new attempt
                if any(marker in line for marker in _JUDGE_WAIT_START_MARKERS):
                    current_start = t
                    continue

                # If we are inside an attempt, end it on the first terminal marker
                if current_start is not None and any(marker in line for marker in _JUDGE_WAIT_END_MARKERS):
                    total_wait += _delta_seconds_with_midnight_wrap(current_start, t)
                    saw_any_complete_attempt = True
                    current_start = None
                    continue

    except FileNotFoundError:
        return None

    if not saw_any_complete_attempt:
        return None

    return float(total_wait)


def _parse_bench_and_table_from_path(log_path: Path) -> Optional[Tuple[str, int]]:
    """
    Expect .../<bench>/table_<k>/<run_id>/artisan.log
    """
    parts = list(log_path.parts)
    for i, p in enumerate(parts):
        if p.startswith("table_"):
            bench = parts[i - 1] if i - 1 >= 0 else None
            m = re.match(r"table_(\d+)$", p)
            if bench and m:
                return bench, int(m.group(1))
    return None


# -------------------------
# Helpers
# -------------------------

def is_number(x: Any) -> bool:
    return isinstance(x, (int, float)) and math.isfinite(float(x))


def build_inferred_agent_time_map(run_root: Path) -> Dict[str, float]:
    """
    Scan all artisan.log inside the run_root and infer agent_time per instance_id.

    instance_id convention: "<bench>-t<table>-r1"
    """
    mapping: Dict[str, float] = {}
    for log_path in sorted(run_root.rglob("artisan.log")):
        parsed = _parse_bench_and_table_from_path(log_path)
        if not parsed:
            continue
        bench, table_num = parsed
        instance_id = f"{bench}-t{table_num}-r1"

        inferred = infer_agent_time_from_artisan_log(log_path)
        if inferred is None:
            continue
        mapping[instance_id] = inferred
    return mapping


def build_inferred_judge_wait_map(run_root: Path) -> Dict[str, float]:
    """
    Scan all artisan.log inside the run_root and infer judge_wait per instance_id.

    instance_id convention: "<bench>-t<table>-r1"
    """
    mapping: Dict[str, float] = {}
    for log_path in sorted(run_root.rglob("artisan.log")):
        parsed = _parse_bench_and_table_from_path(log_path)
        if not parsed:
            continue
        bench, table_num = parsed
        instance_id = f"{bench}-t{table_num}-r1"

        inferred = infer_judge_wait_from_artisan_log(log_path)
        if inferred is None:
            continue
        mapping[instance_id] = inferred
    return mapping


# -------------------------
# Public API used by main file
# -------------------------

def fill_agent_time_from_artisan_logs(
    instances: dict[str, Any],
    run_root: str | Path,
) -> int:
    """
    Fill missing per-instance 'agent_time' by inferring it from artisan.log.
    Returns number of instances updated.
    """
    run_root = Path(run_root)
    inferred_map = build_inferred_agent_time_map(run_root)

    filled = 0
    for instance_id, entry in instances.items():
        if not isinstance(entry, dict):
            continue

        if is_number(entry.get("agent_time")):
            continue

        inferred = inferred_map.get(instance_id)
        if inferred is None:
            continue

        entry["agent_time"] = float(inferred)
        filled += 1

    return filled


def fill_judge_wait_from_artisan_logs(
    instances: dict[str, Any],
    run_root: str | Path,
) -> int:
    """
    Fill missing per-instance 'judge_wait' by inferring it from artisan.log.
    Returns number of instances updated.
    """
    run_root = Path(run_root)
    inferred_map = build_inferred_judge_wait_map(run_root)

    filled = 0
    for instance_id, entry in instances.items():
        if not isinstance(entry, dict):
            continue

        if is_number(entry.get("judge_wait")):
            continue

        inferred = inferred_map.get(instance_id)
        if inferred is None:
            continue

        entry["judge_wait"] = float(inferred)
        filled += 1

    return filled


def shrink_time_using_agent_time(
    instances: dict[str, Any],
    *,
    only_if_smaller: bool = True,
) -> int:
    """
    Optional: shrink per-instance 'time' using 'agent_time' when it exists.

    This mirrors your previous "time correction" behavior:
      - If agent_time exists and is smaller than time, set time=agent_time.

    Returns number of 'time' values updated.
    """
    updates = 0
    for _iid, entry in instances.items():
        if not isinstance(entry, dict):
            continue

        t = entry.get("time")
        at = entry.get("agent_time")

        if not (is_number(at)):
            continue

        atf = float(at)

        if not is_number(t):
            # If time missing/bad, set it to agent_time
            entry["time"] = atf
            updates += 1
            continue

        tf = float(t)
        if only_if_smaller:
            if atf > 0 and atf < tf:
                entry["time"] = atf
                updates += 1
        else:
            entry["time"] = atf
            updates += 1

    return updates


def correct_time_from_logs(
    instances: dict[str, Any],
    run_root: str | Path,
    *,
    fill_agent_time: bool = True,
    fill_judge_wait: bool = True,
    shrink_time: bool = True,
) -> tuple[int, int, int]:
    """
    Convenience wrapper used by your main file.

    Returns:
        (n_agent_time_filled, n_judge_wait_filled, n_time_shrunk)
    """
    n_fill_agent_time = 0
    n_fill_judge_wait = 0
    n_shrink = 0

    if fill_agent_time:
        n_fill_agent_time = fill_agent_time_from_artisan_logs(instances, run_root)

    if fill_judge_wait:
        n_fill_judge_wait = fill_judge_wait_from_artisan_logs(instances, run_root)

    if shrink_time:
        n_shrink = shrink_time_using_agent_time(instances, only_if_smaller=True)

    return n_fill_agent_time, n_fill_judge_wait, n_shrink
