#!/usr/bin/env bash
REC_ID="11095274"
WORKDIR="/workspace"
ZIP_PATH="${WORKDIR}/bloat-study-artifact.zip"
OUTDIR="${WORKDIR}/artifact"

mkdir -p "$WORKDIR" "$OUTDIR"

# Download the Zenodo record metadata and fetch the most likely artifact ZIP
python3 - <<'PY'
import json, sys, urllib.request

rec_id = "11095274"
api = f"https://zenodo.org/api/records/{rec_id}"

with urllib.request.urlopen(api) as r:
    data = json.load(r)

files = data.get("files", [])
if not files:
    print("ERROR: No files found in Zenodo record", file=sys.stderr)
    sys.exit(1)

# Prefer a .zip (and prefer one that looks like the artifact)
zips = [f for f in files if f.get("key","").lower().endswith(".zip")]
if not zips:
    print("ERROR: No .zip file found in Zenodo record", file=sys.stderr)
    print("Available files:", [f.get("key") for f in files], file=sys.stderr)
    sys.exit(1)

def score(f):
    k = f.get("key","").lower()
    s = 0
    if "artifact" in k: s += 10
    if "bloat" in k: s += 5
    return s

best = sorted(zips, key=score, reverse=True)[0]
url = best.get("links", {}).get("self") or best.get("links", {}).get("download")
if not url:
    print("ERROR: Could not find download URL for zip", file=sys.stderr)
    sys.exit(1)

print(url)
PY

ZIP_URL="$(python3 - <<'PY'
import json, sys, urllib.request
rec_id = "11095274"
api = f"https://zenodo.org/api/records/{rec_id}"
with urllib.request.urlopen(api) as r:
    data = json.load(r)
files = data.get("files", [])
zips = [f for f in files if f.get("key","").lower().endswith(".zip")]
def score(f):
    k = f.get("key","").lower()
    s = 0
    if "artifact" in k: s += 10
    if "bloat" in k: s += 5
    return s
best = sorted(zips, key=score, reverse=True)[0]
print(best["links"].get("self") or best["links"].get("download"))
PY
)"

echo "Downloading: $ZIP_URL"
curl -fL -o "$ZIP_PATH" "$ZIP_URL"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"
unzip -q "$ZIP_PATH" -d "$OUTDIR"

# Find the extracted artifact root (don’t hardcode the hash folder name)
ART_ROOT="$(find "$OUTDIR" -maxdepth 2 -type d -name 'gdrosos-bloat-study-artifact-*' | head -n 1)"
if [[ -z "${ART_ROOT}" ]]; then
  echo "ERROR: Could not find extracted gdrosos-bloat-study-artifact-* directory under $OUTDIR" >&2
  echo "Top-level dirs:" >&2
  find "$OUTDIR" -maxdepth 2 -type d -print >&2
  exit 1
fi

cd "$ART_ROOT"

python3 -m pip install --quiet pandas
python3 scripts/descriptives/evaluation.py -csv data/results/rq1a.csv > "${WORKDIR}/repro_raw.txt"

python3 - <<'PY'
import re
from decimal import Decimal, ROUND_HALF_UP

raw = open("/workspace/repro_raw.txt", encoding="utf-8", errors="replace").read().strip().splitlines()
raw = [l.rstrip() for l in raw if l.strip()]
if len(raw) < 2:
    raise SystemExit("ERROR: unexpected evaluation output (too short)")

rows = []
for l in raw[1:]:
    parts = re.split(r"\s+", l.strip())
    if len(parts) < 5:
        continue
    label = parts[0]
    agg = int(float(parts[1]))
    prop = float(parts[2])
    avg = float(parts[3])
    med = float(parts[4])
    rows.append((label, agg, prop, avg, med))

if not rows:
    raise SystemExit("ERROR: no data rows parsed from evaluation output")

def fmt_int_commas(n: int) -> str:
    return f"{n:,}"

def fmt_pct_1(x: float) -> str:
    return f"{x:.1f}%"

def fmt_avg_int_commas(x: float) -> str:
    n = int(Decimal(str(x)).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    return f"{n:,}"

def fmt_med_1_commas(x: float) -> str:
    return f"{x:,.1f}"

md = []
md.append("**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**")
md.append("")
md.append("|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |")
md.append("| --- | --- | --- | --- | --- | --- |")
md.append("|  |  |  |  |  |  |")

order = ["Resolved", "Unresolved"]
row_map = {r[0]: r for r in rows}
for k in order:
    if k not in row_map:
        continue
    label, agg, prop, avg, med = row_map[k]
    md.append(
        f"|  | {label} | {fmt_int_commas(agg)} | {fmt_pct_1(prop)} | {fmt_avg_int_commas(avg)} | {fmt_med_1_commas(med)} |"
    )

open("/workspace/repro.txt", "w", encoding="utf-8").write("\n".join(md) + "\n")
PY

echo "<artisan_submit>"
cat /workspace/repro.txt
echo "</artisan_submit>"
