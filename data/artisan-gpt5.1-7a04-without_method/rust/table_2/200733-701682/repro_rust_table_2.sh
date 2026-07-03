#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary of RUF usage**

| Type       | RUF Count | Package Versions | RUF Usage Items |
| ---------- | ---------:| ----------------:| ---------------:|
| Accepted   |       ??? |           ??,??? |          ??,??? |
| Active     |       ??? |           ??,??? |         ???,??? |
| Incomplete |         ? |            ?,??? |           ?,??? |
| Removed    |        ?? |           ??,??? |          ??,??? |
| Unknown    |       ??? |           ??,??? |          ??,??? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10496086
# Section 3: Reproduction commands (populate from reviewed steps)
# They should output the reproduction results to /workspace/repro.txt
cd Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
make download_20220811_rawdata
python - << 'PY'
import csv, collections, pathlib

# Base directory for research result CSVs (relative to project root)
base = pathlib.Path("data/Release-20220811/ResearchResults")

# 1) RUF Count per status from Result2_UsedRUF.csv
ruf_counts = collections.Counter()
with (base / "Result2_UsedRUF.csv").open() as f:
    reader = csv.DictReader(f)
    for row in reader:
        ruf_counts[row["status"]] += 1

# 2) Package Versions and RUF Usage Items per status from Result2_RUFUsage.csv
pkg_versions = collections.defaultdict(set)
usage_items = collections.Counter()
with (base / "Result2_RUFUsage.csv").open() as f:
    reader = csv.DictReader(f)
    for row in reader:
        status = row["status"]
        vid = row["id"]
        pkg_versions[status].add(vid)
        usage_items[status] += 1

rows = [
    ("Accepted",   "accepted"),
    ("Active",     "active"),
    ("Incomplete", "incomplete"),
    ("Removed",    "removed"),
    ("Unknown",    "unknown"),
]

out_path = pathlib.Path("/workspace/repro.txt")
with out_path.open("w") as out:
    out.write("**Table 2: Summary of RUF usage**\n\n")
    out.write("| Type       | RUF Count | Package Versions | RUF Usage Items |\n")
    out.write("| ---------- | ---------:| ----------------:| ---------------:|\n")
    for label, key in rows:
        ruf = ruf_counts.get(key, 0)
        pkgs = len(pkg_versions.get(key, set()))
        uses = usage_items.get(key, 0)
        out.write(
            f"| {label:<9} | {ruf:9d} | {pkgs:16,} | {uses:15,} |\n"
        )
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
