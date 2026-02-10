#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o Cargo-Ecosystem-Monitor-ICSE.zip https://zenodo.org/api/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip/content
unzip Cargo-Ecosystem-Monitor-ICSE.zip -d Cargo-Ecosystem-Monitor-ICSE

cd Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
make download_20220811_rawdata

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

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
