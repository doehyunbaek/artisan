from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import requests

import artisan
from artisan.tools import format
from artisan import speedometer


def _normalize_judge_url(url: str) -> str:
    url = url.rstrip("/")
    if not url.endswith("/submit"):
        url += "/submit"
    return url


def cmd_submit(
    script: Path,
    mode: str = "PART",
    judge_url: str | None = None,
) -> int:
    """Send a submission request to the running judge service."""
    try:
        script_content = script.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"Error: unable to read script contents: {exc}", file=sys.stderr)
        return 2

    payload = {"script": script_content, "script_name": script.name, "mode": mode}
    judge_url = _normalize_judge_url(judge_url or artisan.ARTISAN_JUDGE_URL)
    timeout = artisan.ARTISAN_JUDGE_TIMEOUT

    try:
        print(f"Submitting to judge service at {judge_url}...")
        response = requests.post(judge_url, json=payload, timeout=timeout)
    except requests.RequestException as exc:
        print(f"Error: failed to contact judge service at {judge_url}: {exc}", file=sys.stderr)
        return 1
    if response.status_code != 200:
        message = response.text
        try:
            data = response.json()
            message = data.get("error", message)
        except (ValueError, json.JSONDecodeError):
            pass
        print(
            f"Error: judge service returned status {response.status_code}: {message}",
            file=sys.stderr,
        )
        return 1
    try:
        data = response.json()
    except ValueError:
        print("Error: judge service returned non-JSON response.", file=sys.stderr)
        return 1
    stdout_text = data.get("stdout", "")
    stderr_text = data.get("stderr", "")
    warning_text = data.get("warning", "")
    return_code = int(data.get("return_code", 1))

    format_logs = data.get("format_logs", [])
    if format_logs:
        for log in format_logs:
            log["reason"] = format.REASON_SUBMIT_VALIDATION
        log_path = artisan.FORMAT_LOG_PATH
        try:
            existing_logs = []
            if log_path.exists():
                existing_logs = json.loads(log_path.read_text(encoding="utf-8"))
            all_logs = existing_logs + format_logs
            log_path.write_text(json.dumps(all_logs, indent=2), encoding="utf-8")
            print(f"Wrote format tool logs to {log_path}", file=sys.stderr)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            print(f"Warning: unable to write format tool logs to {log_path}: {exc}", file=sys.stderr)

    speedometer_logs = data.get("speedometer_logs", [])
    if speedometer_logs:
        for log in speedometer_logs:
            log["reason"] = speedometer.REASON_SUBMIT_VALIDATION
        log_path = artisan.SPEEDOMETER_LOG_PATH
        try:
            existing_logs = []
            if log_path.exists():
                existing_logs = json.loads(log_path.read_text(encoding="utf-8"))
            all_logs = existing_logs + speedometer_logs
            log_path.write_text(json.dumps(all_logs, indent=2), encoding="utf-8")
            print(f"Wrote speedometer tool logs to {log_path}", file=sys.stderr)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            print(f"Warning: unable to write speedometer tool logs to {log_path}: {exc}", file=sys.stderr)

    if stdout_text:
        sys.stdout.write(stdout_text)
        if not stdout_text.endswith("\n"):
            sys.stdout.write("\n")
        sys.stdout.flush()

    if stderr_text:
        sys.stderr.write(stderr_text)
        if not stderr_text.endswith("\n"):
            sys.stderr.write("\n")
        sys.stderr.flush()
    if warning_text:
        print(f"Warning: {warning_text}", file=sys.stderr)

    return return_code


def _submit_from_cli(args: argparse.Namespace) -> int:
    """Adapter so argparse dispatch can call cmd_submit with parsed args."""
    return cmd_submit(args.script, args.mode, args.judge_url)


def register_subparser(subparsers: argparse._SubParsersAction) -> None:
    """Register the `artisan submit` subparser with the shared CLI."""
    submit_p = subparsers.add_parser(
        "submit",
        help=("Verify a reproduction script"),
    )
    submit_p.add_argument(
        "script",
        type=Path,
        nargs="?",
        help="Path to reproduction script",
    )
    submit_p.add_argument(
        "--mode",
        choices=["FULL", "PART", "NONE", "WITHOUT_OUTPUT", "WITHOUT_METHOD"],
        default="PART",
        help=(
            "Output mode: FULL shows full diff, PART shows obfuscated diff, NONE shows success/fail only. "
            "WITHOUT_OUTPUT skips output matching (only method check). "
            "WITHOUT_METHOD skips method check (only output matching)."
        ),
    )
    submit_p.add_argument(
        "--judge-url",
        default=None,
        help=(
            "URL of the judge service (defaults to ARTISAN_JUDGE_URL or http://localhost:8000/submit). "
            "If a base URL is provided, /submit will be appended automatically."
        ),
    )
    submit_p.set_defaults(func=_submit_from_cli)
