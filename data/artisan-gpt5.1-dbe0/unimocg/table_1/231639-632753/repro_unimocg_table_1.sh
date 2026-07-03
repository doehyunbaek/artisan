#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Soundness of call-graphs for different JVM features**

| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |
| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |
| Non-virtual Calls    |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Virtual Calls        |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Types                |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Static Initializer   |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Java ? Interfaces    |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Unsafe               |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Class.forName        |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Sign. Polymorph.     |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Java ?+              |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Non-Java             |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| MethodHandle         |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Invokedynamic        |           ?/?? |          ??/?? |            ??/?? |          ??/?? |          ??/?? |            ??/?? |
| Reflection           |           ?/?? |           ?/?? |             ?/?? |           ?/?? |           ?/?? |             ?/?? |
| JVM Calls            |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Serialization        |           ?/?? |           ?/?? |             ?/?? |           ?/?? |           ?/?? |             ?/?? |
| Library Analysis     |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Class Loading        |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| DynamicProxy         |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| **Sum (out of ???)** |   **?? (??%)** |   **?? (??%)** |     **?? (??%)** |   **?? (??%)** |   **?? (??%)** |     **?? (??%)** |

*Algorithms within each framework are ordered by increasing precision. “Soundness” column values are test cases passed soundly (all/some/none).*
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10890011

# Section 3: Reproduction commands (compute aggregation from raw fingerprints)
cd /workspace/Unimocg_Artifact
python3 docker/runner/aggregate_fingerprints.py evaluation/fingerprints/*.profile > /workspace/repro.txt
cd /workspace

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
