#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import tempfile
from functools import lru_cache
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

@lru_cache(maxsize=None)
def repo_root(cwd: Path | None = None) -> Path:
    """Return the absolute path to the current Git repository root."""
    out = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=str(cwd) if cwd else None,
        text=True,
    ).strip()
    return Path(out)

ARTISAN_DIR = repo_root()
EVALUATION_DIR = ARTISAN_DIR / "evaluation"
SCRIPTS_DIR = EVALUATION_DIR / "scripts"
TABLES_DIR = EVALUATION_DIR / "tables"
PROMPTS_DIR = ARTISAN_DIR / "prompts"

OPENHANDS_DIR = ARTISAN_DIR / "third_party" / "OpenHands"

def git_describe(dir_: Path) -> str:
    return subprocess.check_output(
        ["git", "describe", "--always", "--dirty"],
        cwd=str(dir_),
        text=True
    ).strip()

TEMPLATE_NAME = "task_table.j2"
PROMPT_ENV = Environment(
    loader=FileSystemLoader(PROMPTS_DIR),
    trim_blocks=True,
    lstrip_blocks=True,
)

def render_openhands_config(workspace_path: Path, model_name, api_key) -> Path:
    """Render the OpenHands TOML from a Jinja template into a temp file."""
    template_path = EVALUATION_DIR / "openhands_config.j2"
    env = Environment(loader=FileSystemLoader(template_path.parent), autoescape=False)
    template = env.get_template(template_path.name)

    rendered = template.render(
        model_name=model_name,
        openai_api_key=api_key,
        workspace_volume=str(workspace_path),
    )

    tmp = tempfile.NamedTemporaryFile(mode="w", delete=False, suffix=".toml")
    with tmp:
        tmp.write(rendered)
    return Path(tmp.name)


# --------------------------------------------------------------------------------------
# Docker helpers
# --------------------------------------------------------------------------------------

def kill_openhands_containers() -> None:
    """Kill all running containers for the OpenHands runtime image."""
    try:
        ids = subprocess.check_output(
            ["docker", "ps", "-q", "--filter", "ancestor=ghcr.io/all-hands-ai/runtime"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).split()
    except subprocess.CalledProcessError:
        ids = []

    if ids:
        subprocess.run(
            ["docker", "kill", *ids],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

def docker_prune_containers() -> None:
    subprocess.run(
        ["docker", "container", "prune", "-f"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )