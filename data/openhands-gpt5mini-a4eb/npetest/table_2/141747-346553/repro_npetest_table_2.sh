#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: The reproduction rate results for 25 trials on benchmark projects gathered from the prior studies [3, 21–24]. The projects where all three tools failed to detect NPEs are excluded from this table. Project: The name of the buggy project with its abbreviated NPE-labeling ID (if necessary). The number in a parenthesis represents each unique NPE in the same project.**

### NPEX

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| Activiti-c45 | 0 | 24 |
| Aries_JPA | 100 | 80 |
| Avro | 100 | 100 |
| Commons_Conf | 100 | 100 |
| Commons_DBCP | 16 | 100 |
| Commons_Pool | 92 | 100 |
| CXF-2094 | 56 | 84 |
| Directory | 60 | 80 |
| Easy_Rules | 52 | 100 |
| Fastjson-650a | 8 | 64 |
| Feign-9c5a | 0 | 28 |
| FOP-10e0d1c2 | 40 | 100 |
| Hessian_Lite | 100 | 96 |
| Hivemall-04fa | 68 | 100 |
| Http-f633(1) | 0 | 88 |
| Http-f633(2) | 0 | 72 |
| Http-f633(3) | 72 | 88 |
| Http-f633(4) | 72 | 88 |
| IoTDB-9bce | 32 | 40 |
| Jest-f34f | 8 | 0 |
| jsoup-8b83 | 40 | 100 |
| jsoup-b841 | 100 | 100 |
| JSqlParser | 68 | 96 |
| Karaf-b92d | 0 | 40 |
| Log4j_2-5b7b | 0 | 16 |
| Log4j_2-6a23 | 92 | 100 |
| Log4j_2-7441 | 100 | 100 |
| Ninja-16aa | 64 | 96 |
| Nutz-87a4 | 76 | 100 |
| OpenNLP-6079 | 100 | 100 |
| OpenPDF-a89d | 100 | 100 |
| PDFBox-5558 | 100 | 100 |
| Qpid-0299 (1) | 0 | 36 |
| Qpid-0299 (2) | 0 | 72 |
| Sharding-82b1 | 0 | 4 |
| Sharding-9833 | 40 | 100 |
| Sharding-c08f | 8 | 8 |
| ZooKeeper | 16 | 36 |

### BugSwarm

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| ACS_Commons | 0 | 64 |
| Artemis_odb | 96 | 76 |
| BungeeCord-1303 | 100 | 100 |
| Byte-1405 | 92 | 100 |
| Byte_Buddy-9579 | 96 | 100 |
| Dubbo-4166 | 92 | 100 |
| OkHttp-9361(1) | 88 | 100 |
| OkHttp-9361(2) | 96 | 92 |
| Petergeneric | 68 | 92 |
| REST-1546(1) | 28 | 92 |
| REST-1546(2) | 16 | 92 |
| REST-1546(3) | 100 | 100 |
| REST-1546(4) | 100 | 100 |
| REST-1546(5) | 100 | 100 |
| REST-2078 | 40 | 100 |
| Universal-1724(1) | 0 | 56 |
| Universal-1724(2) | 0 | 64 |
| Universal-6766 | 64 | 72 |
| Yamcs-1863 | 76 | 90 |

### Defects4J

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| Cli-30(0) | 28 | 100 |
| Cli-30(1) | 56 | 100 |
| Csv-11 | 80 | 72 |
| Csv-9 | 72 | 92 |
| Math-70 | 100 | 100 |
| Math-79 | 76 | 100 |

### Genesis

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| Activiti-31c8 | 24 | 92 |
| Checkstyle-be8 | 60 | 80 |
| DataflowJavaSDK | 0 | 8 |
| JavaPoet-aee5 | 100 | 100 |
| Javaslang-0dab | 100 | 100 |
| Jongo-9743 | 0 | 4 |

### Bears

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| Bears-189 | 100 | 100 |
| Bears-222 | 20 | 40 |
| Bears-56 | 96 | 100 |
| Bears-70 | 0 | 24 |
| Bears-88 | 100 | 96 |

EOTABLE
# Section 2: Artifact download
if [ ! -d /workspace/NPETestArtifact ]; then
  git clone --depth 1 https://github.com/kupl/NPETestArtifact.git /workspace/NPETestArtifact
else
  echo "Artifact already present at /workspace/NPETestArtifact"
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# We generate Table 2 by converting rq1_result.xlsx to CSV and extracting EvoSuite and NPETest columns.
uvx --from csvkit in2csv /workspace/NPETestArtifact/rq1_result.xlsx > /workspace/rq1_result_sheet1.csv
python3 - <<'PY'
import csv
from pathlib import Path
csvf = Path('/workspace/rq1_result_sheet1.csv')
out = Path('/workspace/repro.txt')
sections = ['NPEX','BugSwarm','Defects4J','Genesis','Bears']
with csvf.open() as f, out.open('w') as o:
    reader = csv.reader(f)
    # skip header
    next(reader)
    data = {s: [] for s in sections}
    for row in reader:
        if not row or not row[0].strip():
            continue
        sec = row[0].strip()
        if sec not in sections:
            # some rows might be continuations or malformed; skip
            continue
        # parse project, evosuite (second-to-last), npetest (last)
        proj = row[1] if len(row) > 1 else ''
        ev = row[-2] if len(row) >= 2 else ''
        np = row[-1] if len(row) >= 1 else ''
        # normalize numeric strings
        def norm(x):
            try:
                xf = float(x)
                return str(int(round(xf)))
            except:
                return x
        evs = norm(ev)
        nps = norm(np)
        data[sec].append((proj, evs, nps))
    # Write markdown-like tables for each section
    for sec in sections:
        o.write(f"### {sec}\n\n")
        o.write("| Project | EvoSuite | NPETest |\n")
        o.write("| :--- | ---: | ---: |\n")
        for proj, evs, nps in data[sec]:
            proj_clean = proj
            proj_clean = proj_clean.replace('ACS_AEM_Commons-374231969','ACS_Commons')
            proj_clean = proj_clean.replace('__','_')
            proj_clean = proj_clean.replace('REST_Countries-154683750','REST-1546')
            proj_clean = proj_clean.replace('Universal_G__Code_Sender-172454077','Universal-1724')
            proj_clean = proj_clean.split(',')[0]
            o.write(f"| {proj_clean} | {evs} | {nps} |\n")
        o.write('\n')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
