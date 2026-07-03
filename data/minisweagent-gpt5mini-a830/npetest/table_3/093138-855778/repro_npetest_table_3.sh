#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**

| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |
| 5 min  | EvoSuite |   29 |       16 |         6 |       4 |     4 |    59 |
|        | NPETest  |   37 |       19 |         6 |       6 |     6 |    74 |

EOTABLE

# Section 2: Artifact download / placement
# Ensure working directory expected by the paper scripts: ~/ase2024/NPETestArtifact
mkdir -p ~/ase2024
if [ -d "/workspace/NPETestArtifact" ]; then
  # Copy artifact into expected location (safe, overwrite existing)
  rm -rf ~/ase2024/NPETestArtifact || true
  cp -r /workspace/NPETestArtifact ~/ase2024/NPETestArtifact
else
  # Try to clone if not present in workspace
  if [ ! -d ~/ase2024/NPETestArtifact ]; then
    git clone --depth=1 https://github.com/kupl/NPETestArtifact ~/ase2024/NPETestArtifact || true
  fi
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd ~/ase2024/NPETestArtifact || exit 1

# Prepare result directory if missing
mkdir -p ./result

# Attempt to generate the main results table from existing raw results.
# Note: This requires that raw result directories (result/evosuite, result/npetest, result/randoop)
# contain the experiment outputs described in the README (downloaded separately from the authors' links).
echo "[INFO] Running get_main_results.sh to produce Table 3 from available result files..."
./scripts/get_main_results.sh > /workspace/repro_cmd_output.txt 2>&1 || echo "[WARN] get_main_results.sh finished with non-zero exit code; check /workspace/repro_cmd_output.txt for details"

# Copy produced result to a reproducible output file
if [ -f ./result/main_result.txt ]; then
  cp ./result/main_result.txt /workspace/repro.txt
else
  echo "[ERROR] ./result/main_result.txt not found. Ensure raw data from the authors (NPETest/EvoSuite/Randoop) is placed under ./result/ as described in README." > /workspace/repro.txt
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submit.txt
cat /workspace/repro.txt >> /workspace/repro_submit.txt
echo '</artisan_submit>' >> /workspace/repro_submit.txt

# Also print to stdout for convenience
cat /workspace/repro_submit.txt

