#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Demographics of our dataset of 107 Java projects**

|                           |    Q1 |  Q2 |   Q3 | min |     max |
| ------------------------- | ----: | --: | ---: | --: | ------: |
| (p)’s direct dependencies |   ?.? |   ? |    ? |   ? |      ?? |
| releases ((N_R))          |   ??? | ??? | ???? |  ?? |  ??,??? |
| libraries ((N_L))         |  ??.? |  ?? |  ??? |   ? |     ??? |
| dependency edges ((E_D))  | ???.? | ??? | ???? |   ? | ???,??? |
| versions edges ((E_V))    |   ??? | ??? | ???? |  ?? |  ??,??? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/13741330 || true

# Section 3: Reproduction commands (nearest-rank percentiles)
python3 - <<'PY' > /workspace/repro.txt
import csv, glob, math

pattern = "ASE24_data_and_tools/ASE24_data_and_tools/results_data/execution/*/executionsData.csv"
files = glob.glob(pattern)
projects = {}
fields = {
    'direct': 'directDepNumber',
    'releases': 'releaseSize',
    'libraries': 'artifactSize',
    'dependency_edges': 'dependencySize',
    'version_edges': 'versionSize'
}

for f in files:
    try:
        with open(f, newline='', encoding='utf-8') as fh:
            reader = csv.DictReader(fh)
            for row in reader:
                name = row.get('name') or row.get('repoName')
                if not name:
                    continue
                if name in projects:
                    continue
                try:
                    projects[name] = {
                        'direct': int(row.get(fields['direct'],0) or 0),
                        'releases': int(row.get(fields['releases'],0) or 0),
                        'libraries': int(row.get(fields['libraries'],0) or 0),
                        'dependency_edges': int(row.get(fields['dependency_edges'],0) or 0),
                        'version_edges': int(row.get(fields['version_edges'],0) or 0)
                    }
                except ValueError:
                    continue
    except FileNotFoundError:
        continue

def nearest_rank(sorted_list, p):
    # nearest-rank method: rank = ceil(p * n), 1-based. Return element at rank-1.
    n = len(sorted_list)
    if n == 0:
        return 0.0
    rank = math.ceil(p * n)
    # ensure within [1,n]
    rank = max(1, min(n, rank))
    return float(sorted_list[rank-1])

def fmt_q(x):
    if abs(x - round(x)) < 1e-9:
        return f"{int(round(x))}"
    return f"{x:.1f}"

def fmt_int_commas(x):
    return f"{int(x):,}"

vals = {k: sorted([v[k] for v in projects.values()]) for k in ['direct','releases','libraries','dependency_edges','version_edges']}

stats = {}
for k,l in vals.items():
    if not l:
        stats[k] = (0,0,0,0,0)
    else:
        q1 = nearest_rank(l, 0.25)
        q2 = nearest_rank(l, 0.5)
        q3 = nearest_rank(l, 0.75)
        mn = min(l)
        mx = max(l)
        stats[k] = (q1,q2,q3,mn,mx)

out = []
out.append("**Table 2: Demographics of our dataset of {n} Java projects**\\n".format(n=len(projects)))
out.append("|                           |    Q1 |  Q2 |   Q3 | min |     max |")
out.append("| ------------------------- | ----: | --: | ---: | --: | ------: |")

q1,q2,q3,mn,mx = stats['direct']
out.append("| (p)’s direct dependencies | {q1} | {q2} | {q3} | {mn} | {mx} |".format(
    q1=fmt_q(q1), q2=fmt_q(q2), q3=fmt_q(q3), mn=fmt_q(mn), mx=fmt_q(mx)
))

q1,q2,q3,mn,mx = stats['releases']
out.append("| releases ((N_R))          | {q1} | {q2} | {q3} | {mn} | {mx} |".format(
    q1=fmt_q(q1), q2=fmt_q(q2), q3=fmt_q(q3), mn=fmt_int_commas(mn), mx=fmt_int_commas(mx)
))

q1,q2,q3,mn,mx = stats['libraries']
out.append("| libraries ((N_L))         | {q1} | {q2} | {q3} | {mn} | {mx} |".format(
    q1=fmt_q(q1), q2=fmt_q(q2), q3=fmt_q(q3), mn=fmt_int_commas(mn), mx=fmt_int_commas(mx)
))

q1,q2,q3,mn,mx = stats['dependency_edges']
out.append("| dependency edges ((E_D))  | {q1} | {q2} | {q3} | {mn} | {mx} |".format(
    q1=fmt_q(q1), q2=fmt_q(q2), q3=fmt_q(q3), mn=fmt_int_commas(mn), mx=fmt_int_commas(mx)
))

q1,q2,q3,mn,mx = stats['version_edges']
out.append("| versions edges ((E_V))    | {q1} | {q2} | {q3} | {mn} | {mx} |".format(
    q1=fmt_q(q1), q2=fmt_q(q2), q3=fmt_q(q3), mn=fmt_int_commas(mn), mx=fmt_int_commas(mx)
))

print("\\n".join(out))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
