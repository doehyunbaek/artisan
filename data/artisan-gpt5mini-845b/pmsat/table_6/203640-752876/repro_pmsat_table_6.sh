#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: Statistics of inferring the nRF52832 BLE chip with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       ? |        ??? |         ?.?? |          ?? |         ? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670

# Section 3: Reproduction commands (populate from reviewed steps)
cd pmsat-inference-and-publication-artifacts/pmsat-inference || exit 1

# Build the docker image as instructed
docker-compose build

# Ensure no stale container, start container in detached sleep mode
docker rm -f pmsat_run || true
docker run -d --init --entrypoint bash --name pmsat_run pmsat-inference-pmsat -c 'sleep infinity'

# Copy the repository files into the running container (the runtime image expects sources)
docker cp . pmsat_run:/pmsat-inference

# Run the model mining for the BLE use case (n_max 16)
docker exec pmsat_run /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/ble_nRF52832/nRF52832_moore_without_mtu_req_parsed_trace_cleaned.json -nmax 16"

# Extract the Table 6 CSV-like output from the produced TRACE-results using a small Python snippet
# (avoid matplotlib import in parser to prevent NumPy extension issues)
docker exec pmsat_run /bin/bash --noprofile --norc -c "python - <<'PY'
import json, glob, os
base='/pmsat-inference/TRACE-results'
# find the target run directory (prefer the one named in README, but fallback to latest)
cands = sorted([d for d in glob.glob(os.path.join(base, '*')) if os.path.isdir(d)])
target = None
for d in cands:
    if 'bdec710c6bfabb38f70d9dc5a452f8c6' in d:
        target = d
        break
if target is None and cands:
    target = cands[-1]
if target is None:
    print('ERROR: No TRACE-results found', file=sys.stderr)
    exit(1)
files = sorted(glob.glob(os.path.join(target, 'pmsatLearned-*.json')))
results = []
for fname in files:
    with open(fname, 'r') as fh:
        results.append(json.load(fh))
results.sort(key=lambda x: x.get('num_states', 0))
print('n,n_reach,# Glitches,Mean d_g fr.,Max d_g fr.,Min d fr.,bisimilar to n=')
for r in results:
    n = r.get('num_states','')
    n_reach = r.get('dominant_reachable_states','')
    glitches = r.get('cost','')
    gd = r.get('glitched_delta_freq') or [0]
    if not isinstance(gd, list):
        try:
            gd = [float(gd)]
        except Exception:
            gd = [0.0]
    else:
        gd = [float(x) for x in gd]
    mean_gd = sum(gd)/len(gd) if gd else 0.0
    max_gd = max(gd) if gd else 0.0
    dom = r.get('dominant_delta_freq') or [0]
    if not isinstance(dom, list):
        try:
            dom = [float(dom)]
        except Exception:
            dom = [0.0]
    else:
        dom = [float(x) for x in dom]
    min_dom = min(dom) if dom else 0.0
    bis = r.get('bisimilar_to_pmsat_with_states') or n
    print(f\"{n},{n_reach},{glitches},{mean_gd:.2f},{max_gd},{min_dom},{bis}\")
PY" > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
