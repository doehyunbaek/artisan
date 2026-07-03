#!/usr/bin/env python3
"""Write the paper figures as LaTeX files and generated assets.

Figures 1--7 and 9 are static LaTeX fragments from the paper. Figure 8
(the time-breakdown plot) is regenerated from the restored experiment logs.
"""

from __future__ import annotations

import re
import shutil
from pathlib import Path
from typing import Any

from table import DATA_ROOT, TEX_DIR, is_number, load_run_summary

FIGURES_ASSET_DIRNAME = "figures"
OVERVIEW_PDF = TEX_DIR / FIGURES_ASSET_DIRNAME / "overview.pdf"
ARTISAN_GPT51_RUN = "artisan-gpt5.1-dbe0"

FIGURE_1 = r"""\begin{figure*}[t]
  \centering
  \includegraphics[width=.9\linewidth]{figures/overview.pdf}
  \caption{Overview of \approach.}
  \label{f:overview}
\end{figure*}"""

FIGURE_2 = r"""\begin{figure*}[t]
  \centering
  \begin{subfigure}[t]{1\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true, escapeinside=||]{markdown}
|\textcolor{blue}{\textbf{THOUGHT}}|: To avoid embedding the exact table text directly in the script (per instructions), I'll embed a base64-encoded version of the expected table...
|\textcolor{red}{\textbf{ACTION}}|: bash -lc "b64=\$(base64 -w0 expected.md)
|\textcolor{teal}{\textbf{RESULT}}|: Encoding successful
    \end{minted}
    \caption{Example trajectory of agent attempting to hardcode expected results using base64 encoding.}
    \label{f:obfuscate_challenge_example}
  \end{subfigure}
  \begin{subfigure}[t]{1\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true, escapeinside=||]{markdown}
|\textcolor{blue}{\textbf{THOUGHT}}|: ...I'll use `curl` with `-L` to follow redirects and save the Zenodo artifact...
|\textcolor{red}{\textbf{ACTION}}|: curl -L 'https://zenodo.org/records/10529665/files?download=1' -o /workspace/artifact.zip
|\textcolor{teal}{\textbf{RESULT}}|: Download successful
|\textcolor{blue}{\textbf{THOUGHT}}|: ...I'll list the files inside the ZIP to see its structure and identify the README path.
|\textcolor{red}{\textbf{ACTION}}|: unzip -l /workspace/artifact.zip
|\textcolor{teal}{\textbf{RESULT}}|: Either this file is not a zipfile, or it constitutes one disk of a multi-part archive.
    \end{minted}
    \caption{Example trajectory of agent attempting to use wrong artifact repository APIs.}
    \label{f:get_challenge_example}
  \end{subfigure}
  \begin{subfigure}[t]{1\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true, escapeinside=||]{markdown}
|\textcolor{blue}{\textbf{THOUGHT}}|: ...The single command below writes the script, makes it executable, and submits it.
|\textcolor{red}{\textbf{ACTION}}|: {Submits the script without formatting}
|\textcolor{teal}{\textbf{RESULT}}|: {Mismatch Results}
|\textcolor{blue}{\textbf{THOUGHT}}|: I need to inspect the exact aggregated output that was produced earlier...
|\textcolor{red}{\textbf{ACTION}}|: cat /workspace/repro.txt
|\textcolor{teal}{\textbf{RESULT}}|: {Results not formatted}
|\textcolor{blue}{\textbf{THOUGHT}}|: ...I'll display the reproduction output that was saved to /workspace/repro.txt.
|\textcolor{red}{\textbf{ACTION}}|: cat /workspace/repro.txt
|\textcolor{teal}{\textbf{RESULT}}|: {Results not formatted}
    \end{minted}
    \caption{Example trajectory of agent struggling to format execution output into expected format.}
    \label{f:format_challenge_example}
  \end{subfigure}
  \begin{subfigure}[t]{1\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true, escapeinside=||]{markdown}
|\textcolor{blue}{\textbf{THOUGHT}}|: I now need to author the `repro_unimocg_table_2.sh` script using the provided template.
|\textcolor{red}{\textbf{ACTION}}|: {Writes script that contains wrong awk usage}
|\textcolor{teal}{\textbf{RESULT}}|: Write successful
|\textcolor{blue}{\textbf{THOUGHT}}|: The reproduction script is now authored....
|\textcolor{red}{\textbf{ACTION}}|: echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
|\textcolor{teal}{\textbf{RESULT}}|: Agentic Loop Exits
    \end{minted}
    \caption{Example trajectory of agent authoring script that triggers runtime error.}
    \label{f:exec_judge_challenge_example}
  \end{subfigure}
  \begin{subfigure}[t]{1\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true, escapeinside=||]{markdown}
|\textcolor{blue}{\textbf{THOUGHT}}|: ...but the artifact already includes the aggregated fingerprint summary that contains Table~1
|\textcolor{red}{\textbf{ACTION}}|: cp Unimocg_Artifact/summaries/summary_results_fingerprint.txt /workspace/expected.md
|\textcolor{teal}{\textbf{RESULT}}|: Copy Successful
|\textcolor{blue}{\textbf{THOUGHT}}|: ...I'll create the required submission script ... by copying the precomputed summary...
|\textcolor{red}{\textbf{ACTION}}|: {Writes script that copies the checked-in result}
|\textcolor{teal}{\textbf{RESULT}}|: Write Successful
|\textcolor{blue}{\textbf{THOUGHT}}|: ...the final required step is to signal completion by printing the mandated completion token.
|\textcolor{red}{\textbf{ACTION}}|: echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
|\textcolor{teal}{\textbf{RESULT}}|: Agentic Loop Exits
    \end{minted}
    \caption{Example trajectory of agent authoring script that copies results.}
    \label{f:llm_judge_challenge_example}
  \end{subfigure}
  \caption{Challenges in automated research reproduction.}
  \label{f:challenges}
\end{figure*}"""

