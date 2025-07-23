#!/usr/bin/env python3
from __future__ import annotations
import argparse
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, List, Tuple
import util

REPEAT_COUNT = int(os.getenv("REPEAT_COUNT", "1"))
MAX_ITERATIONS = int(os.getenv("MAX_ITERATIONS", "50"))
BUDGET = float(os.getenv("BUDGET", "1.0"))
MODEL_NAME = os.getenv("MODEL_NAME", "openai/gpt-4o-mini")
API_KEY = os.environ.get("OPENAI_API_KEY", "")

def list_experiments(scripts_dir: Path) -> List[Tuple[str, str, str]]:
    """Return list of (paper, kind, index) from script filenames: paper_kind_index.py"""
    exps = []
    for file in scripts_dir.iterdir():
        if file.is_file():
            base = file.stem  # filename without suffix
            parts = base.split("_")
            if len(parts) == 3:
                exps.append(tuple(parts))  # type: ignore[arg-type]
    return exps

def filter_experiments(
    experiments: Iterable[Tuple[str, str, str]],
    paper: str | None,
    kind: str | None,
    index: str | None,
) -> List[Tuple[str, str, str]]:
    exps = list(experiments)
    if paper:
        exps = [e for e in exps if e[0] == paper]
        if kind:
            exps = [e for e in exps if e[1] == kind]
            if index:
                exps = [e for e in exps if e[2] == index]
    return exps

def run_experiment(paper: str, kind: str, index: str, run_idx: int) -> None:
    datestamp = datetime.now(timezone.utc).strftime("%y%m%d")
    timestamp = datetime.now(timezone.utc).strftime("%H%M")

    log_dir = util.ARTISAN_DIR / "logs" / datestamp / f"{paper}_{kind}_{index}"
    log_dir.mkdir(parents=True, exist_ok=True)
    workspace_dir = log_dir / f"{timestamp}_workspace"
    workspace_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"{timestamp}.log"

    rendered_prompt_json_escaped = util.render_prompt(paper, index)
    openhands_toml = util.render_openhands_config(workspace_dir, MODEL_NAME, API_KEY)

    print(f"[Run {run_idx}] log → {log_file}")
    cmd = [
        "poetry", "run", "python", "-m", "openhands.core.main",
        "--config-file", str(openhands_toml),
        "-t", rendered_prompt_json_escaped,
        "-i", str(MAX_ITERATIONS),
        "-b", str(BUDGET),
    ]
    env = os.environ.copy()
    env["LOG_ALL_EVENTS"] = "true"
    env["DEBUG"] = "true"

    with log_file.open("w") as lf:
        lf.write(f"Artisan Git Version: {util.git_describe(util.ARTISAN_DIR)}\n")
        lf.write(f"OpenHands Git Version: {util.git_describe(util.OPENHANDS_DIR)}\n")
        lf.write(f"Model name: {MODEL_NAME}\n")
        lf.write(f"Repeat count: {REPEAT_COUNT}\n")
        lf.write(f"Max Iterations: {MAX_ITERATIONS}\n")
        lf.write(f"Budget: {BUDGET}\n")

    # Append subprocess output to the log_file
    with log_file.open("a") as lf:
        subprocess.run(
            cmd,
            cwd=str(util.OPENHANDS_DIR),
            check=True,
            stdout=lf,
            stderr=subprocess.STDOUT,
            env=env,
        )

    util.docker_prune_containers()

def main() -> None:
    parser = argparse.ArgumentParser(description="Run a subset of experiments.")
    parser.add_argument("paper", nargs="?", help="Paper name")
    parser.add_argument("kind", nargs="?", help="Experiment kind")
    parser.add_argument("index", nargs="?", help="Experiment index")
    args = parser.parse_args()

    experiments = list_experiments(util.SCRIPTS_DIR)
    filtered = filter_experiments(experiments, args.paper, args.kind, args.index)

    if not filtered:
        print("No experiments match your filter.")
        return

    util.kill_openhands_containers()
    for paper, kind, index in filtered:
        for run_idx in range(1, REPEAT_COUNT + 1):
            run_experiment(paper, kind, index, run_idx)

if __name__ == "__main__":
    main()
