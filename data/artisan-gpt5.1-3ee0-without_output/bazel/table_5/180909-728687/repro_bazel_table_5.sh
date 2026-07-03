#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5. Build technologies adopted after Bazel abandonment**

| Domain    | Build Technology   | # Projects | Language(s)                    |
| --------- | ------------------ | ---------: | ------------------------------ |
| D1        | Go Build           |         28 | Go                             |
| D1        | SPM                |          2 | Swift                          |
| D1        | Mage               |          1 | Go                             |
| D1        | SBT                |          1 | Scala                          |
| D1        | Gradle             |          1 | Java                           |
| D1        | Setuptools         |          1 | Python                         |
| D2        | CMake              |         11 | C++, Go, Python, Shell         |
| D2        | Make               |          8 | Go, JavaScript, C              |
| D3        | Nix                |          3 | Go, TypeScript, Scala, Haskell |
| D3        | Google Cloud Build |          5 | Go                             |
| **Total** |                    |     **61** |                                |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10553683
# Section 3: Reproduction commands (populate from reviewed steps)
# Convert the "Labeled data" sheet to CSV
uvx --from csvkit in2csv build-downgrade/build-downgrade/study/3.thematic-analysis/bazel-abandonment-labels.xlsx --sheet "Labeled data" > /workspace/bazel_abandonment_labeled.csv
# Derive the reproduced table from the labeled data
python - << 'PY'
import csv, collections, pathlib, textwrap

path = pathlib.Path("/workspace/bazel_abandonment_labeled.csv")
counts = collections.Counter()

with path.open() as f:
    reader = csv.DictReader(f)
    for row in reader:
        raw = (row.get("replaced-by") or "").strip()
        if not raw:
            continue
        low = raw.lower()
        # Map composite "CMake + MAKE (go build)" to CMake, as in the paper's narrative
        if "cmake + make" in low:
            tech = "CMake"
        elif low in {"go build", "go  build"}:
            tech = "Go Build"
        elif low == "swift pm" or low == "spm":
            tech = "SPM"
        elif low == "mage":
            tech = "Mage"
        elif low == "sbt":
            tech = "SBT"
        elif low == "gradle":
            tech = "Gradle"
        elif low == "setuptools":
            tech = "Setuptools"
        elif low.startswith("cmake"):
            tech = "CMake"
        elif low in {"make", "makefile"}:
            tech = "Make"
        elif low == "nix":
            tech = "Nix"
        elif low in {"google cloud build", "gcb"}:
            tech = "Google Cloud Build"
        else:
            tech = raw
        counts[tech] += 1

go_build = counts.get("Go Build", 0)
spm = counts.get("SPM", 0)
mage = counts.get("Mage", 0)
sbt = counts.get("SBT", 0)
gradle = counts.get("Gradle", 0)
setuptools = counts.get("Setuptools", 0)
cmake = counts.get("CMake", 0)
make = counts.get("Make", 0)
nix = counts.get("Nix", 0)
gcb = counts.get("Google Cloud Build", 0)

total = go_build + spm + mage + sbt + gradle + setuptools + cmake + make + nix + gcb

repro_md = textwrap.dedent(f"""\
**Table 5. Build technologies adopted after Bazel abandonment**

| Domain    | Build Technology   | # Projects | Language(s)                    |
| --------- | ------------------ | ---------: | ------------------------------ |
| D1        | Go Build           | {go_build} | Go                             |
| D1        | SPM                | {spm} | Swift                          |
| D1        | Mage               | {mage} | Go                             |
| D1        | SBT                | {sbt} | Scala                          |
| D1        | Gradle             | {gradle} | Java                           |
| D1        | Setuptools         | {setuptools} | Python                         |
| D2        | CMake              | {cmake} | C++, Go, Python, Shell         |
| D2        | Make               | {make} | Go, JavaScript, C              |
| D3        | Nix                | {nix} | Go, TypeScript, Scala, Haskell |
| D3        | Google Cloud Build | {gcb} | Go                             |
| **Total** |                    | {total} |                                |
""")

pathlib.Path("/workspace/repro.txt").write_text(repro_md)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
