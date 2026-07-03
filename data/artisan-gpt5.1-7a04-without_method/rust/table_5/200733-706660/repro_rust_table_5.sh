#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | 259,540 | 70,913 |
| After Mitigation  | 259,540 | 6,978 |
EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10496086
# Section 3: Reproduction commands (populate from reviewed steps)
cd Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/Code/nightly_propagation/ruf_mitigation_analysis
python - << 'PY'
import pathlib

path = pathlib.Path("results_20220811.txt")
lines = [l.strip() for l in path.read_text().splitlines() if l.strip()]

vals = {}
current = None
for line in lines:
    if line in ("Newest_version", "All versions"):
        current = line
        continue
    parts = line.split()
    if current and len(parts) == 2 and parts[0].startswith("count"):
        key = f"{current}_{parts[0]}"
        vals[key] = int(parts[1])

before_total = vals["Newest_version_count"]
before_fail = vals["Newest_version_count_failure"]
after_total = vals["All versions_count"]
after_fail = vals["All versions_count_failure"]

def fmt(n: int) -> str:
    return f"{n:,}"

table = f"""**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | {fmt(before_total)} | {fmt(before_fail)} |
| After Mitigation  | {fmt(after_total)} | {fmt(after_fail)} |
"""

pathlib.Path("/workspace/repro.txt").write_text(table)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
