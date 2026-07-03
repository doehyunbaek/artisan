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

# Section 2: Artifact download (harmless if already present)
artisan get https://zenodo.org/records/10890011

# Section 3: Reproduction commands — build a repro.txt that lists only the needed profiles in the table's column order
INPUT=Unimocg_Artifact/summaries/summary_results_fingerprint.txt
: > /workspace/repro.txt
# Append WALA-CHA, WALA-RTA, WALA-0-CFA, Soot-CHA, Soot-RTA, Soot-SPARK in that order
awk 'BEGIN{RS="-------------------------------------------------------------------\n"; ORS="\n\n"} /WALA-CHA.profile/ {print $0}' "$INPUT" >> /workspace/repro.txt
awk 'BEGIN{RS="-------------------------------------------------------------------\n"; ORS="\n\n"} /WALA-RTA.profile/ {print $0}' "$INPUT" >> /workspace/repro.txt
awk 'BEGIN{RS="-------------------------------------------------------------------\n"; ORS="\n\n"} /WALA-0-CFA.profile/ {print $0}' "$INPUT" >> /workspace/repro.txt
awk 'BEGIN{RS="-------------------------------------------------------------------\n"; ORS="\n\n"} /Soot-CHA.profile/ {print $0}' "$INPUT" >> /workspace/repro.txt
awk 'BEGIN{RS="-------------------------------------------------------------------\n"; ORS="\n\n"} /Soot-RTA.profile/ {print $0}' "$INPUT" >> /workspace/repro.txt
awk 'BEGIN{RS="-------------------------------------------------------------------\n"; ORS="\n\n"} /Soot-SPARK.profile/ {print $0}' "$INPUT" >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
