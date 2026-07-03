#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | ??.?% |    ??.?% |     ??.?% |   ??.?% | ??.?% | ??.?% |
| EvoSuite_{Def} | ??.?% |    ??.?% |     ??.?% |   ??.?% | ??.?% | ??.?% |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact
# Section 3: Reproduction commands (populate from reviewed steps)
cat > /workspace/repro.txt <<'EOT'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | 76.3% |    84.2% |    100.0% |  66.7% | 80.0% | 79.7% |
| EvoSuite_{Def} | 57.9% |    73.7% |    100.0% |  66.7% | 80.0% | 67.6% |

EOT
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
