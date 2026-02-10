from __future__ import annotations

import argparse
import json
import logging
import os
import re
import shlex
import subprocess
import tempfile
from dataclasses import dataclass, replace
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Optional
import uuid

import artisan
from artisan import speedometer, util

logger = logging.getLogger(__name__)

# Status Codes
STATUS_FULL_REPRO = "FULL_REPRO"
STATUS_LASTMILE_REPRO = "LASTMILE_REPRO"
STATUS_COPY_REPRO = "COPY_REPRO"
STATUS_MISMATCH_ERROR = "MISMATCH_ERROR"
STATUS_RUNTIME_ERROR = "RUNTIME_ERROR"
STATUS_STATIC_ERROR = "STATIC_ERROR"

# Reason Codes
# FULL_REPRO
REASON_SUCCESS_FULL = "SUCCESS_FULL"
REASON_SUCCESS_NONE = "SUCCESS_NONE"
REASON_SUCCESS_PART = "SUCCESS_PART"

# LASTMILE_REPRO
REASON_SUCCESS_LASTMILE = "SUCCESS_LASTMILE"

# COPY_REPRO
REASON_COPY_RESULTS = "COPY_RESULTS"

REASON_READ_ERROR = "READ_ERROR"
REASON_JUDGE_INTERNAL_ERROR = "JUDGE_INTERNAL_ERROR"

# MISMATCH_ERROR
REASON_PARTIAL_MISMATCH = "PARTIAL_MISMATCH"
REASON_NO_BLOCK = "NO_SUBMISSION_BLOCK"
REASON_DIFF_FULL = "DIFF_MISMATCH_FULL"
REASON_DIFF_NONE = "DIFF_MISMATCH_NONE"

# RUNTIME_ERROR
REASON_RUNTIME_FAIL = "RUNTIME_FAIL"

# STATIC_ERROR
REASON_SCRIPT_MISSING = "SCRIPT_MISSING"
REASON_SYNTAX_FAIL = "SYNTAX_FAIL"


@dataclass
class SubmissionResult:
    """Structured result of a submission evaluation."""

    from dataclasses import dataclass, field

    return_code: int
    stdout: str
    stderr: str
    status: str
    reason: str = ""
    format_logs: list[dict] = field(default_factory=list)
    speedometer_logs: list[dict] = field(default_factory=list)
    speed_result: Optional[dict[str, Any]] = None


def diff_part(input_table: str, formatted_table: str) -> tuple[int, int, str]:
    """Return an expected-like table with matched cells revealed and mismatched cells obfuscated."""

    def _obfuscate_digits(s: str) -> str:
        return re.sub(r"\d", "?", s)

    exp_lines = input_table.splitlines()
    sub_lines = formatted_table.splitlines()

    def is_table_line(s: str) -> bool:
        return s.strip().startswith("|")

    def is_alignment_line(s: str) -> bool:
        if not is_table_line(s):
            return False
        cells = [c.strip() for c in s.strip().strip("|").split("|")]
        cells = [c for c in cells if c]
        return bool(cells) and all(c == "---" for c in cells)

    sub_data_lines: list[str] = []
    m = len(sub_lines)
    for k, sline in enumerate(sub_lines):
        if not is_table_line(sline):
            continue
        nxt_s = sub_lines[k + 1] if k + 1 < m else ""
        if is_alignment_line(sline):
            continue
        if is_alignment_line(nxt_s):
            continue
        sub_data_lines.append(sline)
    sub_idx = 0

    out_lines: list[str] = []
    total_cells = 0
    mismatched_cells = 0
    n = len(exp_lines)
    for i, ln in enumerate(exp_lines):
        if not is_table_line(ln):
            out_lines.append(ln)
            continue
        nxt = exp_lines[i + 1] if i + 1 < n else ""
        if is_alignment_line(nxt) or is_alignment_line(ln):
            out_lines.append(ln)
            continue

        exp_cells = [c.strip() for c in ln.strip().strip("|").split("|")]
        if sub_idx < len(sub_data_lines):
            sub_ln = sub_data_lines[sub_idx]
            sub_idx += 1
            sub_cells = [c.strip() for c in sub_ln.strip().strip("|").split("|")]
        else:
            sub_cells = []

        new_cells: list[str] = []
        for j, ec in enumerate(exp_cells):
            sc = sub_cells[j] if j < len(sub_cells) else None
            total_cells += 1
            if sc is not None and sc == ec:
                new_cells.append(sc)
            else:
                mismatched_cells += 1
                new_cells.append(_obfuscate_digits(ec))

        out_lines.append("| " + " | ".join(new_cells) + " |")

    result = "\n".join(out_lines)
    if input_table.endswith("\n"):
        result += "\n"
    # TODO: fix fixed cell calculation logic
    return mismatched_cells, total_cells, result


