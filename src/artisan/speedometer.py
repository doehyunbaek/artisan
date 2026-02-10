"""
LLM-powered speedometer for research reproduction scripts.

This module analyzes a bash script to estimate the "speed" of the reproduction
process (copy, fast, or slow) and identifies potential heavy files to exclude.

Notes:
- Uses the Python OpenAI client at import time.
- Network calls require `OPENAI_API_KEY` in the environment.
"""

from __future__ import annotations

import re
import argparse
from typing import Any, Literal
import json
import logging
import time
from pathlib import Path
import uuid
import concurrent.futures
from openai import OpenAI
from pydantic import BaseModel, Field

from minisweagent.agents.default import DefaultAgent, AgentConfig, FormatError
from minisweagent.models.litellm_model import LitellmModel
from minisweagent.environments.docker import DockerEnvironment

import artisan
from artisan import util

logger = logging.getLogger(__name__)

REASON_SUBMIT_VALIDATION = "submit_validation"
REASON_EXIT_VALIDATION = "exit_validation"
REASON_FINAL_VALIDATION = "final_validation"

SPEEDOMTER_COPY = "copy"
SPEEDOMETER_LASTMILE = "lastmile"
SPEEDOMETER_FULL = "full"

SYSTEM_INSTRUCTIONS = """
You are an expert research engineer specializing in reproducing scientific papers.
Analyze the provided Bash script to estimate the completeness of the reproduction process.

CLASSIFICATION RULES:
- "copy": The script just copies the results without actually reproducing. Examples:
    - The result is hard-coded without any process to generate it.
    - The result is copied from checked-in files as-is. NOTE: commands like `cp`.
- "lastmile": The script performs lightweight reproduction and skips heavy computations. Examples:
    - The result is generated using baked-in raw data.
    - The script performs statistical analysis on precomputed outputs.
- "full": The script performs complete reproduction. Examples:
    - Raw data is generated from scratch from the input dataset.
    - NOTE: Even if the script downloads artifact from repositories like Zenodo, FigShare, GitHub Releases, etc., if it performs the full computation to generate the final results, classify as "full".
    - NOTE: Even if the script uses Docker images or prebuilt environments, if it performs the full computation to generate the final results, classify as "full".

IMPORTANT POINTS:
- The script should be classified with a fastest path it can possibly take. If a script contains both "copy" and "lastmile" reproduction, you should classify it as "copy"

FILES TO EXCLUDE:
Identify file paths or names referenced in the script (e.g., in `wget`, `curl`, `tar`, `python` args) that are checked-in results or raw data and should be excluded to make reproduction more complete. Look for extensions like .pth, .ckpt, .bin, .tar.gz, .zip, .h5.
- NOTE: FILES TO EXCLUDE should be output only when speed is classified as "copy" or "lastmile". If these files are excluded the script should be more likely to be judged as "full".

OUTPUT FORMAT:
Return ONLY a valid JSON object. No markdown formatting, no code fences.
{
    "speed": "copy" | "lastmile" | "full",
    "reason": "A concise justification for the classification.",
    "files_to_exclude": ["list", "of", "filenames", "or", "paths"]
}
"""


class SpeedometerOutput(BaseModel):
    speed: str
    reason: str
    files_to_exclude: list[str] = Field(default_factory=list)


