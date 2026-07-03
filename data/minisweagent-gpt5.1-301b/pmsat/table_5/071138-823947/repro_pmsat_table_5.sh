#!/usr/bin/bash
set -e

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       8 |         52 |         17.3 |          25 |         3 |
| 10 |       8 |         27 |         13.5 |          23 |         3 |
| 11 |      11 |          4 |            4 |           4 |         3 |
| 13 |      13 |          1 |            1 |           1 |         0 |
| 14 |      14 |          0 |            0 |           0 |         0 |

EOTABLE

# Section 2: Artifact download
cd /workspace
if [ ! -f pmsat-artifact.zip ]; then
  curl -L -o pmsat-artifact.zip 'https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip?download=1'
fi
if [ ! -d pmsat-inference ]; then
  unzip -o pmsat-artifact.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference

# Build Docker image as described in README
docker-compose build

# Ensure a clean container
docker rm -f pmsat_table5 >/dev/null 2>&1 || true

# Start long-lived container with correct volume mount
docker run -d --init --entrypoint bash \
  -v /workspace/pmsat-inference:/pmsat-inference \
  --name pmsat_table5 \
  pmsat-inference-pmsat -c 'sleep infinity'

# Mine models from SmokeMeter trace
docker exec pmsat_table5 /bin/bash --noprofile --norc -c \
  "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/avl415SE_smokemeter/smokemeter_trace.json -nmax 14"

# Fix NumPy ABI incompatibility so matplotlib and python-sat can import
docker exec pmsat_table5 /bin/bash --noprofile --norc -c \
  "/opt/venv/bin/pip install 'numpy<2'"

# Parse single-run results to produce raw Table 5 CSV
docker exec pmsat_table5 /bin/bash --noprofile --norc -c \
  "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/2804424892661995c1e6a665fa35e490 > table5.csv"

# Convert CSV to markdown table subset matching Table 5 and write to /workspace/repro.txt
cd /workspace/pmsat-inference
awk -F',' '
BEGIN {
  print "|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |";
  print "| -: | ------: | ---------: | -----------: | ----------: | --------: |";
}
NR > 1 {
  n = $1 + 0;
  if (n==9 || n==10 || n==11 || n==13 || n==14) {
    nr   = $2; g    = $3; mean = $4; maxd = $5; mind = $6;
    gsub(/^[ \t]+|[ \t]+$/, "", nr);
    gsub(/^[ \t]+|[ \t]+$/, "", g);
    gsub(/^[ \t]+|[ \t]+$/, "", mean);
    gsub(/^[ \t]+|[ \t]+$/, "", maxd);
    gsub(/^[ \t]+|[ \t]+$/, "", mind);
    sub(/\.0$/, "", mean);
    printf("| %2d | %7s | %9s | %11s | %10s | %8s |\n", n, nr, g, mean, maxd, mind);
  }
}
' table5.csv > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
