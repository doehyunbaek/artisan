#!/usr/bin/bash
set -euo pipefail
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       8 |         52 |         17.3 |          25 |         3 |
| 10 |       8 |         27 |         13.5 |          23 |         3 |
| 11 |      11 |          4 |            4 |           4 |         3 |
| 13 |      13 |          1 |            1 |           1 |         0 |
| 14 |      14 |          0 |            0 |           0 |         0 |

EOTABLE

# Section 2: Artifact download
echo "[STEP] Downloading Zenodo record page for 10423670" | tee /workspace/repro.txt
curl -sL 'https://zenodo.org/records/10423670' -o /workspace/zenodo_record_10423670.html || true
echo "[STEP] Extracting file links from Zenodo HTML (if any) and downloading them to /workspace" | tee -a /workspace/repro.txt
grep -oP 'href="\K(/record/10423670/files/[^"]+)' /workspace/zenodo_record_10423670.html 2>/dev/null | sed -E 's/&amp;/\&/g' | while read -r path; do
  url="https://zenodo.org${path}"
  echo "[DL] $url" | tee -a /workspace/repro.txt
  wget -c -P /workspace "$url" || echo "[WARN] Failed to download $url" | tee -a /workspace/repro.txt
done || true

# Also try to download the "download all" zip if present via the 'download' link
if ! ls /workspace | grep -qiE 'zip|tar|tgz|tar.gz|tar.bz2'; then
  echo "[INFO] No archive files found yet; attempting to download record page as fallback." | tee -a /workspace/repro.txt
fi

# Section 3: Reproduction commands (populate from reviewed steps)
echo "[STEP] Locating README and paper files in /workspace" | tee -a /workspace/repro.txt
ls -la /workspace | tee -a /workspace/repro.txt

# Prefer README.md or README
README_CANDIDATES=(/workspace/README.md /workspace/README /workspace/readme.md /workspace/README.txt)
README=""
for f in "${README_CANDIDATES[@]}"; do
  if [ -f "$f" ]; then
    README="$f"
    break
  fi
done
# If none found, try to find any README
if [ -z "$README" ]; then
  README="$(find /workspace -maxdepth 2 -type f -iname 'readme*' | head -n1 || true)"
fi

if [ -n "$README" ] && [ -f "$README" ]; then
  echo "[FOUND README] $README" | tee -a /workspace/repro.txt
  echo "[GREP docker lines]" | tee -a /workspace/repro.txt
  grep -in 'docker' "$README" | tee -a /workspace/repro.txt || true
  echo "[GREP Table 5 references in README]" | tee -a /workspace/repro.txt
  grep -in 'Table 5' "$README" | tee -a /workspace/repro.txt || true
else
  echo "[WARN] No README found in /workspace" | tee -a /workspace/repro.txt
fi

# Convert any PDF paper to markdown using provided uvx tool if present
PAPER_MD="/workspace/paper.md"
if [ -f "$PAPER_MD" ]; then
  echo "[FOUND] paper.md at $PAPER_MD" | tee -a /workspace/repro.txt
else
  # try to find a PDF and convert
  PDF="$(find /workspace -maxdepth 2 -type f -iname '*.pdf' | head -n1 || true)"
  if [ -n "$PDF" ]; then
    echo "[INFO] Converting PDF to markdown: $PDF" | tee -a /workspace/repro.txt
    uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' "$PDF" > /workspace/paper.md 2>/workspace/uvx_paper_conversion.log || true
    echo "[INFO] Conversion log:" | tee -a /workspace/repro.txt
    tail -n 200 /workspace/uvx_paper_conversion.log 2>/dev/null | tee -a /workspace/repro.txt || true
    PAPER_MD="/workspace/paper.md"
  else
    echo "[WARN] No paper PDF found to convert." | tee -a /workspace/repro.txt
  fi
fi

# Inspect paper.md for Table 5
if [ -f "$PAPER_MD" ]; then
  echo "[GREP Table 5 in paper.md]" | tee -a /workspace/repro.txt
  grep -in 'Table 5' "$PAPER_MD" | tee -a /workspace/repro.txt || true
fi

