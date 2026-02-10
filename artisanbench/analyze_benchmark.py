# %%
from __future__ import annotations
import json
from collections import Counter
from pathlib import Path
from tabulate import tabulate


def _is_result_table(table_entry: dict | None) -> bool:
    if not isinstance(table_entry, dict):
        return False
    flags = ("non-result", "missing", "non-deterministic")
    return not any(table_entry.get(flag) is True for flag in flags)


def count_tables(entry: dict) -> int:
    tables = entry.get("tables", {})
    if not isinstance(tables, dict):
        return 0
    # Count tables while excluding those explicitly marked as non-result: true
    count = 0
    for _, table in tables.items():
        if _is_result_table(table):
            count += 1
    return count


def _manual_table_key_variants(entry_id: str | None, table_key: str) -> set[str]:
    normalized = str(table_key)
    variants: set[str] = {normalized}
    if normalized.startswith("table_"):
        variants.add(normalized[len("table_") :])
    else:
        variants.add(f"table_{normalized}")
    if entry_id:
        base = str(entry_id).lower()
        for variant in list(variants):
            variants.add(f"{base}_{variant}")
    return {variant.lower() for variant in variants}


def count_checked(entry: dict) -> int:
    tables = entry.get("tables", {})
    if not isinstance(tables, dict):
        return 0

    paper_id = entry.get("id")
    count = 0
    for key, value in tables.items():
        if not _is_result_table(value):
            continue
        if value.get("ground-truth-checked") is True:
            count += 1
            continue

        manual_keys = _manual_table_key_variants(paper_id, key)
        if any(candidate in _MANUAL_TABLE_LOOKUP for candidate in manual_keys):
            count += 1
    return count


flaky_script_map = {
    "action_table_5": "format tool",
    "flashsyn_table_4": "format tool",
}

partial_success_map = {
    "action_table_1.sh": 0.99,
    "action_table_3.sh": 0.96,
    "action_table_4.sh": 0.96,
    "action_table_4.sh": 0.79,
    "sctype_table_3.sh": 0.9625,
}


def count_repro_script(tid):
    this_file = Path(__file__).resolve()
    repo_root = this_file.parent.parent
    scripts_dir = repo_root / "artisanbench" / "scripts"

    auto_count = 0
    manual_count = 0
    partial_count = 0
    for p in scripts_dir.rglob("*.sh"):
        name = p.name
        prefix = name.split("_", 1)[0].lower()
        if prefix == tid:
            if name in partial_success_map and partial_success_map[name] > 0.95:
                partial_count += 1
            elif "manual" in p.parts:
                manual_count += 1
            else:
                auto_count += 1
    return auto_count, manual_count, partial_count


def _count_copy_scripts() -> int:
    this_file = Path(__file__).resolve()
    copy_dir = this_file.parent / "scripts" / "copy"
    if not copy_dir.exists():
        return 0
    return sum(1 for candidate in copy_dir.glob("*.sh") if candidate.is_file())


def analyze_topics():
    with open("benchmark.json", "r", encoding="utf-8") as f:
        data = json.loads(f.read())

    # Topic mapping to verbose labels
    topic_labels = {
        "static": "Static Analysis",
        "study": "Empirical Study",
        "security": "Security",
        "dynamic": "Dynamic Analysis",
        "fuzzing": "Fuzzing",
        "mutation": "Mutation Testing",
        "model": "Model-based Testing",
        "mobile": "Mobile Applications",
        "repair": "Program Repair",
        "testing": "Test Automation",
        "ai4se": "AI for Software Engineering",
        "maintenance": "Software Maintenance",
    }

    # Count topics
    topic_counter = Counter()

    for paper in data:
        topic = paper.get("topic", "unknown")
        topic_counter[topic] += 1

    # Create bar chart (sorted by count in descending order)
    sorted_topics = topic_counter.most_common()

    # Generate LaTeX table for topics
    print("\nLaTeX Table for Software Engineering Techniques:")
    print("=" * 50)
    table_data = []
    for topic, count in sorted_topics:
        verbose_label = topic_labels.get(topic, topic)
        table_data.append([verbose_label, count])

    # Append totals row for topics
    total_papers = sum(count for _, count in sorted_topics)
    table_data.append(["Total", total_papers])

    latex_table = tabulate(
        table_data,
        headers=["Technique", "Papers"],
        tablefmt="latex_booktabs",
        colalign=("left", "center"),
    )
    print(latex_table)


