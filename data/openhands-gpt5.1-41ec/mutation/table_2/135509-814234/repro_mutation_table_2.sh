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
curl -L -o RIPR-framework.zip 'https://zenodo.org/records/10505175/files/RIPR-framework.zip?download=1'
unzip -q RIPR-framework.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/RIPR-framework-Zenodo
docker pull qinfendeheichi/getsankeyamd:v1
docker run --rm --name sankeyamd qinfendeheichi/getsankeyamd:v1 > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
awk 'BEGIN {
  print "**Table 2: Method Exit Anomalies**";
  print "";
  print "| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |";
  print "| ----------------- | --------------: | --------------: | -----------------: |";
}
{
  printf("| %-16s | %13s %s %s | %13s %s %s | %17s %s %s |\n",
         $1, $3, $4, $5, $6, $7, $8, $9, $10, $11);
}' /workspace/repro.txt
echo '</artisan_submit>'