FEW_SHOT_EXAMPLES: list[dict[str, Any]] = [
    {
        "name": "hypertesting_t1",
        "script": """#!/usr/bin/bash
    artisan get https://zenodo.org/records/10451088
    (
      printf \"### Table 1: Correlation results\\n\\n| Sample (UnsecureOnlyDataset) | R | p-value |\\n| :--- | :--- | :--- |\\n\"
      tar -xOf ReplicationPackage/submission-results.tar.xz RQ1/hypercoveragetester_28-07-2023_135630/hypercoveragetester-metrics.json \
      | sed -n '/\"csvTable\": [/,/]/p' \
      | sed -E 's/^([^;]+);([^;]+);([^;]+)$/| \\1 | \\2 | \\3 |/'
    ) > /workspace/repro.txt
    artisan format --expected /workspace/expected.md --repro /workspace/repro.txt""",
        "output": {
            "speed": "copy",
            "reason": "Streams the ready-made RQ1 CSV rows out of submission-results.tar.xz instead of rerunning HyperTesting.",
            "files_to_exclude": [
                "ReplicationPackage/submission-results.tar.xz",
                "RQ1/hypercoveragetester_28-07-2023_135630/hypercoveragetester-metrics.json",
            ],
        },
    },
    {
        "name": "baro_t2",
        "script": """#!/usr/bin/bash
    artisan get https://zenodo.org/records/11094092
    cat > /workspace/repro.txt <<'EOREPRO'
    Method: N-Sigma
    Dataset: Online Boutique
    Precision: 0.54
    Recall   : 1
    F1       : 0.70

    Method: BARO (Ours)
    Dataset: Online Boutique
    Precision: 0.69
    Recall   : 1
    F1       : 0.82
    EOREPRO
    artisan format --expected /workspace/expected.md --repro /workspace/repro.txt""",
        "output": {
            "speed": "copy",
            "reason": "Hard-codes every BARO metric via heredoc instead of running any detectors.",
            "files_to_exclude": [],
        },
    },
    {
        "name": "sja_t1",
        "script": """#!/usr/bin/bash
    artisan get https://zenodo.org/records/12670597
    python3 - << 'PY' > /workspace/repro.txt
    import math
    gt = 662208
    fns = {\"sja\":1451, \"dyninst\":60463}
    fps = {\"sja\":17347, \"dyninst\":3143}
    def prec(fp, gt): return 100.0/(1.0 + (fp/gt))
    def rec(fn, gt):  return 100.0/(1.0 + (fn/gt))
    def f1(p, r): return 0.0 if (p+r)==0 else 2.0*p*r/(p+r)
    print(f\"| **Precision** | {prec(fps['dyninst'], gt):.1f} | {prec(fps['sja'], gt):.1f} |\")
    print(f\"| **Recall** | {rec(fns['dyninst'], gt):.1f} | {rec(fns['sja'], gt):.1f} |\")
    print(f\"| **F?-score** | {f1(prec(fps['dyninst'], gt), rec(fns['dyninst'], gt)):.1f} | {f1(prec(fps['sja'], gt), rec(fns['sja'], gt)):.1f} |\")
    PY
    artisan format --expected /workspace/expected.md --repro /workspace/repro.txt""",
        "output": {
            "speed": "copy",
            "reason": "Computes percentages from hard-coded FP/FN counts, so no binaries or datasets ever run.",
            "files_to_exclude": [],
        },
    },
]


def _build_few_shot_section(examples: list[dict[str, Any]] | None) -> str:
    if not examples:
        return ""
    parts = [
        "You will see reference speedometer examples (script -> JSON output). Use them for calibration before evaluating the new script.\n"
    ]
    for ex in examples:
        rendered_output = json.dumps(ex["output"], ensure_ascii=True, indent=2)
        parts.append(
            f'<example name="{ex["name"]}">\n'
            f"[script]\n{ex['script'].strip()}\n"
            f"[output]\n{rendered_output}\n"
            f"</example>\n"
        )
    return "\n".join(parts).strip()


class DefaultAgentWithLogs(DefaultAgent):
    def add_message(self, role, content, **kwargs):
        logger.debug(f"role: {role}, content:\n{content}")
        super().add_message(role, content, **kwargs)

    def parse_action(self, response: dict) -> dict:
        """Parse the action from the message. Returns the action."""
        actions = re.findall(r"<mini_swe_agent_bash>\n(.*?)\n</mini_swe_agent_bash>", response["content"], re.DOTALL)
        if len(actions) == 1:
            return {"action": actions[0].strip(), **response}
        raise FormatError(self.render_template(self.config.format_error_template, actions=actions))


def analyze_script(script_content: str, log_path: Path | None = None) -> dict[str, Any]:
    """
    Analyze the bash script content using the LLM to determine speed and exclusions.
    """
    mdl = artisan.SPEEDOMETER_MODEL
    key = artisan.OPENAI_API_KEY
    client = OpenAI(api_key=key)

    few_shot_section = _build_few_shot_section(FEW_SHOT_EXAMPLES)
    task_block = f"<task>\n[script]\n{script_content.strip()}\n</task>\nReturn only the JSON object described above."
    user_prompt = f"{few_shot_section}\n\n{task_block}" if few_shot_section else task_block

    prompt_messages: list[dict[str, str]] = [
        {"role": "system", "content": SYSTEM_INSTRUCTIONS},
        {"role": "user", "content": user_prompt},
    ]

    start_ts = time.time()
    resp = client.responses.parse(
        model=mdl,
        input=prompt_messages,
        text_format=SpeedometerOutput,
    )
    duration_s = time.time() - start_ts

    parsed: SpeedometerOutput = resp.output_parsed
    result_json = parsed.model_dump()

    usage = getattr(resp, "usage", None)
    input_tokens = getattr(usage, "input_tokens", None)
    output_tokens = getattr(usage, "output_tokens", None)
    input_details = getattr(usage, "input_tokens_details", None)
    cached_tokens = getattr(input_details, "cached_tokens", None)
    cost = util._estimate_cost_usd(mdl, input_tokens, output_tokens, cached_tokens)
    result = {
        **result_json,
        "time": duration_s,
        "cost": cost,
    }
    util._log_invocation_to_file(
        model=mdl,
        input=prompt_messages,
        output=result_json,
        duration_s=duration_s,
        usage=usage,
        log_path=log_path or artisan.SPEEDOMETER_LOG_PATH,
        reason=None,
    )

    return result