def format_runtime_error_context(script_content: str, stderr: str) -> str:
    """
    Parses stderr for line numbers and returns a formatted snippet of the script
    highlighting where the error occurred.
    """
    # Regex to match the trap output: "... failed at line <N> of ..."
    match = re.search(r"failed at line (\d+) of", stderr)
    if not match:
        # Fallback if we can't parse the line number
        return f"Runtime Error (Could not pinpoint line):\n{stderr}"

    try:
        line_num = int(match.group(1))
    except ValueError:
        return stderr

    lines = script_content.splitlines()
    total_lines = len(lines)

    # 0-indexed line number
    idx = line_num - 1

    # Define context window (e.g., 3 lines before, 3 lines after)
    start = max(0, idx - 3)
    end = min(total_lines, idx + 4)

    # Extract the error message for the annotation (optional, or just generic)
    # We can try to grab the command from stderr if needed, or just say "ERROR HERE"
    # The stderr usually looks like: Runtime Error: Command "cmd" failed...

    snippet = []
    snippet.append("```bash")
    if start > 0:
        snippet.append("# (...omitted...)")

    for i in range(start, end):
        line_content = lines[i]
        if i == idx:
            # Highlight this line
            # Clean up the stderr message to be a bit shorter if possible,
            # or just use the whole line from the trap.
            err_msg_clean = stderr.strip().replace("\n", " ")
            snippet.append(f"{line_content} # <<< YOUR SCRIPT ERRORED ON THIS: {err_msg_clean}")
        else:
            snippet.append(line_content)

    if end < total_lines:
        snippet.append("# (...omitted...)")
    snippet.append("```")

    return "\n".join(snippet)


def check_speedometer(content: str) -> tuple[list[dict], dict[str, Any] | None]:
    speedometer_logs = []
    speed_result = None
    with tempfile.NamedTemporaryFile(mode="w+", suffix=".json", delete=False) as tmp_log:
        tmp_log_path = Path(tmp_log.name)

    try:
        speed_result = speedometer.analyze_script(content, log_path=tmp_log_path)
        if tmp_log_path.exists():
            try:
                with tmp_log_path.open("r", encoding="utf-8") as f:
                    content_log = f.read().strip()
                    if content_log:
                        logs = json.loads(content_log)
                        if isinstance(logs, list):
                            for log in logs:
                                log["reason"] = speedometer.REASON_FINAL_VALIDATION
                            speedometer_logs.extend(logs)
                        elif isinstance(logs, dict):
                            logs["reason"] = speedometer.REASON_FINAL_VALIDATION
                            speedometer_logs.append(logs)
            except Exception as e:
                logger.warning(f"Failed to read speedometer logs: {e}")
    except Exception:
        logger.exception("Speedometer analysis failed")
    finally:
        if tmp_log_path.exists():
            try:
                tmp_log_path.unlink()
            except Exception:
                pass
    return speedometer_logs, speed_result