# Attempt to identify docker related commands in README and run them in preferred order
if [ -n "$README" ] && [ -f "$README" ]; then
  echo "[STEP] Extracting docker commands from README and categorizing (pull, load, import, build)" | tee -a /workspace/repro.txt
  # Extract full lines containing docker commands
  grep -Eio '(^|\s)(docker (pull|load|import|build|run)[^;]*)' "$README" | sed -E 's/^[[:space:]]*//' | sort -u > /workspace/docker_cmds.txt || true
  echo "[INFO] docker commands found:" | tee -a /workspace/repro.txt
  sed -n '1,200p' /workspace/docker_cmds.txt | tee -a /workspace/repro.txt || true

  # Run docker pull first, then docker load/import, then docker build. For docker run -it replace as required.
  # Note: these commands may fail in restricted environments; continue on error and log outputs.
  echo "[ACTION] Executing docker commands in preferred order (pull -> load -> import -> build -> run)" | tee -a /workspace/repro.txt
  # Pulls
  grep -i 'docker pull' /workspace/docker_cmds.txt | while read -r cmd; do
    echo "[DOCKER_PULL] $cmd" | tee -a /workspace/repro.txt
    bash -lc "$cmd" >> /workspace/docker_pull.log 2>&1 || echo "[WARN] docker pull failed for: $cmd" | tee -a /workspace/repro.txt
  done || true
  # Loads
  grep -i 'docker load' /workspace/docker_cmds.txt | while read -r cmd; do
    echo "[DOCKER_LOAD] $cmd" | tee -a /workspace/repro.txt
    bash -lc "$cmd" >> /workspace/docker_load.log 2>&1 || echo "[WARN] docker load failed for: $cmd" | tee -a /workspace/repro.txt
  done || true
  # Imports
  grep -i 'docker import' /workspace/docker_cmds.txt | while read -r cmd; do
    echo "[DOCKER_IMPORT] $cmd" | tee -a /workspace/repro.txt
    bash -lc "$cmd" >> /workspace/docker_import.log 2>&1 || echo "[WARN] docker import failed for: $cmd" | tee -a /workspace/repro.txt
  done || true
  # Builds
  grep -i 'docker build' /workspace/docker_cmds.txt | while read -r cmd; do
    echo "[DOCKER_BUILD] $cmd" | tee -a /workspace/repro.txt
    bash -lc "$cmd" >> /workspace/docker_build.log 2>&1 || echo "[WARN] docker build failed for: $cmd" | tee -a /workspace/repro.txt
  done || true
  # Runs (with replacement of -it)
  grep -i 'docker run' /workspace/docker_cmds.txt | while read -r cmd; do
    echo "[DOCKER_RUN] Original: $cmd" | tee -a /workspace/repro.txt
    # Replace -it with -d --init --entrypoint bash <image> -c 'sleep infinity'
    # Heuristic: find the IMAGE argument as last token after known options
    IMAGE=$(echo "$cmd" | awk '{print $NF}')
    if [ -n "$IMAGE" ]; then
      alt_cmd="docker run -d --init --entrypoint bash ${IMAGE} -c 'sleep infinity'"
      echo "[DOCKER_RUN] Replacing with: $alt_cmd" | tee -a /workspace/repro.txt
      bash -lc "$alt_cmd" >> /workspace/docker_run.log 2>&1 || echo "[WARN] docker run (replacement) failed for: $IMAGE" | tee -a /workspace/repro.txt
    else
      echo "[WARN] Could not parse image from docker run command: $cmd" | tee -a /workspace/repro.txt
    fi
  done || true
else
  echo "[INFO] No README to extract docker commands from." | tee -a /workspace/repro.txt
fi

# If any container was started, show 'docker ps' and attempt to exec reproduction commands mentioned in README or scripts
echo "[INFO] Listing docker containers (if docker is available)" | tee -a /workspace/repro.txt
docker ps -a >> /workspace/docker_ps.log 2>&1 || echo "[WARN] docker ps failed (docker may not be available)" | tee -a /workspace/repro.txt

# Attempt to find scripts or commands in the repo that refer to 'table5' or similar and run them
echo "[STEP] Searching repository for scripts referencing 'table5' or 'table_5' or 'table-5' to execute" | tee -a /workspace/repro.txt
find /workspace -maxdepth 3 -type f -iname '*table5*' -o -iname '*table_5*' -o -iname '*table-5*' | tee -a /workspace/repro.txt | while read -r script; do
  if [ -x "$script" ]; then
    echo "[EXEC] Running $script" | tee -a /workspace/repro.txt
    "$script" >> /workspace/repro_script_runs.log 2>&1 || echo "[WARN] Execution failed: $script" | tee -a /workspace/repro.txt
  else
    # try to run with bash
    echo "[EXEC] Running with bash: $script" | tee -a /workspace/repro.txt
    bash "$script" >> /workspace/repro_script_runs.log 2>&1 || echo "[WARN] Execution failed (bash) for: $script" | tee -a /workspace/repro.txt
  fi
done || true

# Collect and summarize potential outputs for Table 5
echo "[STEP] Gathering candidate outputs and logs to /workspace/repro.txt" | tee -a /workspace/repro.txt
echo "" >> /workspace/repro.txt
echo "===== Candidate logs summary (tail) =====" >> /workspace/repro.txt
for l in /workspace/docker_*.log /workspace/repro_script_runs.log /workspace/uvx_paper_conversion.log /workspace/docker_ps.log; do
  if [ -f "$l" ]; then
    echo "---- $l (last 200 lines) ----" >> /workspace/repro.txt
    tail -n 200 "$l" >> /workspace/repro.txt || true
  fi
done

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submission_block.txt
echo "Reproduction attempt summary for Table 5. Please find logs at /workspace/repro.txt and artifacts in /workspace." >> /workspace/repro_submission_block.txt
echo "</artisan_submit>" >> /workspace/repro_submission_block.txt

echo "Reproduction script completed. Logs and collected outputs are in /workspace/repro.txt. Expected table is at /workspace/expected.md" | tee -a /workspace/repro.txt