def analyze_script_agentic(script_content: str, script_path: Path) -> dict[str, Any]:
    """
    Analyze the bash script content using an agent to determine speed and exclusions.
    """
    mdl = artisan.SPEEDOMETER_MODEL
    model = LitellmModel(model_name=mdl)

    # Setup workspace mount
    ws_path = script_path.resolve().parent
    workspace_mount_spec = f"{ws_path}:/workspace:rw"

    env = DockerEnvironment(
        image=artisan.BASE_IMAGE,
        pull_timeout=3000,
        container_name=f"speedometer-{uuid.uuid4().hex[:4]}",
        run_args=["-v", workspace_mount_spec],
        cwd="/workspace",
    )

    system_template = f"""You are a helpful assistant that can interact with a computer.

    Your response must contain exactly ONE bash code block with ONE command (or commands connected with && or ||).
    Include a THOUGHT section before your command where you explain your reasoning process.
    Format your response as shown in <format_example>.

    <format_example>
    THOUGHT: Your reasoning and analysis here. Explain why you want to perform the action.

    <mini_swe_agent_bash>
    your_command_here
    </mini_swe_agent_bash>
    </format_example>

    Failure to follow these rules will cause your response to be rejected.

{SYSTEM_INSTRUCTIONS}

You have access to a bash shell to explore the files if needed.
You can use commands like `ls`, `cat`, `grep` to inspect the files referenced in the script.
Do not run the reproduction script itself, as it might be heavy. Just analyze it.

To submit your answer, you must run a command that writes the JSON output to `/workspace/speedometer_result.json` and then outputs:
COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
"""

    few_shot_section = _build_few_shot_section(FEW_SHOT_EXAMPLES)
    instance_template = f"""
{{% raw %}}
{few_shot_section}
{{% endraw %}}

<task>
Analyze the following reproduction script:
[script]
{{% raw %}}
{script_content}
{{% endraw %}}
[/script]

The script is located at {script_path.name} in the current directory.
</task>
"""

    config = AgentConfig(system_template=system_template, instance_template=instance_template, cost_limit=0.1)

    agent = DefaultAgentWithLogs(model=model, env=env, config_class=lambda **kwargs: config)

    start_ts = time.time()
    executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
    future = executor.submit(agent.run, "")
    try:
        exit_status, result = future.result(timeout=60)
    except concurrent.futures.TimeoutError:
        exit_status = "Timeout"
        result = "Agent execution timed out."
    finally:
        executor.shutdown(wait=False)

    duration_s = time.time() - start_ts
    # print(f"After running: took {duration_s}")

    # Read result from file
    result_file = ws_path / "speedometer_result.json"
    if result_file.exists():
        result_json = json.loads(result_file.read_text())
        result_file.unlink()
    else:
        # Fallback to parsing result string if file not found
        try:
            result_json = json.loads(result)
        except json.JSONDecodeError:
            raise json.JSONDecodeError

    # Calculate cost
    cost = model.cost
    return {
        **result_json,
        "time": duration_s,
        "cost": cost,
    }


def cmd_speedometer(script_path: Path, out_path: Path | None = None, agentic: bool = False) -> int:
    """CLI entrypoint for the speedometer."""
    script_text = Path(script_path).read_text(encoding="utf-8")

    if agentic:
        result = analyze_script_agentic(script_text, script_path)
    else:
        result = analyze_script(script_text)

    # Dump to JSON string
    output_str = json.dumps(result, indent=2)

    if out_path:
        Path(out_path).write_text(output_str, encoding="utf-8")
    else:
        print(output_str)

    return 0


def _speedometer_from_cli(args: argparse.Namespace) -> int:
    """Adapter for argparse."""
    return cmd_speedometer(args.script, args.out, args.agentic)


def register_subparser(subparsers: argparse._SubParsersAction) -> None:
    """Register the `artisan speedometer` subparser."""
    parser = subparsers.add_parser(
        "speedometer", help="Analyze a reproduction script to estimate speed and identify heavy files."
    )
    parser.add_argument("script", type=Path, help="Path to the bash reproduction script (e.g. run.sh)")
    parser.add_argument("--out", type=Path, help="Optional path to write the JSON output; defaults to stdout")
    parser.add_argument("--agentic", action="store_true", help="Use agentic mode with minisweagent")
    parser.set_defaults(func=_speedometer_from_cli)
