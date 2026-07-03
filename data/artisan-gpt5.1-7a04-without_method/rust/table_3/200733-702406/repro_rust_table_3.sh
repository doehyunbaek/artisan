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

# Section 3: Reproduction commands
# Download the pre-generated ecosystem raw data (Release-20220811) that includes ResearchResults CSVs.
DATA_DIR="Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/data"
RR_BASE="$DATA_DIR/Release-20220811/ResearchResults"

mkdir -p "$DATA_DIR"
if [ ! -d "$DATA_DIR/Release-20220811" ]; then
  curl -L "https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1" -o "$DATA_DIR/Release-20220811.zip"
  (cd "$DATA_DIR" && unzip -q Release-20220811.zip)
fi

# Use Python CSV parsing to compute distinct impacted versions per status for each metric.
python - << 'PY' > /workspace/repro.txt
import csv
from pathlib import Path

print("**Table 3: Summary of RUF impacts. The table shows how package versions are impacted by different types of RUF and through different dependencies.**\n")

base = Path("Cargo-Ecosystem-Monitor-ICSE") / "Cargo-Ecosystem-Monitor" / "data" / "Release-20220811" / "ResearchResults"

def count_distinct(csv_path, id_field):
    counts = {}
    with csv_path.open(newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            status = row.get("status", "").strip()
            vid = row.get(id_field, "").strip()
            if not status or not vid:
                continue
            counts.setdefault(status, set()).add(vid)
    return {k: len(v) for k, v in counts.items()}

direct  = count_distinct(base / "Result2_RUFUsage.csv",       "id")
uncond  = count_distinct(base / "Result3_1UncondImpact.csv",  "version_from")
cond    = count_distinct(base / "Result3_1CondImpact.csv",    "ver")
total   = count_distinct(base / "Result3_1TotalImpact.csv",   "ver")

order = [
    ("accepted",  "Accepted"),
    ("active",    "Active"),
    ("incomplete","Incomplete"),
    ("removed",   "Removed"),
    ("unknown",   "Unknown"),
]

print("| RUF Type   | Direct Usage | Uncond Impact |  Cond Impact |        Total |")
print("| ---------- | -----------: | ------------: | -----------: | -----------: |")

for key, label in order:
    d = direct.get(key, 0)
    u = uncond.get(key, 0)
    c = cond.get(key, 0)
    t = total.get(key, 0)
    fd = f"{d:,}"
    fu = f"{u:,}"
    fc = f"{c:,}"
    ft = f"{t:,}"
    print(f"| {label:<9} | {fd:>11} | {fu:>12} | {fc:>11} | {ft:>11} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
