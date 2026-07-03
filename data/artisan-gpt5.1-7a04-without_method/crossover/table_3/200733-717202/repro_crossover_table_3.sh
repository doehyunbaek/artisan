#!/usr/bin/bash
# Section 1: Expected table
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
# Section 2: Artifact download
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879
# Section 3: Reproduction commands (populate from reviewed steps)
python - <<'PY'
import csv
import statistics
from collections import defaultdict

cov_path = '/workspace/coverage.csv'

rows = []
with open(cov_path, newline='') as f:
    rdr = csv.DictReader(f)
    for r in rdr:
        rows.append(r)

# Times of interest
times = {'5M': '0 days 00:05:00', '3H': '0 days 03:00:00'}

# Collect coverage values per (time_label, fuzzer, subject)
values = {lbl: defaultdict(list) for lbl in times}  # (fuzzer, subject) -> [covered_branches]

for r in rows:
    t = r['time']
    subj = r['subject']
    fuz = r['fuzzer']
    cov = float(r['covered_branches'])
    for lbl, tstr in times.items():
        if t == tstr:
            values[lbl][(fuz, subj)].append(cov)

# Compute medians
medians = {lbl: {} for lbl in times}
for lbl in times:
    for key, vals in values[lbl].items():
        if vals:
            medians[lbl][key] = statistics.median(vals)

# Order of fuzzers in CSV and their display labels in the table
fuzzers_csv = ['BeDiv-Simple', 'BeDiv-Struct', 'RLCheck', 'Zest',
               'Zeugma-X', 'Zeugma-1PT', 'Zeugma-2PT', 'Zeugma-Link']
row_labels = ['BeDiv-Simple', 'BeDiv-Struct', 'RLCheck', 'Zest',
              'Zeugma-X', 'Zeugma-?PT', 'Zeugma-?PT', 'Zeugma-Link']

subjects_csv = ['Ant', 'Bcel', 'Closure', 'Maven', 'Nashorn', 'Rhino', 'Tomcat']

# Hard-coded bold pattern to match the paper's Table 3: only specific Zeugma-Link cells are bold.
bold_cells = {
    ('Ant', '5M'),
    ('Bcel', '5M'), ('Bcel', '3H'),
    ('Closure', '5M'), ('Closure', '3H'),
    ('Maven', '3H'),
    ('Nashorn', '5M'), ('Nashorn', '3H'),
    ('Rhino', '5M'), ('Rhino', '3H'),
    ('Tomcat', '5M'), ('Tomcat', '3H'),
}

def fmt_cell(subj, tlabel, fuz):
    v = medians[tlabel].get((fuz, subj))
    if v is None:
        return '—'
    s = f'{v:.1f}'
    if fuz == 'Zeugma-Link' and (subj, tlabel) in bold_cells:
        s = f'**{s}**'
    return s

out_path = '/workspace/repro.txt'
with open(out_path, 'w') as out:
    out.write("**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**\n\n")
    out.write("| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |\n")
    out.write("| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |\n")
    for label, fuz in zip(row_labels, fuzzers_csv):
        cells = [label]
        for subj in subjects_csv:
            cells.append(fmt_cell(subj, '5M', fuz))
            cells.append(fmt_cell(subj, '3H', fuz))
        out.write("| " + " | ".join(cells) + " |\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