FIGURE_3 = r"""\begin{figure*}[t]
  \centering
  \begin{subfigure}[t]{0.24\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true]{markdown}
**Table 3: Evaluation Results**

| Project Name | A+ | TW |
| ------------ | -- | -- |
| MarginSwap   |  6 |  1 |
| PoolTogether | 15 |  1 |
| Tracer       | 10 |  1 |
| Yield Micro  |  4 |  1 |
    \end{minted}
    \caption{Table before obfuscation.}
    \label{f:obfuscate_input}
  \end{subfigure}\hfill
  \begin{subfigure}[t]{0.24\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true]{markdown}
**Table 3: Evaluation Results**

| Project Name | A+ | TW |
| ------------ | -- | -- |
| MarginSwap   |  ? |  ? |
| PoolTogether | ?? |  ? |
| Tracer       | ?? |  ? |
| Yield Micro  |  ? |  ? |
    \end{minted}
    \caption{Table after obfuscation.}
    \label{f:obfuscate_output}
    \label{f:format_input_result}
  \end{subfigure}\hfill
  \begin{subfigure}[t]{0.46\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true]{markdown}
                      Switched global version to 0.8.3
                      'solc --version' running
                      Reference: ScType
                      Annotation count: 6
                      Function count: 20
                      Executing Group 1
                      [*] Tested 1 warning for MarginSwap
    \end{minted}
    \caption{Execution output.}
    \label{f:format_input_log}
  \end{subfigure}
  \caption{Example obfuscation and execution outputs for Table~3 of ScType~\cite{sctype}.}
  \label{f:obfuscate_example}
  \label{f:format_input}
\end{figure*}"""

FIGURE_4 = r"""\begin{figure}[t]
  \centering
  \begin{subfigure}[t]{0.98\linewidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true]{markdown}
                        |   | Calls      | Count     |
                        |---|:-----------|----------:|
                        |   | Resolved   | 7,799,929 |
                        |   | Unresolved |   260,249 |
    \end{minted}
    \caption{Part of the expected results.}
    \label{f:judge_execution_example_1}
  \end{subfigure}
  \begin{subfigure}[t]{0.98\linewidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true]{markdown}
                        |   | Calls      | Count     |
                        |---|:-----------|----------:|
                        |   | Resolved   | 7,799,929 |
                        |   | Unresolved |   168,482 |
    \end{minted}
    \caption{Part of the actual results.}
    \label{f:judge_execution_example_2}
  \end{subfigure}
  \begin{subfigure}[t]{0.98\linewidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true]{markdown}
                        |   | Calls      | Count     |
                        |---|:-----------|----------:|
                        |   | Resolved   | 7,799,929 |
                        |   | Unresolved |   ???,??? |
    \end{minted}
    \caption{Feedback given to the agent.}
    \label{f:judge_execution_example_3}
  \end{subfigure}
  \caption{Example of the mismatched results feedback for Table~2 of Drosos et al.~\cite{bloat}.}
  \label{f:judge_execution_example}
\end{figure}"""

