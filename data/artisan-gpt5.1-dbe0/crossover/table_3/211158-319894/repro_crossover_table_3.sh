#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**

| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |
| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |
| BeDiv-Simple |     ???.? |  ???.? |     ????.? |     ????.? |      ????.? |     ?????.? |    ???.? |      ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| BeDiv-Struct |     ???.? |  ???.? |     ????.? |     ????.? |      ????.? |     ?????.? |    ???.? |      ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| RLCheck      |     ???.? |  ???.? |          — |          — |      ????.? |      ????.? |    ???.? |      ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zest         |     ???.? |  ???.? |     ????.? |     ????.? |      ????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-X     |     ???.? |  ???.? |     ????.? |     ????.? |     ?????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-?PT   |     ???.? |  ???.? |     ????.? |     ????.? |     ?????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-?PT   |     ???.? |  ???.? |     ????.? |     ????.? |     ?????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-Link  | **???.?** |  ???.? | **????.?** | **????.?** | **?????.?** | **?????.?** |    ???.? | **????.?** | **????.?** | **????.?** | **????.?** | **????.?** | **???.?** | **???.?** |

EOTABLE

# Section 2: Artifact download
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879

# Section 3: Reproduction commands
# Load Docker image and start a long-running container
docker load -i zeugma-artifact-image.tgz
docker rm -f zeugma-artifact-container 2>/dev/null || true
docker run -d --init --entrypoint bash --name zeugma-artifact-container zeugma-artifact -c "sleep infinity"

# Run analysis inside the container using system Python (pandas is expected to be available there)
docker exec zeugma-artifact-container /bin/bash --noprofile --norc -c '
python3 - << "PY"
import pandas as pd

# Load coverage data from the artifact data directory
df = pd.read_csv("data/coverage.csv")
df["time"] = pd.to_timedelta(df["time"])

# Time points corresponding to 5 minutes and 3 hours
t_5m = pd.to_timedelta(5, "m")
t_3h = pd.to_timedelta(3, "h")
times = [t_5m, t_3h]
labels = {t_5m: "5M", t_3h: "3H"}

df = df[df["time"].isin(times)].copy()
df["time_label"] = df["time"].map(labels)

# Median covered_branches per (time_label, subject, fuzzer)
grp = df.groupby(["time_label", "subject", "fuzzer"])["covered_branches"].median().reset_index()

# Pivot so rows = fuzzers, columns = (subject, time_label)
table = grp.pivot(index="fuzzer", columns=["subject", "time_label"], values="covered_branches")

# Fuzzer order matching Table 3
fuzzers = [
    "BeDiv-Simple",
    "BeDiv-Struct",
    "RLCheck",
    "Zest",
    "Zeugma-X",
    "Zeugma-1PT",
    "Zeugma-2PT",
    "Zeugma-Link",
]

# Subjects in dataset (keys) and their display names (for header only)
subjects = [
    ("Ant", "Ant"),
    ("Bcel", "BCEL"),
    ("Closure", "Closure"),
    ("Maven", "Maven"),
    ("Nashorn", "Nashorn"),
    ("Rhino", "Rhino"),
    ("Tomcat", "Tomcat"),
]

# Column ordering: for each subject, 5M then 3H
cols = []
for subj_key, _ in subjects:
    cols.append((subj_key, "5M"))
    cols.append((subj_key, "3H"))

def get_val(fuzzer, subj, tlabel):
    """Return formatted value for (fuzzer, subject, time_label) or '—' if missing."""
    try:
        v = table.loc[fuzzer, (subj, tlabel)]
    except KeyError:
        return "—"
    if pd.isna(v):
        return "—"
    return f"{float(v):.1f}"

lines = []
# Caption (same as in expected.md)
lines.append("**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**")
lines.append("")
# Header and separator
lines.append("| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |")
lines.append("| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |")

# Data rows
for f in fuzzers:
    row_vals = [get_val(f, subj, tlabel) for (subj, tlabel) in cols]
    formatted = [f"{v:>8}" for v in row_vals]
    line = f"| {f:<12}|"
    for v in formatted:
        line += f" {v} |"
    lines.append(line)

print("\n".join(lines))
PY
' > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
