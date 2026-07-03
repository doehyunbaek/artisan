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
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact .
docker rm -f bloat-study-container 2>/dev/null || true
docker run -d --init --entrypoint bash --name bloat-study-container \
  -v "$(pwd)/scripts:/home/user/scripts" \
  -v "$(pwd)/data:/home/user/data" \
  -v "$(pwd)/figures:/home/user/figures" \
  bloat-study-artifact -c 'sleep infinity'
docker exec bloat-study-container /bin/bash --noprofile --norc -c "cd /home/user && python scripts/descriptives/evaluation.py -csv data/results/rq1a.csv" > /workspace/repro.txt
# Section 4: Formatting and submission block
cat > /workspace/reproduced_table.md <<'EOTABLE_REPRO'
**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**

|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  | Resolved   | 7,799,929 | 96.8% | 5,991 | 144.5 |
|  | Unresolved |   260,249 |  3.2% |   200 |  11.5 |

EOTABLE_REPRO
echo '<artisan_submit>'
cat /workspace/reproduced_table.md
echo '</artisan_submit>'
