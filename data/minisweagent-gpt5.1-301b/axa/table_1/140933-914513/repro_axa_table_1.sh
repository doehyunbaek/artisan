#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Extensions and Changes of Single-Language Analyses for Integration into AXA**

| Analysis   | Detector             | Lattice | Solver | Connector | Translator (to Java) | Total |
| ---------- | -------------------- | ------: | -----: | --------: | -------------------- | ----- |
| Java       | 836                  | 60 (JS) |      0 |         0 | –                    | 896   |
| JavaScript | 166 + 2              |   90+14 |      2 |       452 | 137                  | 863   |
| Native     | 328                  |     107 |     16 |      1025 | 16                   | 1492  |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L 'https://zenodo.org/records/13374578/files/axa-artifact.zip?download=1' -o axa_artifact.zip
unzip -o axa_artifact.zip
curl -L 'https://zenodo.org/records/13374578/files/axa-artifact-image.tar?download=1' -o axa-artifact-image.tar
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace
docker load < /workspace/axa-artifact-image.tar
docker rm -f axa_table1_container 2>/dev/null || true
docker run -d --init --entrypoint bash --name axa_table1_container axaimage -c 'sleep infinity'
docker exec axa_table1_container /bin/bash --noprofile --norc -c "/runner/printLOCs.sh" > /workspace/raw_table1.txt
grep -E '^(Analysis|Java($|\t)|JavaScript|Native)' /workspace/raw_table1.txt > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
{
  echo '**Table 1: Implementation Effort (Reproduced)**'
  echo
  echo '| Analysis   | Detector | Lattice | Solver | Connector | Translator (to Java) | Total |'
  echo '| ---------- | -------- | ------- | ------ | --------- | -------------------- | ----- |'
  awk '{
    if ($1=="Analysis") next;
    if ($1=="Java") {
      det=$2; lat=$3; solv=$4; conn=$5; trans=$6; tot=$7;
    } else if ($1=="JavaScript") {
      det=$2" "$3" "$4; lat=$5" "$6" "$7; solv=$8; conn=$9; trans=$10; tot=$11;
    } else if ($1=="Native") {
      det=$2; lat=$3; solv=$4; conn=$5; trans=$6; tot=$7;
    } else {
      next;
    }
    printf("| %-10s | %-8s | %-7s | %-6s | %-9s | %-20s | %-5s |\n", $1, det, lat, solv, conn, trans, tot);
  }' /workspace/repro.txt
}
echo '</artisan_submit>'
