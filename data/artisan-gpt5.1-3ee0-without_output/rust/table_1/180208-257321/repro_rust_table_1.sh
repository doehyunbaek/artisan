#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Resolution accuracy.**

| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |
| ------------ | ------------: | --------: | -----: | ------: |
| Random       |        99.39% |    99.76% | 98.93% |  99.35% |
| Popular      |        99.50% |   100.00% | 99.17% |  99.58% |
| Mostdep      |        97.04% |    99.96% | 97.49% |  98.71% |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10496086

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
make submodule
docker build -t cargo-ecosystem-monitor .
DOCKER_ID=$(docker run -d --init --entrypoint bash -p 127.0.0.1:12345:5432 -e POSTGRES_PASSWORD=postgres -w /app --mount type=bind,src=$(pwd),target=/app cargo-ecosystem-monitor -c 'sleep infinity')
docker exec $DOCKER_ID /bin/bash --noprofile --norc -c 'cd /app && make postgresql'
docker exec $DOCKER_ID /bin/bash --noprofile --norc -c 'cd /app/Code/accuracy_evaluation && unzip -o EDG_Evaluation_20220811.zip'
docker exec $DOCKER_ID /bin/bash --noprofile --norc -c 'cd /app/Code/accuracy_evaluation && cargo run --bin summary_release' > /workspace/summary_output.txt

awk '
  /^Dataset: / { ds = $2 }
  /^Tree Accuracy/ { ta[ds] = $3 }
  /^Precision/ { pr[ds] = $3 }
  /^Recall/ { re[ds] = $3 }
  /^F1Score/ { f1[ds] = $3 }
  END {
    ds_key[1] = "random";  ds_name[1] = "Random";
    ds_key[2] = "popular"; ds_name[2] = "Popular";
    ds_key[3] = "mostdep"; ds_name[3] = "Mostdep";
    printf "**Table 1: Resolution accuracy.**\n\n";
    printf "| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |\n";
    printf "| ------------ | ------------: | --------: | -----: | ------: |\n";
    for (i = 1; i <= 3; i++) {
      k = ds_key[i];
      t = ta[k]; p = pr[k]; r = re[k]; f = f1[k];
      gsub("%","",t); gsub("%","",p); gsub("%","",r); gsub("%","",f);
      printf "| %-11s | %11.2f%% | %9.2f%% | %6.2f%% | %7.2f%% |\n", ds_name[i], t, p, r, f;
    }
  }
' /workspace/summary_output.txt > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
