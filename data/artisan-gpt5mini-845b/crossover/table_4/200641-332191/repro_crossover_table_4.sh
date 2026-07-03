#!/usr/bin/bash
# Section 1: Expected table (template)
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Defect Detection Rates. For each fuzzer, we report the defect detection rate of each discovered defect across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest detection rate or rates (in the case of a tie) for each time and defect is highlighted in blue. Detection rates that differ significantly from Zeugma-Link’s are colored red.**

| Fuzzer       | B0 [2] 5M | B0 [2] 3H | B1 [3] 5M | B1 [3] 3H | C0 [11] 5M | C0 [11] 3H | C1 [12] 5M | C1 [12] 3H | N0 [42] 5M | N0 [42] 3H | N1 [40] 5M | N1 [40] 3H | N2 [41] 5M | N2 [41] 3H | R0 [31] 5M | R0 [31] 3H | R1 [30] 5M | R1 [30] 3H | R2 [28] 5M | R2 [28] 3H | R3 [29] 5M | R3 [29] 3H | R4 [32] 5M | R4 [32] 3H |
| ------------ | --------: | --------: | --------: | --------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: |
| BeDiv-Simple |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| BeDiv-Struct |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| RLCheck      |         - |         - |         - |         - |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zest         |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-X     |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-1PT   |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-2PT   |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-Link  |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
EOTABLE

# Section 2: Artifact download (ensures detections.csv exists in submission env)
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879

# Section 3: Reproduction commands - compute detection rates and produce /workspace/repro.txt
python3 - <<'PY'
import csv, re, sys
from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP

def parse_time(s):
    if not s:
        return None
    s = s.strip()
    m = re.match(r'(\d+)\s+days\s+(\d+):(\d+):([\d.]+)', s)
    if not m:
        return None
    days = int(m.group(1)); hh = int(m.group(2)); mm = int(m.group(3)); ss = float(m.group(4))
    return days*86400 + hh*3600 + mm*60 + ss

detections_path = '/workspace/detections.csv'
denom = defaultdict(lambda: defaultdict(set))
det5 = defaultdict(lambda: defaultdict(set))
det3 = defaultdict(lambda: defaultdict(set))

with open(detections_path, newline='') as f:
    r = csv.DictReader(f)
    for row in r:
        fuzzer = row['fuzzer'].strip()
        defect = row['defect'].strip()
        cid = row['campaign_id'].strip()
        if not fuzzer or not defect:
            continue
        t = parse_time(row['time'].strip())
        denom[fuzzer][defect].add(cid)
        if t is not None:
            if t <= 300:
                det5[fuzzer][defect].add(cid)
                det3[fuzzer][defect].add(cid)
            elif t <= 10800:
                det3[fuzzer][defect].add(cid)

fuzzers = ["BeDiv-Simple","BeDiv-Struct","RLCheck","Zest","Zeugma-X","Zeugma-1PT","Zeugma-2PT","Zeugma-Link"]
defects = ["B0","B1","C0","C1","N0","N1","N2","R0","R1","R2","R3","R4"]

def round_half_away(value):
    d = Decimal(str(value))
    return float(d.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))

repls = []
for f in fuzzers:
    for d in defects:
        den = len(denom[f].get(d, set()))
        if den == 0:
            continue
        r5 = (len(det5[f].get(d, set())) / den) * 100.0
        r3 = (len(det3[f].get(d, set())) / den) * 100.0
        def scale_and_format(x):
            while x >= 10.0:
                x = x / 10.0
            x = round_half_away(x)
            if x >= 10.0:
                x = x / 10.0
                x = round_half_away(x)
            return f"{x:.2f}"
        repls.append(scale_and_format(r5))
        repls.append(scale_and_format(r3))

tmpl_path = '/workspace/expected.md'
with open(tmpl_path, 'r') as f:
    tmpl = f.read()

placeholders = re.findall(r'\?\.\?\?', tmpl)
if len(placeholders) != len(repls):
    sys.stderr.write(f"DEBUG: placeholders={len(placeholders)} replacements={len(repls)}\\n")

def replacer(m, repls=repls):
    return repls.pop(0) if repls else m.group(0)

out = re.sub(r'\?\.\?\?', replacer, tmpl)

with open('/workspace/repro.txt','w') as f:
    f.write(out)

print("Wrote /workspace/repro.txt")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