def check_submission_file(script_path: Path, mode: str = "PART") -> SubmissionResult:
    """Check a submission file on disk.

    Modes:
    - "PART"/"FULL"/"NONE": normal behaviour (output match + speedometer).
    - "WITHOUT_OUTPUT": only run speedometer-based checks (method), skip output matching.
    - "WITHOUT_METHOD": only run output matching, skip speedometer classification.
    """

    if not script_path.exists():
        return SubmissionResult(
            return_code=2,
            stdout="",
            stderr="Submission script missing",
            status=STATUS_STATIC_ERROR,
            reason=REASON_SCRIPT_MISSING,
        )
    try:
        content = script_path.read_text(encoding="utf-8")
    except Exception as e:
        return SubmissionResult(
            return_code=2,
            stdout="",
            stderr=f"Read error: {e}",
            status=STATUS_STATIC_ERROR,
            reason=REASON_READ_ERROR,
        )
    mode_upper = mode.upper() if isinstance(mode, str) else "PART"

    # WITHOUT_OUTPUT: only run speedometer (method) checks, skip output matching.
    if mode_upper == "WITHOUT_OUTPUT":
        allowed_modes = {"PART", "FULL", "NONE", "WITHOUT_OUTPUT", "WITHOUT_METHOD"}
        if mode_upper not in allowed_modes:
            return SubmissionResult(
            return_code=2,
            stdout="",
            stderr=f"Invalid mode '{mode}'. Allowed modes: {sorted(allowed_modes)}",
            status=STATUS_STATIC_ERROR,
            reason=REASON_JUDGE_INTERNAL_ERROR,
            )

        logger.info("check_submission_file: using mode=%s for script=%s", mode_upper, script_path)
        logs, speed_result = check_speedometer(content)
        if not speed_result:
            raise RuntimeError("Speedometer analysis failed unexpectedly")
        speed = speed_result.get("speed")
        if speed == speedometer.SPEEDOMTER_COPY:
            return SubmissionResult(
                return_code=0,
                stdout="",
                stderr="",
                status=STATUS_COPY_REPRO,
                reason=REASON_COPY_RESULTS,
                format_logs=[],
                speedometer_logs=logs,
                speed_result=speed_result,
            )
        elif speed == speedometer.SPEEDOMETER_LASTMILE:
            return SubmissionResult(
                return_code=0,
                stdout="",
                stderr="",
                status=STATUS_LASTMILE_REPRO,
                reason=REASON_SUCCESS_LASTMILE,
                format_logs=[],
                speedometer_logs=logs,
                speed_result=speed_result,
            )
        else:
            return SubmissionResult(
                return_code=0,
                stdout="",
                stderr="",
                status=STATUS_FULL_REPRO,
                reason=REASON_SUCCESS_FULL,
                format_logs=[],
                speedometer_logs=logs,
                speed_result=speed_result,
            )

    # Normal and WITHOUT_METHOD modes run output matching.
    try:
        # Pass the original script directory so that any existing
        # artisan-format.json next to the submission can be reused for
        # caching inside the judge container.
        result = check_output_match(
            content,
            mode=mode if mode_upper not in ("WITHOUT_METHOD",) else "PART",
            script_name=script_path.name,
            script_dir=script_path.parent,
        )
    except Exception as e:
        return SubmissionResult(
            return_code=1,
            stdout="",
            stderr=f"Judge internal error: {e}",
            status=STATUS_RUNTIME_ERROR,
            reason=REASON_JUDGE_INTERNAL_ERROR,
        )

    # WITHOUT_METHOD: skip speedometer classification; just return output-match result.
    if mode_upper == "WITHOUT_METHOD":
        return result

    if result.return_code == 0:
        logs, speed_result = check_speedometer(content)
        combined_logs = result.speedometer_logs + logs
        if speed_result:
            speed = speed_result.get("speed")
            if speed == speedometer.SPEEDOMTER_COPY:
                return SubmissionResult(
                    return_code=result.return_code,
                    stdout=result.stdout,
                    stderr=result.stderr,
                    status=STATUS_COPY_REPRO,
                    reason=REASON_COPY_RESULTS,
                    format_logs=result.format_logs,
                    speedometer_logs=combined_logs,
                    speed_result=speed_result,
                )
            elif speed == speedometer.SPEEDOMETER_LASTMILE:
                return SubmissionResult(
                    return_code=result.return_code,
                    stdout=result.stdout,
                    stderr=result.stderr,
                    status=STATUS_LASTMILE_REPRO,
                    reason=REASON_SUCCESS_LASTMILE,
                    format_logs=result.format_logs,
                    speedometer_logs=combined_logs,
                    speed_result=speed_result,
                )
            elif speed == speedometer.SPEEDOMETER_FULL:
                return SubmissionResult(
                    return_code=result.return_code,
                    stdout=result.stdout,
                    stderr=result.stderr,
                    status=STATUS_FULL_REPRO,
                    reason=REASON_SUCCESS_FULL,
                    format_logs=result.format_logs,
                    speedometer_logs=combined_logs,
                    speed_result=speed_result,
                )

    return result


