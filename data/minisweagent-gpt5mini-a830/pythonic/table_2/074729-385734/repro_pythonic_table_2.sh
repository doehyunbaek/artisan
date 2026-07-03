#!/usr/bin/env bash
set -eu
# repro_pythonic_table_2.sh
# Automates the reproduction steps for Table 2 per the provided workflow.

LOG=/workspace/repro.log
REPRO_OUT=/workspace/repro.txt
ARTIFACT_DIR=/workspace/artifact
WORKDIR=/workspace
ZENODO_RECORD_URL="https://zenodo.org/records/10554377"

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**

| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |
| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |
| Lambda    |                    112 |                     98 |                    53.33 |                    115 |                     95 |                    54.76 |
| Compr.    |                     99 |                    111 |                    47.14 |                    114 |                     96 |                    54.29 |
| MRF       |                     80 |                    130 |                    38.10 |                     85 |                    125 |                    40.48 |

EOTABLE

echo "Starting reproduction script" >"$LOG"
mkdir -p "$ARTIFACT_DIR"
cd "$ARTIFACT_DIR"

# Section 2: Artifact download
echo "Fetching Zenodo record page: $ZENODO_RECORD_URL" >>"$LOG"
# Download HTML of the record and try to find a file link to an archive (zip/tar.gz/tgz)
curl -L --fail -s "$ZENODO_RECORD_URL" -o /tmp/zenodo_record.html || { echo "Failed to fetch zenodo record HTML" >>"$LOG"; }
# Parse for file links to archives (common: .zip, .tar.gz, .tgz)
ARCHIVE_URL=$(grep -Eo 'https?://[^"]+\.(zip|tar\.gz|tgz)' /tmp/zenodo_record.html | head -n 1 || true)
if [ -z "$ARCHIVE_URL" ]; then
  echo "No archive link found on the Zenodo page; attempting to fetch common filename patterns" >>"$LOG"
  # Try plausible fallback names (may fail)
  ARCHIVE_URL="https://zenodo.org/record/10554377/files/artifact.zip"
fi
echo "Archive URL: $ARCHIVE_URL" >>"$LOG"
# Download archive
ARCHIVE_PATH="$ARTIFACT_DIR/artifact_download"
curl -L --fail -o "$ARCHIVE_PATH" "$ARCHIVE_URL" || {
  echo "Download failed for $ARCHIVE_URL; saving page for inspection" >>"$LOG"
  cp /tmp/zenodo_record.html "$ARTIFACT_DIR/zenodo_record.html" || true
}
# Try to unpack intelligently
file "$ARCHIVE_PATH" 2>>"$LOG" || true
# If it's not a real archive, try to list files in the artifact directory if present
if file "$ARCHIVE_PATH" | grep -q 'Zip archive'; then
  echo "Unpacking zip archive" >>"$LOG"
  unzip -o "$ARCHIVE_PATH" -d "$ARTIFACT_DIR" >>"$LOG" 2>&1 || true
elif file "$ARCHIVE_PATH" | grep -q -E 'gzip|tar'; then
  echo "Unpacking tar archive" >>"$LOG"
  tar -xzf "$ARCHIVE_PATH" -C "$ARTIFACT_DIR" >>"$LOG" 2>&1 || true
else
  echo "Archive file not recognized as zip/tar; listing artifact dir for clues" >>"$LOG"
fi

# Also attempt to download zenodo 'files' JSON to find filenames (best-effort)
curl -s "https://zenodo.org/api/records/10554377" -o /tmp/zenodo_api.json || true
jq -r '.files[].links.self' /tmp/zenodo_api.json 2>/dev/null | grep -E '\.(zip|tar.gz|tgz)$' | head -n1 | xargs -r -I{} curl -L -o "$ARTIFACT_DIR/artifact_from_api" "{}" || true

