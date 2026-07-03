#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**

|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  | Resolved | ?,???,??? | ??.?% | ?,??? | ???.? |
|  | Unresolved | ???,??? | ?.?% | ??? | ??.? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11095274
# Section 3: Reproduction commands (install pandas if needed and run evaluation)
cd bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5 || exit 1
# Try installing pandas as a user, fallback to system install if needed
(python -m pip install --upgrade --no-input --user pandas || python -m pip install --upgrade --no-input pandas) >/dev/null 2>&1
# Run the evaluation script to produce Table 2 and save output to /workspace/repro.txt
python scripts/descriptives/evaluation.py -csv data/results/rq1a.csv > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
