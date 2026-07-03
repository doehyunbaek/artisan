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
curl -L -o /workspace/artifact.zip "https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip"
unzip -q /workspace/artifact.zip -d /workspace/artifact
# Section 3: Reproduction commands
cd /workspace/artifact/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact . 2>&1 | tail -5
# Run the docker command and output results to repro.txt
docker run -it --rm -v $(pwd)/scripts:/home/user/scripts -v $(pwd)/data:/home/user/data -v $(pwd)/figures:/home/user/figures bloat-study-artifact /bin/bash -c "cd /home/user && python scripts/rq4.py data/results/qualitative_results.json --table3" > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'