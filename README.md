# Artisan: Agentic Artifact Evaluation

This repository contains artifacts for the paper, "Artisan: Agentic Artifact Evaluation".

## Installation

### Supported platforms

Currently developed and supported on Ubuntu 24.04.3 LTS. If it does not work on other platforms, please open an issue or submit a PR.

### Prerequisites

Install [uv](https://uv.io/) and [Docker](https://www.docker.com/) to run Artisan.

### Installation steps

1. Clone the repository
```sh
git clone --recurse-submodules
```

2. Install dependencies
```sh
uv sync
```

3. Install the package in editable mode for development
```sh
uv pip install -e .
```

## Running Artisan on single table

You can read the [run.py](./src/artisan/run.py) code for more details about the `artisan run` command.

You can run Artisan on a single table with the following command:
```sh
artisan run --paper ./artisanbench/papers/bloat.pdf --table ./artisanbench/tables/bloat_table_2.md --artifact https://zenodo.org/records/11095274
```

## Artisan-Bench

## Notes on the copyright

Due to the copyright, we can not upload all the papers in the Artisan-Bench to the public repository.
We are currently contacting the authors to obtain the copyright-free version of the papers.
For the missing papers, download them manually and put them into [artisanbench/papers](./artisanbench/papers/) directory with a file name {id}.pdf (id should be found in [metadata.json](./artisanbench/metadata.json)).

Note: PDFs in `papers/` are third-party works under their own licenses (see `papers/README.md`).

## Running the benchmark

You can read the [artisanbench](./artisanbench/benchmark.py) code for more details about the benchmark design and implementation.
You can read the [metadata.json](./artisanbench/metadata.json) file for the metadata of the benchmark, including the papers, tables, and reproduction scripts used in the benchmark.

Run on the whole artisanbench
```sh
uv run artisanbench/benchmark.py
```

Run specific paper
```sh
uv run artisanbench/benchmark.py -f pythonic
```

Run specific table of the paper
```sh
uv run artisanbench/benchmark.py -f pythonic-t2
```

Run with multiple workers
```sh
uv run artisanbench/benchmark.py -w 8 -f pythonic-t2
```

## Repository structure

* [src](./src): Artisan implementation.
  * [src/artisan](./src/artisan):
    * [src/artisan/run.py](./src/artisan/run.py): Entrypoint for Artisan.
    * [src/artisan/judge.py](./src/artisan/judge.py): Judging mechanism including the execution-based method judge.
    * [src/artisan/speedometer.py](./src/artisan/speedometer.py): LLM-based method juge.
    * [src/artisan/submit.py](./src/artisan/submit.py): Submits a reproduction script to a judging mechanism.
    * [src/artisan/serve.py](./src/artisan/serve.py): Caches docker images.
    * [src/artisan/mitm.py](./src/artisan/mitm.py): Caches artifact repository downloads.
    * [src/artisan/tools](./src/artisan/tools): Tool implementations exposed to the agent (thin wrappers around repo actions).
      * [src/artisan/tools/get.py](./src/artisan/tools/get.py): Download mechanism.
      * [src/artisan/tools/format.py](./src/artisan/tools/format.py): Format tool

* [artisanbench](./artisanbench): Artisan-bench implementation.
  * [artisanbench/metadata.json](./artisanbench/metadata.json): Metadata about the benchmark.
  * [artisanbench/benchmark.py](./artisanbench/benchmark.py): Entrypoint for the artisanbench
  * [artisanbench/select_papers.py](./artisanbench/select_papers.py): Paper selection process
  * [artisanbench/select_tables.py](./artisanbench/select_tables.py): Task selection process
  * [artisanbench/test_speedometer.py](./artisanbench/test_speedometer.py): Method judge evaluation (RQ4)
  * [artisanbench/agents](./artisanbench/agents): Scaffold for agents (SWE-Agent, OpenHands, mini-swe-agent, Artisan) used in the benchmark
  * [artisanbench/prompts](./artisanbench/prompts): Config templates for Scaffold for agents (SWE-Agent, OpenHands, mini-swe-agent, Artisan) used in the benchmark
  * [artisanbench/scripts](./artisanbench/scripts): Groudn truth scripts.
  * [artisanbench/copy_scripts](./artisanbench/copy_scripts): Copied results scripts and the trajectories for RQ4.
  * [artisanbench/tables](./artisanbench/tables): Tables used as artisanbench tasks.
    * [artisanbench/tables/inconsistencies](./artisanbench/tables/inconsistencies): Tables with paper-artifact inconsistencies corrected.
    * [artisanbench/tables/partial](./artisanbench/tables/partial): Tables that were partially used for the benchmarks.
    * [artisanbench/tables/obfuscated](./artisanbench/tables/obfuscated): Tables that are manually obfuscated.
  * [artisanbench/papers](./artisanbench/papers): PDF files of the research papers.
  * [artisanbench/report](./artisanbench/report): Scripts for reporting paper-artifact inconsistencies.
