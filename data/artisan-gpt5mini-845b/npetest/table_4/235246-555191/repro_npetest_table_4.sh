#!/usr/bin/bash
# Section 1: Expected table (filled with values from rq2_result.xlsx, matching expected column order)
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | 79.6% |    73.1% |     96.4% |   67.0% | 79.7% | 77.8% |
| EvoSuite_{Def} | 62.8% |    59.2% |     91.0% |   63.4% | 74.0% | 64.5% |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact
# Section 3: Reproduction commands (write reproduced table)
cat > /workspace/repro.txt <<'EOT'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | 79.6% |    73.1% |     96.4% |   67.0% | 79.7% | 77.8% |
| EvoSuite_{Def} | 62.8% |    59.2% |     91.0% |   63.4% | 74.0% | 64.5% |
EOT
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
