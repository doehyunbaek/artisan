#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**

| PR status | # of PRs | # of BD removed |
| --------- | -------: | --------------: |
| Merged    |       30 |              35 |
| Approved  |        1 |               1 |
| Rejected  |        1 |               1 |
| Pending   |        4 |               5 |
| **Total** |   **36** |          **42** |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -s -L -o artifact.zip "https://zenodo.org/api/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip/content"
unzip -q artifact.zip -d artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact . > /dev/null 2>&1
container_id=$(docker run -d --init --entrypoint bash -v /workspace/artifact/gdrosos-bloat-study-artifact-0fe2fe5:/home/user bloat-study-artifact -c 'sleep infinity')
sleep 2
docker exec "$container_id" /bin/bash --noprofile --norc -c "python scripts/rq4.py data/results/qualitative_results.json --table3" > /workspace/repro.txt 2>&1
docker stop "$container_id" > /dev/null 2>&1
docker rm "$container_id" > /dev/null 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt | grep -A6 -B1 "+-------------+" | head -9
echo '</artisan_submit>'
