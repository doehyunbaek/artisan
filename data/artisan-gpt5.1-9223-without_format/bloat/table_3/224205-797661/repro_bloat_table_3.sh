#!/usr/bin/bash
# Section 1: Expected table (from artifact's RQ4 script)
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
artisan get https://zenodo.org/records/11095274

# Section 3: Reproduction commands (from README RQ4 instructions)
cd /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5
docker rm -f bloat-art >/dev/null 2>&1 || true
docker build -t bloat-study-artifact .
docker run -d --init --name bloat-art --entrypoint bash \
  -v "$(pwd)/scripts:/home/user/scripts" \
  -v "$(pwd)/data:/home/user/data" \
  -v "$(pwd)/figures:/home/user/figures" \
  bloat-study-artifact -c 'sleep infinity'
docker exec bloat-art /bin/bash --noprofile --norc -c \
  "cd /home/user && python scripts/rq4.py data/results/qualitative_results.json --table3" \
  > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
