#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       ? |         ?? |            ? |           ? |         ? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670

# Section 3: Reproduction commands (populate from reviewed steps)
cd pmsat-inference-and-publication-artifacts/pmsat-inference

# Build Docker image as per README
docker-compose build

# Mine models from use case APC trace (Table 4)
docker-compose run -T pmsat bash -lc 'python run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13'

# Generate Table 4 CSV inside Docker, working around NumPy ABI issue
docker-compose run -T pmsat bash -lc 'pip install "numpy<2" && python parse_single_run_results.py TRACE-results/cec0073ace4949b9131532f72e03f409 > table4.csv'

# Convert the n=7 row from table4.csv into the Markdown table for /workspace/repro.txt
{
  echo '**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**'
  echo
  echo '|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |'
  echo '| -: | ------: | ---------: | -----------: | ----------: | --------: |'
  awk -F, 'NR==2 {
    # Trim spaces from numeric fields
    gsub(/ /, "", $1);
    gsub(/ /, "", $2);
    gsub(/ /, "", $3);
    gsub(/ /, "", $4);
    gsub(/ /, "", $5);
    gsub(/ /, "", $6);
    # Format row to match expected alignment
    printf("| %2s | %7s | %9s | %11s | %10s | %8s |\n", $1, $2, $3, $4, $5, $6);
  }' table4.csv
} > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
