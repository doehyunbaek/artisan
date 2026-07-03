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
artisan get https://zenodo.org/records/11095274
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact .
docker run -d --init --entrypoint bash --name bloat_container \
  -v "$(pwd)/scripts:/home/user/scripts" \
  -v "$(pwd)/data:/home/user/data" \
  -v "$(pwd)/figures:/home/user/figures" \
  bloat-study-artifact -c 'sleep infinity'
docker exec bloat_container /bin/bash --noprofile --norc -c "cd /home/user && python scripts/rq4.py data/results/qualitative_results.json --table3" > /workspace/rq4_table3_raw.txt
docker rm -f bloat_container
# Transform the ASCII table from rq4.py into a Markdown table for repro.txt
cat > /workspace/repro.txt <<'REPRO_HEADER'
**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**

| PR status | # of PRs | # of BD removed |
| --------- | -------: | --------------: |
REPRO_HEADER
awk '
  # Select only table rows (exclude borders and header)
  /^\\|/ && $0 !~ /PR Status/ && $0 !~ /^\\+/
  {
    # Strip leading/trailing pipes
    gsub(/^\\||\\|$/,"");
    # Split into the three columns
    split($0, a, /\\|/);
    for (i=1; i<=3; i++) {
      gsub(/^ +| +$/, "", a[i]);
    }
    status = a[1];
    nprs   = a[2];
    nbd    = a[3];
    if (status == "Total") {
      printf("| **%s** | **%s** | **%s** |\n", status, nprs, nbd);
    } else {
      printf("| %s | %s | %s |\n", status, nprs, nbd);
    }
  }
' /workspace/rq4_table3_raw.txt >> /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
