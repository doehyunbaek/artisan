#!/usr/bin/bash
# Section 1: Expected table
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

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor || exit 1

# Build Docker image
docker build -t cargo-ecosystem-monitor .

# Run Docker container with modified invocation
docker run -d --init --entrypoint bash -dp 127.0.0.1:12345:5432 -e POSTGRES_PASSWORD="postgres" \
  -w /app --mount type=bind,src="$(pwd)",target=/app cargo-ecosystem-monitor -c 'sleep infinity' \
  > /workspace/docker_id.txt

DOCKER_ID="$(cat /workspace/docker_id.txt)"

# Extract precomputed evaluation results
docker exec "$DOCKER_ID" /bin/bash --noprofile --norc -c \
  'cd /app/Code/accuracy_evaluation && unzip -o EDG_Evaluation_20220811.zip'

# Run summary_release to compute accuracy metrics
docker exec "$DOCKER_ID" /bin/bash --noprofile --norc -c \
  'cd /app/Code/accuracy_evaluation && cargo run --bin summary_release > /app/summary_output.txt'

# Generate reproduction table from summary_output.txt using portable awk
awk '
$1 == "Dataset:"        { cur = $2 }
$1 == "Tree" && $2=="Accuracy" {
  v = $(NF); sub(/%$/, "", v); ta[cur] = v
}
$1 == "Precision" {
  v = $(NF); sub(/%$/, "", v); pr[cur] = v
}
$1 == "Recall" {
  v = $(NF); sub(/%$/, "", v); rc[cur] = v
}
$1 == "F1Score" {
  v = $(NF); sub(/%$/, "", v); f1[cur] = v
}
END {
  print "**Table 1: Resolution accuracy.**";
  print "";
  print "| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |";
  print "| ------------ | ------------: | --------: | -----: | ------: |";
  printf "| Random       | %12.3f%% | %8.3f%% | %6.3f%% | %7.3f%% |\n", ta["random"],  pr["random"],  rc["random"],  f1["random"];
  printf "| Popular      | %12.3f%% | %8.3f%% | %6.3f%% | %7.3f%% |\n", ta["popular"], pr["popular"], rc["popular"], f1["popular"];
  printf "| Mostdep      | %12.3f%% | %8.3f%% | %6.3f%% | %7.3f%% |\n", ta["mostdep"], pr["mostdep"], rc["mostdep"], f1["mostdep"];
}
' /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/summary_output.txt > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
