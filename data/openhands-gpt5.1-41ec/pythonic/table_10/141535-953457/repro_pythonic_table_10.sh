#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 10: Reasons for using functional and procedural code**

| Reason                        | Lambdas | Comp. | MRF | Proc. |
| ----------------------------- | ------: | ----: | --: | ----: |
| Coding time                   |      11 |    12 |  10 |     2 |
| Ease of use                   |       4 |    10 |   8 |     7 |
| Maintainability               |      14 |     9 |  14 |     6 |
| Performance                   |       7 |    28 |  23 |     6 |
| Readability/Understandability |      19 |    89 |  33 |    27 |
| Size                          |      41 |    76 |  39 |     — |
| Lack of knowledge             |       — |     — |   — |    16 |
| Project constraints           |       — |     — |   — |     5 |
| Simplify debugging            |       — |     — |   — |     9 |

EOTABLE

# Section 2: Artifact download
cd /workspace
if [ ! -f ICSE2024-funcConstructs-Artifacts.zip ]; then
  curl -L https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip -o ICSE2024-funcConstructs-Artifacts.zip
fi
if [ ! -d ICSE2024-funcConstructs-Artifacts ]; then
  unzip -o ICSE2024-funcConstructs-Artifacts.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts
python - << 'PY'
import subprocess, csv, io, collections, os

xlsx_path = os.path.join('/workspace','ICSE2024-funcConstructs-Artifacts','working-results','RQ3ManualValidation.xlsx')

sheets = ["Lambda","Comprehension","MRF","Procedural"]
reasons = [
    "Coding time",
    "Ease of use",
    "Maintainability",
    "Performance",
    "Readability/Understandability",
    "Size",
    "Lack of knowledge",
    "Project constraints",
    "Simplify debugging",
]

def normalize(s: str) -> str:
    return " ".join((s or "").strip().lower().split())

mapping = {
    "coding time": "Coding time",
    "ease of use": "Ease of use",
    "maintainability": "Maintainability",
    "performance": "Performance",
    "readability/understandability": "Readability/Understandability",
    "size": "Size",
    "lack of knowledge": "Lack of knowledge",
    "project constraint": "Project constraints",
    "project constraints": "Project constraints",
    "debugging is easier": "Simplify debugging",
    "simplify debugging": "Simplify debugging",
}


def get_counts(sheet: str):
    cmd = ["uvx","--from","csvkit","in2csv","--sheet",sheet,xlsx_path]
    csv_bytes = subprocess.check_output(cmd)
    text = csv_bytes.decode("utf-8", errors="replace")
    reader = csv.DictReader(io.StringIO(text))
    counts = collections.Counter()
    for row in reader:
        raw = row.get("Final Classification") or ""
        key = normalize(raw)
        if not key:
            continue
        canon = mapping.get(key)
        if canon is None:
            # Ignore categories that are not part of Table 10
            continue
        counts[canon] += 1
    return counts

all_counts = {sheet: get_counts(sheet) for sheet in sheets}


def val(reason: str, sheet: str) -> str:
    if reason in ["Lack of knowledge","Project constraints","Simplify debugging"] and sheet != "Procedural":
        return "—"
    if reason == "Size" and sheet == "Procedural":
        return "—"
    cnt = all_counts[sheet].get(reason, 0)
    return str(cnt) if cnt > 0 else "—"

lines = [
    "**Table 10: Reasons for using functional and procedural code**",
    "",
    "| Reason                        | Lambdas | Comp. | MRF | Proc. |",
    "| ----------------------------- | ------: | ----: | --: | ----: |",
]

for reason in reasons:
    row = "| {reason:<27} | {lam:>6} | {comp:>4} | {mrf:>3} | {proc:>4} |".format(
        reason=reason,
        lam=val(reason,"Lambda"),
        comp=val(reason,"Comprehension"),
        mrf=val(reason,"MRF"),
        proc=val(reason,"Procedural"),
    )
    lines.append(row)

output_path = "/workspace/repro.txt"
with open(output_path,"w",encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
