"""
LLM-powered formatter for reproduced results → expected table shape.

This module exposes helpers to transform a raw reproduction (logs, tables,
CSV-like output) into a GitHub-flavored Markdown table that matches a given
expected-table template by delegating the transformation to an OpenAI model.

Notes:
- Uses the Python OpenAI client at import time.
- Network calls require `OPENAI_API_KEY` in the environment. The default model
  can be overridden via `OPENAI_FORMAT_MODEL`.
"""

# TODO: handle <0.01. See pythonic_table_3.md, action_table_1.md

from __future__ import annotations

import argparse
from typing import Optional, Sequence, Any
from dataclasses import dataclass
import json
import os
import re
import socket
import time
from pathlib import Path
import httpx
from openai import OpenAI

import artisan
from artisan import util

SIMPLE_TABLE = """
Intro line
| A | B |
| --- | --- |
| 12 | 34 |
""".lstrip()

OBF_SIMPLE_TABLE = """
Intro line
| A | B |
| --- | --- |
| ?? | ?? |
""".lstrip()

MIXED_TABLE = """
Some intro line 123 stays (not a table row)
| Col1 | Col2 | Col3 |
| --- | --- | --- |
| 123.45 | 67 | text |
| 0.001 | 999 | more |
""".lstrip()

OBF_MIXED_TABLE = """
Some intro line 123 stays (not a table row)
| Col1 | Col2 | Col3 |
| --- | --- | --- |
| ???.?? | ?? | text |
| ?.??? | ??? | more |
""".lstrip()

EXAMPLES: dict[str, dict[str, Any]] = {
    "simple": {
        "reproduction": """
Metrics Report
---
A = 12
B = 34
""".lstrip(),
        "expected_table": OBF_SIMPLE_TABLE,
        "output": SIMPLE_TABLE,
    },
    "mixed": {
        "reproduction": """
Run results for 'text' category:
  - Col1 value: 123.45
  - Col2 value: 67

Run results for 'more' category:
  - Col1 value: 0.001
  - Col2 value: 999
""".lstrip(),
        "expected_table": OBF_MIXED_TABLE,
        "output": MIXED_TABLE,
    },
    "less_than_thresholds": {
        "reproduction": """
Experiment summary
------------------
Strategy Alpha:
  - affected cases: 0.0% of all runs
  - time saved: 0.0% of total time

Strategy Beta:
  - affected cases: 3.4% of all runs
  - time saved: 0.03% of total time
""".lstrip(),
        "expected_table": """
| Strategy | Affected runs | Time saved |
| -------- | ------------: | ---------: |
| Alpha    |        <?.?%  |   <0.0?%  |
| Beta     |        ?.?%   |    0.0?%  |
""".lstrip(),
        "output": """
| Strategy | Affected runs | Time saved |
| -------- | ------------: | ---------: |
| Alpha    |        <0.1%  |   <0.01%  |
| Beta     |         3.4%  |    0.03%  |
""".lstrip(),
    },
}


# Master system instructions for the formatter model. Kept global so tests
# can introspect and we avoid accidental drift between copies.
SYSTEM_INSTRUCTIONS = """
You format results into GitHub-flavored Markdown tables.

CRITICAL TEMPLATE RULE:
Return a table that is IDENTICAL to the provided expected table except that
every placeholder question mark (?) is replaced by exactly one decimal digit
(0-9). One ? => one digit. A pattern like "??.??" means two digits, a dot,
two digits. A pattern like "?,???,???" means digits in those exact slots with
commas preserved. Do NOT add, remove, or move pipes |, spaces, commas, dots,
percent signs %, header separators, or rows. Do NOT alter any cell that
contains no ? characters. Preserve capitalization and ordering exactly.

DATA FILLING:
Derive each replaced digit sequence from ONLY the reproduction text. Never
invent new rows or columns. If a numeric value must be rounded to fit the
number of ? placeholders, ROUND HALF AWAY FROM ZERO to the needed precision
and then emit exactly one digit per ?.

STRICT DIGIT COUNT / NO EXTRA PADDING:
- Never add extra leading zeros unless the placeholder pattern itself forces
    them (e.g. a pattern like 0? or 00? would, but a plain ??.?? must not turn
    11.5 into 011.5).
- A block of consecutive ? represents an unconstrained-length number segment
    with exactly that many digits – do NOT left-pad or right-pad with zeros to
    "help"; emit the natural digits after rounding/truncation.
- Do not fabricate trailing zeros after decimals unless a ? requires them.

THOUSANDS SEPARATORS:
Only output commas where commas already appear among the ? placeholders.
Never insert a new comma into a placeholder run that lacks one.

PERCENT SIGNS:
Retain % if and only if it exists in the expected template cell. Never add a
new % sign to a cell without one and never remove an existing %.

LESS-THAN THRESHOLDS ("<0.1", "<0.01", etc.):
- Some cells encode "smaller than display precision" using patterns like
    "<?.?%", "<0.0?%", or "<0.01". In these cells:
  - Always preserve the literal "<" exactly where it appears in the template.
  - The ? characters still represent digits to be filled.
- When the reproduction already contains a "<"-style value (e.g., "<0.1%",
    "<0.01"), copy its digits into the ? slots of the matching template cell
    so that the final text keeps the "<" and the same numeric threshold.
- When the reproduction shows a zero value (e.g., "0.0%", "0.00%") but the
    expected template uses a "<" with d decimal places (e.g., "<?.?%",
    "<0.0?"), interpret this as "less than the smallest non-zero value at that
    precision" and:
    - Emit "<0." + (d-1 zeros) + "1" (for d decimal digits).
      Examples:
      - Template "<?.?%"  (1 decimal)  -> "<0.1%"
      - Template "<0.0?%" (2 decimals) -> "<0.01%"
- You may reuse digits that already appear anywhere in the reproduction text,
    but you must NOT introduce new digit symbols that never appear in the
    reproduction at all.

OUTPUT FORMAT:
Only output the final table. No prose. No explanations. No code fences. No
surrounding text.
"""