def analyze_languages():
    with open("benchmark.json", "r", encoding="utf-8") as f:
        data = json.loads(f.read())

    # Topic mapping to verbose labels
    topic_labels = {
        "python": "Python",
        "java": "Java",
        "rust": "Rust",
        "ocaml": "OCaml",
        "scala": "Scala",
        "bash": "Bash",
        "c": "C",
    }

    # Count topics
    topic_counter = Counter()

    for paper in data:
        language = paper.get("language", "unknown")
        topic_counter[language] += 1

    # Create bar chart (sorted by count in descending order)
    sorted_topics = topic_counter.most_common()
    topics = [topic_labels.get(language, language) for language, count in sorted_topics]
    counts = [count for language, count in sorted_topics]
    # Generate LaTeX table for languages
    print("\nLaTeX Table for Programming Languages:")
    print("=" * 50)
    table_data = []
    for language, count in sorted_topics:
        verbose_label = topic_labels.get(language, language)
        table_data.append([verbose_label, count])

    # Append totals row for languages
    total_papers = sum(count for _, count in sorted_topics)
    table_data.append(["Total", total_papers])

    latex_table = tabulate(
        table_data,
        headers=["Language", "Papers"],
        tablefmt="latex_booktabs",
        colalign=("left", "center"),
    )
    print(latex_table)


def analyze_repro_kinds():
    with open("benchmark.json", "r", encoding="utf-8") as f:
        data = json.loads(f.read())

    repro_counter = Counter()
    total_tables = 0
    copy_scripts = _count_copy_scripts()

    for paper in data:
        tables = paper.get("tables", {})
        if not isinstance(tables, dict):
            continue
        for table in tables.values():
            if not _is_result_table(table):
                continue
            total_tables += 1
            repro_counter[table.get("repro-kind", "unspecified")] += 1

    print("\nLaTeX Table for Reproduction Kind Distribution:")
    print("=" * 55)
    sorted_counts = repro_counter.most_common()
    table_data = []
    for label, count in sorted_counts:
        table_data.append([label.capitalize(), count])
    total_tables += copy_scripts
    table_data.append(["Copy results", copy_scripts])
    table_data.append(["Total", total_tables])
    latex_table = tabulate(
        table_data,
        headers=["Reproduction Kind", "Tables"],
        tablefmt="latex_booktabs",
        colalign=("left", "center"),
    )
    print(latex_table)


def total_result_tables() -> int:
    dataset = json.loads(Path("benchmark.json").read_text(encoding="utf-8"))
    total_tables = 0
    non_result = 0
    missing = 0
    non_deterministic = 0

    for entry in dataset:
        tables = entry.get("tables", {})
        if not isinstance(tables, dict):
            continue
        total_tables += len(tables)
        for table in tables.values():
            if not isinstance(table, dict):
                continue
            if table.get("non-result") is True:
                non_result += 1
            elif table.get("missing") is True:
                missing += 1
            elif table.get("non-deterministic") is True:
                non_deterministic += 1

    after_non_result = total_tables - non_result
    after_missing = after_non_result - missing
    result_tables = after_missing - non_deterministic

    print("Total tables in benchmark dataset:", total_tables)
    print("Excluding non-result tables:", non_result, "->", after_non_result)
    print("Excluding missing tables:", missing, "->", after_missing)
    print("Excluding non-deterministic tables:", non_deterministic, "->", result_tables)
    return result_tables


# Additional partial tables from inconsistencies table
# npetest_table_2.md
# npetest_table_3.md
# pmsat_table_5.md
# provenfix_table_2.md
# provenfix_table_3.md
# provenfix_table_4.md
# sctype_table_3.md
# urcrat_table_1.md


