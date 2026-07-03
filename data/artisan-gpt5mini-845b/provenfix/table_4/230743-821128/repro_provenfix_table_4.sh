#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4. Automatically finding/fixing double-free bugs.**

| Project   |         Repaired Bugs |
| --------- | --------------------: |
| lxc       |                     ? |
| p??-kit   |                     ? |
| grub      |                     ? |
| **Total** |                 **?** |

EOTABLE

# Section 2: Artifact download
artisan get https://github.com/songyahui/infer_TempFix

# Section 3: Reproduction commands (populate from reviewed steps)
# Pull and run the authors' Docker image (detached, init, sleep infinity)
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
docker run -d --init --name provnfix --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Prepare the tool: fetch branches, stash local changes, checkout doubleFreeClose and compile inside the container
docker exec provnfix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && git fetch --all --prune && git stash push -u -m 'auto-stash before switching to doubleFreeClose' || true && git checkout doubleFreeClose && ./compile"

# Ensure workspace exists on host
mkdir -p /workspace

# Run ProveNFix on p11-kit and capture output to /workspace/repro.txt
docker exec provnfix /bin/bash --noprofile --norc -c "cp /home/infer_TempFix/spec_Temp_p11.c /home/infer_TempFix/spec.c && cd /home/benchmarks-RQ3/p11-kit && /home/infer_TempFix/infer/bin/tempFix >/home/benchmarks-RQ3/p11-kit/TempFix-out/detail.txt 2>&1 && echo 'p11-kit:' && tail -n +1 /home/benchmarks-RQ3/p11-kit/TempFix-out/detail.txt" > /workspace/repro.txt

# Run ProveNFix on lxc and append to repro file
docker exec provnfix /bin/bash --noprofile --norc -c "cp /home/infer_TempFix/spec_Temp_lxc.c /home/infer_TempFix/spec.c && cd /home/benchmarks-RQ3/lxc && /home/infer_TempFix/infer/bin/tempFix >/home/benchmarks-RQ3/lxc/TempFix-out/detail.txt 2>&1 && echo 'lxc:' && tail -n +1 /home/benchmarks-RQ3/lxc/TempFix-out/detail.txt" >> /workspace/repro.txt

# Run ProveNFix on grub and append to repro file
docker exec provnfix /bin/bash --noprofile --norc -c "cp /home/infer_TempFix/spec_Temp_grub.c /home/infer_TempFix/spec.c && cd /home/benchmarks-RQ3/grub && /home/infer_TempFix/infer/bin/tempFix >/home/benchmarks-RQ3/grub/TempFix-out/detail.txt 2>&1 && echo 'grub:' && tail -n +1 /home/benchmarks-RQ3/grub/TempFix-out/detail.txt" >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