# Section 3: Read README and locate relevant commands
# Find a README or README.md under the artifact directory or workspace root
README_PATH=""
for candidate in "$ARTIFACT_DIR"/README* "$ARTIFACT_DIR"/*/README* /workspace/README*; do
  if [ -f "$candidate" ]; then
    README_PATH="$candidate"
    break
  fi
done
if [ -z "$README_PATH" ]; then
  echo "WARNING: README not found under artifact; attempting to find other docs" >>"$LOG"
  README_PATH=$(find "$ARTIFACT_DIR" -maxdepth 3 -type f -iname 'readme*' | head -n1 || true) || true
fi
echo "Using README at: $README_PATH" >>"$LOG"

# Extract docker-related commands and "Table 2" mentions
grep -in "docker" "$README_PATH" 2>>"$LOG" || true > /tmp/README_docker_lines || true
grep -in "Table 2" "$README_PATH" 2>>"$LOG" || true > /tmp/README_table2_lines || true
cp "$README_PATH" /tmp/README_copy 2>>"$LOG" || true

echo "Docker lines (excerpt):" >>"$LOG"
sed -n '1,120p' /tmp/README_docker_lines >>"$LOG" 2>&1 || true
echo "Table 2 lines (excerpt):" >>"$LOG"
sed -n '1,120p' /tmp/README_table2_lines >>"$LOG" 2>&1 || true

# Parse docker actions in preferred order: pull -> load -> import -> build
DOCKER_PULLS=()
DOCKER_LOADS=()
DOCKER_IMPORTS=()
DOCKER_BUILDS=()
while read -r line; do
  # simple heuristics to extract commands
  if echo "$line" | grep -qi "docker pull"; then
    img=$(echo "$line" | sed -E 's/.*docker pull +([^ ]+).*/\1/')
    DOCKER_PULLS+=("$img")
  elif echo "$line" | grep -qi "docker load"; then
    # capture filename if present
    file=$(echo "$line" | sed -E 's/.*docker load( --input|-i)? +(-i )?([^ ]+).*/\3/; s/.*docker load +< *([^ ]+).*/\1/')
    DOCKER_LOADS+=("$file")
  elif echo "$line" | grep -qi "docker import"; then
    dockerfile=$(echo "$line" | sed -E 's/.*docker import +([^ ]+).*/\1/')
    DOCKER_IMPORTS+=("$dockerfile")
  elif echo "$line" | grep -qi "docker build"; then
    # try to get -t tag or context
    tag=$(echo "$line" | sed -n 's/.*-t\s\+\([^ ]\+\).*/\1/p')
    if [ -n "$tag" ]; then
      DOCKER_BUILDS+=("$tag")
    else
      # fallback: use context path
      ctx=$(echo "$line" | awk '{print $NF}')
      DOCKER_BUILDS+=("$ctx")
    fi
  fi
done < /tmp/README_copy || true

echo "Discovered docker pulls: ${DOCKER_PULLS[*]}" >>"$LOG"
echo "Discovered docker loads: ${DOCKER_LOADS[*]}" >>"$LOG"
echo "Discovered docker imports: ${DOCKER_IMPORTS[*]}" >>"$LOG"
echo "Discovered docker builds (tags/contexts): ${DOCKER_BUILDS[*]}" >>"$LOG"

# Section 4: Acquire Docker images in the preferred order
# Note: these commands may fail if docker is unavailable; we capture logs and continue.
for img in "${DOCKER_PULLS[@]:-}"; do
  echo "Attempting docker pull $img" >>"$LOG"
  docker pull "$img" >>"$LOG" 2>&1 || echo "docker pull failed for $img" >>"$LOG"
done

# For docker load, if filenames are relative, try to find them in artifact dir; otherwise attempt to load given path.
for f in "${DOCKER_LOADS[@]:-}"; do
  if [ -z "$f" ]; then
    continue
  fi
  # choose candidate file path
  if [ -f "$ARTIFACT_DIR/$f" ]; then
    path="$ARTIFACT_DIR/$f"
  elif [ -f "$f" ]; then
    path="$f"
  else
    path="$f"
  fi
  echo "Attempting docker load from $path" >>"$LOG"
  docker load -i "$path" >>"$LOG" 2>&1 || echo "docker load failed for $path" >>"$LOG"
done

for imp in "${DOCKER_IMPORTS[@]:-}"; do
  if [ -f "$ARTIFACT_DIR/$imp" ]; then
    path="$ARTIFACT_DIR/$imp"
  else
    path="$imp"
  fi
  echo "Attempting docker import from $path" >>"$LOG"
  docker import "$path" >>"$LOG" 2>&1 || echo "docker import failed for $path" >>"$LOG"
done

# For builds, attempt to run docker build if contexts exist inside artifact; otherwise skip
for ctx in "${DOCKER_BUILDS[@]:-}"; do
  if [ -d "$ARTIFACT_DIR/$ctx" ]; then
    echo "Attempting docker build -t repro_tmp:$ctx $ARTIFACT_DIR/$ctx" >>"$LOG"
    docker build -t "repro_tmp:$ctx" "$ARTIFACT_DIR/$ctx" >>"$LOG" 2>&1 || echo "docker build failed for context $ctx" >>"$LOG"
  else
    # if ctx looks like a tag, skip (likely already built/pulled)
    echo "Skipping docker build for $ctx (context not found)" >>"$LOG"
  fi
done

# Determine an image to run: prefer first DOCKER_PULLS or DOCKER_BUILDS tag or repro_tmp
IMAGE_TO_RUN=""
if [ "${#DOCKER_PULLS[@]}" -gt 0 ]; then
  IMAGE_TO_RUN="${DOCKER_PULLS[0]}"
elif [ "${#DOCKER_BUILDS[@]}" -gt 0 ]; then
  IMAGE_TO_RUN="${DOCKER_BUILDS[0]}"