def generate_combined_analysis():
    """Generate both charts and LaTeX tables"""
    print("Generating analysis for Software Engineering Papers Benchmark...")
    print("=" * 60)

    # Generate topics analysis
    print("\n1. SOFTWARE ENGINEERING TECHNIQUES ANALYSIS")
    print("-" * 45)
    analyze_topics()

    print("\n" + "=" * 60)

    # Generate languages analysis
    print("\n2. PROGRAMMING LANGUAGES ANALYSIS")
    print("-" * 35)
    analyze_languages()

    print("\n" + "=" * 60)

    # Generate reproduction kind analysis
    print("\n3. REPRODUCTION KIND DISTRIBUTION")
    print("-" * 40)
    analyze_repro_kinds()

    print("\n" + "=" * 60)

    print("\n" + "=" * 60)

    total_result_tables()
    print("Analysis complete! Charts saved as PNG files and LaTeX tables printed above.")


if __name__ == "__main__":
    generate_combined_analysis()

# %%
import os
import statistics
from pathlib import Path

this_file = Path(__file__).resolve()
repo_root = this_file.parent.parent
scripts_dir = repo_root / "artisanbench" / "scripts"
files = sorted([p for p in scripts_dir.iterdir() if p.is_file()])

START_SUBSTR = "cat > /workspace/expected.md"
END_MARKER = "EOTABLE"


def _compute_loc_variants(path: Path) -> dict[str, int]:
    """Compute LOC variants.

    - loc_total / loc_nonblank: raw lines and non-blank lines (excluding comments)
    - eloc_total / eloc_nonblank: excludes the expected.md heredoc block
      (from line containing START_SUBSTR through a line that is exactly END_MARKER)
    """

    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()

    loc_total = len(lines)
    # Exclude blank lines and comment lines (starting with #)
    loc_nonblank = sum(1 for line in lines if line.strip() and not line.strip().startswith("#"))

    excluded = [False] * len(lines)
    in_block = False
    for i, line in enumerate(lines):
        if not in_block and START_SUBSTR in line:
            in_block = True
            excluded[i] = True
            continue
        if in_block:
            excluded[i] = True
            if line.strip() == END_MARKER:
                in_block = False

    eloc_total = sum(1 for i in range(len(lines)) if not excluded[i])
    eloc_nonblank = sum(
        1 for i, line in enumerate(lines) if (not excluded[i]) and line.strip() and not line.strip().startswith("#")
    )

    return {
        "loc_total": loc_total,
        "loc_nonblank": loc_nonblank,
        "eloc_total": eloc_total,
        "eloc_nonblank": eloc_nonblank,
        "excluded_total": loc_total - eloc_total,
        "excluded_nonblank": loc_nonblank - eloc_nonblank,
    }


rows: list[dict[str, object]] = []
for p in files:
    rows.append({"path": p.as_posix(), **_compute_loc_variants(p)})

print(f"Scripts found: {len(rows)}")
if not rows:
    raise SystemExit(1)


def _print_summary(label: str, values: list[int]) -> None:
    print(f"\n{label} summary:")
    print(f"  mean  : {statistics.mean(values):.2f}")
    print(f"  median: {statistics.median(values):.2f}")
    print(f"  min   : {min(values)}")
    print(f"  max   : {max(values)}")


loc_total = [int(r["loc_total"]) for r in rows]
loc_nonblank = [int(r["loc_nonblank"]) for r in rows]
eloc_total = [int(r["eloc_total"]) for r in rows]
eloc_nonblank = [int(r["eloc_nonblank"]) for r in rows]

_print_summary("LOC total lines", loc_total)
_print_summary("LOC non-blank lines", loc_nonblank)
_print_summary("eLoc total lines (excluding expected.md heredoc)", eloc_total)
_print_summary("eLoc non-blank lines (excluding expected.md heredoc)", eloc_nonblank)


def _print_bar_chart(title: str, key: str) -> None:
    bar_width = 50
    max_val = max(int(r[key]) for r in rows) or 1
    print(f"\nBar chart ({title}):")
    for r in sorted(rows, key=lambda r: int(r[key]), reverse=True):
        v = int(r[key])
        n = int(round((v / max_val) * bar_width))
        bar = "█" * n
        name = os.path.basename(str(r["path"]))
        print(f"{v:4d} | {bar:<50} | {name}")


_print_bar_chart("LOC non-blank per script", "loc_nonblank")
_print_bar_chart("eLoc non-blank per script", "eloc_nonblank")

# %%
