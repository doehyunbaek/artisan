#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**

|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  | Resolved | ?,???,??? | ??.?% | ?,??? | 144.5 |
|  | Unresolved | ???,??? | ?.?% | ??? | 11.5 |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11095274
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace
docker build -t bloat-study-artifact bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5
mkdir -p bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5/figures
docker run -d --init --name bloat-table2 \
  -v /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5/scripts:/home/user/scripts \
  -v /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5/data:/home/user/data \
  -v /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5/figures:/home/user/figures \
  --entrypoint bash bloat-study-artifact -c 'sleep infinity'
docker exec bloat-table2 /bin/bash --noprofile --norc -c "cd /home/user && python scripts/descriptives/evaluation.py -csv data/results/rq1a.csv" > /workspace/repro.txt
docker stop bloat-table2
docker rm bloat-table2
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
