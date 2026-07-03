#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | 50.7% |    68.0% |     64.7% |   47.3% | 64.0% | 56.9% |
| EvoSuite_{Def} | 48.8% |    62.7% |     83.3% |   45.3% | 60.0% | 55.7% |

EOTABLE

# Section 2: Artifact download
if [ ! -d /workspace/NPETestArtifact ]; then
  git clone https://github.com/kupl/NPETestArtifact.git /workspace/NPETestArtifact
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Convert the "npedetection (2)" sheet from rq2_result.xlsx to CSV
uvx --from csvkit in2csv /workspace/NPETestArtifact/rq2_result.xlsx --sheet 'npedetection (2)' > /workspace/npe_npedetection.csv

# Aggregate per-benchmark-set averages for EvoSuite and EvoSuite_Def and build the Markdown table
python - << 'PY'
import csv
from collections import defaultdict

csv_path = "/workspace/npe_npedetection.csv"

# Aggregators: sum of percentages and counts per benchmark set
sums = defaultdict(lambda: {"evosuite": 0.0, "evosuite_def": 0.0,
                            "count_evo": 0, "count_def": 0})
total = {"evosuite": 0.0, "evosuite_def": 0.0,
         "count_evo": 0, "count_def": 0}

with open(csv_path, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        bench = row["a"].strip()
        for key, col in (("evosuite", "evosuite"), ("evosuite_def", "evosuite_def")):
            val = row[col].strip()
            if not val:
                continue
            try:
                v = float(val)
            except ValueError:
                continue
            sums[bench][key] += v
            if key == "evosuite":
                sums[bench]["count_evo"] += 1
                total["count_evo"] += 1
            else:
                sums[bench]["count_def"] += 1
                total["count_def"] += 1
            total[key] += v

def avg(container, key, cnt_key):
    return container[key] / container[cnt_key] if container[cnt_key] else 0.0

benchmarks = ["NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears"]

results_evo = {}
results_def = {}
for bench in benchmarks:
    results_evo[bench] = avg(sums[bench], "evosuite", "count_evo")
    results_def[bench] = avg(sums[bench], "evosuite_def", "count_def")

total_evo = avg(total, "evosuite", "count_evo")
total_def = avg(total, "evosuite_def", "count_def")

out_path = "/workspace/repro.txt"
with open(out_path, "w") as out:
    out.write("**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**\n\n")
    out.write("| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |\n")
    out.write("| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |\n")

    def fmt(v):  # one decimal place with percent sign
        return f"{v:.1f}%"

    # EvoSuite row
    out.write(
        "| EvoSuite       | "
        f"{fmt(results_evo['NPEX'])} | "
        f"{fmt(results_evo['BugSwarm'])} | "
        f"{fmt(results_evo['Defects4J'])} | "
        f"{fmt(results_evo['Genesis'])} | "
        f"{fmt(results_evo['Bears'])} | "
        f"{fmt(total_evo)} |\n"
    )

    # EvoSuite_{Def} row
    out.write(
        "| EvoSuite_{Def} | "
        f"{fmt(results_def['NPEX'])} | "
        f"{fmt(results_def['BugSwarm'])} | "
        f"{fmt(results_def['Defects4J'])} | "
        f"{fmt(results_def['Genesis'])} | "
        f"{fmt(results_def['Bears'])} | "
        f"{fmt(total_def)} |\n"
    )
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
