#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\delta_g) fr. | Max (\delta_g) fr. | Min (\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
|   3 |           3 |         31 |                7.75 |                 26 |               65 |
|   4 |           4 |          5 |                1.25 |                  2 |               26 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L -o artifact.zip https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content 2>&1 | tail -5
unzip -o artifact.zip 2>&1 | head -10
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference
docker-compose build 2>&1 | tail -10
docker-compose run -d pmsat sleep infinity 2>&1 | tail -5
container_id=$(docker ps | grep pmsat-inference-pmsat | awk '{print $1}')
docker exec -w /pmsat-inference $container_id /bin/bash --noprofile --norc -c "python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7 2>&1"
docker exec -w /pmsat-inference $container_id /bin/bash --noprofile --norc -c "python -c '
import json, statistics
def extract_table():
    result = []
    for n in [3, 4]:
        with open(f\"TRACE-results/92e710ef352c4739cd7569794272588a/pmsatLearned-rc2-N{n}.json\") as f:
            d = json.load(f)
        n_reach = d[\"dominant_reachable_states\"]
        glitches = d[\"cost\"]
        glitched_freq = d.get(\"glitched_delta_freq\", [])
        dominant_freq = d.get(\"dominant_delta_freq\", [])
        mean_glitched = statistics.mean(glitched_freq) if glitched_freq else 0
        max_glitched = max(glitched_freq) if glitched_freq else 0
        min_dominant = min(dominant_freq) if dominant_freq else 0
        result.append((n, n_reach, glitches, mean_glitched, max_glitched, min_dominant))
    return result
res = extract_table()
print(\"Reproduced Table 2:\")
print(\"| (n) | (n_{reach}) | # Glitches | Mean (\\\\delta_g) fr. | Max (\\\\delta_g) fr. | Min (\\\\delta) fr. |\")
print(\"| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |\")
for n, n_reach, glitches, mean_g, max_g, min_d in res:
    print(f\"| {n:>3} | {n_reach:>11} | {glitches:>10} | {mean_g:>19.2f} | {max_g:>16} | {min_d:>15} |\")
' 2>&1" > /workspace/repro.txt
echo "Results saved to /workspace/repro.txt"
cat /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt | grep -E "^Reproduced Table 2:|^\|" | head -10
echo '</artisan_submit>'