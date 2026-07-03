#!/usr/bin/bash
set -euo pipefail

# Write expected table for the formatter
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**

| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |
| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |
| BeDiv-Simple |     ???.? |  ???.? |     ????.? |     ????.? |      ????.? |     ?????.? |    ???.? |      ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| BeDiv-Struct |     ???.? |  ???.? |     ????.? |     ????.? |      ????.? |     ?????.? |    ???.? |      ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| RLCheck      |     ???.? |  ???.? |          — |          — |      ????.? |      ????.? |    ???.? |      ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zest         |     ???.? |  ???.? |     ????.? |     ????.? |      ????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-X     |     ???.? |  ???.? |     ????.? |     ????.? |     ?????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-?PT   |     ???.? |  ???.? |     ????.? |     ????.? |     ?????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-?PT   |     ???.? |  ???.? |     ????.? |     ????.? |     ?????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-Link  | **???.?** |  ???.? | **????.?** | **????.?** | **?????.?** | **?????.?** |    ???.? | **????.?** | **????.?** | **????.?** | **????.?** | **????.?** | **???.?** | **???.?** |

EOTABLE

# Locate campaigns directory among likely paths
candidates=( "/workspace/campaigns/campaigns" "/workspace/campaigns" "campaigns/campaigns" "campaigns" )
CAMDIR=""
for p in "${candidates[@]}"; do
  if [ -d "$p" ]; then
    CAMDIR="$p"
    break
  fi
done

if [ -z "$CAMDIR" ]; then
  # No campaigns found: write placeholder reproduction table
  cat > /workspace/repro.txt <<'TABLE'
| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |
| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |
| BeDiv-Simple |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |
| BeDiv-Struct |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |
| RLCheck      |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |
| Zest         |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |
| Zeugma-X     |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |
| Zeugma-?PT   |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |
| Zeugma-?PT   |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |
| Zeugma-Link  |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |     — |
TABLE
  echo "No campaigns found; wrote placeholder /workspace/repro.txt" >&2
else
  # Compute medians using Python standard library
  CAMDIR_INLINE="$CAMDIR" python3 - <<'PY'
import os, json, csv, statistics, sys

base = os.environ.get("CAMDIR_INLINE")
if not base or not os.path.isdir(base):
    print("ERROR: campaigns base missing", file=sys.stderr)
    sys.exit(0)

subjects = ["ant","bcel","closure","maven","nashorn","rhino","tomcat"]
fuzzer_raws = [
    "bedivfuzz-simple","bedivfuzz-structure",
    "rlcheck","zest",
    "zeugma-linked","zeugma-none","zeugma-one_point","zeugma-two_point"
]
display_map = {
    "bedivfuzz-simple":"BeDiv-Simple",
    "bedivfuzz-structure":"BeDiv-Struct",
    "rlcheck":"RLCheck",
    "zest":"Zest",
    "zeugma-linked":"Zeugma-Link",
    "zeugma-none":"Zeugma-X",
    "zeugma-one_point":"Zeugma-?PT",
    "zeugma-two_point":"Zeugma-?PT"
}
row_order = [
    "BeDiv-Simple","BeDiv-Struct","RLCheck","Zest",
    "Zeugma-X","Zeugma-?PT","Zeugma-?PT","Zeugma-Link"
]
targets = {"5M":300000, "3H":10800000}

def find_value(obj, candidates):
    if isinstance(obj, dict):
        for k,v in obj.items():
            res = find_value(v, candidates)
            if res is not None:
                return res
    elif isinstance(obj, list):
        for item in obj:
            res = find_value(item, candidates)
            if res is not None:
                return res
    else:
        if isinstance(obj, str) and obj in candidates:
            return obj
    return None

data = {}
for entry in os.listdir(base):
    d = os.path.join(base, entry)
    if not os.path.isdir(d):
        continue
    summary_path = os.path.join(d, "summary.json")
    cov_path = os.path.join(d, "coverage.csv")
    if not os.path.isfile(summary_path) or not os.path.isfile(cov_path):
        continue
    try:
        with open(summary_path,'r') as f:
            summary = json.load(f)
    except Exception:
        continue
    sub = find_value(summary, subjects)
    fuz = find_value(summary, fuzzer_raws)
    if sub is None:
        sub = summary.get("subject") or (summary.get("configuration") or {}).get("subject")
    if fuz is None:
        fuz = summary.get("fuzzer") or (summary.get("configuration") or {}).get("fuzzer")
    if sub is None or fuz is None:
        continue
    display = display_map.get(fuz, fuz)
    times = []
    try:
        with open(cov_path,'r') as f:
            reader = csv.reader((line.replace('\\r','') for line in f))
            for row in reader:
                if not row: continue
                try:
                    t = int(row[0].strip())
                    v = int(row[1].strip())
                    times.append((t,v))
                except Exception:
                    continue
    except Exception:
        continue
    if not times:
        continue
    times.sort()
    def get_at_target(tt):
        val = None
        for t,v in times:
            if t <= tt:
                val = v
            else:
                break
        return val
    v5 = get_at_target(targets["5M"])
    v3 = get_at_target(targets["3H"])
    key = (display, sub)
    if key not in data:
        data[key] = {"5M":[], "3H":[]}
    if v5 is not None:
        data[key]["5M"].append(v5)
    if v3 is not None:
        data[key]["3H"].append(v3)

def fmt(val):
    if val is None:
        return "    —"
    else:
        return "{:8.1f}".format(val)

medians = {}
for display in row_order:
    medians[display] = {}
    for sub in subjects:
        key = (display, sub)
        arr5 = data.get(key,{}).get("5M",[])
        arr3 = data.get(key,{}).get("3H",[])
        m5 = statistics.median(arr5) if arr5 else None
        m3 = statistics.median(arr3) if arr3 else None
        medians[display][sub] = (m5,m3)

header = "| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |"
sep = "| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |"
lines = [header, sep]
for display in row_order:
    cells = [display]
    for sub in subjects:
        m5,m3 = medians[display][sub]
        cells.append(fmt(m5))
        cells.append(fmt(m3))
    row = "| " + " | ".join(cells) + " |"
    lines.append(row)

out = "\\n".join(lines) + "\\n"
with open("/workspace/repro.txt", "w") as f:
    f.write(out)

print("Computed medians and wrote /workspace/repro.txt")
PY
fi

# Print submission block and run formatter
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
