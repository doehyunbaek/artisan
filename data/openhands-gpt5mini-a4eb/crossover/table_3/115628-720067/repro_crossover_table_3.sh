#!/usr/bin/env bash
set -euo pipefail

# repro_crossover_table_3.sh
# Reproduce Table 3 from the Crossover in Parametric Fuzzing artifact.
# This script is a best-effort reproduction template. It attempts to
# download the artifact, prepare docker images/containers, run the
# reproduction commands and write results to /workspace/repro.txt.

# Section 1: Expected table (write expected.md so submission is self-contained)
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**

| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |
| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |
| BeDiv-Simple |     755.0 |  899.0 |     1435.5 |     1846.5 |      9328.0 |     11863.5 |    590.5 |      738.0 |     3008.5 |     3319.5 |     2952.0 |     3235.5 |     274.5 |     341.0 |
| BeDiv-Struct |     786.5 |  896.5 |     1412.5 |     1876.5 |      9336.5 |     11904.5 |    578.5 |      641.5 |     2993.5 |     3092.0 |     2915.5 |     3237.0 |     161.0 |     242.5 |
| RLCheck      |     769.0 |  889.0 |          — |          — |      8262.5 |      9480.5 |    579.0 |      663.0 |     1298.0 |     1298.0 |     2627.0 |     2730.0 |     299.0 |     338.0 |
| Zest         |     820.0 |  927.0 |     1516.5 |     1909.5 |      9782.5 |     12352.0 |    778.5 |     1098.5 |     2654.5 |     2717.0 |     3108.5 |     3408.0 |     295.0 |     340.0 |
| Zeugma-X     |     835.5 |  911.0 |     1480.5 |     1927.0 |     10274.5 |     12251.0 |    873.0 |     1138.0 |     4259.0 |     7411.0 |     3169.0 |     3551.5 |     297.5 |     345.0 |
| Zeugma-1PT   |     828.0 |  909.5 |     1489.0 |     1917.0 |     10237.5 |     12153.5 |    855.5 |     1138.0 |     4166.0 |     7369.5 |     3169.0 |     3572.5 |     294.0 |     344.0 |
| Zeugma-2PT   |     819.5 |  910.0 |     1472.0 |     1915.0 |     10284.0 |     12038.0 |    797.0 |     1134.0 |     3962.5 |     7310.0 |     3143.0 |     3549.0 |     291.0 |     341.5 |
| Zeugma-Link  | **845.5** |  911.5 | **1541.5** | **1959.0** | **10395.5** | **12709.0** |    906.0 | **1138.0** | **5568.5** | **7654.0** | **3233.5** | **3703.0** | **295.5** | **345.0** |

EOTABLE

# Section 2: Artifact download
# Note: If your environment has network access, this attempts to download the Figshare artifact.
# The Figshare page for the artifact is:
FIGSHARE_PAGE="https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879"
ARTIFACT_DIR=/workspace/artifact
mkdir -p "$ARTIFACT_DIR"

echo "[info] Attempting to download artifact page and locate files."
# Try to fetch the page and attempt to find direct download links (ndownloader figshare pattern)
curl -L -A 'Mozilla/5.0' "$FIGSHARE_PAGE" -o /tmp/figshare_page.html || true
if grep -q "ndownloader.figshare.com" /tmp/figshare_page.html 2>/dev/null; then
  echo "[info] Found ndownloader link in page; attempting to download all files referenced."
  # Extract likely file URLs and download them
  grep -oE 'https?://ndownloader\.figshare\.com/files/[0-9]+' /tmp/figshare_page.html | sort -u | while read -r url; do
    echo "[info] Downloading $url"
    curl -L "$url" -o "$ARTIFACT_DIR/$(basename $url)" || true
  done
else
  echo "[warn] Could not automatically find ndownloader links in the page."
  echo "[warn] If you have already downloaded the artifact manually, place it under $ARTIFACT_DIR and re-run this script."
