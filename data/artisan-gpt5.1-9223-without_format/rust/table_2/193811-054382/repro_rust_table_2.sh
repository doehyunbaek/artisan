#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary of RUF usage**

| Type       | RUF Count | Package Versions | RUF Usage Items |
| ---------- | ---------:| ----------------:| ---------------:|
| Accepted   |       382 |           24,681 |          38,858 |
| Active     |       381 |           55,785 |         101,494 |
| Incomplete |         7 |            5,829 |            5,926 |
| Removed    |        41 |           14,812 |          21,096 |
| Unknown    |       189 |           10,534 |          14,652 |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10496086

# Section 3: Reproduction commands (populate from reviewed steps)
# Download and unpack the 2022-08-11 raw data (includes Result2_RUFUsage.csv)
cd Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
make download_20220811_rawdata

# Compute RUF counts, package-version counts, and usage-item counts per status
python - <<'PY'
import csv, collections, os, pathlib

# We are currently in Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
csv_path = pathlib.Path("data") / "Release-20220811" / "ResearchResults" / "Result2_RUFUsage.csv"

ruf_set = collections.defaultdict(set)
pkg_set = collections.defaultdict(set)
usage_cnt = collections.defaultdict(int)

with csv_path.open(newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        status = row["status"].strip().lower()
        feat = row["feature"].strip()
        vid = row["id"].strip()
        if feat:
            ruf_set[status].add(feat)
        if vid:
            pkg_set[status].add(vid)
        usage_cnt[status] += 1

def fmt(n: int) -> str:
    return f"{n:,}"

order = [
    ("accepted",   "Accepted"),
    ("active",     "Active"),
    ("incomplete", "Incomplete"),
    ("removed",    "Removed"),
    ("unknown",    "Unknown"),
]

lines = []
lines.append("**Table 2: Summary of RUF usage**\n\n")
lines.append("| Type       | RUF Count | Package Versions | RUF Usage Items |\n")
lines.append("| ---------- | ---------:| ----------------:| ---------------:|\n")

for key, label in order:
    rufs = len(ruf_set[key])
    pkgs = len(pkg_set[key])
    uses = usage_cnt[key]
    lines.append(
        f"| {label:<9} | {rufs:9d} | {fmt(pkgs):16} | {fmt(uses):15} |\n"
    )

os.makedirs("/workspace", exist_ok=True)
with open("/workspace/repro.txt", "w") as out:
    out.writelines(lines)
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
