# Experimental logs for the paper: Artisan: Agentic Artifact Evaluation

This repository contains experimental logs for the paper, "Artisan: Agentic Artifact Evaluation".

## Repository Structure

### General files and directories

* [analyze_results.py](./analyze_results.py): Primary analysis entry point (loads run outputs, computes metrics, and emits summaries/plots/tables).
* [correct_effectiveness.py](./correct_effectiveness.py): Script that takes account the manual analysis of the success cases.
* [correct_time.py](./correct_time.py): Script that recovers the agent runtime from log.
* [method_judge_eval.jsonl](./method_judge_eval.jsonl): Log for the method judge experiments
* [manual_analysis](./manual_analysis): Manual analysis of the reproduction methods of the success cases.

### Experimental run logs

Baseline runs:

* [sweagent-deepseek-reasoner-4bdc](./sweagent-deepseek-reasoner-4bdc): SWEAgent run using `deepseek-reasoner`.
* [sweagent-gpt5mini-5d98](./sweagent-gpt5mini-5d98): SWEAgent run using `GPT-5 mini`.
* [sweagent-gpt5.1-ebe4](./sweagent-gpt5.1-ebe4): SWEAgent run using `GPT-5.1`.
* [openhands-deepseek-reasoner-bd34](./openhands-deepseek-reasoner-bd34): Openhands run using `deepseek-reasoner`.
* [openhands-gpt5mini-a4eb](./openhands-gpt5mini-a4eb): Openhands run using `GPT-5 mini`.
* [openhands-gpt5.1-41ec](./openhands-gpt5.1-41ec): Openhands run using `GPT-5.1`.
* [minisweagent-deepseek-reasoner-e5a7](./minisweagent-deepseek-reasoner-e5a7): mini-swe-agent run using `deepseek-reasoner`.
* [minisweagent-gpt5mini-a830](./minisweagent-gpt5mini-a830): mini-swe-agent run using `GPT-5 mini`.
* [minisweagent-gpt5.1-301b](./minisweagent-gpt5.1-301b): mini-swe-agent run using `GPT-5.1`.
* [artisan-deepseek-reasoner-6f4b](./artisan-deepseek-reasoner-6f4b): Artisan run using `deepseek-reasoner`.
* [artisan-gpt5mini-845b](./artisan-gpt5mini-845b): Artisan run using `GPT-5 mini`.
* [artisan-gpt5.1-dbe0](./artisan-gpt5.1-dbe0): Artisan run using `GPT-5.1`.

Ablation runs:

* [artisan-gpt5.1-3ee0-without_output](./artisan-gpt5.1-3ee0-without_output): Ablation run without the output judge.
* [artisan-gpt5.1-7a04-without_method](./artisan-gpt5.1-7a04-without_method): Ablation run without the method judge.
* [artisan-gpt5.1-9223-without_format](./artisan-gpt5.1-9223-without_format): Ablation run without the format tool.
