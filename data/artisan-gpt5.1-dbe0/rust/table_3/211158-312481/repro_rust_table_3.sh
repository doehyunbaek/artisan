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
artifact_root="Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor"
data_dir="$artifact_root/data"
rr_dir="$data_dir/Release-20220811/ResearchResults"

# Ensure the precomputed ecosystem raw data (including ResearchResults) is available.
if [ ! -d "$rr_dir" ]; then
  mkdir -p "$data_dir"
  (
    cd "$data_dir" && \
    curl -L 'https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1' --output Release-20220811.zip && \
    unzip -o Release-20220811.zip
  )
fi

direct_csv="$rr_dir/Result2_RUFUsage.csv"           # id,conds,feature,status
uncond_csv="$rr_dir/Result3_1UncondImpact.csv"      # version_from,ruf,status
cond_csv="$rr_dir/Result3_1CondImpact.csv"          # ver,ruf,status
total_csv="$rr_dir/Result3_1TotalImpact.csv"        # ver,ruf,status

# Use Python's CSV reader to robustly aggregate distinct package versions per RUF status
python - << 'PY' > /workspace/repro.txt
import csv
from collections import defaultdict

direct_csv = "Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults/Result2_RUFUsage.csv"
uncond_csv = "Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults/Result3_1UncondImpact.csv"
cond_csv   = "Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults/Result3_1CondImpact.csv"
total_csv  = "Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults/Result3_1TotalImpact.csv"

def count_distinct(path, key_field, status_field):
    by_status = defaultdict(set)
    with open(path, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            status = row[status_field]
            key = row[key_field]
            if status and key:
                by_status[status].add(key)
    return {s: len(ids) for s, ids in by_status.items()}

direct_counts = count_distinct(direct_csv, "id", "status")
uncond_counts = count_distinct(uncond_csv, "version_from", "status")
cond_counts   = count_distinct(cond_csv,   "ver",          "status")
total_counts  = count_distinct(total_csv,  "ver",          "status")

def fmt(n: int) -> str:
    return f"{n:,}" if n is not None else ""

order = ["accepted", "active", "incomplete", "removed", "unknown"]
labels = {
    "accepted": "Accepted",
    "active": "Active",
    "incomplete": "Incomplete",
    "removed": "Removed",
    "unknown": "Unknown",
}

print("**Table 3: Summary of RUF impacts. The table shows how package versions are impacted by different types of RUF and through different dependencies.**")
print()
print("| RUF Type   | Direct Usage | Uncond Impact |  Cond Impact |        Total |")
print("| ---------- | -----------: | ------------: | -----------: | -----------: |")

for key in order:
    label = labels[key]
    d = fmt(direct_counts.get(key, 0))
    u = fmt(uncond_counts.get(key, 0))
    c = fmt(cond_counts.get(key, 0))
    t = fmt(total_counts.get(key, 0))
    print(f"| {label:<9} | {d:>11} | {u:>12} | {c:>11} | {t:>11} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