fi

# If there are archives in ARTIFACT_DIR, try to extract them
if compgen -G "$ARTIFACT_DIR/*.zip" >/dev/null 2>&1; then
  for z in "$ARTIFACT_DIR"/*.zip; do
    echo "[info] Extracting $z"
    unzip -o "$z" -d "$ARTIFACT_DIR" || true
  done
fi
if compgen -G "$ARTIFACT_DIR/*.tar.gz" >/dev/null 2>&1; then
  for t in "$ARTIFACT_DIR"/*.tar.gz; do
    echo "[info] Extracting $t"
    tar -xzf "$t" -C "$ARTIFACT_DIR" || true
  done
fi

# Section 3: Reproduction commands
# The exact commands depend on the contents of the artifact. Below are the recommended Docker-based steps
# described in the artifact README. Adjust image names and script paths to match the artifact contents.

REPRO_OUT=/workspace/repro.txt
: > "$REPRO_OUT"

# Example: if the artifact supplies docker images as tarballs, load them first
if compgen -G "$ARTIFACT_DIR"/*.tar >/dev/null 2>&1; then
  for img in "$ARTIFACT_DIR"/*.tar; do
    echo "[info] Loading docker image from $img" | tee -a "$REPRO_OUT"
    docker load -i "$img" | tee -a "$REPRO_OUT" || echo "[warn] docker load failed for $img" | tee -a "$REPRO_OUT"
  done
fi

# Example: If the artifact contains docker-compose files, run them
if [ -f "$ARTIFACT_DIR/docker-compose.yml" ]; then
  echo "[info] Starting docker-compose services (detached)" | tee -a "$REPRO_OUT"
  (cd "$ARTIFACT_DIR" && docker-compose up -d) | tee -a "$REPRO_OUT" || true
fi

# Example run: if there is a provided script to generate Table 3 results, run it.
# We check common script locations used in artifacts.
POSSIBLE_SCRIPTS=(
  "$ARTIFACT_DIR/run_table3.sh"
  "$ARTIFACT_DIR/scripts/run_table3.sh"
  "$ARTIFACT_DIR/scripts/run_all.sh"
  "$ARTIFACT_DIR/bench/run_table3.sh"
)

RUN_SCRIPT=""
for s in "${POSSIBLE_SCRIPTS[@]}"; do
  if [ -x "$s" ]; then
    RUN_SCRIPT="$s"
    break
  fi
done

if [ -n "$RUN_SCRIPT" ]; then
  echo "[info] Found reproduction script: $RUN_SCRIPT. Running it. This may take several hours." | tee -a "$REPRO_OUT"
  # The script is expected to output to stdout; redirect to repro.txt
  "$RUN_SCRIPT" --output "$REPRO_OUT" || echo "[warn] Reproduction script exited with non-zero status" | tee -a "$REPRO_OUT"
else
  echo "[warn] No reproduction script found automatically. Please inspect $ARTIFACT_DIR and run the provided commands manually." | tee -a "$REPRO_OUT"
  echo "[info] Example commands (replace with artifact specifics):" | tee -a "$REPRO_OUT"
  cat >> "$REPRO_OUT" <<'EOT'
# Example commands to run manually (adjust to artifact structure):
# 1) docker run -d --init --entrypoint bash <image> -c 'sleep infinity'
# 2) docker exec <container> /bin/bash --noprofile --norc -c "cd /artifact && ./scripts/run_table3.sh --time 3h --trials 20 --output /tmp/table3_output.csv"
# 3) docker cp <container>:/tmp/table3_output.csv /workspace/repro_table3.csv
# 4) process the CSV to compute medians and format the Markdown table.
EOT
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
if [ -f "$REPRO_OUT" ]; then
  cat "$REPRO_OUT"
else
  echo "[warn] Reproduction output not available. See $ARTIFACT_DIR for artifact files and follow README instructions." 
fi
echo '</artisan_submit>'

echo "COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT"