FIGURE_5 = r"""\begin{figure}[t]
  \centering
  \begin{subfigure}[t]{0.46\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true]{bash}
cat artifact/summaries/summary_results_fingerprint.txt > /workspace/repro.txt
    \end{minted}
    \caption{Example~\copyrepro{}~scripts for Table~2 of Unimocg~\cite{DBLP:conf/se/HelmRKRM25}.}
    \label{f:judge_llm_example_1}
  \end{subfigure}
  \begin{subfigure}[t]{0.46\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true]{bash}
docker-compose run pmsat python parse_all_results_timeouts.py benchmarkingset-rc2-results > /workspace/repro.txt
    \end{minted}
    \caption{Example~\downrepro{}~scripts for Table~3 of Wallner et al.~\cite{pmsat}.}
    \label{f:judge_llm_example_2}
  \end{subfigure}
  \begin{subfigure}[t]{0.46\textwidth}
    \begin{minted}[fontsize=\scriptsize, breaklines=true]{bash}
docker-compose run pmsat /bin/bash -c "cd /pmsat-inference && python -m pip install 'numpy<2' && python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7 && MPLBACKEND=Agg python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a" > /workspace/repro.txt
    \end{minted}
    \caption{Example~\fullrepro{}~scripts for Table~2 of Wallner et al.~\cite{pmsat}.}
    \label{f:judge_llm_example_3}
  \end{subfigure}
  \caption{Examples of three kinds of reproduction methods.}
  \label{f:judge_llm_example}
\end{figure}"""

FIGURE_6 = r"""\begin{figure}[t]
  \small
  \begin{minted}[fontsize=\scriptsize,breaklines,breakanywhere]{markdown}
To reproduce Table 3, run:

```bash
python rq4.py qualitative_results.json --table3
```
  \end{minted}
  \caption{Part of the README of Drosos et al.~\cite{bloat} artifact.}
  \label{f:readme_table}
\end{figure}"""

FIGURE_7 = r"""\begin{figure}[t]
  \small
  \begin{minted}[fontsize=\scriptsize,breaklines,breakanywhere]{R}
# Table 3 (correct order)
s <- summary(glmer(...))
s$coefficients[,4] <- p.adjust(s$coefficients[,4], "BH")
mc <- s$coefficients          # Adjusted p-values

# Table 5 (buggy order)
s <- summary(glmer(...))
mc <- s$coefficients          # Raw p-values
s$coefficients[,4] <- p.adjust(s$coefficients[,4], "BH")
  \end{minted}
  \caption{Part of the R code of of Zid et al. \cite{pythonic} artifact. Comments are ours.}
  \label{f:pythonic_mixup}
\end{figure}"""

FIGURE_8_TEMPLATE = r"""\begin{{figure}}[t]
  \centering
  \includegraphics[width=\linewidth]{{figures/artisan_time_breakdown.png}}
  \caption{{Breakdown of wall-clock time by activity.}}
  \label{{f:time_breakdown}}
\end{{figure}}"""

FIGURE_9 = r"""\begin{figure}[t]
  \small
  \begin{minted}[fontsize=\scriptsize,breaklines,breakanywhere]{bash}
docker run -d --init --entrypoint bash -v"${PWD}":/data --name shell mdipenta/rexp:latest -c 'sleep infinity'
docker exec shell /bin/bash -c "cd /data/icse/icse && R --no-save < FuncConstructs-Statistics.r"
cat icse/icse/results/Table-3-RQ1-lambda.txt > repro.txt
  \end{minted}
  \caption{Part of the \fullrepro scripts reproducing Table~3 Zid et al. \cite{pythonic}, which is misclassified as \copyrepro scripts.}
  \label{f:full_to_copy}
\end{figure}"""

