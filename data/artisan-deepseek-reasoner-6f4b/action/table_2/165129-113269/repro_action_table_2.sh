#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary of resource consumption by CI/CD tasks.**

| Task        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |
| ----------- | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |
| Test        |             ??.? |             ??.? |          ??.? |          ??.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Build       |             ??.? |             ??.? |          ??.? |          ??.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Release     |              ?.? |              ?.? |           ?.? |           ?.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Analyze     |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Lint        |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Linux       |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Update      |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Integration |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Deploy      |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Sync        |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |

* mean (inter-quartile range)

EOTABLE
# Section 2: Artifact download
<Commands to download the artifact>
artisan get https://zenodo.org/records/10529665
# Section 3: Reproduction commands (populate from reviewed steps)
<Commands to reproduce the table. They should output the reproduction results to /workspace/repro.txt>
# Section 4: Formatting and submission block
echo '<artisan_submit>'
<Commands to format the output table>
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
