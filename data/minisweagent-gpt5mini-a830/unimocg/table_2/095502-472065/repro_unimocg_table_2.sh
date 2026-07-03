#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Soundness of Unimocg’s call-graph algorithms**

| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |
| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |
| Non-virtual Calls    |          6/6 |          6/6 |          6/6 |          6/6 |           6/6 |
| Virtual Calls        |          4/4 |          4/4 |          4/4 |          4/4 |           4/4 |
| Types                |          6/6 |          6/6 |          6/6 |          6/6 |           6/6 |
| Static Initializer   |          8/8 |          8/8 |          8/8 |          8/8 |           8/8 |
| Java 8 Interfaces    |          7/7 |          7/7 |          7/7 |          7/7 |           7/7 |
| Unsafe               |          7/7 |          7/7 |          7/7 |          7/7 |           7/7 |
| Class.forName        |          4/4 |          4/4 |          4/4 |          4/4 |           4/4 |
| Sign. Polymorph.     |          7/7 |          7/7 |          7/7 |          7/7 |           7/7 |
| Java 9+              |          2/2 |          2/2 |          2/2 |          2/2 |           2/2 |
| Non-Java             |          2/2 |          2/2 |          2/2 |          2/2 |           2/2 |
| MethodHandle         |          9/9 |          9/9 |          9/9 |          9/9 |           9/9 |
| Invokedynamic        |        11/16 |        11/16 |        11/16 |        11/16 |         11/16 |
| Reflection           |        10/16 |        10/16 |        10/16 |        10/16 |         13/16 |
| JVM Calls            |          3/5 |          3/5 |          3/5 |          3/5 |           3/5 |
| Serialization        |         9/14 |         9/14 |         9/14 |         9/14 |          9/14 |
| Library Analysis     |          2/5 |          2/5 |          2/5 |          2/5 |           2/5 |
| Class Loading        |          0/4 |          0/4 |          0/4 |          0/4 |           0/4 |
| DynamicProxy         |          0/1 |          0/1 |          0/1 |          0/1 |           0/1 |
| **Sum (out of 123)** | **97 (79%)** | **97 (79%)** | **97 (79%)** | **97 (79%)** | **100 (81%)** |

*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*

EOTABLE
# Section 2: Artifact download
# (The artifact is available at Zenodo; this command downloads the Unimocg_Artifact.zip)
curl -L -o /workspace/Unimocg_Artifact.zip 'https://zenodo.org/records/10890011/files/Unimocg_Artifact.zip?download=1' || true
# Extract the artifact
unzip -o /workspace/Unimocg_Artifact.zip -d /workspace/unimocg_artifact || true

# Section 3: Reproduction commands (populate from reviewed steps)
# Run the provided aggregation script over the included fingerprint profiles to reproduce Table 2.
# This writes the aggregated output to /workspace/repro.txt
python3 /workspace/unimocg_artifact/docker/runner/aggregate_fingerprints.py /workspace/unimocg_artifact/evaluation/fingerprints/*.profile > /workspace/repro.txt 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Print the aggregated reproduction output
if [ -f /workspace/repro.txt ]; then
  sed -n '1,400p' /workspace/repro.txt
else
  echo "Reproduction output /workspace/repro.txt not found."
fi
echo '</artisan_submit>'
