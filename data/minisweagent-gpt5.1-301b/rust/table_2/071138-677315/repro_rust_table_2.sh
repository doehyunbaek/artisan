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
cd /workspace || exit 1
if [ ! -f Cargo-Ecosystem-Monitor-ICSE.zip ]; then
  curl -L -o Cargo-Ecosystem-Monitor-ICSE.zip "https://zenodo.org/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip?download=1" || exit 1
fi
if [ ! -d Cargo-Ecosystem-Monitor ]; then
  unzip -q Cargo-Ecosystem-Monitor-ICSE.zip || exit 1
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/Cargo-Ecosystem-Monitor || exit 1

RESULT_CSV="data/Release-20220811/ResearchResults/Result2_RUFUsage.csv"

# Only build Docker and download raw data if the research-results CSV does not already exist
if [ ! -f "$RESULT_CSV" ]; then
  # Build Docker image as recommended in README
  docker build -t cargo-ecosystem-monitor . || exit 1

  # Run Docker container in detached mode with modified invocation per instructions (no host port mapping needed)
  CONTAINER_ID=$(docker run -d --init --entrypoint bash -e POSTGRES_PASSWORD="postgres" -w /app --mount type=bind,src="$(pwd)",target=/app cargo-ecosystem-monitor -c 'sleep infinity') || exit 1

  # Initialize PostgreSQL inside the container
  docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /app && make postgresql" || exit 1

  # Download and unpack the precomputed ecosystem raw data (2022-08-11)
  docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /app && make download_20220811_rawdata" || exit 1
fi

# Aggregate Result2_RUFUsage.csv into the three metrics per status and save to /workspace/repro.txt
python - << 'PYEOF' > /workspace/repro.txt
import csv
from collections import defaultdict, Counter
from pathlib import Path

path = Path("/workspace/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults/Result2_RUFUsage.csv")

features = defaultdict(set)
versions = defaultdict(set)
usage_counts = Counter()

with path.open(newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        status = row["status"].strip().lower()
        features[status].add(row["feature"])
        versions[status].add(row["id"])
        usage_counts[status] += 1

statuses = ["accepted", "active", "incomplete", "removed", "unknown"]
print("status,RUF_Count,Package_Versions,RUF_Usage_Items")
for s in statuses:
    print(f"{s},{len(features[s])},{len(versions[s])},{usage_counts[s]}")
PYEOF

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - << 'PYEOF'
import csv
from pathlib import Path

repro_path = Path("/workspace/repro.txt")
with repro_path.open(newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

rows_by_status = {r["status"].strip().lower(): r for r in rows}

order = ["accepted", "active", "incomplete", "removed", "unknown"]
labels = {
    "accepted": "Accepted",
    "active": "Active",
    "incomplete": "Incomplete",
    "removed": "Removed",
    "unknown": "Unknown",
}

print("**Table 2: Summary of RUF usage**\n")
print("| Type       | RUF Count | Package Versions | RUF Usage Items |")
print("| ---------- | ---------:| ----------------:| ---------------:|")

for status in order:
    r = rows_by_status[status]
    t = labels[status]
    rc = int(r["RUF_Count"])
    pv = int(r["Package_Versions"])
    ui = int(r["RUF_Usage_Items"])
    print(f"| {t:<10} | {rc:9d} | {pv:16d} | {ui:15d} |")
PYEOF
echo '</artisan_submit>'
