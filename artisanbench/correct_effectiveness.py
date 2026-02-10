#!/usr/bin/env python3
from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any, Optional

# -----------------------------------------------------------------------------
# Status constants
# -----------------------------------------------------------------------------

SUCCESS_STATUSES = {"FULL_REPRO", "LASTMILE_REPRO"}
FAIL_STATUSES = {"COPY_REPRO", "MISMATCH_ERROR", "RUNTIME_ERROR", "STATIC_ERROR"}

_STATUS_TO_TOTAL_FIELD = {
    "FULL_REPRO": "total_full_repro",
    "LASTMILE_REPRO": "total_lastmile_repro",
    "COPY_REPRO": "total_copy_repro",
    "MISMATCH_ERROR": "total_mismatch_error",
    "RUNTIME_ERROR": "total_runtime_error",
    "STATIC_ERROR": "total_static_error",
}

# -----------------------------------------------------------------------------
# Manual analysis parsing
# -----------------------------------------------------------------------------

_MANUAL_LINE = re.compile(r'^\s*-\s*"(?P<iid>[^"]+)"\s*:\s*(?P<val>.*)\s*$')


def parse_manual_analysis_md(md_text: str) -> dict[str, str]:
    """
    Parse manual_analysis/<run_name>.md lines like:
      - "foo-t1-r1": COPY_REPRO, ...
      - "bar-t2-r1": RUNTIME_ERROR, ...
    Skips lines whose value starts with OK.
    Returns iid -> new_status
    """
    overrides: dict[str, str] = {}

    for line in md_text.splitlines():
        m = _MANUAL_LINE.match(line)
        if not m:
            continue

        iid = m.group("iid").strip()
        raw_val = (m.group("val") or "").strip()
        if not raw_val:
            continue

        if raw_val.upper().startswith("OK"):
            continue

        first = raw_val.split(",")[0].strip()
        first = first.split()[0].strip() if first else ""
        if first in SUCCESS_STATUSES or first in FAIL_STATUSES:
            overrides[iid] = first

    return overrides


# -----------------------------------------------------------------------------
# Instance status helpers
# -----------------------------------------------------------------------------

def get_instance_status_value(i_info: dict[str, Any]) -> Optional[str]:
    """
    Read current status value from any known field.
    """
    for k in ("exit_status", "status", "result", "judge_status"):
        v = i_info.get(k)
        if isinstance(v, str) and v:
            return v
    return None


def get_instance_status_field_for_write(i_info: dict[str, Any]) -> str:
    """
    Choose which field to write overrides into.
    Your downstream table logic uses exit_status first, so prefer it if present.
    """
    for k in ("exit_status", "status", "result", "judge_status"):
        v = i_info.get(k)
        if isinstance(v, str) and v:
            return k
    return "exit_status"


# -----------------------------------------------------------------------------
# Total stats delta update helpers
# -----------------------------------------------------------------------------

def safe_int(x: Any, default: int = 0) -> int:
    try:
        if isinstance(x, bool):
            return default
        if isinstance(x, (int, float)) and not math.isnan(float(x)):
            return int(x)
    except Exception:
        pass
    return default


def ensure_total_fields_exist(total_stats: dict[str, Any]) -> None:
    """
    Ensure the total_stats has all the counters we might update.
    Do NOT overwrite existing values; only fill missing keys.
    """
    for k in _STATUS_TO_TOTAL_FIELD.values():
        if k not in total_stats:
            total_stats[k] = 0
    if "total_success" not in total_stats:
        total_stats["total_success"] = 0
    if "total_fail" not in total_stats:
        total_stats["total_fail"] = 0
    if "total_instances" not in total_stats:
        total_stats["total_instances"] = 0


def bump_total(total_stats: dict[str, Any], status: str, delta: int) -> None:
    """
    Increment/decrement the relevant counters for a single status.
    """
    if status not in _STATUS_TO_TOTAL_FIELD:
        return

    key = _STATUS_TO_TOTAL_FIELD[status]
    total_stats[key] = safe_int(total_stats.get(key), 0) + delta

    if status in SUCCESS_STATUSES:
        total_stats["total_success"] = safe_int(total_stats.get("total_success"), 0) + delta
    elif status in FAIL_STATUSES:
        total_stats["total_fail"] = safe_int(total_stats.get("total_fail"), 0) + delta


# -----------------------------------------------------------------------------
# Public API: apply overrides + delta-update totals
# -----------------------------------------------------------------------------

def correct_effectiveness_from_manual_md(
    instances: dict[str, Any],
    total_stats: dict[str, Any],
    manual_md_path: Path,
) -> int:
    """
    Apply manual status overrides to instances, and update total_stats incrementally.

    Key behavior:
    - Does NOT clear total_stats (keeps cost/time aggregates intact).
    - Updates existing counters by delta (old_status -> new_status).
    - Writes override to exit_status when possible (matches your counting logic).

    Returns number of status changes applied.
    """
    if not manual_md_path.exists():
        return 0

    md_text = manual_md_path.read_text("utf-8", errors="replace")
    overrides = parse_manual_analysis_md(md_text)
    if not overrides:
        return 0

    ensure_total_fields_exist(total_stats)

    applied = 0

    for iid, new_status in overrides.items():
        i_info = instances.get(iid)
        if not isinstance(i_info, dict):
            continue

        old_status = get_instance_status_value(i_info)
        if old_status == new_status:
            continue

        # Write override into the most appropriate field
        status_field = get_instance_status_field_for_write(i_info)
        i_info[status_field] = new_status
        applied += 1

        # Adjust totals by delta
        if isinstance(old_status, str) and old_status:
            bump_total(total_stats, old_status, -1)
        bump_total(total_stats, new_status, +1)

    # Ensure total_instances is non-zero
    if safe_int(total_stats.get("total_instances"), 0) <= 0:
        total_stats["total_instances"] = sum(1 for v in instances.values() if isinstance(v, dict))

    return applied
