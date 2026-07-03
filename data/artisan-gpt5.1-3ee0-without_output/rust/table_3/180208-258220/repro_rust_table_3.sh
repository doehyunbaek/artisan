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
artisan get https://zenodo.org/records/10496086

# Section 3: Reproduction commands (populate from reviewed steps)
# Download the precomputed ecosystem raw data (contains ResearchResults CSVs) and unzip.
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
mkdir -p data
curl "https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1" --output ./data/Release-20220811.zip
cd data
unzip -o Release-20220811.zip
cd /workspace

# Aggregate Direct Usage, Uncond Impact, Cond Impact, and Total Impact by RUF status
# to reconstruct Table 3 and write it to /workspace/repro.txt.
python - << 'PY'
import csv
from collections import defaultdict
from pathlib import Path

root = Path("/workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor")
base = root / "data/Release-20220811/ResearchResults"

def count_distinct(path: Path, id_col: str):
    counts = defaultdict(set)
    with path.open(newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            status = row["status"]
            vid = row[id_col]
            counts[status].add(vid)
    return {k: len(v) for k, v in counts.items()}

direct = count_distinct(base / "Result2_RUFUsage.csv", "id")
uncond = count_distinct(base / "Result3_1UncondImpact.csv", "version_from")
cond   = count_distinct(base / "Result3_1CondImpact.csv", "ver")
total  = count_distinct(base / "Result3_1TotalImpact.csv", "ver")

def fmt(n: int) -> str:
    return f"{n:,}"

order = ["accepted", "active", "incomplete", "removed", "unknown"]
labels = {
    "accepted": "Accepted",
    "active": "Active",
    "incomplete": "Incomplete",
    "removed": "Removed",
    "unknown": "Unknown",
}

lines = []
lines.append("**Table 3: Summary of RUF impacts. The table shows how package versions are impacted by different types of RUF and through different dependencies.**")
lines.append("")
lines.append("| RUF Type   | Direct Usage | Uncond Impact |  Cond Impact |        Total |")
lines.append("| ---------- | -----------: | ------------: | -----------: | -----------: |")

for status in order:
    label = labels[status]
    row = [
        label,
        fmt(direct.get(status, 0)),
        fmt(uncond.get(status, 0)),
        fmt(cond.get(status, 0)),
        fmt(total.get(status, 0)),
    ]
    # Right-align numeric fields via padding for readability (not required for correctness).
    line = (
        f"| {row[0]:<9} |"
        f" {row[1]:>11} |"
        f" {row[2]:>12} |"
        f" {row[3]:>11} |"
        f" {row[4]:>11} |"
    )
    lines.append(line)

out_path = Path("/workspace/repro.txt")
out_path.write_text("\n".join(lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