@dataclass
class FormatResult:
    table: str
    raw_model_text: str
    cost: float = 0.0
    duration_s: float = 0.0
    cached: bool = False
    openai_request: dict[str, Any] | None = None
    openai_response: Any | None = None


def _strip_code_fences(s: str) -> str:
    s = s.strip()
    # Remove ```...``` or ```markdown ... ``` wrappers if present
    if s.startswith("```") and s.endswith("```"):
        s = s.strip("`")  # remove surrounding backticks first
        # After trimming, attempt to remove optional language marker and newlines
        s = re.sub(r"^\w*\n", "", s)
    return s.strip()


def _lookup_cached_result(prompt_messages: list[dict[str, str]], start_ts: float) -> Optional[FormatResult]:
    """Lookup a cached formatter result from the JSON log, if available.

    This matches against the full `input` field (system + user messages)
    previously recorded in artisan.FORMAT_LOG_PATH.
    """
    log_path = artisan.FORMAT_LOG_PATH
    try:
        if not log_path.exists():
            return None
        with log_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return None

    if not isinstance(data, list):
        data = [data]

    # Walk from the end so the most recent matching entry wins.
    for entry in reversed(data):
        if not isinstance(entry, dict):
            continue
        logged_input = entry.get("input")
        if logged_input != prompt_messages:
            continue
        output = entry.get("output")
        if not isinstance(output, str):
            continue
        # Print a short notice when a cached result is reused (helpful in
        # interactive debugging) and also record the cache hit in the
        # formatter invocation log so usage/caching can be audited.
        try:
            util._log_invocation_to_file(
                model="cached",
                input=prompt_messages,
                output=output,
                duration_s=time.time() - start_ts,
                usage=None,
                log_path=artisan.FORMAT_LOG_PATH,
                reason=REASON_AGENT,
            )
        except Exception:
            # Best-effort logging: failures here must not break formatting.
            pass

        return FormatResult(
            table=output.strip(),
            raw_model_text=output.strip(),
            cost=0.0,
            duration_s=time.time() - start_ts,
            cached=True,
        )

    return None


def _build_few_shot_section(
    examples: dict[str, dict[str, Any]] | None,
    *,
    multiple_variant: bool = False,
) -> str:
    """Build the few-shot section for the system prompt."""
    if not examples:
        return ""
    parts: list[str] = ["You will see example pairs of (reproduction → expected → output). Use them as guidance.\n"]
    for i, ex in enumerate(examples.values(), 1):
        raw_rep = ex["reproduction"]
        if isinstance(raw_rep, list):
            if multiple_variant:
                display_rep = "\n--- VARIANT ---\n".join(r.strip() for r in raw_rep)
            else:
                display_rep = raw_rep[0]
        else:
            display_rep = raw_rep
        parts.append(
            f"<example {i}>\n"
            f"[reproduction]\n{display_rep.strip()}\n"
            f"[expected]\n{ex['expected_table'].strip()}\n"
            f"[output]\n{ex['output'].strip()}\n"
            f"</example {i}>\n"
        )
    return "\n".join(parts)


REASON_AGENT = "agent"
REASON_SUBMIT_VALIDATION = "submit_validation"
REASON_EXIT_VALIDATION = "exit_validation"
REASON_FINAL_VALIDATION = "final_validation"


