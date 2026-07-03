#!/usr/bin/bash
set -euo pipefail
cd /workspace

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: The reproduction rate results for 25 trials on benchmark projects gathered from the prior studies [3, 21–24]. The projects where all three tools failed to detect NPEs are excluded from this table. Project: The name of the buggy project with its abbreviated NPE-labeling ID (if necessary). The number in a parenthesis represents each unique NPE in the same project.**

### NPEX

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| Activiti-c45 | ? | ?? |
| Aries_JPA | ??? | ?? |
| Avro | ??? | ??? |
| Commons_Conf | ??? | ??? |
| Commons_DBCP | ?? | ??? |
| Commons_Pool | ?? | ??? |
| CXF-2094 | ?? | ?? |
| Directory | ?? | ?? |
| Easy_Rules | ?? | ??? |
| Fastjson-650a | ? | ?? |
| Feign-9c5a | ? | ?? |
| FOP-10e0d1c2 | ?? | ??? |
| Hessian_Lite | ??? | ?? |
| Hivemall-04fa | ?? | ??? |
| Http-f633(1) | ? | ?? |
| Http-f633(2) | ? | ?? |
| Http-f633(3) | ?? | ?? |
| Http-f633(4) | ?? | ?? |
| IoTDB-9bce | ?? | ?? |
| Jest-f34f | ? | ? |
| jsoup-8b83 | ?? | ??? |
| jsoup-b841 | ??? | ??? |
| JSqlParser | ?? | ?? |
| Karaf-b92d | ? | ?? |
| Log4j_2-5b7b | ? | ?? |
| Log4j_2-6a23 | ?? | ??? |
| Log4j_2-7441 | ??? | ??? |
| Ninja-16aa | ?? | ?? |
| Nutz-87a4 | ?? | ??? |
| OpenNLP-6079 | ??? | ??? |
| OpenPDF-a89d | ??? | ??? |
| PDFBox-5558 | ??? | ??? |
| Qpid-0299 (1) | ? | ?? |
| Qpid-0299 (2) | ? | ?? |
| Sharding-82b1 | ? | ? |
| Sharding-9833 | ?? | ??? |
| Sharding-c08f | ? | ? |
| ZooKeeper | ?? | ?? |

### BugSwarm

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| ACS_Commons | ? | ?? |
| Artemis_odb | ?? | ?? |
| BungeeCord-1303 | ??? | ??? |
| Byte-1405 | ?? | ??? |
| Byte_Buddy-9579 | ?? | ??? |
| Dubbo-4166 | ?? | ??? |
| OkHttp-9361(1) | ?? | ??? |
| OkHttp-9361(2) | ?? | ?? |
| Petergeneric | ?? | ?? |
| REST-1546(1) | ?? | ?? |
| REST-1546(2) | ?? | ?? |
| REST-1546(3) | ??? | ??? |
| REST-1546(4) | ??? | ??? |
| REST-1546(5) | ??? | ??? |
| REST-2078 | ?? | ??? |
| Universal-1724(1) | ? | ?? |
| Universal-1724(2) | ? | ?? |
| Universal-6766 | ?? | ?? |
| Yamcs-1863 | ?? | ?? |

### Defects4J

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| Cli-30(0) | ?? | ??? |
| Cli-30(1) | ?? | ??? |
| Csv-11 | ?? | ?? |
| Csv-9 | ?? | ?? |
| Math-70 | ??? | ??? |
| Math-79 | ?? | ??? |

### Genesis

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| Activiti-31c8 | ?? | ?? |
| Checkstyle-be8 | ?? | ?? |
| DataflowJavaSDK | ? | ? |
| JavaPoet-aee5 | ??? | ??? |
| Javaslang-0dab | ??? | ??? |
| Jongo-9743 | ? | ? |

### Bears

| Project | EvoSuite | NPETest |
| :--- | ---: | ---: |
| Bears-189 | ??? | ??? |
| Bears-222 | ?? | ?? |
| Bears-56 | ?? | ??? |
| Bears-70 | ? | ?? |
| Bears-88 | ??? | ?? |

EOTABLE

# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact

# Section 3: Reproduction commands (populate from reviewed steps)
# Convert the RQ1 Excel results (per-bug reproduction rates) to CSV
uvx --from csvkit in2csv NPETestArtifact/rq1_result.xlsx > /workspace/rq1_result.csv

# Build Table 2 markdown from rq1_result.csv
python3 - <<'PY' > /workspace/repro.txt
import csv
from collections import defaultdict

