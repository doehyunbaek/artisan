#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o Unimocg_Artifact.zip https://zenodo.org/api/records/10890011/files/Unimocg_Artifact.zip/content
unzip Unimocg_Artifact.zip -d Unimocg_Artifact
cd /workspace/Unimocg_Artifact && python3 docker/runner/aggregate_fingerprints.py evaluation/fingerprints/*.profile > /workspace/repro.txt
echo '<artisan_submit>'
python3 - <<'PY'
import os
import re

repro_path = "/workspace/repro.txt"

# Parse aggregate_fingerprints.py output
raw_results = {}
current = None

with open(repro_path, "r", encoding="utf-8") as f:
    for raw in f:
        line = raw.strip()
        if not line:
            continue
        if line.endswith(".profile"):
            current = line
            raw_results[current] = {}
        elif current is None:
            continue
        elif line.startswith("Sum (out of"):
            m = re.match(r"Sum \(out of (\d+)\): (\d+) \(([^)]+)\)", line)
            if m:
                raw_results[current]["_sum_total"] = int(m.group(1))
                raw_results[current]["_sum_passed"] = int(m.group(2))
                # we ignore m.group(3) and recompute percentages ourselves
        elif ":" in line and not line.startswith("=") and not line.startswith("-"):
            cat, val = [p.strip() for p in line.split(":", 1)]
            if "/" in val:
                raw_results[current][cat] = val

# Normalize keys to basenames so we can refer to, e.g., "WALA-CHA.profile"
results = {}
for k, v in raw_results.items():
    base = os.path.basename(k)
    results[base] = v

# Profiles/columns for Table 1
profiles = [
    ("WALA — CHA",   "WALA-CHA.profile"),
    ("WALA — RTA",   "WALA-RTA.profile"),
    ("WALA — 0-CFA", "WALA-0-CFA.profile"),
    ("Soot — CHA",   "Soot-CHA.profile"),
    ("Soot — RTA",   "Soot-RTA.profile"),
    ("Soot — SPARK", "Soot-SPARK.profile"),
]

# Ensure all required profiles were parsed
missing = [p for _, p in profiles if p not in results]
if missing:
    raise SystemExit(f"Missing profiles in aggregate output: {missing}")

# Features in desired row order: (aggregate key, display label)
features = [
    ("Non-virtual Calls",            "Non-virtual Calls"),
    ("Virtual Calls",                "Virtual Calls"),
    ("Types",                        "Types"),
    ("Static Initializer",           "Static Initializer"),
    ("Java 8 Interfaces",            "Java 8 Interfaces"),
    ("Unsafe",                       "Unsafe"),
    ("Class.forName",                "Class.forName"),
    ("Signature Polymorphic Methods","Sign. Polymorph."),
    ("Java 9+",                      "Java 9+"),
    ("Non-Java",                     "Non-Java"),
    ("MethodHandle",                 "MethodHandle"),
    ("Invokedynamic",                "Invokedynamic"),
    ("Reflection",                   "Reflection"),
    ("JVM Calls",                    "JVM Calls"),
    ("Serialization",                "Serialization"),
    ("Library Analysis",             "Library Analysis"),
    ("Class Loading",                "Class Loading"),
    ("DynamicProxy",                 "DynamicProxy"),
]

# Determine common total number of tests (should be 123 for this artifact)
sum_totals = {results[p]["_sum_total"] for _, p in profiles}
if len(sum_totals) != 1:
    raise SystemExit(f"Inconsistent total test counts across profiles: {sum_totals}")
total_tests = sum_totals.pop()

# Print Markdown table equivalently to Table 1
print("**Table 1: Soundness of call-graphs for different JVM features**\n")
print("| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |")
print("| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |")

for key, label in features:
    row_cells = [label]
    for _, prof in profiles:
        val = results[prof].get(key, "0/0")
        row_cells.append(val)
    print(f"| {row_cells[0]:<20} |"
          f" {row_cells[1]:>12} | {row_cells[2]:>12} | {row_cells[3]:>13} |"
          f" {row_cells[4]:>12} | {row_cells[5]:>12} | {row_cells[6]:>13} |")

# Sum row: use integer percentages rounded from passed / total_tests * 100
sum_cells = []
for _, prof in profiles:
    passed = results[prof]["_sum_passed"]
    percent_int = int(round(passed * 100.0 / total_tests))
    sum_cells.append(f"**{passed} ({percent_int}%)**")

print(f"| **Sum (out of {total_tests})** |"
      f" {sum_cells[0]:>12} | {sum_cells[1]:>12} | {sum_cells[2]:>13} |"
      f" {sum_cells[3]:>12} | {sum_cells[4]:>12} | {sum_cells[5]:>13} |")
print("\n*Algorithms within each framework are ordered by increasing precision. “Soundness” column values are test cases passed soundly (all/some/none).*")
PY
echo '</artisan_submit>'
