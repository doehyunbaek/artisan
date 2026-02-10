#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o ROAM-Artifact.zip \
  https://zenodo.org/api/records/11068809/files/ROAM-Artifact.zip/content
unzip -o ROAM-Artifact.zip -d ROAM-Artifact

uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' \
  ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /workspace/results.md

python3 - <<'PY'
import re, sys, csv

fn = "/workspace/results.md"
with open(fn, "r", encoding="utf-8") as f:
    lines = [l.rstrip("\n") for l in f]

def clean(s: str) -> str:
    return re.sub(r"<.*?>", "", s).strip()

# 1) Find the two header lines
hdr1_idx = None
for i, l in enumerate(lines):
    if l.startswith("|") and ("ROAM" in l and "ROAM-Sim" in l and "ROAM-Dist" in l):
        hdr1_idx = i
        break
if hdr1_idx is None:
    for i, l in enumerate(lines):
        if l.startswith("|") and "Issue id" in l:
            hdr1_idx = i - 1 if i > 0 else i
            break
if hdr1_idx is None:
    print("ERROR: header not found", file=sys.stderr)
    sys.exit(1)

hdr2_idx = None
for j in range(hdr1_idx + 1, min(len(lines), hdr1_idx + 20)):
    if lines[j].startswith("|") and re.search(r"(Issue id|Match|Reproduction)", lines[j], re.I):
        hdr2_idx = j
        break
if hdr2_idx is None:
    print("ERROR: subheader not found", file=sys.stderr)
    sys.exit(1)

cols1 = [clean(c) for c in lines[hdr1_idx].split("|")[1:-1]]
cols2 = [clean(c) for c in lines[hdr2_idx].split("|")[1:-1]]

def find_tool_base(label: str) -> int:
    try:
        return cols1.index(label)
    except ValueError:
        for i, v in enumerate(cols1):
            if v and label in v:
                return i
        raise ValueError(f"tool header {label} not found")

def find_subcols(base: int, window: int = 12) -> tuple[int, int]:
    match_idx = repro_idx = None
    for off in range(window):
        idx = base + off
        if idx >= len(cols2):
            break
        h = cols2[idx].lower()
        if match_idx is None and "match" in h:
            match_idx = idx
        if repro_idx is None and ("repro" in h or "reproduction" in h):
            repro_idx = idx
        if match_idx is not None and repro_idx is not None:
            return match_idx, repro_idx
    raise ValueError(f"cannot locate subcolumns for base={base} within window={window}")

targets = ["ROAM-Sim", "ROAM-Dist", "ROAM"]
results = {}
for t in targets:
    base = find_tool_base(t)
    mi, ri = find_subcols(base, window=12)
    results[t] = {"match_idx": mi, "repro_idx": ri, "matches": [], "successes": 0, "count": 0}

# 3) Locate start of data: skip alignment row
data_start = hdr2_idx + 1
align_re = re.compile(r"^\|\s*(?::?-{3,}:?\s*\|)+\s*$")
while data_start < len(lines) and align_re.match(lines[data_start]):
    data_start += 1

# 4) Scan rows
truthy = {"success", "1", "true"}
for i in range(data_start, len(lines)):
    l = lines[i]
    if not l.startswith("|"):
        continue
    cells = [c.strip() for c in l.split("|")[1:-1]]

    for t, info in results.items():
        mi, ri = info["match_idx"], info["repro_idx"]

        # match accuracy
        if mi < len(cells):
            mv = cells[mi]
            try:
                raw = re.sub(r"[^\d\.eE\-\+]", "", mv)
                if raw:
                    val = float(raw)
                    if val > 1.0000001:  # already percent
                        val /= 100.0
                    info["matches"].append(val)
            except Exception:
                pass

        # reproduction result
        if ri < len(cells):
            rv = cells[ri].strip().lower()
            if rv:
                info["count"] += 1
                if rv in truthy:
                    info["successes"] += 1

# 5) Write summary CSV
out_fn = "/workspace/repro.csv"
with open(out_fn, "w", newline="", encoding="utf-8") as csvf:
    w = csv.writer(csvf)
    w.writerow(["Tool", "Avg. Match Accuracy (%)", "Reproduction Rate (%)"])
    for t in targets:
        info = results[t]
        avg_match = (sum(info["matches"]) / len(info["matches"])) * 100 if info["matches"] else 0.0
        denom = info["count"]
        repro_rate = (info["successes"] / denom) * 100 if denom > 0 else 0.0
        w.writerow([t, f"{avg_match:.2f}", f"{repro_rate:.2f}"])

print(out_fn)
PY

echo '<artisan_submit>'
python3 - <<'PY'
import csv

rows = {r["Tool"].strip(): r for r in csv.DictReader(open("/workspace/repro.csv", encoding="utf-8", errors="replace"))}
order = ["ROAM-Sim", "ROAM-Dist", "ROAM"]

label_map = {
    "ROAM-Sim":  "Roam-Sim",
    "ROAM-Dist": "Roam-Dist",
    "ROAM":      "Roam",
}

def fmt(x: str) -> str:
    return f"{round(float(x)):.0f}"

# extra space goes on the LEFT when padding is odd
def center_leftbias(s: str, width: int) -> str:
    s = str(s)
    pad = width - len(s)
    if pad <= 0:
        return s
    left = (pad + 1) // 2
    right = pad - left
    return (" " * left) + s + (" " * right)

print("**Table 5: The Match Accuracy and Reproduction Rate for RQ5**\n")
print("|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |")
print("| --------- | :---------------------: | :-------------------: |")

# These are the exact inner widths that match the expected file
W_MATCH = 25
W_REPRO = 23

for t in order:
    r = rows[t]
    label = label_map[t]
    match = center_leftbias(fmt(r["Avg. Match Accuracy (%)"]), W_MATCH)
    repro = center_leftbias(fmt(r["Reproduction Rate (%)"]), W_REPRO)
    print(f"| {label:<9} | {match} | {repro} |")

print()  # newline at EOF
PY
echo '</artisan_submit>'

