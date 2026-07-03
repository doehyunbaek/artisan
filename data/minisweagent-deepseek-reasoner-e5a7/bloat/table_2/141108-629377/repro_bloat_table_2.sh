#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**

|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  | Resolved | 7,799,929 | 96.8% | 5,991 | 144.5 |
|  | Unresolved | 260,249 | 3.2% | 200 | 11.5 |
EOTABLE
# Section 2: Artifact download and Docker setup
curl -L -o /workspace/artifact.zip "https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip?download=1"
unzip -q /workspace/artifact.zip -d /workspace/artifact_extracted
# Build Docker image from the artifact
docker build -t bloat-study-artifact /workspace/artifact_extracted/gdrosos-bloat-study-artifact-0fe2fe5
# Run container in detached mode
container_id=$(docker run -d --init \
  -v /workspace/artifact_extracted/gdrosos-bloat-study-artifact-0fe2fe5/scripts:/home/user/scripts \
  -v /workspace/artifact_extracted/gdrosos-bloat-study-artifact-0fe2fe5/data:/home/user/data \
  bloat-study-artifact bash -c 'sleep infinity')
# Section 3: Reproduction commands inside container
docker exec "$container_id" /bin/bash --noprofile --norc -c "cd /home/user && python scripts/descriptives/evaluation.py -csv data/results/rq1a.csv" > /workspace/repro.txt 2>&1
# Clean up container
docker stop "$container_id" > /dev/null 2>&1
docker rm "$container_id" > /dev/null 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
