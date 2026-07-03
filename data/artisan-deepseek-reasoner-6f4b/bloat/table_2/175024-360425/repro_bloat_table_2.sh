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
# Build Docker image
cd bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact .
# Prepare directories and copy data
mkdir -p /workspace/scripts /workspace/data /workspace/figures
cp -r scripts/* /workspace/scripts/
cp -r data/* /workspace/data/
# Run container and execute the evaluation script
CONTAINER_ID=$(docker run -d --init --entrypoint bash -v /workspace/scripts:/home/user/scripts -v /workspace/data:/home/user/data -v /workspace/figures:/home/user/figures bloat-study-artifact -c 'sleep infinity')
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python scripts/descriptives/evaluation.py -csv data/results/rq1a.csv" > /workspace/repro.txt
docker stop $CONTAINER_ID
docker rm $CONTAINER_ID
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
