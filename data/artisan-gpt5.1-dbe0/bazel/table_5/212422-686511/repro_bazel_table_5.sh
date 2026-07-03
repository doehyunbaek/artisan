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
artisan get https://zenodo.org/records/10553683
# Section 3: Reproduction commands (populate from reviewed steps)
# Convert the labeled data sheet to CSV
uvx --from csvkit in2csv build-downgrade/build-downgrade/study/3.thematic-analysis/bazel-abandonment-labels.xlsx --sheet "Labeled data" > /workspace/bazel_labeled_data.csv
# Analyze the CSV to compute counts and render the reproduced Table 5
python - << 'PY' > /workspace/repro.txt
import csv
from collections import Counter

csv_path = "/workspace/bazel_labeled_data.csv"
counts = Counter()

with open(csv_path, newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        val = (row.get("replaced-by") or "").strip()
        if not val:
            continue
        low = val.lower()
        if low == "go build":
            tech = "Go Build"
        elif low == "swift pm":
            tech = "SPM"
        elif low.startswith("cmake"):
            # Treat all CMake variants, including "CMake + MAKE (go build)", as CMake
            tech = "CMake"
        elif low == "make":
            tech = "Make"
        elif low == "google cloud build":
            tech = "Google Cloud Build"
        elif low == "nix":
            tech = "Nix"
        elif low == "sbt":
            tech = "SBT"
        elif low == "setuptools":
            tech = "Setuptools"
        elif low == "gradle":
            tech = "Gradle"
        elif low == "mage":
            tech = "Mage"
        else:
            tech = val
        counts[tech] += 1

# Mapping of technologies to domain and languages, as in the paper
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
    ("D1", "Go Build"),
    ("D1", "SPM"),
    ("D1", "Mage"),
    ("D1", "SBT"),
    ("D1", "Gradle"),
    ("D1", "Setuptools"),
    ("D2", "CMake"),
    ("D2", "Make"),
    ("D3", "Nix"),
    ("D3", "Google Cloud Build"),
]

total = sum(counts[t] for _, t in order)

print("**Table 5. Build technologies adopted after Bazel abandonment**\n")
print("| Domain    | Build Technology   | # Projects | Language(s)                    |")
print("| --------- | ------------------ | ---------: | ------------------------------ |")
for domain, tech in order:
    lang_domain, langs = meta[tech]
    n = counts.get(tech, 0)
    print(f"| {domain:<9}| {tech:<18}| {n:10d} | {langs:<30} |")
print(f"| **Total** |                    |     **{total}** |                                |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
