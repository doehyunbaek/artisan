#!/usr/bin/bash
set -euo pipefail
# Section 1: Expected table (from prompt)
cat > /workspace/expected.md <<'EOTABLE'
### Table 2: Number of all pair-wise permutations ( (P_\text{max}) ) and after our reductions ( (P_\text{FD}), (P_\text{FDF}), (P_\text{OFS}), (P_\text{OFSFDF}) ) for all projects with some, but not a total reduction. Bold numbers indicate the minimum number of permutations required after the reductions. Column (TSP_\text{max}) shows the number of all possible test suite permutations and (TSP_\text{OFSFDF}) the number of permutations that *would be required* with OFSFDF.

|     Project | (P_\text{max}) | (P_\text{FD}) | (P_\text{FDF}) | (P_\text{OFS}) | (P_\text{OFSFDF}) | (TSP_\text{max}) | (TSP_\text{OFSFDF}) |
| ----------: | -------------: | ------------: | -------------: | -------------: | ----------------: | ---------------: | ------------------: |
|    ezstream |            182 |           182 |          **2** |            182 |             **2** |       8.72×10^10 |                   2 |
|        flex |          65280 |         40800 |          40800 |      **25440** |         **25440** |        8.58×10^506 |           4.71×10^284 |
| imagemagick |            272 |           272 |            245 |            272 |           **208** |       3.56×10^14 |          3.11×10^10 |
|      libbde |              6 |             6 |          **6** |              6 |             **4** |                6 |                   4 |
|      libevt |             12 |            12 |             12 |             12 |             **6** |               24 |                   6 |
|     libevtx |             20 |            20 |             20 |             20 |             **8** |              120 |                   8 |
|      libexe |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
| libfastjson |            272 |           272 |            272 |            272 |            **48** |       3.56×10^14 |                  90 |
|   libfsapfs |             12 |            12 |             12 |             12 |             **6** |               24 |                   6 |
|    libfshfs |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
|   libfsntfs |             12 |            12 |             12 |             12 |             **6** |               24 |                   6 |
|   libfsrefs |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
|     libfvde |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
|      libiff |           2550 |          2550 |           2057 |           2550 |           **450** |       1.55×10^66 |            15603840 |
|      liblnk |              6 |             6 |          **4** |              6 |             **4** |                6 |                   4 |
|   libluksde |              6 |             6 |              5 |              6 |             **4** |                6 |                   4 |
|     libmodi |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
|    libnsfdb |              6 |             6 |              6 |              6 |             **2** |                6 |                   2 |
|    libolecf |             12 |            12 |             12 |             12 |             **6** |               24 |                   6 |
|     libqcow |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
|     libregf |             12 |            12 |             12 |             12 |             **6** |               24 |                   6 |
|     libscca |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
|     libvhdi |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
|     libvmdk |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
|  libvshadow |              2 |             2 |              2 |              2 |             **1** |                2 |                   1 |
|    libvslvm |              6 |             6 |              6 |              6 |             **4** |                6 |                   4 |
| naemon-core |           1122 |          1122 |           1122 |           1122 |             **2** |       2.95×10^38 |                   2 |
|     numactl |             72 |            72 |             72 |             72 |             **8** |           362880 |                   8 |
|     safelib |          15750 |         15750 |          15750 |          15750 |             **4** |      2.37×10^211 |                   4 |
|          xz |             42 |            42 |            42 |            42 |             **6** |             5040 |                   6 |

EOTABLE

# Section 2: Artifact download
echo "Downloading artifact from Zenodo (record 13767954) to /workspace..."
curl -L -o /workspace/zenodo_record.html 'https://zenodo.org/records/13767954'
url=$(grep -Eo 'href="(/records/13767954/files[^"]+)"' /workspace/zenodo_record.html | sed 's/href="//;s/"$//' | head -n1)
if [ -z "$url" ]; then
  echo "ERROR: Could not find artifact file link in zenodo_record.html" >&2
  exit 2
fi
echo "Found artifact URL: https://zenodo.org${url}"
curl -L -o /workspace/artifact.tar.gz "https://zenodo.org${url}"
echo "Downloaded artifact to /workspace/artifact.tar.gz"

# Section 3: Reproduction commands
echo "Extracting artifact..."
rm -rf /workspace/artifact && mkdir -p /workspace/artifact
tar -xzf /workspace/artifact.tar.gz -C /workspace/artifact
echo "Listing extracted files:"
find /workspace/artifact -maxdepth 3 -type f -print

# Prepare out directory that will hold produced tables/figures
OUT_DIR="/workspace/artifact/artifact_efficient_test_interference_detection_c/data_analysis/out"
mkdir -p "$OUT_DIR"

# Build the data-mangling docker image (if Docker is available)
IMAGE_NAME="test_interference_detection/data_mangling"
DOCKERFILE_DIR="/workspace/artifact/artifact_efficient_test_interference_detection_c"
if command -v docker >/dev/null 2>&1; then
  echo "Building Docker image $IMAGE_NAME from $DOCKERFILE_DIR/Dockerfile ..."
  docker build -t "$IMAGE_NAME" -f "$DOCKERFILE_DIR/Dockerfile" "$DOCKERFILE_DIR"
  echo "Starting container from image, mounting host out dir into /data_analysis/out in container..."
  CONTAINER_ID=$(docker run -d --init --entrypoint bash -v "${OUT_DIR}":"/data_analysis/out" "$IMAGE_NAME" -c 'sleep infinity')
  echo "Container started: $CONTAINER_ID"
  echo "Copying project files into the running container (to a known path)..."
  docker cp "$DOCKERFILE_DIR" "$CONTAINER_ID":/workspace/artifact || true
  echo "Executing R analysis inside container to generate tables/figures (analyze_data.R)..."
  docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /workspace/artifact/artifact_efficient_test_interference_detection_c/data_analysis && Rscript -e 'source(\"analyze_data.R\")'" > /workspace/repro_run.log 2>&1 || true
  echo "Stopping and removing container..."
  docker stop "$CONTAINER_ID" >/dev/null || true
  docker rm "$CONTAINER_ID" >/dev/null || true
else
  echo "Docker not available: cannot build/run the container. Please run analyze_data.R manually in an R environment." > /workspace/repro_run.log
fi

# Section 4: Collect produced outputs into /workspace/repro.txt
echo '<artisan_submit>' > /workspace/repro.txt
echo "Files produced in data_analysis/out (host):" >> /workspace/repro.txt
ls -lah "$OUT_DIR" >> /workspace/repro.txt 2>&1 || true
for f in "$OUT_DIR"/*; do
  if [ -f "$f" ]; then
    echo "=== BEGIN $f ===" >> /workspace/repro.txt
    head -n 400 "$f" >> /workspace/repro.txt || true
    echo "=== END $f ===" >> /workspace/repro.txt
  fi
done
echo '</artisan_submit>' >> /workspace/repro.txt

echo "Wrote /workspace/repro_interference_table_2.sh and produced /workspace/repro.txt (may be empty if Docker/R not available)."
