#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Summary of RUF impacts. The table shows how package versions are impacted by different types of RUF and through different dependencies.**

| RUF Type   | Direct Usage | Uncond Impact |  Cond Impact |        Total |
| ---------- | -----------: | ------------: | -----------: | -----------: |
| Accepted   |       ??,??? |        ??,??? |       ??,??? |       ??,??? |
| Active     |       ??,??? |        ??,??? |      ???,??? |      ???,??? |
| Incomplete |        ?,??? |         ?,??? |        ?,??? |       ??,??? |
| Removed    |       ??,??? |        ??,??? |       ??,??? |       ??,??? |
| Unknown    |       ??,??? |        ??,??? |       ??,??? |       ??,??? |

EOTABLE

# Section 2: Artifact download
cd /workspace
artisan get https://zenodo.org/records/10496086

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
# Download and unpack the precomputed ecosystem raw data (includes ResearchResults CSVs)
make download_20220811_rawdata
# Aggregate counts per RUF status and output the reconstructed Table 3 to /workspace/repro.txt
python - <<'PY'
import csv
from collections import defaultdict

base = "data/Release-20220811/ResearchResults"

statuses = ["accepted", "active", "incomplete", "removed", "unknown"]
label_map = {
    "accepted": "Accepted",
    "active": "Active",
    "incomplete": "Incomplete",
    "removed": "Removed",
    "unknown": "Unknown",
}

def count_versions(path, ver_col):
    sets = {s: set() for s in statuses}
    with open(path, newline='') as f:
        r = csv.DictReader(f)
        for row in r:
            status = row["status"].strip().lower()
            if status not in sets:
                continue
            ver = row[ver_col].strip()
            if ver:
                sets[status].add(ver)
    return {s: len(sets[s]) for s in statuses}

direct_counts = count_versions(f"{base}/Result2_RUFUsage.csv", "id")
uncond_counts = count_versions(f"{base}/Result3_1UncondImpact.csv", "version_from")
cond_counts = count_versions(f"{base}/Result3_1CondImpact.csv", "ver")
total_counts = count_versions(f"{base}/Result3_1TotalImpact.csv", "ver")

def fmt(n: int) -> str:
    return f"{n:,}"

lines = []
lines.append("**Table 3: Summary of RUF impacts. The table shows how package versions are impacted by different types of RUF and through different dependencies.**")
lines.append("")
lines.append("| RUF Type   | Direct Usage | Uncond Impact |  Cond Impact |        Total |")
lines.append("| ---------- | -----------: | ------------: | -----------: | -----------: |")
for s in statuses:
    row = "| {rtype:<9} | {direct:>11} | {uncond:>12} | {cond:>11} | {total:>11} |".format(
        rtype=label_map[s],
        direct=fmt(direct_counts[s]),
        uncond=fmt(uncond_counts[s]),
        cond=fmt(cond_counts[s]),
        total=fmt(total_counts[s]),
    )
    lines.append(row)

with open("/workspace/repro.txt", "w", encoding="utf-8") as out:
    out.write("\n".join(lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
