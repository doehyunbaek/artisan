#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       7 |         12 |            3 |           6 |         4 |

EOTABLE
# Section 2: Artifact download
# Already downloaded and extracted in /workspace/pmsat-inference
echo "Artifact already available at /workspace/pmsat-inference"
# Section 3: Reproduction commands
cd /workspace/pmsat-inference
# Build Docker image if not already built (should be from previous step)
docker-compose build > /dev/null 2>&1
# Run container
container_id=$(docker run -d --init --entrypoint bash -v $(pwd):/code -w /code pmsat-inference-pmsat -c 'sleep infinity')
# Mine models from APC trace
docker exec $container_id python3 run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13 > /dev/null 2>&1
# Extract results for n=7 from JSON
result=$(docker exec $container_id cat TRACE-results/cec0073ace4949b9131532f72e03f409/pmsatLearned-rc2-N7.json)
# Parse JSON to compute statistics
n=7
n_reach=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['dominant_reachable_states'])")
glitches=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['cost'])")
glitched_freq=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(' '.join(map(str, d['glitched_delta_freq'])))")
dominant_freq=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(' '.join(map(str, d['dominant_delta_freq'])))")
# Compute mean and max of glitched frequencies
mean_dg=$(echo "$glitched_freq" | python3 -c "import sys; nums=list(map(int, sys.stdin.read().split())); print(sum(nums)/len(nums) if len(nums)>0 else 0)")
max_dg=$(echo "$glitched_freq" | python3 -c "import sys; nums=list(map(int, sys.stdin.read().split())); print(max(nums) if len(nums)>0 else 0)")
# Compute min of dominant frequencies
min_d=$(echo "$dominant_freq" | python3 -c "import sys; nums=list(map(int, sys.stdin.read().split())); print(min(nums) if len(nums)>0 else 0)")
# Output to repro.txt
cat > /workspace/repro.txt <<EOREPRO
Reproduced Table 4:
|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
| $n | $n_reach | $glitches | $mean_dg | $max_dg | $min_d |
EOREPRO
# Clean up
docker stop $container_id > /dev/null 2>&1
docker rm $container_id > /dev/null 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