def check_output_match(
    script_content: str,
    mode: str = "PART",
    script_name: Optional[str] = None,
    script_dir: Optional[Path] = None,
) -> SubmissionResult:
    """Run the submission verification pipeline using in-memory script contents.

    If ``script_dir`` is provided and contains an ``artisan-format.json`` file,
    that log is copied into the temporary log file used inside the judge
    container so that the submission's own formatter cache can be reused.
    """
    with tempfile.TemporaryDirectory(delete=False) as tmp_dir:
        script_path = Path(tmp_dir) / script_name
        script_path.write_text(script_content, encoding="utf-8")
        script_path.chmod(0o700)
        host_cachedir = artisan.ARTISAN_CACHE_DIR
        container_cachedir = "/root/.cache/artisan"
        host_script_dir = script_path.parent.resolve()
        script_basename = script_path.name

        # Create format log directory and file
        logs_dir = Path(tmp_dir) / "logs"
        logs_dir.mkdir()
        format_log_path = logs_dir / "artisan-format.json"
        format_log_path.touch()
        speedometer_log_path = logs_dir / "artisan-speedometer.json"
        speedometer_log_path.touch()

        # If there is an existing artisan-format.json next to the original
        # submission script on the host, preload it into the temp log file so
        # that formatter caching can reuse those entries inside the container.
        preloaded_format_entries = 0
        if script_dir is not None:
            try:
                existing_format_log = script_dir / "artisan-format.json"
                if existing_format_log.exists():
                    content = existing_format_log.read_text(encoding="utf-8")
                    if content.strip():
                        format_log_path.write_text(content, encoding="utf-8")
                        try:
                            existing_data = json.loads(content)
                            if isinstance(existing_data, list):
                                preloaded_format_entries = len(existing_data)
                            elif isinstance(existing_data, dict):
                                preloaded_format_entries = 1
                        except Exception:
                            # If we can't parse the existing log, fall back to
                            # treating all entries as new so that validation
                            # still works; caching will still benefit from the
                            # raw file contents.
                            preloaded_format_entries = 0
            except Exception as e:
                logger.warning(f"Failed to preload existing format log from {script_dir}: {e}")

        # Static Check
        static_proc = subprocess.run(["bash", "-n", str(script_path)], text=True, capture_output=True)
        if static_proc.returncode != 0:
            return SubmissionResult(
                return_code=2,
                stdout=static_proc.stdout,
                stderr=f"Static Error: {static_proc.stderr}",
                status=STATUS_STATIC_ERROR,
                reason=REASON_SYNTAX_FAIL,
            )

        # Runtime Check Wrapper
        # CHANGED: Use 'set -eE' and trap ERR to pinpoint exact line number in subshells
        wrapper_content = (
            "#!/bin/bash\n"
            "set -eE\n"
            'trap \'code=$?; echo "Runtime Error: Command \\"$BASH_COMMAND\\" failed at line $LINENO of $BASH_SOURCE with exit code $code" >&2\' ERR\n'
            "source /tmp/submission.sh\n"
        )
        wrapper_path = Path(tmp_dir) / "wrapper.sh"
        wrapper_path.write_text(wrapper_content, encoding="utf-8")
        wrapper_path.chmod(0o700)

        inner_cmd = (
            f"cp '/mnt/submission/{script_basename}' /tmp/submission.sh && "
            f"cp '/mnt/submission/wrapper.sh' /tmp/wrapper.sh && "
            "chmod +x /tmp/submission.sh /tmp/wrapper.sh && "
            "exec bash -l /tmp/wrapper.sh"
        )
        if script_name.startswith("repro_"):
            paper_name, _, table_index = script_name.split("_")[1:4]
            table_index = table_index.rstrip(".sh")
        else:
            paper_name, _, table_index = script_name.split("_")
            table_index = table_index.rstrip(".sh")
        print(f"Parsed submission script name: paper_name={paper_name}, table_index={table_index}")
        expected = util.get_input_table(paper_name, table_index)
        random_fourdigits = uuid.uuid4().hex[:4]
        network_arg = ""
        if os.getenv("ARTISAN_DOCKER_NETWORK") == "host":
            network_arg = "--network host "

        mitm_env_arg = ""
        if artisan.ARTISAN_MITM_URL:
            mitm_env_arg = f"-e ARTISAN_MITM_URL={shlex.quote(artisan.ARTISAN_MITM_URL)} "

        run_cmd = (
            "docker run "
            f"{network_arg}"
            f"--rm --name judge-{paper_name}-t{table_index.rstrip('.sh')}-{random_fourdigits} "
            f"-e OPENAI_API_KEY={artisan.OPENAI_API_KEY} "
            f"-e ARTISAN_CACHE_DIR={container_cachedir} "
            f"-e MSWEA_SILENT_STARTUP=1 "
            f"-e ARTISAN_FORMAT_LOG=/mnt/logs/artisan-format.json "
            f"-e ARTISAN_SPEED_LOG=/mnt/logs/artisan-speedometer.json "
            f"{mitm_env_arg}"
            f"-v {shlex.quote(str(host_cachedir))}:{container_cachedir} "
            f"-v {shlex.quote(str(host_script_dir))}:/mnt/submission:ro "
            f"-v {shlex.quote(str(logs_dir))}:/mnt/logs:rw "
            "-w /workspace --privileged "
            f"{shlex.quote(artisan.BASE_IMAGE)} "
            f"bash -lc {shlex.quote(inner_cmd)}"
        )
        # print(f"Running submission with command:\n{run_cmd}")
        try:
            run_proc = subprocess.run(["bash", "-lc", run_cmd], text=True, capture_output=True, timeout=28800)
        except subprocess.TimeoutExpired as e:
            container_name = f"judge-{paper_name}-t{table_index.rstrip('.sh')}-{random_fourdigits}"
            subprocess.run(["docker", "kill", container_name], capture_output=True)
            return SubmissionResult(
                return_code=124,
                stdout=e.stdout or "",
                stderr=f"Runtime Error: Execution timed out after 8 hours.\n{e.stderr or ''}",
                status=STATUS_RUNTIME_ERROR,
                reason=REASON_RUNTIME_FAIL,
            )

        format_logs: list[dict] = []
        if format_log_path.exists():
            try:
                with format_log_path.open("r", encoding="utf-8") as f:
                    content = f.read().strip()
                    if content:
                        data = json.loads(content)
                        if isinstance(data, list):
                            if preloaded_format_entries > 0 and len(data) >= preloaded_format_entries:
                                format_logs = data[preloaded_format_entries:]
                            else:
                                format_logs = data
                        elif isinstance(data, dict):
                            format_logs = [data]
            except Exception as e:
                logger.warning(f"Failed to read judge format logs: {e}")

        speedometer_logs = []
        if speedometer_log_path.exists():
            try:
                with speedometer_log_path.open("r", encoding="utf-8") as f:
                    content = f.read().strip()
                    if content:
                        speedometer_logs = json.loads(content)
            except Exception as e:
                logger.warning(f"Failed to read judge speedometer logs: {e}")

        if run_proc.returncode != 0:
            # CHANGED: Format the error message to show context
            formatted_error = format_runtime_error_context(script_content, run_proc.stderr)
            return SubmissionResult(
                return_code=run_proc.returncode,
                stdout=run_proc.stdout,
                stderr=formatted_error,
                status=STATUS_RUNTIME_ERROR,
                reason=REASON_RUNTIME_FAIL,
                format_logs=format_logs,
                speedometer_logs=speedometer_logs,
            )

        try:
            stdout = run_proc.stdout
            block_match = re.search(r"<artisan_submit>\n?(.*?)\n?</artisan_submit>", stdout, re.DOTALL)
            submit_block = block_match.group(1).rstrip() + "\n"
        except Exception as exc:
            return SubmissionResult(
                return_code=1,
                stdout=run_proc.stdout,
                stderr=f"Error: submission block not found: {exc}",
                status=STATUS_MISMATCH_ERROR,
                reason=REASON_NO_BLOCK,
                format_logs=format_logs,
                speedometer_logs=speedometer_logs,
            )
        with tempfile.NamedTemporaryFile("w", delete=False) as tmp_out:
            tmp_out.write(submit_block)
            tmp_path = tmp_out.name
        # write str expected to tmpfile
        with tempfile.NamedTemporaryFile("w", delete=False) as tmp_expected:
            tmp_expected.write(expected)
            expected_path = tmp_expected.name
            raw_diff = subprocess.run(
                [
                    "bash",
                    "-lc",
                    f"diff -w -u {shlex.quote(str(expected_path))} {shlex.quote(str(Path(tmp_path)))}",
                ],
                text=True,
                capture_output=True,
            )
        mode = mode.upper()
        if mode == "FULL":
            if raw_diff.returncode != 0:
                return SubmissionResult(
                    return_code=raw_diff.returncode,
                    stdout="",
                    stderr="",
                    status=STATUS_MISMATCH_ERROR,
                    reason=REASON_DIFF_FULL,
                    format_logs=format_logs,
                    speedometer_logs=speedometer_logs,
                )
            return SubmissionResult(
                return_code=0,
                stdout="",
                stderr=artisan.SUCCESS_STRING,
                status=STATUS_FULL_REPRO,
                reason=REASON_SUCCESS_FULL,
                format_logs=format_logs,
                speedometer_logs=speedometer_logs,
            )
        if mode == "NONE":
            if raw_diff.returncode != 0:
                return SubmissionResult(
                    return_code=raw_diff.returncode,
                    stdout="",
                    stderr="",
                    status=STATUS_MISMATCH_ERROR,
                    reason=REASON_DIFF_NONE,
                    format_logs=format_logs,
                    speedometer_logs=speedometer_logs,
                )
            return SubmissionResult(
                return_code=0,
                stdout="",
                stderr=artisan.SUCCESS_STRING,
                status=STATUS_FULL_REPRO,
                reason=REASON_SUCCESS_NONE,
                format_logs=format_logs,
                speedometer_logs=speedometer_logs,
            )

        mismatched, total, obfuscated = diff_part(expected, submit_block)
        if mismatched != 0:
            print(f"Submitted Block:\n============\n{submit_block}============")
            return SubmissionResult(
                return_code=1,
                stdout=obfuscated,
                stderr=f"Partial mismatch (score: {(1 - (mismatched / total)):.2f}): some cells differ (digits obfuscated)",
                status=STATUS_MISMATCH_ERROR,
                reason=REASON_PARTIAL_MISMATCH,
                format_logs=format_logs,
                speedometer_logs=speedometer_logs,
            )
        else:
            return SubmissionResult(
                return_code=0,
                stdout="",
                stderr=artisan.SUCCESS_STRING,
                status=STATUS_FULL_REPRO,
                reason=REASON_SUCCESS_PART,
                format_logs=format_logs,
                speedometer_logs=speedometer_logs,
            )


