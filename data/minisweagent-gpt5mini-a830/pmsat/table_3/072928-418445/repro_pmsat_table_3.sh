#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**

| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |
| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |
| timeout % | 0.5 | 0.3 | 0.5 | 1.5 | 3.5 | 5.8 | 10.3 | 17.5 | 27 | 33 |

EOTABLE

# Section 2: Artifact download
echo "Downloading artifact..."
curl -L -s -o /workspace/pmsat-artifact.zip 'https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip'

# Section 3: Reproduction commands
echo "Extracting artifact..."
unzip -q /workspace/pmsat-artifact.zip -d /workspace

echo "Installing system build tools..."
apt-get update -y
apt-get install -y build-essential g++ python3-dev pkg-config

echo "Installing Python dependencies..."
python3 -m pip install -r /workspace/pmsat-inference/requirements.txt

echo "Generating Table 3 reproduction..."
python3 /workspace/pmsat-inference/parse_all_results_timeouts.py /workspace/pmsat-inference/benchmarkingset-rc2-results > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
