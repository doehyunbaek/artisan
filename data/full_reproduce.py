#!/usr/bin/env python3
"""Run the full Artisan experimental campaign.

This script launches the 15 configurations used for Table 2 and writes logs to
``data/logs/<expected-run-name>`` so the last-mile scripts can consume them.
"""

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

DATA_ROOT = Path(__file__).resolve().parent
REPO_ROOT = DATA_ROOT.parent
LOGS_ROOT = DATA_ROOT / "logs"
BENCHMARK = REPO_ROOT / "artisanbench" / "benchmark.py"


@dataclass(frozen=True)
class RunConfig:
    run_name: str
    agent: str
    model: str
    ablation: str | None = None


RUN_CONFIGS: tuple[RunConfig, ...] = (
    RunConfig("sweagent-deepseek-reasoner-4bdc", "sweagent", "deepseek-reasoner"),
    RunConfig("sweagent-gpt5mini-5d98", "sweagent", "gpt-5-mini"),
    RunConfig("sweagent-gpt5.1-ebe4", "sweagent", "gpt-5.1"),
    RunConfig("openhands-deepseek-reasoner-bd34", "openhands", "deepseek-reasoner"),
    RunConfig("openhands-gpt5mini-a4eb", "openhands", "gpt-5-mini"),
    RunConfig("openhands-gpt5.1-41ec", "openhands", "gpt-5.1"),
    RunConfig("minisweagent-deepseek-reasoner-e5a7", "minisweagent", "deepseek-reasoner"),
    RunConfig("minisweagent-gpt5mini-a830", "minisweagent", "gpt-5-mini"),
    RunConfig("minisweagent-gpt5.1-301b", "minisweagent", "gpt-5.1"),
    RunConfig("artisan-deepseek-reasoner-6f4b", "artisan", "deepseek-reasoner"),
    RunConfig("artisan-gpt5mini-845b", "artisan", "gpt-5-mini"),
    RunConfig("artisan-gpt5.1-dbe0", "artisan", "gpt-5.1"),
    RunConfig("artisan-gpt5.1-3ee0-without_output", "artisan", "gpt-5.1", "without_output"),
    RunConfig("artisan-gpt5.1-7a04-without_method", "artisan", "gpt-5.1", "without_method"),
    RunConfig("artisan-gpt5.1-9223-without_format", "artisan", "gpt-5.1", "without_format"),
)


def shell_join(argv: list[str]) -> str:
    return " ".join(shlex.quote(part) for part in argv)


def selected_configs(only: list[str]) -> list[RunConfig]:
    if not only:
        return list(RUN_CONFIGS)
    selected = []
    wanted = set(only)
    for config in RUN_CONFIGS:
        labels = {
            config.run_name,
            config.agent,
            f"{config.agent}-{config.model}",
            f"{config.agent}-{config.model}-{config.ablation}" if config.ablation else "",
        }
        if wanted & labels:
            selected.append(config)
    missing = wanted - {label for cfg in selected for label in (cfg.run_name, cfg.agent, f"{cfg.agent}-{cfg.model}")}
    if missing:
        known = "\n  ".join(config.run_name for config in RUN_CONFIGS)
        raise SystemExit(f"Unknown --only selection(s): {', '.join(sorted(missing))}\nKnown run names:\n  {known}")
    return selected


def command_for(config: RunConfig, args: argparse.Namespace) -> list[str]:
    log_root = args.logs_root / config.run_name
    argv = [
        sys.executable,
        str(BENCHMARK),
        "--agent",
        config.agent,
        "--model",
        config.model,
        "--workers",
        str(args.workers),
        "--log-root",
        str(log_root),
    ]
    if args.filter:
        argv.extend(["--filter", args.filter])
    if args.repeat != 1:
        argv.extend(["--repeat", str(args.repeat)])
    if config.ablation:
        argv.extend(["--ablation", config.ablation])
    if args.network_host:
        argv.append("--network-host")
    if args.continue_existing and (log_root / "reprobench.json").exists():
        argv.extend(["--continue-run", str(log_root / "reprobench.json")])
    return argv


def check_prerequisites(configs: list[RunConfig], *, allow_missing_keys: bool) -> None:
    missing = []
    if not os.getenv("OPENAI_API_KEY"):
        missing.append("OPENAI_API_KEY")
    if any("deepseek" in config.model for config in configs) and not (
        os.getenv("DEEPSEEK_API_KEY") or os.getenv("LLM_API_KEY")
    ):
        missing.append("DEEPSEEK_API_KEY or LLM_API_KEY")
    if missing and not allow_missing_keys:
        raise SystemExit(
            "Missing required environment variable(s): "
            + ", ".join(missing)
            + "\nPass API keys with Docker -e flags, or use --dry-run to print commands."
        )


DEFAULT_FILTER = ""
SMOKE_BLOAT_RUN = "artisan-gpt5.1-dbe0"
SMOKE_BLOAT_FILTER = "bloat-t1"


def _read_log_tail(path: Path, max_chars: int = 4000) -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    return text[-max_chars:]


