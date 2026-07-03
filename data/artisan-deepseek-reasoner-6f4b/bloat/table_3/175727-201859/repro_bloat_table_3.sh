#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**

| PR status | # of PRs | # of BD removed |
| --------- | -------: | --------------: |
| Merged    |       ?? |              ?? |
| Approved  |        ? |               ? |
| Rejected  |        ? |               ? |
| Pending   |        ? |               ? |
| **Total** |   **??** |          **??** |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11095274
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact .
docker run -d --init --name bloat-study \
  -v /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5/scripts:/home/user/scripts \
  -v /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5/data:/home/user/data \
  -v /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5/figures:/home/user/figures \
  bloat-study-artifact /bin/bash -c 'sleep infinity'
sleep 10
docker exec bloat-study python scripts/rq4.py data/results/qualitative_results.json --table3 2>&1 | head -n 13 > /workspace/repro.txt
docker stop bloat-study
docker rm bloat-study
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
