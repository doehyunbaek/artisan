#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | 50.7% |    68.0% |     64.7% |   47.3% | 64.0% | 56.9% |
| EvoSuite_{Def} | 48.8% |    62.7% |     83.3% |   45.3% | 60.0% | 55.7% |

EOTABLE

# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/NPETestArtifact
python3 - <<'PY' > /workspace/repro.txt
from zipfile import ZipFile
import xml.etree.ElementTree as ET
from pathlib import Path
import re

xlsx_path = Path("rq2_result.xlsx")

def nsstrip(tag: str) -> str:
    return tag.split('}', 1)[-1]

def col_to_index(col: str) -> int:
    idx = 0
    for ch in col:
        idx = idx * 26 + (ord(ch) - ord('A') + 1)
    return idx

with ZipFile(xlsx_path) as z:
    # Locate the "npedetection (2)" worksheet
    wb_root = ET.fromstring(z.read("xl/workbook.xml"))
    ns = {'ns': wb_root.tag.split('}')[0].strip('{')}
    target_name = "npedetection (2)"
    sheet_elem = None
    for s in wb_root.findall("ns:sheets/ns:sheet", ns):
        if s.attrib.get("name") == target_name:
            sheet_elem = s
            break
    if sheet_elem is None:
        raise SystemExit(f"Sheet named {target_name!r} not found")

    rel_id = sheet_elem.attrib.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
    rel_root = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    target_path = None
    for rel in rel_root:
        if rel.attrib.get("Id") == rel_id:
            target_path = "xl/" + rel.attrib["Target"].lstrip("/")
            break
    if target_path is None:
        raise SystemExit(f"Target for rel {rel_id} not found")

    # Load shared strings
    shared = []
    if "xl/sharedStrings.xml" in z.namelist():
        ss_root = ET.fromstring(z.read("xl/sharedStrings.xml"))
        for si in ss_root.iter():
            if nsstrip(si.tag) == "t":
                shared.append(si.text if si.text is not None else "")

    # Parse the worksheet
    ws_root = ET.fromstring(z.read(target_path))
    rows = []
    for row in ws_root.iter():
        if nsstrip(row.tag) != "row":
            continue
        cells = {}
        for c in row:
            if nsstrip(c.tag) != "c":
                continue
            r = c.attrib.get("r", "")
            m = re.match(r"([A-Z]+)([0-9]+)", r)
            if not m:
                continue
            col_letters = m.group(1)
            col_idx = col_to_index(col_letters)
            v_elem = c.find(".//{*}v")
            if v_elem is None or v_elem.text is None:
                text = ""
            else:
                if c.attrib.get("t") == "s":
                    si = int(v_elem.text)
                    text = shared[si]
                else:
                    text = v_elem.text
            cells[col_idx] = text
        if cells:
            # collect first 10 columns for convenience
            row_vals = [cells.get(i, "") for i in range(1, 11)]
            rows.append(row_vals)

# Header row is like: ['', '', '', '', '', 'evosuite', 'evosuite_def', 'npetest', '', '']
if not rows:
    raise SystemExit("No rows parsed from npedetection (2)")

suite_col = 0   # column A: benchmark suite name
ev_col = 5      # column F: evosuite reproduction rate (%)
evd_col = 6     # column G: evosuite_def reproduction rate (%)

per_suite = {
    'NPEX': {'evosuite': [], 'evosuite_def': []},
    'BugSwarm': {'evosuite': [], 'evosuite_def': []},
    'Defects4J': {'evosuite': [], 'evosuite_def': []},
    'Genesis': {'evosuite': [], 'evosuite_def': []},
    'Bears': {'evosuite': [], 'evosuite_def': []},
}
all_evo = []
all_evo_def = []

for r in rows[1:]:
    suite = r[suite_col]
    if suite not in per_suite:
        continue
    ev_s = r[ev_col]
    evd_s = r[evd_col]
    if ev_s == "" and evd_s == "":
        continue
    try:
        ev = float(ev_s) if ev_s != "" else 0.0
        evd = float(evd_s) if evd_s != "" else 0.0
    except ValueError:
        continue
    per_suite[suite]['evosuite'].append(ev)
    per_suite[suite]['evosuite_def'].append(evd)
    all_evo.append(ev)
    all_evo_def.append(evd)

def avg(vals):
    return sum(vals) / len(vals) if vals else 0.0

order = ['NPEX','BugSwarm','Defects4J','Genesis','Bears']

evo_vals = []
evo_def_vals = []
for s in order:
    evo_vals.append(avg(per_suite[s]['evosuite']))
    evo_def_vals.append(avg(per_suite[s]['evosuite_def']))

# Overall averages across all NPEs
evo_vals.append(avg(all_evo))
evo_def_vals.append(avg(all_evo_def))

def fmt(vals):
    # Round to one decimal and format with percent sign
    return ["%.1f%%" % round(v, 1) for v in vals]

evo_fmt = fmt(evo_vals)
evo_def_fmt = fmt(evo_def_vals)

# Emit the markdown table in the exact structure of Table 4
print("**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**")
print()
print("| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |")
print("| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |")
print(f"| EvoSuite       | {evo_fmt[0]} |    {evo_fmt[1]} |     {evo_fmt[2]} |   {evo_fmt[3]} | {evo_fmt[4]} | {evo_fmt[5]} |")
print(f"| EvoSuite_{{Def}} | {evo_def_fmt[0]} |    {evo_def_fmt[1]} |     {evo_def_fmt[2]} |   {evo_def_fmt[3]} | {evo_def_fmt[4]} | {evo_def_fmt[5]} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
