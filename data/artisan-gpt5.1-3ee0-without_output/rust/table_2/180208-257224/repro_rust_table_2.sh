#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary of RUF usage**

| Type       | RUF Count | Package Versions | RUF Usage Items |
| ---------- | ---------:| ----------------:| ---------------:|
| Accepted   |       382 |           24,681 |          38,858 |
| Active     |       381 |           55,785 |         101,494 |
| Incomplete |         7 |            5,829 |           5,926 |
| Removed    |        41 |           14,812 |          21,096 |
| Unknown    |       189 |           10,534 |          14,652 |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10496086
# Section 3: Reproduction commands (populate from reviewed steps)
# Download the 2022-08-11 research results (raw data) and extract them
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
mkdir -p data
curl -L "https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1" --output ./data/Release-20220811.zip
cd data
unzip -o Release-20220811.zip
# Compute Table 2 numbers from the provided CSVs and write Markdown table
python - << 'PY' > /workspace/repro.txt
import csv
from collections import defaultdict

base = "/workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults"

# RUF Count from Result2_UsedRUF.csv
ruf_count = defaultdict(int)
with open(f"{base}/Result2_UsedRUF.csv", newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        ruf_count[row["status"]] += 1

# Package Versions and RUF Usage Items from Result2_RUFUsage.csv
pkg_versions = defaultdict(set)
usage_items = defaultdict(int)
with open(f"{base}/Result2_RUFUsage.csv", newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        status = row["status"]
        usage_items[status] += 1
        pkg_versions[status].add(row["id"])

rows = [
    ("Accepted",  "accepted"),
    ("Active",    "active"),
    ("Incomplete","incomplete"),
    ("Removed",   "removed"),
    ("Unknown",   "unknown"),
]

print("**Table 2: Summary of RUF usage**\n")
print("| Type       | RUF Count | Package Versions | RUF Usage Items |")
print("| ---------- | ---------:| ----------------:| ---------------:|")
for label, status in rows:
    rc = ruf_count.get(status, 0)
    pv = len(pkg_versions.get(status, set()))
    ui = usage_items.get(status, 0)
    print(f"| {label:<9} | {rc:9,} | {pv:16,} | {ui:15,} |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
