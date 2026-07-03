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
git clone https://github.com/songyahui/infer_TempFix.git /workspace/infer_TempFix
# Section 3: Reproduction commands (populate from reviewed steps)
# Start the docker container with the artifact
container_id=$(docker run -d --init --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity')
sleep 5
# Extract repaired bugs from each project
{
echo "**Table 3. Experimental results for repairing 10 C projects, comparing with SAVER and FootPatch. Columns marked as # are numbers of the total true positives found by Infer-v1.1.0 and PROVENFIX, summarised from Table 2. The numbers of false positives reported by Infer-v0.9.3 are marked as +n.**"
echo ""
echo "| Project         | Repaired Bugs |"
echo "| --------------- | ------------: |"
total=0
for proj in swoole-src lxc WavPack flex p11-kit x264 recutils-1.8 inetutils-1.9.4 snort-2.9.13 grub; do
    # Get the repaired bugs count from detail.txt
    count=$(docker exec "$container_id" /bin/bash --noprofile --norc -c "grep '\[Repaired.*Bugs\]' /home/benchmarks-RQ1N2/$proj/TempFix-out/detail.txt 2>/dev/null | awk '{print \$NF}' || echo '0'")
    # Map directory names to table names
    case $proj in
        swoole-src) name="Swoole" ;;
        lxc) name="lxc" ;;
        WavPack) name="WavPack" ;;
        flex) name="flex" ;;
        p11-kit) name="p11-kit" ;;
        x264) name="x264" ;;
        recutils-1.8) name="recutils-1.8" ;;
        inetutils-1.9.4) name="inetutils-1.9.4" ;;
        snort-2.9.13) name="snort-2.9.13" ;;
        grub) name="grub" ;;
    esac
    printf "| %-15s | %13s |\n" "$name" "$count"
    total=$((total + count))
done
printf "| %-15s | %13s |\n" "**Total**" "**$total**"
} > /workspace/repro.txt
# Stop the container
docker stop "$container_id" >/dev/null
docker rm "$container_id" >/dev/null
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
