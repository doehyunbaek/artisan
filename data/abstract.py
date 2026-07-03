#!/usr/bin/env python3
"""Write the Artisan paper abstract with benchmark results computed locally."""

from __future__ import annotations

import json
from pathlib import Path

DATA_ROOT = Path(__file__).resolve().parent
REPO_ROOT = DATA_ROOT.parent
METADATA_PATH = REPO_ROOT / "artisanbench" / "metadata.json"
BUGS_PATH = DATA_ROOT / "bugs" / "bugs.json"
TEX_DIR = DATA_ROOT / "tex"

ABSTRACT_TEMPLATE = """Reproducibility is an important goal in computer science research, e.g., for artifact evaluation and to build upon experimental results of prior work. Recently, LLM agents are being used to automatically reproduce research results, but they fail to provide executable evidence of reproduction and do not consider the method of reproduction, which limits their usefulness. We present Artisan, an LLM agent that reproduces tables of numeric results, given a paper and its artifact. The approach is enabled by two key contributions: First, we frame the reproduction problem as a code generation task, enabling users to audit and re-run the resulting reproduction script independently of the agent. Second, we design automated judging mechanisms that steer the agent toward correct results without exposing them, while preventing shortcuts like copying pre-computed results. To evaluate Artisan, we introduce Artisan-Bench, the first benchmark assessing the ability to generate code that reproduces research results. Artisan-Bench comprises {tasks:,} tasks derived from {papers:,} software engineering papers. Our experiments show that Artisan is effective and efficient, with the added benefit of aiding the discovery of {new_errors:,} new errors in either the paper or artifact."""


def get_tasks() -> int:
    with METADATA_PATH.open("r", encoding="utf-8") as f:
        metadata = json.load(f)

    excluded_flags = ("non-result", "missing", "non-deterministic", "exceed-hardware")
    return sum(
        1
        for paper in metadata
        for table in paper["tables"].values()
        if not any(table.get(flag) is True for flag in excluded_flags)
    )


def get_papers() -> int:
    with METADATA_PATH.open("r", encoding="utf-8") as f:
        metadata = json.load(f)
    return len(metadata)


def get_newerrors() -> int:
    with BUGS_PATH.open("r", encoding="utf-8") as f:
        bugs = json.load(f)
    return len(bugs["bugs"])


def get_abstract() -> str:
    return ABSTRACT_TEMPLATE.format(
        papers=get_papers(),
        tasks=get_tasks(),
        new_errors=get_newerrors(),
    )


def write_abstract(output_dir: Path = TEX_DIR) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / "abstract.tex"
    path.write_text(get_abstract().rstrip() + "\n", encoding="utf-8")
    return path


def main() -> None:
    print(f"Wrote {write_abstract()}")


if __name__ == "__main__":
    main()
