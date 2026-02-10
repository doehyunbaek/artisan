#!/usr/bin/bash
git clone https://github.com/kupl/NPETestArtifact >> /workspace/repro.txt 2>&1 || true
python3 -m pip install --quiet --upgrade pandas matplotlib matplotlib-venn

cat << 'EOF' > NPETestArtifact/scripts/build_table.py
#!/usr/bin/env python3
import sys
import pandas as pd
from pathlib import Path

def load(csv_path: str) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    required = {"Benchmark", "Project", "Tool", "NPE", "Execution"}
    missing = required - set(df.columns)
    if missing:
        raise SystemExit(f"Missing required columns: {sorted(missing)}")
    df["Tool"] = df["Tool"].str.strip().str.lower()
    df["Detected"] = df["NPE"].fillna(0) > 0
    return df

def table3_style(df: pd.DataFrame) -> pd.DataFrame:
    corpora = ["NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears"]
    has_time = "Time" in df.columns
    if not has_time:
        df = df.assign(Time="all")

    agg = (
        df.groupby(["Time", "Tool", "Benchmark", "Project"], as_index=False)["Detected"]
          .max()
    )

    counts = (
        agg.groupby(["Time", "Tool", "Benchmark"], as_index=False)["Detected"]
           .sum()
           .rename(columns={"Detected": "Count"})
    )

    wide = (
        counts.pivot_table(index=["Time", "Tool"],
                           columns="Benchmark",
                           values="Count",
                           fill_value=0,
                           aggfunc="sum")
              .reindex(columns=corpora, fill_value=0)
              .astype(int)
    )

    wide["Total"] = wide.sum(axis=1).astype(int)

    name_map = {"randoop": "Randoop", "evosuite": "EvoSuite", "npetest": "NPETest"}
    wide = wide.reset_index()
    wide["Tools"] = wide["Tool"].map(name_map).fillna(wide["Tool"])
    tool_order = pd.Categorical(wide["Tools"], categories=["Randoop", "EvoSuite", "NPETest"], ordered=True)
    wide = wide.assign(_tool_order=tool_order).sort_values(["Time", "_tool_order"]).drop(columns=["_tool_order","Tool"])
    return wide[["Time", "Tools"] + corpora + ["Total"]]

def print_markdown_table3(df_table3: pd.DataFrame) -> str:
    lines = []
    header = ["Time", "Tools", "NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears", "Total"]
    lines.append("| " + " | ".join(header) + " |")
    lines.append("| " + " | ".join(["---"] + [":---:"]*(len(header)-1)) + " |")
    for time_value, group in df_table3.groupby("Time", sort=False):
        for _, row in group.iterrows():
            cells = [str(row["Time"]), row["Tools"]] + [str(int(row[c])) for c in ["NPEX","BugSwarm","Defects4J","Genesis","Bears","Total"]]
            lines.append("| " + " | ".join(cells) + " |")
        lines.append("")
    return "\n".join(lines).strip() + "\n"

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {Path(sys.argv[0]).name} <merged_result.csv> <out.txt>", file=sys.stderr)
        sys.exit(2)
    csv_path, out_path = sys.argv[1], sys.argv[2]
    df = load(csv_path)
    tbl3 = table3_style(df)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("Table 3-style summary (projects with ≥1 NPE detected):\n\n")
        f.write(print_markdown_table3(tbl3))

if __name__ == "__main__":
    main()
EOF

cd NPETestArtifact/result
curl -L -o evosuite_result.zip "https://zenodo.org/records/13738493/files/evosuite_opt_result.zip?download=1"
unzip -o evosuite_result.zip
mkdir -p evosuite
rm -rf evosuite/evosuite_opt_result || true
mv -f evosuite_opt_result evosuite/

curl -L -o npetest_result.zip "https://zenodo.org/records/13738493/files/npetest_result.zip?download=1"
unzip -o npetest_result.zip
mkdir -p npetest
rm -rf npetest/npetest_result || true
mv -f npetest_result npetest/

cd /workspace/NPETestArtifact && ./scripts/get_main_results.sh

{
  echo "========EVOSUITE RESULT========"
  cat /workspace/NPETestArtifact/result/evosuite_result.csv
  echo "========NPETEST RESULT========"
  cat /workspace/NPETestArtifact/result/npetest_result.csv
} > /workspace/repro.txt

echo "<artisan_submit>"
python3 - <<'PY'
import csv, io, re
from collections import defaultdict

REPRO = "/workspace/repro.txt"

BENCH_ORDER = ["NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears"]

def read_block(text: str, start_marker: str, end_marker: str | None):
    lines = text.splitlines()
    try:
        s = lines.index(start_marker) + 1
    except ValueError:
        return []
    e = len(lines)
    if end_marker is not None:
        try:
            e = lines.index(end_marker)
        except ValueError:
            e = len(lines)

    out = []
    for l in lines[s:e]:
        l = l.strip("\n")
        if not l.strip():
            continue
        if l.lstrip().startswith("#"):  # ignore comments like "# Unique NPE,59"
            continue
        out.append(l)
    return out

txt = open(REPRO, "r", encoding="utf-8", errors="replace").read()

ev_lines = read_block(txt, "========EVOSUITE RESULT========", "========NPETEST RESULT========")
np_lines = read_block(txt, "========NPETEST RESULT========", None)

def count_unique_npes(csv_lines):
    """
    Interprets each CSV row as one *unique NPE instance* (project variant like Foo(0), Foo(1), ...).
    Count per-benchmark = number of rows with NPE > 0.
    """
    per = defaultdict(int)
    if not csv_lines:
        return per
    r = csv.DictReader(io.StringIO("\n".join(csv_lines)))
    for row in r:
        bench = (row.get("Benchmark") or "").strip()
        try:
            npe = int(float(row.get("NPE") or 0))
        except Exception:
            npe = 0
        if bench and npe > 0:
            per[bench] += 1
    return per

ev = count_unique_npes(ev_lines)
np = count_unique_npes(np_lines)

def row_counts(d):
    vals = [int(d.get(b, 0)) for b in BENCH_ORDER]
    return vals + [sum(vals)]

# Emit the table exactly like expected (5 min, two tool rows)
print("**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**\n")
print("| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |")
print("| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |")

ev_vals = row_counts(ev)
np_vals = row_counts(np)

print(f"| 5 min  | EvoSuite | {ev_vals[0]} | {ev_vals[1]} | {ev_vals[2]} | {ev_vals[3]} | {ev_vals[4]} | {ev_vals[5]} |")
print(f"|        | NPETest  | {np_vals[0]} | {np_vals[1]} | {np_vals[2]} | {np_vals[3]} | {np_vals[4]} | {np_vals[5]} |")
PY
echo "</artisan_submit>"
