#!/usr/bin/bash
# Create expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3. Experimental results for repairing 10 C projects, comparing with SAVER and FootPatch. Columns marked as # are numbers of the total true positives found by Infer-v1.1.0 and PROVENFIX, summarised from Table 2. The numbers of false positives reported by Infer-v0.9.3 are marked as +n.**

| Project         | Repaired Bugs |
| --------------- | ------------: |
| Swoole          |            ?? |
| lxc             |            ?? |
| WavPack         |            ?? |
| flex            |            ?? |
| p11-kit         |            ?? |
| x264            |            ?? |
| recutils-1.8    |            ?? |
| inetutils-1.9.4 |            ?? |
| snort-2.9.13    |            ?? |
| grub            |            ?? |
| **Total**       |       **???** |

EOTABLE

# Ensure artifact present
artisan get https://github.com/songyahui/infer_TempFix

# Start a container from the provided image (isolated for this run)
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu >/dev/null 2>&1 || true
CONTAINER=$(docker run -d --init --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity') || { echo "ERROR: docker run failed" >&2; exit 1; }
sleep 1

# Prepare a compact repro file containing only project header and the "[Repaired Bugs]" line
rm -f /workspace/repro.txt
echo "Using container: $CONTAINER" > /workspace/repro.txt

projects=(
  "Swoole|spec_Swoole.c|swoole-src"
  "lxc|spec_Lxc.c|lxc"
  "WavPack|spec_WavPack.c|WavPack"
  "flex|spec_flex.c|flex"
  "p11-kit|spec_p11.c|p11-kit"
  "x264|spec-x264.c|x264"
  "recutils-1.8|spec-recutils.c|recutils-1.8"
  "inetutils-1.9.4|spec-inetutils.c|inetutils-1.9.4"
  "snort-2.9.13|spec_snort-2.9.13.c|snort-2.9.13"
  "grub|spec_Grub.c|grub"
)

for entry in "${projects[@]}"; do
  IFS='|' read -r name specfile dir <<< "$entry"
  echo "=== Project: $name ===" >> /workspace/repro.txt
  # Run the tool for the project but capture output into a small temp file per project
  docker exec "$CONTAINER" /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp $specfile spec.c || true && cd /home/benchmarks-RQ1N2/$dir && make clean >/dev/null 2>&1; /home/infer_TempFix/infer/bin/tempFix" > /tmp/prove_out.txt 2>&1 || true
  # Extract the relevant summary lines (Failed Assert and Repaired Bugs) to keep the repro compact
  grep -E '^\[Failed Assert\]|\[Repaired Bugs\]' /tmp/prove_out.txt >> /workspace/repro.txt || echo "[Repaired Bugs] MISSING" >> /workspace/repro.txt
  echo "" >> /workspace/repro.txt
done

# Clean up the container
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

# Print submission block with compact repro for formatting
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
