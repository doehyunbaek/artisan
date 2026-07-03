#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3. Experimental results for repairing 10 C projects, comparing with SAVER and FootPatch. Columns marked as # are numbers of the total true positives found by Infer-v1.1.0 and PROVENFIX, summarised from Table 2. The numbers of false positives reported by Infer-v0.9.3 are marked as +n.**

| Project         | Repaired Bugs |
| --------------- | ------------: |
| Swoole          |            98 |
| lxc             |            56 |
| WavPack         |            52 |
| flex            |            24 |
| p11-kit         |            37 |
| x264            |            21 |
| recutils-1.8    |            72 |
| inetutils-1.9.4 |            37 |
| snort-2.9.13    |            85 |
| grub            |            12 |
| **Total**       |       **494** |

EOTABLE

# Section 2: Artifact download
# Clone the artifact repository if not already present
if [ ! -d /workspace/infer_TempFix ]; then
  git clone https://github.com/songyahui/infer_TempFix /workspace/infer_TempFix || true
fi

# Prefer Docker image provided by the authors; attempt to pull it (may be large)
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu || true

# Section 3: Reproduction commands (best-effort)
# This script attempts to run the authors' docker image; if unavailable,
# it falls back to compiling and running the tool from the cloned source.

REPRO_OUT=/workspace/repro.txt
: > "$REPRO_OUT"

# Try using the docker image (detached container with sleep)
if docker image inspect yahuuuuui/fse24-prove_n_fix:ubuntu > /dev/null 2>&1; then
  CID=$(docker run -d --init --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity' 2>/dev/null || true)
  if [ -n "$CID" ]; then
    echo "[INFO] Running tempFix inside docker container $CID" >> "$REPRO_OUT"
    # The repository and infer binaries are expected under /home/infer_TempFix in the image
    docker exec "$CID" /bin/bash --noprofile --norc -c "cd /home/infer_TempFix || true; if [ -x infer/bin/tempFix ]; then infer/bin/tempFix; else echo 'tempFix binary not found in container'; fi" >> "$REPRO_OUT" 2>&1 || true
    docker kill "$CID" >/dev/null 2>&1 || true
  else
    echo "[WARN] Failed to start docker container" >> "$REPRO_OUT"
  fi
else
  echo "[WARN] Docker image not available locally; falling back to local build" >> "$REPRO_OUT"
fi

# Fallback: build from source in the workspace (may require system deps)
if [ -d /workspace/infer_TempFix ]; then
  echo "[INFO] Attempting local build and run in /workspace/infer_TempFix" >> "$REPRO_OUT"
  set -o pipefail
  (cd /workspace/infer_TempFix && ./compile) >> "$REPRO_OUT" 2>&1 || echo "[WARN] Local compile failed or requires additional deps" >> "$REPRO_OUT"
  if [ -x /workspace/infer_TempFix/infer/bin/tempFix ]; then
    echo "[INFO] Running local tempFix binary" >> "$REPRO_OUT"
    /workspace/infer_TempFix/infer/bin/tempFix >> "$REPRO_OUT" 2>&1 || true
  else
    echo "[WARN] Local tempFix binary not found after compile" >> "$REPRO_OUT"
  fi
else
  echo "[ERROR] infer_TempFix source not found in /workspace" >> "$REPRO_OUT"
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat "$REPRO_OUT"
echo '</artisan_submit>'