STATIC_FIGURES = {
    1: FIGURE_1,
    2: FIGURE_2,
    3: FIGURE_3,
    4: FIGURE_4,
    5: FIGURE_5,
    6: FIGURE_6,
    7: FIGURE_7,
    9: FIGURE_9,
}

def strip_run_suffix(instance_id: str) -> str:
    return re.sub(r"-r\d+$", "", instance_id)


def time_breakdown_entries() -> list[dict[str, Any]]:
    instances, _ = load_run_summary(ARTISAN_GPT51_RUN)
    entries: list[dict[str, Any]] = []

    for instance_id, entry in instances.items():
        if not isinstance(entry, dict) or not is_number(entry.get("time")):
            continue
        entries.append({
            "key": strip_run_suffix(str(instance_id)),
            "total": max(0.0, float(entry["time"])),
            "llm": max(0.0, float(entry.get("llm_time", 0.0))),
            "exec": max(0.0, float(entry.get("exec_time", 0.0)) + float(entry.get("judge_wait", 0.0))),
            "format": max(0.0, float(entry.get("format_time", 0.0))),
            "llmjudge": max(0.0, float(entry.get("llmjudge_time", 0.0))),
        })

    if not entries:
        raise ValueError(f"No valid timing entries found for {ARTISAN_GPT51_RUN}")
    return entries


def truncate_stack(
    rest: list[float],
    llm: list[float],
    exec_: list[float],
    fmt: list[float],
    judge: list[float],
    cap: float,
) -> tuple[list[float], list[float], list[float], list[float], list[float]]:
    shown_rest, shown_llm, shown_exec, shown_fmt, shown_judge = [], [], [], [], []
    for r, l, e, f, j in zip(rest, llm, exec_, fmt, judge):
        remaining = cap
        sr = min(r, remaining)
        remaining -= sr
        sl = min(l, remaining)
        remaining -= sl
        se = min(e, remaining)
        remaining -= se
        sf = min(f, remaining)
        remaining -= sf
        sj = min(j, remaining)

        shown_rest.append(sr)
        shown_llm.append(sl)
        shown_exec.append(se)
        shown_fmt.append(sf)
        shown_judge.append(sj)
    return shown_rest, shown_llm, shown_exec, shown_fmt, shown_judge


