#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | ??.?% |    ??.?% |     ??.?% |   ??.?% | ??.?% | ??.?% |
| EvoSuite_{Def} | ??.?% |    ??.?% |     ??.?% |   ??.?% | ??.?% | ??.?% |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact
# Section 3: Reproduction commands (populate from reviewed steps)
uvx --from csvkit in2csv NPETestArtifact/rq2_result.xlsx --sheet "npedetection (2)" > /workspace/npedetection.csv
python - << 'PY' > /workspace/repro.txt
import csv

path = "/workspace/npedetection.csv"
groups = {}

with open(path, newline="") as f:
    r = csv.DictReader(f)
    for row in r:
        group = row["a"].strip()
        if group in ("", "a"):
            continue
        ev = row["evosuite"].strip()
        ev_def = row["evosuite_def"].strip()
        def conv(x):
            if x == "":
                return None
            try:
                return float(x)
            except ValueError:
                return None
        ev_v = conv(ev)
        evd_v = conv(ev_def)
        groups.setdefault(group, {"ev": [], "evd": []})
        if ev_v is not None:
            groups[group]["ev"].append(ev_v)
        if evd_v is not None:
            groups[group]["evd"].append(evd_v)

order = ["NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears"]

def mean(vals):
    return sum(vals) / len(vals) if vals else 0.0

ev_means = {g: mean(groups[g]["ev"]) for g in order}
evd_means = {g: mean(groups[g]["evd"]) for g in order}

all_ev = [v for g in groups.values() for v in g["ev"]]
all_evd = [v for g in groups.values() for v in g["evd"]]
total_ev = mean(all_ev)
total_evd = mean(all_evd)

def fmt(x):
    return f"{x:.1f}%"

header = """**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |"""
print(header)

row_evo = "| EvoSuite       | " + " | ".join([
    fmt(ev_means["NPEX"]),
    fmt(ev_means["BugSwarm"]),
    fmt(ev_means["Defects4J"]),
    fmt(ev_means["Genesis"]),
    fmt(ev_means["Bears"]),
    fmt(total_ev),
]) + " |"
row_evo_def = "| EvoSuite_{Def} | " + " | ".join([
    fmt(evd_means["NPEX"]),
    fmt(evd_means["BugSwarm"]),
    fmt(evd_means["Defects4J"]),
    fmt(evd_means["Genesis"]),
    fmt(evd_means["Bears"]),
    fmt(total_evd),
]) + " |"

print(row_evo)
print(row_evo_def)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
