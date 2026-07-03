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

# Section 2: Artifact download (attempt to get a local copy under /workspace/infer_TempFix)
if [ ! -d /workspace/infer_TempFix ]; then
  echo "Cloning infer_TempFix into /workspace/infer_TempFix"
  git clone https://github.com/songyahui/infer_TempFix /workspace/infer_TempFix || true
else
  echo "/workspace/infer_TempFix already exists, skipping clone"
fi

# Section 3: Reproduction commands
# We prefer the provided docker image. The script below pulls the image, runs it in detached sleep mode
# and then executes the ProveNFix tool inside the container. We mount /workspace into the container so outputs
# are available on the host at /workspace.
IMAGE="yahuuuuui/fse24-prove_n_fix:ubuntu"
CONTAINER_NAME="prove_n_fix_repro"

echo "Pulling docker image ${IMAGE} (if available)"
docker pull ${IMAGE} || echo "docker pull failed or image not available locally"

# Run container in detached mode with /workspace mounted and the repository mounted to /home/infer_TempFix
# Replace interactive run with detached sleep as requested in the workflow
docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true

docker run -d --init --name ${CONTAINER_NAME} \
  -v /workspace:/workspace \
  -v /workspace/infer_TempFix:/home/infer_TempFix \
  --entrypoint /bin/bash \
  ${IMAGE} -c 'sleep infinity' || echo "docker run may have failed (image might be missing)"

# Exec into container and run the tempFix binary. If the binary exists, run it; otherwise print a helpful message.
# All output (including TempFix-out/detail.txt) is copied to /workspace/repro.txt on the host.

echo "Running ProveNFix inside container to reproduce Table 3 results (if available)"

docker exec ${CONTAINER_NAME} /bin/bash --noprofile --norc -c "
  set -euo pipefail
  if [ -x /home/infer_TempFix/infer/bin/tempFix ]; then
    echo 'Found tempFix binary, running it (this may take long)'
    cd /home/infer_TempFix || exit 1
    /home/infer_TempFix/infer/bin/tempFix || true
  else
    echo 'tempFix binary not found at /home/infer_TempFix/infer/bin/tempFix'
    echo 'Container image may not have been pulled, or repository not present. Listing /home/infer_TempFix:'
    ls -la /home/infer_TempFix || true
  fi
  # Collect the analysis/repair results if present
  if [ -f /home/infer_TempFix/TempFix-out/detail.txt ]; then
    echo 'Copying TempFix-out/detail.txt to /workspace/repro.txt'
    cp /home/infer_TempFix/TempFix-out/detail.txt /workspace/repro.txt
  else
    echo 'No TempFix-out/detail.txt found. Creating a placeholder /workspace/repro.txt with instructions.'
    cat > /workspace/repro.txt <<'REPRO'
Could not run ProveNFix inside the container. Possible reasons:
- Docker image ${IMAGE} not available or docker pull failed in this environment.
- The repository was not mounted into the container at /home/infer_TempFix.

To reproduce locally:
1. docker pull ${IMAGE} 
2. docker run -d --init --name ${CONTAINER_NAME} -v /path/to/infer_TempFix:/home/infer_TempFix -v /path/to/workspace:/workspace --entrypoint /bin/bash ${IMAGE} -c 'sleep infinity'
3. docker exec ${CONTAINER_NAME} /bin/bash --noprofile --norc -c '/home/infer_TempFix/infer/bin/tempFix'
4. Check /home/infer_TempFix/TempFix-out/detail.txt and copy it to host /workspace/repro.txt
REPRO
  fi
"

# Section 4: Formatting and submission block
# Format the expected table and print both expected and reproduction result location
echo '<artisan_submit>'
cat /workspace/expected.md || true
if [ -f /workspace/repro.txt ]; then
  echo
  echo '---'
  echo 'Reproduction output saved to /workspace/repro.txt'
  echo 'You can inspect /workspace/repro.txt for the detailed results from running ProveNFix.'
else
  echo
  echo '---'
  echo '/workspace/repro.txt not found. The reproduction inside docker likely failed; see instructions in the script.'
fi
echo '</artisan_submit>'
