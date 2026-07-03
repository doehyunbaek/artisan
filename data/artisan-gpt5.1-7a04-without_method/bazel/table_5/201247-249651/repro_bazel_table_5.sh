#!/usr/bin/bash
# Section 1: Expected table (structure only; digits redacted)
cat > /workspace/expected.md <<'EOTABLE'
**Table 5. Build technologies adopted after Bazel abandonment**

| Domain    | Build Technology   | # Projects | Language(s)                    |
| --------- | ------------------ | ---------: | ------------------------------ |
| D1        | Go Build           |         ?? | Go                             |
| D1        | SPM                |          ? | Swift                          |
| D1        | Mage               |          ? | Go                             |
| D1        | SBT                |          ? | Scala                          |
| D1        | Gradle             |          ? | Java                           |
| D1        | Setuptools         |          ? | Python                         |
| D2        | CMake              |         ?? | C++, Go, Python, Shell         |
| D2        | Make               |          ? | Go, JavaScript, C              |
| D3        | Nix                |          ? | Go, TypeScript, Scala, Haskell |
| D3        | Google Cloud Build |          ? | Go                             |
| **Total** |                    |     **??** |                                |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10553683
# Section 3: Reproduction commands: derive counts from labeled data
# Use the pre-extracted labeled CSV if present; otherwise, create it.
if [ ! -f /workspace/bazel_labeled.csv ]; then
  uvx --from csvkit in2csv --sheet "Labeled data" build-downgrade/build-downgrade/study/3.thematic-analysis/bazel-abandonment-labels.xlsx > /workspace/bazel_labeled.csv
fi

python - <<'PY' > /workspace/repro.txt
import csv
from collections import Counter

path = "/workspace/bazel_labeled.csv"
counts_raw = Counter()
with open(path, newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        v = (row.get("replaced-by") or "").strip()
        if not v:
            continue
        counts_raw[v] += 1

# Normalize to canonical build-technology labels used in Table 5.
norm = Counter()
for val, c in counts_raw.items():
    v = val.strip()
    if v in ("Go Build", "Go build"):
        norm["Go Build"] += c
    elif v == "Swift PM":
        norm["SPM"] += c
    elif v == "Mage":
        norm["Mage"] += c
    elif v == "SBT":
        norm["SBT"] += c
    elif v == "Setuptools":
        norm["Setuptools"] += c
    elif v == "Gradle":
        norm["Gradle"] += c
    elif v.startswith("CMake"):
        # Treat bare "CMake" and "CMake + MAKE (go build)" as CMake.
        norm["CMake"] += c
    elif v == "Make":
        norm["Make"] += c
    elif v == "Nix":
        norm["Nix"] += c
    elif v.lower() == "google cloud build":
        norm["Google Cloud Build"] += c
    else:
        # Ignore anything that is clearly not a build technology name.
        continue

total = sum(norm.values())

# Helper to get count with default 0
g = lambda k: norm.get(k, 0)

print("**Table 5. Build technologies adopted after Bazel abandonment**\n")
print("| Domain    | Build Technology   | # Projects | Language(s)                    |")
print("| --------- | ------------------ | ---------: | ------------------------------ |")
print(f"| D1        | Go Build           |{g('Go Build'):11d} | Go                             |")
print(f"| D1        | SPM                |{g('SPM'):11d} | Swift                          |")
print(f"| D1        | Mage               |{g('Mage'):11d} | Go                             |")
print(f"| D1        | SBT                |{g('SBT'):11d} | Scala                          |")
print(f"| D1        | Gradle             |{g('Gradle'):11d} | Java                           |")
print(f"| D1        | Setuptools         |{g('Setuptools'):11d} | Python                         |")
print(f"| D2        | CMake              |{g('CMake'):11d} | C++, Go, Python, Shell         |")
print(f"| D2        | Make               |{g('Make'):11d} | Go, JavaScript, C              |")
print(f"| D3        | Nix                |{g('Nix'):11d} | Go, TypeScript, Scala, Haskell |")
print(f"| D3        | Google Cloud Build |{g('Google Cloud Build'):11d} | Go                             |")
print(f"| **Total** |                    |     **{total}** |                                |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
