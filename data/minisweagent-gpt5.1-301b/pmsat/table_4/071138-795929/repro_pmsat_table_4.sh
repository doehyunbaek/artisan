#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       7 |         12 |            3 |           6 |         4 |

EOTABLE

# Section 2: Artifact download
mkdir -p /workspace/artifact
curl -L "https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content" -o /workspace/pmsat-inference-and-publication-artifacts.zip
cd /workspace/artifact
unzip -q /workspace/pmsat-inference-and-publication-artifacts.zip

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/pmsat-inference

# Build Docker image as described in README
docker-compose build

# Mine models from APC trace (Table 4 use case)
docker-compose run --rm pmsat python run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13

# Parse the single-run APC results into CSV, ensuring NumPy<2 is used for matplotlib compatibility
docker-compose run --rm pmsat bash -lc "pip install 'numpy<2' >/dev/null && python parse_single_run_results.py TRACE-results/cec0073ace4949b9131532f72e03f409" > table4.csv

# Extract the n=7 row from table4.csv and format it as a Markdown table into /workspace/repro.txt
n=$(awk -F',' 'NR==2 {gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' table4.csv)
n_reach=$(awk -F',' 'NR==2 {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' table4.csv)
glitches=$(awk -F',' 'NR==2 {gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}' table4.csv)
mean=$(awk -F',' 'NR==2 {gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}' table4.csv)
maxd=$(awk -F',' 'NR==2 {gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}' table4.csv)
mind=$(awk -F',' 'NR==2 {gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}' table4.csv)

# Convert mean (e.g., 3.0) to integer for display
mean_int=${mean%.*}

cat > /workspace/repro.txt <<EOTABLE
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  $n |       $n_reach |         $glitches |            $mean_int |           $maxd |         $mind |
EOTABLE

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