def _wait_for_judge(proc: subprocess.Popen, *, port: int, log_path: Path, timeout: float = 10.0) -> None:
    start = time.time()
    deadline = start + timeout
    min_ready_time = start + 0.75
    url = f"http://127.0.0.1:{port}/submit"
    while time.time() < deadline:
        if proc.poll() is not None:
            tail = _read_log_tail(log_path)
            raise SystemExit(f"Judge server exited before becoming ready. Log:\n{tail}")
        try:
            urllib.request.urlopen(url, timeout=0.5)
        except urllib.error.HTTPError as exc:
            # The judge only implements POST. HTTP 501 for GET means the server is up.
            if exc.code == 501:
                if time.time() < min_ready_time:
                    time.sleep(0.25)
                    continue
                if proc.poll() is not None:
                    tail = _read_log_tail(log_path)
                    raise SystemExit(f"Judge server exited before becoming ready. Log:\n{tail}")
                return
        except (OSError, TimeoutError):
            pass
        time.sleep(0.25)
    tail = _read_log_tail(log_path)
    raise SystemExit(f"Judge server did not become ready at {url}. Log:\n{tail}")


def _start_judge_server(args: argparse.Namespace) -> tuple[subprocess.Popen | None, object | None]:
    if not args.with_judge:
        return None, None

    args.judge_workdir.mkdir(parents=True, exist_ok=True)
    log_path = args.judge_workdir / "judge.log"
    os.environ["ARTISAN_JUDGE_WORKDIR"] = str(args.judge_workdir)
    os.environ["ARTISAN_JUDGE_URL"] = f"http://127.0.0.1:{args.judge_port}/submit"
    args.network_host = True

    if args.dry_run:
        print(f"Would start judge server on {args.judge_host}:{args.judge_port}; log: {log_path}", flush=True)
        return None, None

    log_fh = log_path.open("w", encoding="utf-8")
    proc = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "artisan.cli",
            "judge",
            "--host",
            args.judge_host,
            "--port",
            str(args.judge_port),
        ],
        cwd=REPO_ROOT,
        env=os.environ.copy(),
        stdout=log_fh,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        _wait_for_judge(proc, port=args.judge_port, log_path=log_path)
    except Exception:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
        log_fh.close()
        raise

    print(f"Started judge server on {args.judge_host}:{args.judge_port}; log: {log_path}", flush=True)
    return proc, log_fh


def _stop_judge_server(proc: subprocess.Popen | None, log_fh: object | None) -> None:
    if proc is not None and proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)
    if log_fh is not None:
        try:
            log_fh.close()
        except Exception:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(description="Run all full-reproduction benchmark configurations")
    parser.add_argument("--workers", "-w", type=int, default=1, help="parallel tasks per configuration")
    parser.add_argument("--repeat", "-r", type=int, default=1, help="repeat count per benchmark task")
    parser.add_argument("--filter", "-f", default=DEFAULT_FILTER, help="regex filter for instance IDs")
    parser.add_argument("--logs-root", type=Path, default=None, help="root directory for generated logs")
    parser.add_argument("--output-root", type=Path, default=None, help="root for smoke-test logs and judge workdir")
    parser.add_argument("--only", action="append", default=[], help="run only this run name/agent/config; repeatable")
    parser.add_argument("--network-host", action="store_true", help="pass --network-host to benchmark.py")
    parser.add_argument("--with-judge", dest="with_judge", action="store_true", default=True, help="start a local judge server for in-agent artisan submit (default)")
    parser.add_argument("--no-judge", dest="with_judge", action="store_false", help="do not start the local judge server")
    parser.add_argument("--judge-workdir", type=Path, default=None, help="directory for judge temp files and judge.log")
    parser.add_argument("--judge-host", default="0.0.0.0", help="host interface for --with-judge")
    parser.add_argument("--judge-port", type=int, default=8000, help="port for --with-judge")
    parser.add_argument("--smoke-bloat-t1", action="store_true", help="run the documented bloat Table 1 smoke test")
    parser.add_argument("--continue-existing", action="store_true", help="continue existing reprobench.json files")
    parser.add_argument("--allow-missing-keys", action="store_true", help="do not stop if API key env vars are missing")
    parser.add_argument("--dry-run", action="store_true", help="print commands without running them")
    args = parser.parse_args()

    if args.smoke_bloat_t1:
        if not args.only:
            args.only = [SMOKE_BLOAT_RUN]
        if not args.filter:
            args.filter = SMOKE_BLOAT_FILTER

    if args.output_root is not None:
        args.output_root = args.output_root.expanduser().resolve()
    if args.logs_root is None:
        args.logs_root = (args.output_root / "logs") if args.output_root is not None else LOGS_ROOT
    args.logs_root = args.logs_root.expanduser().resolve()
    if args.judge_workdir is None:
        args.judge_workdir = ((args.output_root / "judge-work") if args.output_root is not None else (args.logs_root.parent / "judge-work"))
    args.judge_workdir = args.judge_workdir.expanduser().resolve()

    configs = selected_configs(args.only)
    check_prerequisites(configs, allow_missing_keys=args.allow_missing_keys or args.dry_run)

    judge_proc, judge_log = _start_judge_server(args)
    try:
        print(f"Selected {len(configs)} configuration(s). Logs root: {args.logs_root}", flush=True)
        for config in configs:
            argv = command_for(config, args)
            print(f"\n== {config.run_name} ==", flush=True)
            print(f"$ {shell_join(argv)}", flush=True)
            if not args.dry_run:
                subprocess.run(argv, cwd=REPO_ROOT, check=True)
    finally:
        _stop_judge_server(judge_proc, judge_log)

    print("\nFull reproduction commands completed.", flush=True)
    print("Run last-mile aggregation with:", flush=True)
    print("  python3 data/reproduce.py", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
