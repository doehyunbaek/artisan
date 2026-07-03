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
artisan get https://zenodo.org/records/10505175

# Section 3: Reproduction commands (as used previously)
if [ -f RIPR-framework.zip ]; then
  ZIPPATH="RIPR-framework.zip"
elif [ -f RIPR-framework/RIPR-framework-Zenodo/RIPR-framework.zip ]; then
  ZIPPATH="RIPR-framework/RIPR-framework-Zenodo/RIPR-framework.zip"
else
  ZIPPATH=""
fi

if [ -n "$ZIPPATH" ]; then
  mkdir -p /workspace/RIPR-extracted
  unzip -o "$ZIPPATH" -d /workspace/RIPR-extracted || true
fi

find /workspace/RIPR-extracted -type f -name '*.zip' -print0 | while IFS= read -r -d '' z; do
  d="/workspace/extracted_from_$(basename "$z" .zip)"
  mkdir -p "$d"
  unzip -o "$z" -d "$d" || true
done

find /workspace/RIPR-extracted /workspace -maxdepth 3 -type f -name '*.csv' -print0 2>/dev/null | xargs -0 -I{} cp -f {} /workspace/ 2>/dev/null || true

MISSING_CSVS=0
for base in commons-cli commons-text joda-money jline-reader commons-validator cdk-data "spotify-web-api" commons-codec jfreechart dyn4j; do
  if [ ! -f "/workspace/${base}.csv" ]; then
    MISSING_CSVS=1
    break
  fi
done

if [ "$MISSING_CSVS" -eq 1 ]; then
  if [ -f getsankeyamd.tar ]; then
    docker load -i getsankeyamd.tar || true
    docker run -d --init --entrypoint bash --name sankeyamd qinfendeheichi/getsankeyamd:v1 -c 'sleep infinity' || true
    docker cp sankeyamd:/RQ2Script.py /workspace/ 2>/dev/null || true
    for base in commons-cli commons-text joda-money jline-reader commons-validator cdk-data "spotify-web-api" commons-codec jfreechart dyn4j; do
      docker cp sankeyamd:/"${base}.csv" /workspace/ 2>/dev/null || true
    done
    docker rm -f sankeyamd >/dev/null 2>&1 || true
  fi
fi

if [ ! -f /workspace/RQ2Script.py ]; then
  find /workspace/RIPR-extracted -type f -name 'RQ2Script.py' -exec cp -f {} /workspace/ \; 2>/dev/null || true
fi

if command -v python3 >/dev/null 2>&1 && [ -f /workspace/RQ2Script.py ]; then
  python3 /workspace/RQ2Script.py > /workspace/repro.txt 2>&1 || true
else
  echo "ERROR: python3 or RQ2Script.py missing" > /workspace/repro.txt
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
