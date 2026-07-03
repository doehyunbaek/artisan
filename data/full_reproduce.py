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


def main() -> int:
    parser = argparse.ArgumentParser(description="Run all full-reproduction benchmark configurations")
    parser.add_argument("--workers", "-w", type=int, default=1, help="parallel tasks per configuration")
    parser.add_argument("--repeat", "-r", type=int, default=1, help="repeat count per benchmark task")
    parser.add_argument("--filter", "-f", default=DEFAULT_FILTER, help="regex filter for instance IDs")
    parser.add_argument("--logs-root", type=Path, default=LOGS_ROOT, help="root directory for generated logs")
    parser.add_argument("--only", action="append", default=[], help="run only this run name/agent/config; repeatable")
    parser.add_argument("--network-host", action="store_true", help="pass --network-host to benchmark.py")
    parser.add_argument("--continue-existing", action="store_true", help="continue existing reprobench.json files")
    parser.add_argument("--allow-missing-keys", action="store_true", help="do not stop if API key env vars are missing")
    parser.add_argument("--dry-run", action="store_true", help="print commands without running them")
    args = parser.parse_args()

    args.logs_root = args.logs_root.expanduser().resolve()
    configs = selected_configs(args.only)
    check_prerequisites(configs, allow_missing_keys=args.allow_missing_keys or args.dry_run)

    print(f"Selected {len(configs)} configuration(s). Logs root: {args.logs_root}", flush=True)
    for config in configs:
        argv = command_for(config, args)
        print(f"\n== {config.run_name} ==", flush=True)
        print(f"$ {shell_join(argv)}", flush=True)
        if not args.dry_run:
            subprocess.run(argv, cwd=REPO_ROOT, check=True)

    print("\nFull reproduction commands completed.", flush=True)
    print("Run last-mile aggregation with:", flush=True)
    print("  python3 data/reproduce.py", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