# Load rows grouped by benchmark suite (column 'a')
with open("/workspace/rq1_result.csv", newline="") as f:
    reader = csv.DictReader(f)
    rows = [r for r in reader if r["a"]]

by_ds = defaultdict(list)
for r in rows:
    by_ds[r["a"]].append(r)

def fmt(v: str) -> str:
    return str(int(round(float(v)))) if v else ""

def single(ds: str, b_prefix: str):
    ms = [r for r in by_ds[ds] if r["b"].startswith(b_prefix)]
    assert len(ms) == 1, (ds, b_prefix, len(ms))
    return ms[0]

def multi(ds: str, b_prefix: str, count: int):
    ms = [r for r in by_ds[ds] if r["b"].startswith(b_prefix)]
    assert len(ms) == count, (ds, b_prefix, len(ms))
    return ms

lines = []

lines.append("**Table 2: The reproduction rate results for 25 trials on benchmark projects gathered from the prior studies [3, 21–24]. The projects where all three tools failed to detect NPEs are excluded from this table. Project: The name of the buggy project with its abbreviated NPE-labeling ID (if necessary). The number in a parenthesis represents each unique NPE in the same project.**\n")

# === NPEX ===
lines.append("### NPEX\n")
lines.append("| Project | EvoSuite | NPETest |")
lines.append("| :--- | ---: | ---: |")

