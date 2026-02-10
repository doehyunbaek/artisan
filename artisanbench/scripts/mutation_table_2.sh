#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o getsankeyamd.tar \
  https://zenodo.org/api/records/10505175/files/getsankeyamd.tar/content

docker load -i getsankeyamd.tar
docker run -d --init --name sankeyamd --entrypoint bash qinfendeheichi/getsankeyamd:v1 -c 'sleep infinity'
docker exec sankeyamd /bin/bash --noprofile --norc -c "python3 RQ2Script.py" > /workspace/rq2_raw.txt

python - <<'PY'
from pathlib import Path
import re

rq2_path = Path("/workspace/rq2_raw.txt")
expected_path = Path("/workspace/expected.md")
out_path = Path("/workspace/repro.txt")

if not rq2_path.is_file():
    raise SystemExit(f"Missing RQ2 output at {rq2_path}")

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

def ensure_expected_lines() -> list[str]:
    """
    If expected.md is present, use it.
    Otherwise generate the SAME markdown structure as the benchmark table.
    """
    if expected_path.is_file():
        return [ln.rstrip("\n") for ln in expected_path.read_text(encoding="utf-8").splitlines()]

    # Benchmark-format Table 2
    title = "**Table 2: Method Exit Anomalies**"
    blank = ""

    header = "| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |"
    sep    = "| ----------------- | --------------: | --------------: | -----------------: |"

    # Placeholders should include padding so format_cell can keep alignment.
    # Keep the same spacing style as the benchmark (right-aligned numeric columns).
    placeholder_failed = "              0 (0.00%) "
    placeholder_anom   = "              0 (0.00%) "
    placeholder_src    = "              0 (0.00%) "

    body = []
    for p in expected_prog_order:
        # Program column width in benchmark is 17 chars after the leading space.
        body.append(
            f"| {p:<17} |{placeholder_failed}|{placeholder_anom}|{placeholder_src}|"
        )

    return [title, blank, header, sep, *body]

expected_lines = ensure_expected_lines()
result_lines = []

def format_cell(old: str, value: str, pct: float) -> str:
    lead = len(old) - len(old.lstrip(" "))
    trail = len(old) - len(old.rstrip(" "))
    inner = f"{value} ({pct:0.2f}%)"
    return " " * lead + inner + " " * trail

for line in expected_lines:
    new_line = line
    # Patch only data rows (skip header/separator)
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

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
