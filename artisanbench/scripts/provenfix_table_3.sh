#!/usr/bin/bash
git clone https://github.com/songyahui/infer_TempFix
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
container=prove_n_fix_repro
docker rm -f "$container" >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name "$container" yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'
docker exec "$container" /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && git reset --hard && git checkout main && ./compile"
run_proj() {
  local spec="$1"
  local dir="$2"
  docker exec "$container" /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp $spec spec.c && cd /home/benchmarks-RQ1N2/$dir && make clean >/dev/null 2>&1 && /home/infer_TempFix/infer/bin/tempFix 2>/dev/null | grep '\[Repaired' | tail -1 | awk '{print \$NF}'"
}

Swoole=$(run_proj spec_Swoole.c swoole-src)
Lxc=$(run_proj spec_Lxc.c lxc)
WavPack=$(run_proj spec_WavPack.c WavPack)
Flex=$(run_proj spec_flex.c flex)
P11kit=$(run_proj spec_p11.c p11-kit)
X264=$(run_proj spec-x264.c x264)
Recutils=$(run_proj spec-recutils.c recutils-1.8)
Inetutils=$(run_proj spec-inetutils.c inetutils-1.9.4)
Snort=$(run_proj spec_snort-2.9.13.c snort-2.9.13)
Grub=$(run_proj spec_Grub.c grub)

Total=$((Swoole + Lxc + WavPack + Flex + P11kit + X264 + Recutils + Inetutils + Snort + Grub))

cat > /workspace/repro.txt <<EOT
**Table 3. Experimental results for repairing 10 C projects, comparing with SAVER and FootPatch. Columns marked as # are numbers of the total true positives found by Infer-v1.1.0 and PROVENFIX, summarised from Table 2. The numbers of false positives reported by Infer-v0.9.3 are marked as +n.**

| Project         | Repaired Bugs |
| --------------- | ------------: |
| Swoole          |            $Swoole |
| lxc             |            $Lxc |
| WavPack         |            $WavPack |
| flex            |            $Flex |
| p11-kit         |            $P11kit |
| x264            |            $X264 |
| recutils-1.8    |            $Recutils |
| inetutils-1.9.4 |            $Inetutils |
| snort-2.9.13    |            $Snort |
| grub            |            $Grub |
| **Total**       |       **$Total** |

EOT

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
