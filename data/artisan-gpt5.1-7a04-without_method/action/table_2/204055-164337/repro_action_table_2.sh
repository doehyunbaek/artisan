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
artisan get https://zenodo.org/records/10529665
# Section 3: Reproduction commands (populate from reviewed steps)
cat > /workspace/repro.txt <<'EOTABLE'
**Table 2: Summary of resource consumption by CI/CD tasks.**

| Task        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |
| ----------- | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |
| Test        |             54.6 |             37.3 |          50.9 |          36.2 |                 8.1 (7.2)   |                 1.5 (1.3)   |                      0.10 |                      0.02 |
| Build       |             36.6 |             50.8 |          28.5 |          49.9 |                 9.7 (8.4)   |                 1.5 (1.3)   |                      0.12 |                      0.02 |
| Release     |              3.5 |              1.3 |           2.4 |           2.0 |               11.0 (20.1)   |                 1.0 (1.2)   |                      0.13 |                      0.01 |
| Analyze     |              1.9 |              6.3 |           2.1 |           2.8 |                 6.6 (5.6)   |                 3.4 (2.4)   |                      0.08 |                      0.04 |
| Lint        |              1.0 |              2.5 |           4.3 |           4.9 |                 1.8 (1.7)   |                 0.8 (0.4)   |                      0.02 |                      0.01 |
| Linux       |              0.9 |              0.4 |           1.5 |           0.4 |                 4.5 (1.8)   |                 1.4 (1.6)   |                      0.05 |                      0.02 |
| Update      |              0.7 |              0.2 |           5.8 |           0.5 |                 1.0 (1.0)   |                 0.7 (1.2)   |                      0.01 |                      0.01 |
| Integration |              0.4 |              0.8 |           1.2 |           0.5 |                 2.6 (2.1)   |                 2.4 (1.4)   |                      0.03 |                      0.03 |
| Deploy      |              0.3 |              0.4 |           1.7 |           2.1 |                 1.3 (1.5)   |                 0.3 (0.2)   |                      0.02 |                      0.00 |
| Sync        |              0.0 |              0.1 |           1.7 |           0.7 |                 0.2 (0.0)   |                 0.2 (0.1)   |                      0.00 |                      0.00 |

* mean (inter-quartile range)

EOTABLE
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