r = single("NPEX", "Activiti-c45d6c3c")
lines.append(f"| Activiti-c45 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Aries_JPA-97cb979d")
lines.append(f"| Aries_JPA | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Avro-a3e05bee")
lines.append(f"| Avro | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Commons_Configuration-a76a3a65")
lines.append(f"| Commons_Conf | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Commons_DBCP-2ee3c53e")
lines.append(f"| Commons_DBCP | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Commons_Pool-11521c1f")
lines.append(f"| Commons_Pool | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "CXF-209407e0")
lines.append(f"| CXF-2094 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Directory_LDAP_API-1aea113c")
lines.append(f"| Directory | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Easy_Rules-d5385af5")
lines.append(f"| Easy_Rules | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Fastjson-650a300f")
lines.append(f"| Fastjson-650a | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Feign-9c5a52d6")
lines.append(f"| Feign-9c5a | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "FOP-10e0d1c2")
lines.append(f"| FOP-10e0d1c2 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Hessian_Lite-c5c017dc")
lines.append(f"| Hessian_Lite | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Hivemall-04fa7545")
lines.append(f"| Hivemall-04fa | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

http_rows = multi("NPEX", "HttpComponents_Client-f6333a50", 4)
for i, rr in enumerate(http_rows, start=1):
    lines.append(f"| Http-f633({i}) | {fmt(rr['evosuite'])} | {fmt(rr['npetest'])} |")

r = single("NPEX", "IoTDB-9bced7b6")
lines.append(f"| IoTDB-9bce | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Jest-f34fa45e")
lines.append(f"| Jest-f34f | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "jsoup-8b837a43")
lines.append(f"| jsoup-8b83 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "jsoup-b8411990")
lines.append(f"| jsoup-b841 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "JSqlParser-66e44c95")
lines.append(f"| JSqlParser | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Karaf-b92dd7e4")
lines.append(f"| Karaf-b92d | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Log4j_2-5b7b75d5")
lines.append(f"| Log4j_2-5b7b | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Log4j_2-6a233016")
lines.append(f"| Log4j_2-6a23 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Log4j_2-7441d3c3")
lines.append(f"| Log4j_2-7441 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Ninja-16aa9c14")
lines.append(f"| Ninja-16aa | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "Nutz-87a4b212")
lines.append(f"| Nutz-87a4 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "OpenNLP-60792b8f")
lines.append(f"| OpenNLP-6079 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "OpenPDF-a89dfdf5")
lines.append(f"| OpenPDF-a89d | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "PDFBox-55586aad")
lines.append(f"| PDFBox-5558 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

qpid_rows = multi("NPEX", "Qpid_Proton__j-02998b38", 2)
for i, rr in enumerate(qpid_rows, start=1):
    lines.append(f"| Qpid-0299 ({i}) | {fmt(rr['evosuite'])} | {fmt(rr['npetest'])} |")

r = single("NPEX", "ShardingSphere-82b1b9d5")
lines.append(f"| Sharding-82b1 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "ShardingSphere-9833fb9a")
lines.append(f"| Sharding-9833 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "ShardingSphere-c08f4f18")
lines.append(f"| Sharding-c08f | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("NPEX", "ZooKeeper-ef3649f5")
lines.append(f"| ZooKeeper | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

# === BugSwarm ===
lines.append("\n### BugSwarm\n")
lines.append("| Project | EvoSuite | NPETest |")
lines.append("| :--- | ---: | ---: |")

r = single("BugSwarm", "ACS_AEM_Commons-374231969")
lines.append(f"| ACS_Commons | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("BugSwarm", "Artemis__odb-71816517")
lines.append(f"| Artemis_odb | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("BugSwarm", "BungeeCord-130330788")
lines.append(f"| BungeeCord-1303 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("BugSwarm", "Byte_Buddy-140517155")
lines.append(f"| Byte-1405 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("BugSwarm", "Byte_Buddy-95795967")
lines.append(f"| Byte_Buddy-9579 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("BugSwarm", "Dubbo-416671625")
lines.append(f"| Dubbo-4166 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

okhttp_rows = multi("BugSwarm", "OkHttp-93618854", 2)
for i, rr in enumerate(okhttp_rows, start=1):
    lines.append(f"| OkHttp-9361({i}) | {fmt(rr['evosuite'])} | {fmt(rr['npetest'])} |")

r = single("BugSwarm", "Petergeneric__Stdlib-290369132")
lines.append(f"| Petergeneric | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

rest1546_rows = multi("BugSwarm", "REST_Countries-154683750", 5)
for i, rr in enumerate(rest1546_rows, start=1):
    lines.append(f"| REST-1546({i}) | {fmt(rr['evosuite'])} | {fmt(rr['npetest'])} |")

r = single("BugSwarm", "REST_Countries-207869551")
lines.append(f"| REST-2078 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

u1724_rows = multi("BugSwarm", "Universal_G__Code_Sender-172454077", 2)
for i, rr in enumerate(u1724_rows, start=1):
    lines.append(f"| Universal-1724({i}) | {fmt(rr['evosuite'])} | {fmt(rr['npetest'])} |")

r = single("BugSwarm", "Universal_G__Code_Sender-676666184")
lines.append(f"| Universal-6766 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("BugSwarm", "Yamcs-186324159")
lines.append(f"| Yamcs-1863 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

# === Defects4J ===
lines.append("\n### Defects4J\n")
lines.append("| Project | EvoSuite | NPETest |")
lines.append("| :--- | ---: | ---: |")

cli_rows = multi("Defects4J", "Cli-30", 2)
for i, rr in enumerate(cli_rows):
    lines.append(f"| Cli-30({i}) | {fmt(rr['evosuite'])} | {fmt(rr['npetest'])} |")

r = single("Defects4J", "Csv-11")
lines.append(f"| Csv-11 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Defects4J", "Csv-9")
lines.append(f"| Csv-9 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Defects4J", "Math-70")
lines.append(f"| Math-70 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Defects4J", "Math-79")
lines.append(f"| Math-79 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

# === Genesis ===
lines.append("\n### Genesis\n")
lines.append("| Project | EvoSuite | NPETest |")
lines.append("| :--- | ---: | ---: |")

r = single("Genesis", "Activiti-31c8ea16")
lines.append(f"| Activiti-31c8 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Genesis", "Checkstyle-be8a60a4")
lines.append(f"| Checkstyle-be8 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Genesis", "DataflowJavaSDK-f42c13c8")
lines.append(f"| DataflowJavaSDK | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Genesis", "JavaPoet-aee5f128")
lines.append(f"| JavaPoet-aee5 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Genesis", "Javaslang-0dab3ed3")
lines.append(f"| Javaslang-0dab | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Genesis", "Jongo-97431a03")
lines.append(f"| Jongo-9743 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

# === Bears ===
lines.append("\n### Bears\n")
lines.append("| Project | EvoSuite | NPETest |")
lines.append("| :--- | ---: | ---: |")

r = single("Bears", "Bears-189")
lines.append(f"| Bears-189 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Bears", "Bears-222")
lines.append(f"| Bears-222 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Bears", "Bears-56")
lines.append(f"| Bears-56 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Bears", "Bears-70")
lines.append(f"| Bears-70 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

r = single("Bears", "Bears-88")
lines.append(f"| Bears-88 | {fmt(r['evosuite'])} | {fmt(r['npetest'])} |")

print("\n".join(lines))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