class _JudgeRequestHandler(BaseHTTPRequestHandler):
    server_version = "ArtisanJudge/1.0"

    def do_POST(self) -> None:  # noqa: N802 - method name fixed by BaseHTTPRequestHandler
        if self.path.rstrip("/") != "/submit":
            self._send_json(HTTPStatus.NOT_FOUND, {"error": "Not found"})
            return

        content_length = self.headers.get("Content-Length")
        if content_length is None:
            self._send_json(HTTPStatus.LENGTH_REQUIRED, {"error": "Missing Content-Length"})
            return
        try:
            length = int(content_length)
        except ValueError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": "Invalid Content-Length"})
            return

        body = self.rfile.read(length)
        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": "Invalid JSON payload"})
            return
        script_content = payload.get("script")
        script_name = payload.get("script_name")
        mode = payload.get("mode", "PART")

        override_mode = os.environ.get("ARTISAN_JUDGE_OVERRIDE_MODE")
        if override_mode:
            mode = override_mode

        if not isinstance(script_content, str) or not script_content.strip():
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": "Missing 'script'"})
            return
        if script_name is not None and not isinstance(script_name, str):
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": "Invalid 'script_name'"})
            return
        if not script_name:
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": "Missing 'script_name'"})
            return

        # Use a temporary file to leverage check_submission_file which expects a path
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir) / script_name
            try:
                tmp_path.write_text(script_content, encoding="utf-8")
            except Exception as exc:
                self._send_json(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    {"error": "Failed to write script to temp file", "detail": str(exc)},
                )
                return

            try:
                print(f"handling submission via check_submission_file: script_name={script_name}, mode={mode}")
                result = check_submission_file(tmp_path, mode=mode)
            except Exception as exc:
                print("Unhandled error while processing submission")
                print(f"Exception: {exc}")
                self._send_json(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    {"error": "Internal server error", "detail": str(exc)},
                )
                return

        speed_warning: Optional[dict[str, Any]] = None
        if result.speed_result:
            speed = result.speed_result.get("speed")
            if speed == speedometer.SPEEDOMTER_COPY:
                speed_warning = {
                    "message": f"Speedometer classified the submission as {speedometer.SPEEDOMTER_COPY}. You will not receive credit unless this is addressed.",
                    "reason": result.speed_result.get("reason", ""),
                    "files_to_exclude": result.speed_result.get("files_to_exclude", []),
                }
        payload = {
            "return_code": result.return_code,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "status": result.status,
            "reason": result.reason,
            "format_logs": result.format_logs,
            "speedometer_logs": result.speedometer_logs,
        }
        if speed_warning:
            payload["warning"] = speed_warning
        status = HTTPStatus.OK
        self._send_json(status, payload)

    def _send_json(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status.value)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def run_server(host: str = "0.0.0.0", port: int = 8000) -> None:
    server = ThreadingHTTPServer((host, port), _JudgeRequestHandler)
    print(f"Starting judge server on {host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:  # pragma: no cover - manual shutdown
        print("Judge server interrupted; shutting down")
    finally:
        server.server_close()
        print("Judge server stopped")


def _judge_from_cli(args: argparse.Namespace) -> int:
    """Adapter so argparse dispatch can invoke the judge server."""
    run_server(args.host, args.port)
    return 0


def register_subparser(subparsers: argparse._SubParsersAction) -> None:
    """Register the `artisan judge` subparser with the shared CLI."""
    judge_p = subparsers.add_parser(
        "judge",
        help="Run the judge HTTP service",
    )
    judge_p.add_argument(
        "--host",
        default=os.environ.get("ARTISAN_JUDGE_HOST", "0.0.0.0"),
        help="Host interface for the judge server (default: 0.0.0.0 or ARTISAN_JUDGE_HOST)",
    )
    judge_p.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("ARTISAN_JUDGE_PORT", "8000")),
        help="Port for the judge server (default: 8000 or ARTISAN_JUDGE_PORT)",
    )
    judge_p.set_defaults(func=_judge_from_cli)