def format_reproduction(
    reproduction: str,
    expected_table: str,
) -> FormatResult:
    """
    Use an OpenAI model to transform `reproduction` into a Markdown table that
    matches the header/shape/ordering of `expected_table`.

    Returns both the final table and the raw model text (for debugging).
    """
    mdl = artisan.FORMAT_MODEL
    key = artisan.OPENAI_API_KEY
    start_ts = time.time()

    # Compose prompt using the global SYSTEM_INSTRUCTIONS (defined below)
    shots = _build_few_shot_section(EXAMPLES, multiple_variant=False)
    user_prompt = (
        f"{shots}\n"
        f"<task>\n"
        f"[reproduction]\n{reproduction.strip()}\n"
        f"[expected]\n{expected_table.strip()}\n"
        f"</task>\n"
        f"Output only the final table."
    )

    prompt_messages: list[dict[str, str]] = [
        {"role": "system", "content": SYSTEM_INSTRUCTIONS},
        {"role": "user", "content": user_prompt},
    ]

    # First, attempt to reuse a previous invocation if the same full
    # prompt (system + user messages) already exists in the log.
    cached = _lookup_cached_result(prompt_messages, start_ts)
    if cached is not None:
        return cached

    client = OpenAI(api_key=key, http_client=httpx.Client(trust_env=False))

    # Prefer the Responses API (new) if available
    request_payload = {
        "model": mdl,
        "reasoning": {"effort": "medium"},
        "input": prompt_messages,
    }

    
    resp = client.responses.create(**request_payload)
    duration_s = time.time() - start_ts

    # The library returns content as a list of items; grab text segments
    parts: list[str] = []
    for item in resp.output or []:  # type: ignore[attr-defined]
        if getattr(item, "type", None) == "message":
            for c in getattr(item, "content", []) or []:
                if getattr(c, "type", None) == "output_text":
                    parts.append(getattr(c, "text", ""))
    raw_text = "\n".join(p for p in parts if p).strip() or getattr(resp, "output_text", "").strip()

    cleaned = _strip_code_fences(raw_text)
    usage = getattr(resp, "usage", None)

    cost = 0.0
    if usage:
        input_tokens = getattr(usage, "input_tokens", 0)
        output_tokens = getattr(usage, "output_tokens", 0)
        input_details = getattr(usage, "input_tokens_details", None)
        cached_tokens = getattr(input_details, "cached_tokens", 0) if input_details else 0
        cost = util._estimate_cost_usd(mdl, input_tokens, output_tokens, cached_tokens) or 0.0

    util._log_invocation_to_file(
        model=mdl,
        input=prompt_messages,
        output=cleaned,
        duration_s=duration_s,
        usage=usage,
        log_path=artisan.FORMAT_LOG_PATH,
        reason=REASON_AGENT,
    )

    return FormatResult(
        table=cleaned,
        raw_model_text=raw_text,
        cost=cost,
        duration_s=duration_s,
        cached=False,
        openai_request=request_payload,
        openai_response=resp,
    )


def cmd_format(expected_path, repro_path, out_path=None, model_override: str | None = None) -> int:
    """CLI entrypoint for formatting (moved from cli.py)."""
    if model_override:
        import artisan as _artisan

        _artisan.FORMAT_MODEL = model_override

    expected_text = Path(expected_path).read_text(encoding="utf-8")
    repro_text = Path(repro_path).read_text(encoding="utf-8")
    # TODO: add logic of cutting down repro_text if too long
    res = format_reproduction(repro_text, expected_text)
    out = res.table
    if out_path:
        Path(out_path).write_text(out, encoding="utf-8")
    else:
        import sys as _sys

        _sys.stdout.write(out + ("\n" if not out.endswith("\n") else ""))
    return 0


def _format_from_cli(args: argparse.Namespace) -> int:
    """Adapter so argparse dispatch can call cmd_format with parsed args."""
    return cmd_format(args.expected, args.repro, args.out, getattr(args, "model", None))


def register_subparser(subparsers: argparse._SubParsersAction) -> None:
    """Register the `artisan format` subparser with the shared CLI."""
    fmt_p = subparsers.add_parser(
        "format",
        help=(
            "Format raw reproduction into the expected Markdown table using an LLM. "
            "Reads both expected and reproduction from files; stdin is not supported."
        ),
    )
    fmt_p.add_argument(
        "--expected",
        type=Path,
        required=True,
        help="Path to the expected table Markdown template (e.g., expected.md)",
    )
    fmt_p.add_argument(
        "--repro",
        type=Path,
        required=True,
        help="Path to raw reproduction text file",
    )
    fmt_p.add_argument(
        "--out",
        type=Path,
        help="Optional path to write the formatted table; defaults to stdout",
    )
    fmt_p.set_defaults(func=_format_from_cli)
