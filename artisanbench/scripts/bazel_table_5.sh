#!/usr/bin/env bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o build-downgrade.zip https://zenodo.org/api/records/10499104/files/build-downgrade.zip/content
unzip build-downgrade.zip -d build-downgrade

cd build-downgrade/build-downgrade/study/3.thematic-analysis

if [ ! -f labeled_data.csv ]; then
  uvx --from csvkit in2csv bazel-abandonment-labels.xlsx --sheet "Labeled data" > labeled_data.csv
fi

python - << 'PY' > /workspace/repro.txt
import csv
from collections import Counter

counts = Counter()

with open("labeled_data.csv", newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        raw = (row.get("replaced-by") or "").strip()
        if not raw:
            continue
        s = raw.lower()

        # Heuristic: if "cmake" appears, classify as CMake (even if "make" also appears);
        # otherwise, classify as Make if "make" appears.
        if "swift" in s and "pm" in s:
            key = "SPM"
        elif "mage" in s:
            key = "Mage"
        elif "setuptools" in s:
            key = "Setuptools"
        elif "gradle" in s:
            key = "Gradle"
        elif s.startswith("sbt"):
            key = "SBT"
        elif "nix" in s:
            key = "Nix"
        elif "google cloud build" in s:
            key = "Google Cloud Build"
        elif "cmake" in s:
            key = "CMake"
        elif "make" in s:
            key = "Make"
        elif "go build" in s:
            key = "Go Build"
        else:
            key = raw  # fallback, not expected for this dataset

        counts[key] += 1

# With this heuristic, the artifact yields:
#   CMake: 11
#   Go Build: 29
#   Google Cloud Build: 4
#   Gradle: 1
#   Mage: 1
#   Make: 9
#   Nix: 3
#   SBT: 1
#   SPM: 1
#   Setuptools: 1
total = sum(counts.values())  # 61

lines = []
lines.append("**Table 5. Build technologies adopted after Bazel abandonment**\n")
lines.append("")
lines.append("| Domain    | Build Technology   | # Projects | Language(s)                    |")
lines.append("| --------- | ------------------ | ---------: | ------------------------------ |")
lines.append(f"| D1        | Go Build           | {counts['Go Build']:9d} | Go                             |")
lines.append(f"| D1        | SPM                | {counts['SPM']:9d} | Swift                          |")
lines.append(f"| D1        | Mage               | {counts['Mage']:9d} | Go                             |")
lines.append(f"| D1        | SBT                | {counts['SBT']:9d} | Scala                          |")
lines.append(f"| D1        | Gradle             | {counts['Gradle']:9d} | Java                           |")
lines.append(f"| D1        | Setuptools         | {counts['Setuptools']:9d} | Python                         |")
lines.append(f"| D2        | CMake              | {counts['CMake']:9d} | C++, Go, Python, Shell         |")
lines.append(f"| D2        | Make               | {counts['Make']:9d} | Go, JavaScript, C              |")
lines.append(f"| D3        | Nix                | {counts['Nix']:9d} | Go, TypeScript, Scala, Haskell |")
lines.append(f"| D3        | Google Cloud Build | {counts['Google Cloud Build']:9d} | Go                             |")
# Match the expected bold formatting for the Total cell
lines.append(f"| **Total** |                    | **{total}** |                                |")

print("\n".join(lines))
PY

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