elif docker images --format '{{.Repository}}:{{.Tag}}' | grep -q 'repro_tmp'; then
  IMAGE_TO_RUN=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep repro_tmp | head -n1)
else
  # As a last resort, try to find any image that looks relevant
  IMAGE_TO_RUN=$(docker images --format '{{.Repository}}:{{.Tag}}' | head -n1 || true)
fi
echo "Selected image to run: $IMAGE_TO_RUN" >>"$LOG"

CONTAINER_ID=""
if [ -n "$IMAGE_TO_RUN" ]; then
  # start container detached with replacement run syntax
  echo "Starting container from image $IMAGE_TO_RUN" >>"$LOG"
  CONTAINER_ID=$(docker run -d --init --entrypoint bash "$IMAGE_TO_RUN" -c 'sleep infinity' 2>>"$LOG" || true)
  echo "Container ID: $CONTAINER_ID" >>"$LOG"
fi

# Section 5: Execute reproduction commands
# Find explicit reproduction commands in README near "Table 2" or lines mentioning "repro" or "table"
CANDIDATES=()
# Lines mentioning "table" or "table 2" or "repro" or "reproduce"
grep -inE "table|repro|reproduce|table 2|Table 2" "$README_PATH" 2>>"$LOG" | sed 's/^.*: *//' | head -n 30 | while read -r l; do
  echo "$l"
done > /tmp/README_candidate_lines || true

# Also search for scripts that might be used to reproduce table (common names)
for script in "$ARTIFACT_DIR"/run* "$ARTIFACT_DIR"/repro* "$ARTIFACT_DIR"/*reproduce* "$ARTIFACT_DIR"/*table* /workspace/run* /workspace/repro*; do
  if [ -f "$script" ]; then
    CANDIDATES+=("$script")
  fi
done

# Add some fallback commands to try inside the container (non-destructive)
CANDIDATES+=( "python reproduce.py" "python3 reproduce.py" "bash reproduce.sh" "bash run.sh" "make table2" "python scripts/reproduce_table2.py" )
echo "Candidate commands to try:" >>"$LOG"
printf '%s\n' "${CANDIDATES[@]}" >>"$LOG"

# Helper to attempt to run a command either locally or inside the container
attempt_cmd() {
  cmd="$1"
  echo "Attempting: $cmd" >>"$LOG"
  if [ -n "$CONTAINER_ID" ]; then
    docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "$cmd" >>"$REPRO_OUT" 2>>"$LOG" && return 0 || return 1
  else
    # Try locally in artifact dir or workspace
    (cd "$ARTIFACT_DIR" 2>/dev/null || true; /bin/bash -lc "$cmd") >>"$REPRO_OUT" 2>>"$LOG" && return 0 || return 1
  fi
}

# First try any explicit script files found
FOUND=false
for f in "${CANDIDATES[@]}"; do
  # If f is a path to a file, attempt to run it appropriately
  if [ -f "$f" ]; then
    chmod +x "$f" || true
    attempt_cmd "./$(basename "$f")" && FOUND=true && break || true
  else
    # Otherwise attempt the command as-is
    attempt_cmd "$f" && FOUND=true && break || true
  fi
done

# If nothing found, attempt to run any Makefile targets "table" or "table2" or "all"
if [ "$FOUND" = false ]; then
  if [ -f "$ARTIFACT_DIR/Makefile" ] || [ -f "$WORKDIR/Makefile" ]; then
    for t in table table2 all; do
      attempt_cmd "make $t" && FOUND=true && break || true
    done
  fi
fi

# If still not found, attempt a generic Python script search for "table 2" or "table2" in repository and run it
if [ "$FOUND" = false ]; then
  for py in $(grep -RIl "table 2\|table2\|reproduce" "$ARTIFACT_DIR" 2>/dev/null | head -n 20 || true); do
    attempt_cmd "python3 $(realpath --relative-to="$ARTIFACT_DIR" "$py")" && FOUND=true && break || true
  done
fi

if [ "$FOUND" = false ]; then
  echo "No reproduction command succeeded or was found. See logs for details." >>"$LOG"
  echo "See $LOG and copied README at /tmp/README_copy" >>"$REPRO_OUT"
else
  echo "A reproduction attempt succeeded. Output saved to $REPRO_OUT" >>"$LOG"
fi

# Section 6: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submission_block.txt
# If /workspace/repro.txt exists, include it; otherwise include the logfile
if [ -s "$REPRO_OUT" ]; then
  sed -n '1,10000p' "$REPRO_OUT" >> /workspace/repro_submission_block.txt || true
else
  sed -n '1,10000p' "$LOG" >> /workspace/repro_submission_block.txt || true
fi
echo '</artisan_submit>' >> /workspace/repro_submission_block.txt

echo "Script completed. Logs: $LOG, Repro output: $REPRO_OUT, Submission block: /workspace/repro_submission_block.txt" >>"$LOG"
