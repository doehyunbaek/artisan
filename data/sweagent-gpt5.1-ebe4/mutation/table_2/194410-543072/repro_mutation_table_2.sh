#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Method Exit Anomalies**

| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |
| ----------------- | --------------: | --------------: | -----------------: |
| commons-cli       | 13,965 (60.32%) |  4,216 (30.19%) |     1,728 (40.99%) |
| commons-text      | 17,832 (67.95%) |  4,985 (27.96%) |     1,882 (37.75%) |
| joda-money        | 36,495 (50.68%) | 10,486 (28.73%) |     5,931 (56.56%) |
| jline-reader      | 21,448 (19.36%) |  9,842 (45.89%) |     1,529 (15.54%) |
| commons-validator | 13,340 (51.42%) |  4,947 (37.08%) |     1,159 (23.43%) |
| cdk-data          | 80,398 (45.35%) | 38,550 (47.95%) |     5,717 (14.83%) |
| spotify-web-api   |  2,688 (34.19%) |    677 (25.19%) |          0 (0.00%) |
| commons-codec     | 18,097 (64.04%) |  5,250 (29.01%) |     1,195 (22.76%) |
| jfreechart        | 96,626 (37.92%) | 31,676 (32.78%) |    12,749 (40.25%) |
| dyn4j             | 89,603 (44.43%) | 47,065 (52.53%) |    22,324 (47.43%) |

EOTABLE
# Section 2: Artifact download
cd /workspace
if [ ! -d RIPR-framework-Zenodo ]; then
  curl -sSLO https://zenodo.org/records/10505175/files/RIPR-framework.zip
  unzip -q RIPR-framework.zip
fi
cd /workspace/RIPR-framework-Zenodo
if [ ! -f getsankeyamd.tar ]; then
  curl -sSLO https://zenodo.org/records/10505175/files/getsankeyamd.tar
fi
# Section 3: Reproduction commands (populate from reviewed steps)
# Load Docker image (idempotent)
docker load -i getsankeyamd.tar >/dev/null
# Start container if not already running
if ! docker ps --format '{{.Names}}' | grep -q '^sankeyamd$'; then
  if docker ps -a --format '{{.Names}}' | grep -q '^sankeyamd$'; then
    docker start sankeyamd >/dev/null
  else
    docker run -d --init --name sankeyamd --entrypoint bash qinfendeheichi/getsankeyamd:v1 -c 'sleep infinity' >/dev/null
  fi
fi
# Run RQ2 script to generate Table 2 and save to repro.txt
docker exec sankeyamd /bin/bash --noprofile --norc -c "python RQ2Script.py" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
