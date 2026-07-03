# Experimental logs for the paper: Artisan: Agentic Artifact Evaluation

This repository contains experimental logs for the paper, "Artisan: Agentic Artifact Evaluation".

## Repository Structure

### General files and directories

* [table.py](./table.py): Generates the paper tables. Table 2 is derived from the restored logs and applies the manual effectiveness/runtime corrections inline.
* [download_logs.py](./download_logs.py): Restores the ignored experimental run logs under `./logs`.
* [method_judge_eval.jsonl](./method_judge_eval.jsonl): Log for the method judge experiments
* [manual_analysis](./manual_analysis): Manual analysis of the reproduction methods of the success cases.

### Experimental run logs

Baseline runs:

* [sweagent-deepseek-reasoner-4bdc](./logs/sweagent-deepseek-reasoner-4bdc): SWEAgent run using `deepseek-reasoner`.
* [sweagent-gpt5mini-5d98](./logs/sweagent-gpt5mini-5d98): SWEAgent run using `GPT-5 mini`.
* [sweagent-gpt5.1-ebe4](./logs/sweagent-gpt5.1-ebe4): SWEAgent run using `GPT-5.1`.
* [openhands-deepseek-reasoner-bd34](./logs/openhands-deepseek-reasoner-bd34): Openhands run using `deepseek-reasoner`.
* [openhands-gpt5mini-a4eb](./logs/openhands-gpt5mini-a4eb): Openhands run using `GPT-5 mini`.
* [openhands-gpt5.1-41ec](./logs/openhands-gpt5.1-41ec): Openhands run using `GPT-5.1`.
* [minisweagent-deepseek-reasoner-e5a7](./logs/minisweagent-deepseek-reasoner-e5a7): mini-swe-agent run using `deepseek-reasoner`.
* [minisweagent-gpt5mini-a830](./logs/minisweagent-gpt5mini-a830): mini-swe-agent run using `GPT-5 mini`.
* [minisweagent-gpt5.1-301b](./logs/minisweagent-gpt5.1-301b): mini-swe-agent run using `GPT-5.1`.
* [artisan-deepseek-reasoner-6f4b](./logs/artisan-deepseek-reasoner-6f4b): Artisan run using `deepseek-reasoner`.
* [artisan-gpt5mini-845b](./logs/artisan-gpt5mini-845b): Artisan run using `GPT-5 mini`.
* [artisan-gpt5.1-dbe0](./logs/artisan-gpt5.1-dbe0): Artisan run using `GPT-5.1`.

Ablation runs:

* [artisan-gpt5.1-3ee0-without_output](./logs/artisan-gpt5.1-3ee0-without_output): Ablation run without the output judge.
* [artisan-gpt5.1-7a04-without_method](./logs/artisan-gpt5.1-7a04-without_method): Ablation run without the method judge.
* [artisan-gpt5.1-9223-without_format](./logs/artisan-gpt5.1-9223-without_format): Ablation run without the format tool.
