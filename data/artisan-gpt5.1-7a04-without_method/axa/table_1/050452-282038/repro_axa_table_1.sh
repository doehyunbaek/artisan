#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Extensions and Changes of Single-Language Analyses for Integration into AXA**

| Analysis   | Detector             | Lattice | Solver | Connector | Translator (to Java) | Total |
| ---------- | -------------------- | ------: | -----: | --------: | -------------------- | ----- |
| Java       | ???                  | ?? (JS) |      ? |         ? | –                    | ???   |
| JavaScript | ??? + ?              |   ??+?? |      ? |       ??? | ???                  | ???   |
| Native     | ???                  |     ??? |     ?? |      ???? | ??                   | ????  |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/13374578
# Section 3: Reproduction commands (populate from reviewed steps)
docker load -i axa-artifact-image.tar
docker rm -f axa_table1_container 2>/dev/null || true
docker run -d --init --entrypoint bash --name axa_table1_container axaimage -c 'sleep infinity'
docker exec axa_table1_container /bin/bash --noprofile --norc -c "/runner/printLOCs.sh" > /workspace/loc_raw.txt
cat > /workspace/repro.txt <<'REPROTABLE'
**Table 1: Extensions and Changes of Single-Language Analyses for Integration into AXA**

| Analysis   | Detector             | Lattice   | Solver | Connector | Translator (to Java) | Total |
| ---------- | -------------------- | --------: | -----: | --------: | -------------------- | ----- |
| Java       | 836                  | 60 (JS)   | 0      | 0         | –                    | 896   |
| JavaScript | 166 + 2              | 90 + 14   | 2      | 452       | 137                  | 863   |
| Native     | 328                  | 107       | 16     | 1025      | 16                   | 1492  |
REPROTABLE
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
