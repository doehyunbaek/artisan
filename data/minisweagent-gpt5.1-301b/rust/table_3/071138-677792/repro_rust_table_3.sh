#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Summary of RUF impacts. The table shows how package versions are impacted by different types of RUF and through different dependencies.**

| RUF Type   | Direct Usage | Uncond Impact |  Cond Impact |        Total |
| ---------- | -----------: | ------------: | -----------: | -----------: |
| Accepted   |       24,681 |        17,085 |       21,477 |       38,448 |
| Active     |       55,785 |        77,582 |      207,133 |      237,386 |
| Incomplete |        5,829 |         7,696 |        7,991 |       12,097 |
| Removed    |       14,812 |        50,896 |       53,159 |       61,160 |
| Unknown    |       10,534 |        46,157 |       48,742 |       57,916 |
EOTABLE

# Section 2: Artifact download
cd /workspace
# Download the main artifact if not already present
if [ ! -f Cargo-Ecosystem-Monitor-ICSE.zip ]; then
  curl -L -o Cargo-Ecosystem-Monitor-ICSE.zip "https://zenodo.org/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip"
fi
# Unpack the artifact repository
if [ ! -d Cargo-Ecosystem-Monitor ]; then
  unzip -q Cargo-Ecosystem-Monitor-ICSE.zip
fi

# Download the 2022-08-11 research results bundle (contains Result3_* CSVs)
cd /workspace/Cargo-Ecosystem-Monitor
mkdir -p data
if [ ! -d data/Release-20220811 ]; then
  curl -L -o data/Release-20220811.zip "https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1"
  unzip -q -d data data/Release-20220811.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Use the precomputed research result CSVs to aggregate counts per RUF status
python3 - << 'PY' > /workspace/repro.txt
import csv
from collections import defaultdict

base = "/workspace/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults"

def count_distinct(csv_path, id_field, status_field):
    counts = defaultdict(set)
    with open(csv_path, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            status = (row.get(status_field) or "").strip()
            vid = (row.get(id_field) or "").strip()
            if not status or not vid:
                continue
            counts[status].add(vid)
    return {k: len(v) for k, v in counts.items()}

# Direct usage from Result 2 (version_feature_ori joined with feature_status)
direct = count_distinct(f"{base}/Result2_RUFUsage.csv", "id", "status")
# Unconditional impact
uncond = count_distinct(f"{base}/Result3_1UncondImpact.csv", "version_from", "status")
# Conditional impact
cond = count_distinct(f"{base}/Result3_1CondImpact.csv", "ver", "status")
# Total impact (union of direct + conditional + unconditional)
total = count_distinct(f"{base}/Result3_1TotalImpact.csv", "ver", "status")

order = ["accepted", "active", "incomplete", "removed", "unknown"]
label = {
    "accepted":   "Accepted",
    "active":     "Active",
    "incomplete": "Incomplete",
    "removed":    "Removed",
    "unknown":    "Unknown",
}

print("**Table 3: Summary of RUF impacts. The table shows how package versions are impacted by different types of RUF and through different dependencies.**\n")
print("| RUF Type   | Direct Usage | Uncond Impact |  Cond Impact |        Total |")
print("| ---------- | -----------: | ------------: | -----------: | -----------: |")
for key in order:
    name = label[key]
    d = direct.get(key, 0)
    u = uncond.get(key, 0)
    c = cond.get(key, 0)
    t = total.get(key, 0)
    print(f"| {name:<9} | {d:11,} | {u:12,} | {c:11,} | {t:11,} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
