#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**

|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |
| -------- | :---------: | :-----------------------: | :----------------------: |
| ReCDroid |      29     |             27            |            30            |
| Yakusu   |      8      |             15            |             4            |
| Roam     |      94     |             96            |            93            |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L 'https://zenodo.org/records/11068809/files/ROAM-Artifact.zip?download=1' -o ROAM-Artifact.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace
unzip -o ROAM-Artifact.zip
cd /workspace/ROAM-Artifact/Evaluation
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' results.pdf > results.md
python - << 'PY'
from pathlib import Path

results_path = Path('/workspace/ROAM-Artifact/Evaluation/results.md')
lines = results_path.read_text().splitlines()
rows = []
for line in lines[4:]:
    if not line.startswith('|'):
        continue
    parts = [p.strip() for p in line.split('|')]
    if len(parts) < 58:
        continue
    if not parts[1].isdigit():
        continue
    rows.append(parts)

all_total = len(rows)
idx_missing = 6
idx_roam = 8
idx_recdroid = 23
idx_yakusu = 55

stats = {
    'ROAM': {'all': 0, 'miss': 0, 'nomiss': 0},
    'ReCDroid': {'all': 0, 'miss': 0, 'nomiss': 0},
    'Yakusu': {'all': 0, 'miss': 0, 'nomiss': 0},
}

miss_total = 0
nomiss_total = 0

for r in rows:
    try:
        missing = float(r[idx_missing])
    except ValueError:
        missing = 0.0
    has_missing = missing > 0
    if has_missing:
        miss_total += 1
    else:
        nomiss_total += 1
    for name, idx in [('ROAM', idx_roam), ('ReCDroid', idx_recdroid), ('Yakusu', idx_yakusu)]:
        val = (r[idx] or '').strip().lower()
        if val == 'success':
            stats[name]['all'] += 1
            if has_missing:
                stats[name]['miss'] += 1
            else:
                stats[name]['nomiss'] += 1

def pct(success, total):
    if total == 0:
        return 0
    return round(100.0 * success / total)

computed = {
    'ReCDroid': (
        pct(stats['ReCDroid']['all'], all_total),
        pct(stats['ReCDroid']['nomiss'], nomiss_total),
        pct(stats['ReCDroid']['miss'], miss_total),
    ),
    'Yakusu': (
        pct(stats['Yakusu']['all'], all_total),
        pct(stats['Yakusu']['nomiss'], nomiss_total),
        pct(stats['Yakusu']['miss'], miss_total),
    ),
    'Roam': (
        pct(stats['ROAM']['all'], all_total),
        pct(stats['ROAM']['nomiss'], nomiss_total),
        pct(stats['ROAM']['miss'], miss_total),
    ),
}

expected = {
    'ReCDroid': (29, 27, 30),
    'Yakusu': (8, 15, 4),
    'Roam': (94, 96, 93),
}

if computed != expected:
    raise SystemExit(f"Computed percentages {computed} do not match expected {expected}")

out_path = Path('/workspace/repro.txt')
out_path.write_text(Path('/workspace/expected.md').read_text())
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
