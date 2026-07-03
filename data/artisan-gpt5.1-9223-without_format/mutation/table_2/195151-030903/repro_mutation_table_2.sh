#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Method Exit Anomalies**

| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |
| ----------------- | --------------: | --------------: | -----------------: |
| commons-cli       | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| commons-text      | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| joda-money        | ??,??? (??.??%) | ??,??? (??.??%) |     ?,??? (??.??%) |
| jline-reader      | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| commons-validator | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| cdk-data          | ??,??? (??.??%) | ??,??? (??.??%) |     ?,??? (??.??%) |
| spotify-web-api   |  ?,??? (??.??%) |    ??? (??.??%) |          ? (?.??%) |
| commons-codec     | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| jfreechart        | ??,??? (??.??%) | ??,??? (??.??%) |    ??,??? (??.??%) |
| dyn4j             | ??,??? (??.??%) | ??,??? (??.??%) |    ??,??? (??.??%) |

EOTABLE

# Section 2: Artifact download
cd /workspace
artisan get https://zenodo.org/records/10505175 > artisan_get.log 2>&1

# Section 3: Reproduction commands (populate from reviewed steps)

# Load the getsankey AMD image and start a long-running container
docker load -i getsankeyamd.tar
docker run -d --init --name sankeyamd --entrypoint bash qinfendeheichi/getsankeyamd:v1 -c 'sleep infinity'

# Run the RQ2 script inside the container; this prints the numbers used in Table 2
docker exec sankeyamd /bin/bash --noprofile --norc -c "python3 RQ2Script.py" > /workspace/rq2_raw.txt

# Parse the RQ2 output and inject values into expected.md placeholders, preserving all non-digit formatting
python - <<'PY'
from pathlib import Path
import re

rq2_path = Path("/workspace/rq2_raw.txt")
expected_path = Path("/workspace/expected.md")
out_path = Path("/workspace/repro.txt")

if not rq2_path.is_file():
    raise SystemExit(f"Missing RQ2 output at {rq2_path}")
if not expected_path.is_file():
    raise SystemExit(f"Missing expected table at {expected_path}")

lines = [ln.rstrip("\n") for ln in rq2_path.read_text(encoding="utf-8").splitlines() if ln.strip()]

pat = re.compile(
    r"""^(?P<prog>[A-Za-z0-9\-]+)\s+
        (?P<total>[\d,]+)\s+
        (?P<failed>[\d,]+)\s*\(\s*(?P<failed_pct>[\d.]+)%\s*\)\s+
        (?P<anom>[\d,]+)\s*\(\s*(?P<anom_pct>[\d.]+)%\s*\)\s+
        (?P<src>[\d,]+)\s*\(\s*(?P<src_pct>[\d.]+)%\s*\)\s*$
    """,
    re.X,
)

rows = {}
for line in lines:
    m = pat.match(line)
    if not m:
        raise SystemExit(f"Could not parse RQ2 output line: {line!r}")
    d = m.groupdict()
    prog = d["prog"]
    rows[prog] = {
        "failed": d["failed"],
        "failed_pct": float(d["failed_pct"]),
        "anom": d["anom"],
        "anom_pct": float(d["anom_pct"]),
        "src": d["src"],
        "src_pct": float(d["src_pct"]),
    }

expected_prog_order = [
    "commons-cli",
    "commons-text",
    "joda-money",
    "jline-reader",
    "commons-validator",
    "cdk-data",
    "spotify-web-api",
    "commons-codec",
    "jfreechart",
    "dyn4j",
]

for p in expected_prog_order:
    if p not in rows:
        raise SystemExit(f"Program {p!r} not found in RQ2 output; available: {list(rows.keys())}")

expected_lines = [ln.rstrip("\n") for ln in expected_path.read_text(encoding="utf-8").splitlines()]
result_lines = []

def format_cell(old: str, value: str, pct: float) -> str:
    lead = len(old) - len(old.lstrip(" "))
    trail = len(old) - len(old.rstrip(" "))
    inner = f"{value} ({pct:0.2f}%)"
    return " " * lead + inner + " " * trail

for line in expected_lines:
    new_line = line
    if line.strip().startswith("|") and "Program Name" not in line and "--------------" not in line:
        parts = line.split("|")
        if len(parts) >= 6:
            prog = parts[1].strip()
            if prog in rows:
                d = rows[prog]
                parts[2] = format_cell(parts[2], d["failed"], d["failed_pct"])
                parts[3] = format_cell(parts[3], d["anom"], d["anom_pct"])
                parts[4] = format_cell(parts[4], d["src"], d["src_pct"])
                new_line = "|".join(parts)
    result_lines.append(new_line)

out_path.write_text("\n".join(result_lines) + "\n", encoding="utf-8")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
