#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5. Build technologies adopted after Bazel abandonment**

| Domain    | Build Technology   | # Projects | Language(s)                    |
| --------- | ------------------ | ---------: | ------------------------------ |
| D1        | Go Build           |         29 | Go                             |
| D1        | SPM                |          1 | Swift                          |
| D1        | Mage               |          1 | Go                             |
| D1        | SBT                |          1 | Scala                          |
| D1        | Gradle             |          1 | Java                           |
| D1        | Setuptools         |          1 | Python                         |
| D2        | CMake              |         11 | C++, Go, Python, Shell         |
| D2        | Make               |          9 | Go, JavaScript, C              |
| D3        | Nix                |          3 | Go, TypeScript, Scala, Haskell |
| D3        | Google Cloud Build |          4 | Go                             |
| **Total** |                    |     **61** |                                |

EOTABLE

# Section 2: Artifact download
cd /workspace
curl -L -o artifact.zip https://zenodo.org/api/records/10553683/files-archive
mkdir -p artifact
unzip -q -o artifact.zip -d artifact
mkdir -p artifact/build-downgrade
unzip -q -o artifact/build-downgrade.zip -d artifact/build-downgrade

# Section 3: Reproduction commands (populate from reviewed steps)
# 3.1 Extract the "Labeled data" sheet that contains Bazel abandonment replacements.
uvx --from csvkit in2csv --sheet "Labeled data" \
  /workspace/artifact/build-downgrade/build-downgrade/study/3.thematic-analysis/bazel-abandonment-labels.xlsx \
  > /workspace/labeled_bazel_abandonment.csv

# 3.2 Derive Table 5 from the labeled data by normalizing replacement names,
#     aggregating counts, and attaching domain and language metadata.
python - <<'PY'
from pathlib import Path
import csv
from collections import Counter

labeled_path = Path("/workspace/labeled_bazel_abandonment.csv")
rows = list(csv.DictReader(labeled_path.open(newline='', encoding='utf-8')))

counts = Counter()
for r in rows:
    raw = (r.get("replaced-by") or "").strip()
    if not raw:
        continue
    lower = raw.lower()
    if lower.startswith("go build"):
        canon = "Go Build"
    elif lower.startswith("swift pm"):
        canon = "SPM"
    elif lower == "mage":
        canon = "Mage"
    elif lower == "sbt":
        canon = "SBT"
    elif lower == "gradle":
        canon = "Gradle"
    elif lower == "setuptools":
        canon = "Setuptools"
    elif lower.startswith("cmake"):
        # includes variants with whitespace and "CMake + MAKE (go build)"
        canon = "CMake"
    elif lower == "make":
        canon = "Make"
    elif lower == "nix":
        canon = "Nix"
    elif lower.startswith("google cloud build"):
        canon = "Google Cloud Build"
    else:
        canon = raw
    counts[canon] += 1

meta = {
    "Go Build": ("D1", "Go"),
    "SPM": ("D1", "Swift"),
    "Mage": ("D1", "Go"),
    "SBT": ("D1", "Scala"),
    "Gradle": ("D1", "Java"),
    "Setuptools": ("D1", "Python"),
    "CMake": ("D2", "C++, Go, Python, Shell"),
    "Make": ("D2", "Go, JavaScript, C"),
    "Nix": ("D3", "Go, TypeScript, Scala, Haskell"),
    "Google Cloud Build": ("D3", "Go"),
}

order = [
    "Go Build",
    "SPM",
    "Mage",
    "SBT",
    "Gradle",
    "Setuptools",
    "CMake",
    "Make",
    "Nix",
    "Google Cloud Build",
]

total = sum(counts.values())

lines = []
lines.append("**Table 5. Build technologies adopted after Bazel abandonment**")
lines.append("")
lines.append("| Domain    | Build Technology   | # Projects | Language(s)                    |")
lines.append("| --------- | ------------------ | ---------: | ------------------------------ |")
for name in order:
    domain, langs = meta[name]
    n = counts.get(name, 0)
    lines.append(f"| {domain:<8} | {name:<18} | {n:9d} | {langs:<28} |")
lines.append(f"| **Total** |                    |     **{total}** |                                |")

Path("/workspace/repro.txt").write_text("\n".join(lines), encoding="utf-8")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