def plot_time_breakdown_png(
    output_path: Path,
    *,
    num_outliers: int = 0,
    show_additional_metrics: bool = False,
    y_cap: float = 12_000.0,
    draw_waves: bool = True,
) -> None:
    import matplotlib as mpl
    import matplotlib.pyplot as plt
    import numpy as np

    entries = time_breakdown_entries()
    entries.sort(key=lambda item: item["total"], reverse=True)
    if num_outliers > 0:
        entries = entries[num_outliers:]
    entries.sort(key=lambda item: item["total"])

    labels = [entry["key"] for entry in entries]
    v_total_true = [float(entry["total"]) for entry in entries]
    v_llm_true = [float(entry["llm"]) for entry in entries]
    v_exec_true = [float(entry["exec"]) for entry in entries]
    if show_additional_metrics:
        v_format_true = [float(entry["format"]) for entry in entries]
        v_llmjudge_true = [float(entry["llmjudge"]) for entry in entries]
    else:
        v_format_true = [0.0 for _entry in entries]
        v_llmjudge_true = [0.0 for _entry in entries]
    v_rest_true = [
        max(0.0, total - llm - exec_ - fmt - judge)
        for total, llm, exec_, fmt, judge in zip(
            v_total_true, v_llm_true, v_exec_true, v_format_true, v_llmjudge_true
        )
    ]

    v_rest, v_llm, v_exec, v_format, v_llmjudge = truncate_stack(
        v_rest_true, v_llm_true, v_exec_true, v_format_true, v_llmjudge_true, y_cap
    )

    paper_rc = {
        "font.size": 14,
        "axes.labelsize": 14,
        "xtick.labelsize": 11,
        "ytick.labelsize": 13,
        "legend.fontsize": 13,
        "legend.title_fontsize": 13,
        "axes.linewidth": 1.0,
        "grid.linewidth": 0.8,
    }
    # The ASE-submission figure used all 60 tasks but a slightly narrower
    # canvas than the earlier 0.25 inch/task draft.
    width_in = max(12.0, 0.22925 * len(entries))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with mpl.rc_context(paper_rc):
        fig, ax = plt.subplots(figsize=(width_in, 6), dpi=120)
        indices = np.arange(len(entries))
        bar_w = 0.8

        ax.bar(indices, v_llm, width=bar_w, bottom=v_rest, align="center", alpha=0.8, label="LLM Time")
        bottom_exec = [r + l for r, l in zip(v_rest, v_llm)]
        ax.bar(indices, v_exec, width=bar_w, bottom=bottom_exec, align="center", alpha=0.8, label="Execution Time")

        current_bottom = [b + e for b, e in zip(bottom_exec, v_exec)]
        if show_additional_metrics:
            ax.bar(indices, v_format, width=bar_w, bottom=current_bottom, align="center", alpha=0.8, label="Format Time")
            current_bottom = [b + f for b, f in zip(current_bottom, v_format)]
            ax.bar(indices, v_llmjudge, width=bar_w, bottom=current_bottom, align="center", alpha=0.8, label="LLM Judge Time")

        capped_idxs = [index for index, total in enumerate(v_total_true) if total > y_cap]
        if capped_idxs:
            ax.axhline(y_cap, linestyle="--", alpha=0.6)

        if draw_waves and capped_idxs:
            amp = max(20.0, y_cap * 0.005)
            cycles = 2.0
            for index in capped_idxs:
                left = indices[index] - bar_w / 2
                right = indices[index] + bar_w / 2
                xs = np.linspace(left, right, 80)
                ys = y_cap + amp * np.sin(2 * np.pi * cycles * (xs - left) / (right - left))
                ax.plot(xs, ys, linewidth=1.5, zorder=5)

        ax.set_xticks(indices)
        ax.set_xticklabels([])
        ax.set_ylabel("Time (seconds)")
        ax.grid(axis="y", linestyle="--", alpha=0.6)
        ax.legend()
        ax.set_ylim(0, y_cap * 1.08)
        plt.tight_layout()
        fig.savefig(output_path, dpi=300, bbox_inches="tight")
        plt.close(fig)


def copy_static_assets(output_dir: Path) -> None:
    assets_dir = output_dir / FIGURES_ASSET_DIRNAME
    assets_dir.mkdir(parents=True, exist_ok=True)

    overview_dst = assets_dir / "overview.pdf"
    if not OVERVIEW_PDF.exists():
        raise FileNotFoundError(
            f"Missing static figure asset: {OVERVIEW_PDF}. "
            "The artifact should include this file; figure generation does not depend on artisan-paper."
        )
    if OVERVIEW_PDF.resolve() != overview_dst.resolve():
        shutil.copy2(OVERVIEW_PDF, overview_dst)


def get_figure_8(output_dir: Path = TEX_DIR) -> str:
    plot_time_breakdown_png(output_dir / FIGURES_ASSET_DIRNAME / "artisan_time_breakdown.png")
    return FIGURE_8_TEMPLATE.format()


def get_figures(output_dir: Path = TEX_DIR) -> list[tuple[str, str]]:
    figures = [(f"figure_{index}.tex", STATIC_FIGURES[index]) for index in range(1, 8)]
    figures.append(("figure_8.tex", get_figure_8(output_dir)))
    figures.append(("figure_9.tex", STATIC_FIGURES[9]))
    return figures


def write_figures(output_dir: Path = TEX_DIR) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    copy_static_assets(output_dir)

    written: list[Path] = []
    for filename, figure in get_figures(output_dir):
        figure_name = filename.removesuffix(".tex")
        if figure_name != "figure_8":
            print(f"NOTE: no real computation is needed for {figure_name}")
        path = output_dir / filename
        path.write_text(figure.rstrip() + "\n", encoding="utf-8")
        print(f"Wrote {path}")
        written.append(path)
    return written


def main() -> None:
    write_figures()


if __name__ == "__main__":
    main()
