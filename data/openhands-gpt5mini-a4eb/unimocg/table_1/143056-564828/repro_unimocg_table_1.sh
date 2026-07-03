#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Soundness of call-graphs for different JVM features**

| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |
| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |
| Non-virtual Calls    |            6/6 |            6/6 |              6/6 |            6/6 |            6/6 |              6/6 |
| Virtual Calls        |            4/4 |            4/4 |              4/4 |            4/4 |            4/4 |              4/4 |
| Types                |            6/6 |            6/6 |              6/6 |            6/6 |            6/6 |              6/6 |
| Static Initializer   |            4/8 |            7/8 |              6/8 |            7/8 |            7/8 |              7/8 |
| Java 8 Interfaces    |            7/7 |            7/7 |              7/7 |            7/7 |            7/7 |              7/7 |
| Unsafe               |            7/7 |            7/7 |              0/7 |            7/7 |            7/7 |              0/7 |
| Class.forName        |            2/4 |            4/4 |              4/4 |            2/4 |            2/4 |              2/4 |
| Sign. Polymorph.     |            0/7 |            0/7 |              0/7 |            0/7 |            0/7 |              0/7 |
| Java 9+              |            2/2 |            1/2 |              1/2 |            2/2 |            2/2 |              2/2 |
| Non-Java             |            2/2 |            2/2 |              2/2 |            0/2 |            0/2 |              0/2 |
| MethodHandle         |            2/9 |            2/9 |              0/9 |            2/9 |            2/9 |              0/9 |
| Invokedynamic        |           0/16 |          10/16 |            10/16 |          11/16 |          11/16 |            11/16 |
| Reflection           |           2/16 |           3/16 |             6/16 |           2/16 |           2/16 |             0/16 |
| JVM Calls            |            2/5 |            3/5 |              3/5 |            4/5 |            4/5 |              3/5 |
| Serialization        |           3/14 |           1/14 |             1/14 |           3/14 |           1/14 |             1/14 |
| Library Analysis     |            2/5 |            2/5 |              1/5 |            2/5 |            2/5 |              2/5 |
| Class Loading        |            0/4 |            0/4 |              0/4 |            0/4 |            0/4 |              0/4 |
| DynamicProxy         |            0/1 |            0/1 |              0/1 |            0/1 |            0/1 |              0/1 |
| **Sum (out of 123)** |   **51 (41%)** |   **65 (53%)** |     **57 (46%)** |   **65 (53%)** |   **63 (51%)** |     **51 (41%)** |

*Algorithms within each framework are ordered by increasing precision. “Soundness” column values are test cases passed soundly (all/some/none).*

EOTABLE
# Section 2: Artifact download
# Download the artifact from Zenodo and extract it to /workspace/unimocg_artifact
if [ ! -d /workspace/unimocg_artifact ]; then
  curl -sS -L -o /workspace/Unimocg_Artifact.zip "https://zenodo.org/records/10890011/files/Unimocg_Artifact.zip"
  unzip -q /workspace/Unimocg_Artifact.zip -d /workspace/unimocg_artifact
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Aggregate the fingerprint profiles to reproduce Table 1. Output to /workspace/repro.txt
python3 /workspace/unimocg_artifact/docker/runner/aggregate_fingerprints.py /workspace/unimocg_artifact/evaluation/fingerprints/*.profile > /workspace/repro.txt 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Print the aggregated reproduction results
cat /workspace/repro.txt || true
echo '</artisan_submit>'
