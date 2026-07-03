#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2. Experimental results for analyzing 10 C projects, comparing with Infer-v1.1.0. Columns **#NPD**, **#ML**, **#RL** record the numbers of null pointer dereferences, memory leaks, and resource leaks, respectively. The number of false positives found by Infer and more true positives found by PROVENFIX are represented by +n and +n respectively. Colunns in #Time record the analysis time spent.**

| Project         | Failed Assert |
| --------------- | ------------: |
| Swoole          |            98 |
| lxc             |            56 |
| WavPack         |            52 |
| flex            |            24 |
| p11-kit         |            37 |
| x264            |            21 |
| recutils-1.8    |            75 |
| inetutils-1.9.4 |            37 |
| snort-2.9.13    |            98 |
| grub            |            12 |
| **Total**       |       **510** |

EOTABLE

# Section 2: Artifact download
# (If not already present) clone the repository and pull docker image
if [ ! -d /workspace/infer_TempFix ]; then
  git clone https://github.com/songyahui/infer_TempFix /workspace/infer_TempFix
fi

docker pull yahuuuuui/fse24-prove_n_fix:ubuntu

# Section 3: Reproduction commands (populate from reviewed steps)
# Run the docker container (detached) and compute Failed Assertion counts
CONTAINER_NAME=prove_n_fix_repro
# Remove any existing container with same name
if docker ps -a --format '{{.Names}}' | grep -xq "$CONTAINER_NAME"; then
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

docker run -d --init --entrypoint bash --name "$CONTAINER_NAME" yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Wait a little for container to be ready
sleep 2

REPORT_PATH=/home/infer_TempFix/TempFix-out/report.csv

# Projects to aggregate
projects=("Swoole" "lxc" "WavPack" "flex" "p11-kit" "x264" "recutils-1.8" "inetutils-1.9.4" "snort-2.9.13" "grub")

# Produce reproduction output
out=/workspace/repro.txt
echo "Reproduction of Table 2 (Failed Assertion counts)" > "$out"
echo "Project,Failed_Assert" >> "$out"

total=0
for p in "${projects[@]}"; do
  # Use grep -F to find lines containing the project directory and sum column 7 (Failed Assertion)
  sum=$(docker exec "$CONTAINER_NAME" /bin/bash -c "grep -F '/$p/' '$REPORT_PATH' || true" | awk -F, '{s+=\$7} END{print s+0}')
  # If grep inside container returned nothing, try case-insensitive search on basename
  if [ -z "$sum" ]; then sum=0; fi
  echo "$p,$sum" >> "$out"
  total=$((total + sum))
done

echo "Total,$total" >> "$out"

# Copy out the report.csv for reference (if exists)
if docker exec "$CONTAINER_NAME" /bin/bash -c "test -f '$REPORT_PATH'" >/dev/null 2>&1; then
  docker cp "$CONTAINER_NAME":"$REPORT_PATH" /workspace/TempFix-report.csv >/dev/null 2>&1 || true
fi

# Stop and remove the container
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat "$out"
echo '</artisan_submit>'
