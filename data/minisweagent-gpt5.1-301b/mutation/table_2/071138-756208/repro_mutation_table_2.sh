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
# Download the Zenodo artifact ZIP that contains the RIPR framework and related files.
mkdir -p /workspace
cd /workspace
curl -L 'https://zenodo.org/api/records/10505175/files/RIPR-framework.zip/content' -o RIPR-framework.zip
mkdir -p RIPR-framework
unzip -q RIPR-framework.zip -d RIPR-framework

# Section 3: Reproduction commands (populate from reviewed steps)
# Use the published Docker image that bundles the CSVs and RQ2Script.py, which prints
# the RQ2 results corresponding to Table 2 in the paper.

# Ensure the getsankey AMD image is available (preferred over docker load).
docker pull qinfendeheichi/getsankeyamd:v1

# (Re)create the sankeyamd container using the required detached pattern.
docker rm -f sankeyamd >/dev/null 2>&1 || true
docker run -d --init --name sankeyamd --entrypoint bash qinfendeheichi/getsankeyamd:v1 -c 'sleep infinity'

# Run RQ2Script.py inside the container and capture its terminal output.
docker exec sankeyamd /bin/bash --noprofile --norc -c "python3 RQ2Script.py" > /workspace/repro_raw.txt

# Convert the raw RQ2 output into a Markdown table matching the structure of Table 2.
awk 'BEGIN {
  print "**Table 2: Method Exit Anomalies**\n";
  print "| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |";
  print "| ----------------- | --------------: | --------------: | -----------------: |";
}
{
  prog=$1;
  failed=$3" "$4;
  anomaly=$5" "$6;
  oracle=$7" "$8;
  # Clean up spacing around commas and inside parentheses to match expected formatting.
  gsub(/ ,/, ",", failed);
  gsub(/ ,/, ",", anomaly);
  gsub(/ ,/, ",", oracle);
  gsub(/\( /,"(", failed);
  gsub(/\( /,"(", anomaly);
  gsub(/\( /,"(", oracle);
  printf "| %-16s | %14s | %14s | %17s |\n", prog, failed, anomaly, oracle;
}' /workspace/repro_raw.txt > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
