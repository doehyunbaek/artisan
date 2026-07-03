#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table (placeholders, as provided)
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Resolution accuracy.**

| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |
| ------------ | ------------: | --------: | -----: | ------: |
| Random       |        ??.??% |    ??.??% | ??.??% |  ??.??% |
| Popular      |        ??.??% |    ???.??% | ??.??% |  ??.??% |
| Mostdep      |        ??.??% |    ??.??% | ??.??% |  ??.??% |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10496086

ROOT="/workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor"

# Section 3: Reproduction commands

# 3.1: Unzip the precomputed accuracy evaluation results
cd "$ROOT/Code/accuracy_evaluation"
unzip -o EDG_Evaluation_20220811.zip >/dev/null

# 3.2: Initialize submodules and build Docker image
cd "$ROOT"
make submodule
docker build -t cargo-ecosystem-monitor .

# 3.3: Run Docker container (detached, no host port binding) and execute summary_release inside it
CID=$(docker run -d --init --entrypoint bash -e POSTGRES_PASSWORD="postgres" -w /app --mount type=bind,src="$ROOT",target=/app cargo-ecosystem-monitor -c 'sleep infinity')
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /app/Code/accuracy_evaluation && cargo run --bin summary_release" > /workspace/summary_output.txt
docker rm -f "$CID" >/dev/null

# 3.4: Parse summary_release output and write the reproduced Table 1 to /workspace/repro.txt
awk '
  /^Dataset:/ { ds = $2 }
  /Tree Accuracy/ { ta[ds] = $4 }
  /^Precision/ { pr[ds] = $4 }
  /^Recall/ { rc[ds] = $4 }
  /^F1Score/ { f1[ds] = $4 }
  END {
    print "**Table 1: Resolution accuracy.**"
    print ""
    print "| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |"
    print "| ------------ | ------------: | --------: | -----: | ------: |"
    printf "| Random       | %12s | %8s | %6s | %7s |\n",  ta["random"],  pr["random"],  rc["random"],  f1["random"]
    printf "| Popular      | %12s | %8s | %6s | %7s |\n",  ta["popular"], pr["popular"], rc["popular"], f1["popular"]
    printf "| Mostdep      | %12s | %8s | %6s | %7s |\n", ta["mostdep"], pr["mostdep"], rc["mostdep"], f1["mostdep"]
  }
' /workspace/summary_output.txt > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
