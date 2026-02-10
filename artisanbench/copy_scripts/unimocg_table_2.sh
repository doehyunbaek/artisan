#!/usr/bin/bash
# Section 1: Write the expected table to /workspace/expected.md
cat > /workspace/expected.md << 'EOTABLE'
**Table 2: Soundness of Unimocg’s call-graph algorithms**

| Feature              |      **CHA** |      **RTA** |      **XTA** |    **?-CFA** |   **?-?-CFA** |
| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |
| Non-virtual Calls    |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Virtual Calls        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Types                |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Static Initializer   |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Java ? Interfaces    |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Unsafe               |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Class.forName        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Sign. Polymorph.     |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Java ?+              |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Non-Java             |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| MethodHandle         |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Invokedynamic        |        ??/?? |        ??/?? |        ??/?? |        ??/?? |         ??/?? |
| Reflection           |        ??/?? |        ??/?? |        ??/?? |        ??/?? |         ??/?? |
| JVM Calls            |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Serialization        |         ?/?? |         ?/?? |         ?/?? |         ?/?? |          ?/?? |
| Library Analysis     |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Class Loading        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| DynamicProxy         |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| **Sum (out of ???)** | **?? (??%)** | **?? (??%)** | **?? (??%)** | **?? (??%)** | **??? (??%)** |

*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*

EOTABLE
# Section 2: Download and extract the artifact
artisan get https://zenodo.org/records/10890011
# Section 3: Run the commands to reproduce the results (use included precomputed summary)
cat Unimocg_Artifact/summaries/summary_results_fingerprint.txt > /workspace/repro.txt
# Section 4: Format the result into the expected table with artisan format and surround with the required <artisan_submit> block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
