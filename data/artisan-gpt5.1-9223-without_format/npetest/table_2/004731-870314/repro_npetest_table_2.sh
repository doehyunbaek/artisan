#!/usr/bin/bash
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

# Section 3: Reproduction commands
uvx --from csvkit in2csv NPETestArtifact/rq1_result.xlsx > NPETestArtifact/rq1_result.csv

python3 - <<'PY'
import csv
from collections import defaultdict

csv_path = "NPETestArtifact/rq1_result.csv"

# rows[benchmark][project_id] = [rows...]
rows = defaultdict(lambda: defaultdict(list))

with open(csv_path, newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        bench = row.get('a')
        proj = row.get('b')
        if not bench or not proj:
            continue
        rows[bench][proj].append(row)

def to_int_str(v):
    if v is None or v == "":
        return ""
    return str(int(round(float(v))))

def get_vals(bench, proj, idx):
    lst = rows[bench][proj]
    if idx >= len(lst):
        raise RuntimeError(f"Missing row for {bench} / {proj} index {idx}")
    r = lst[idx]
    return to_int_str(r.get('evosuite')), to_int_str(r.get('npetest'))

# Mapping from table labels to (benchmark, underlying project-id, index)
npex_conf = [
    ("Activiti-c45",      "Activiti-c45d6c3c",              0),
    ("Aries_JPA",         "Aries_JPA-97cb979d",             0),
    ("Avro",              "Avro-a3e05bee",                  0),
    ("Commons_Conf",      "Commons_Configuration-a76a3a65", 0),
    ("Commons_DBCP",      "Commons_DBCP-2ee3c53e",          0),
    ("Commons_Pool",      "Commons_Pool-11521c1f",          0),
    ("CXF-2094",          "CXF-209407e0",                   0),
    ("Directory",         "Directory_LDAP_API-1aea113c",    0),
    ("Easy_Rules",        "Easy_Rules-d5385af5",            0),
    ("Fastjson-650a",     "Fastjson-650a300f",              0),
    ("Feign-9c5a",        "Feign-9c5a52d6",                 0),
    ("FOP-10e0d1c2",      "FOP-10e0d1c2",                   0),
    ("Hessian_Lite",      "Hessian_Lite-c5c017dc",          0),
    ("Hivemall-04fa",     "Hivemall-04fa7545",              0),
    ("Http-f633(1)",      "HttpComponents_Client-f6333a50", 0),
    ("Http-f633(2)",      "HttpComponents_Client-f6333a50", 1),
    ("Http-f633(3)",      "HttpComponents_Client-f6333a50", 2),
    ("Http-f633(4)",      "HttpComponents_Client-f6333a50", 3),
    ("IoTDB-9bce",        "IoTDB-9bced7b6",                 0),
    ("Jest-f34f",         "Jest-f34fa45e",                  0),
    ("jsoup-8b83",        "jsoup-8b837a43",                 0),
    ("jsoup-b841",        "jsoup-b8411990",                 0),
    ("JSqlParser",        "JSqlParser-66e44c95",            0),
    ("Karaf-b92d",        "Karaf-b92dd7e4",                 0),
    ("Log4j_2-5b7b",      "Log4j_2-5b7b75d5",               0),
    ("Log4j_2-6a23",      "Log4j_2-6a233016",               0),
    ("Log4j_2-7441",      "Log4j_2-7441d3c3",               0),
    ("Ninja-16aa",        "Ninja-16aa9c14",                 0),
    ("Nutz-87a4",         "Nutz-87a4b212",                  0),
    ("OpenNLP-6079",      "OpenNLP-60792b8f",               0),
    ("OpenPDF-a89d",      "OpenPDF-a89dfdf5",               0),
    ("PDFBox-5558",       "PDFBox-55586aad",                0),
    ("Qpid-0299 (1)",     "Qpid_Proton__j-02998b38",        0),
    ("Qpid-0299 (2)",     "Qpid_Proton__j-02998b38",        1),
    ("Sharding-82b1",     "ShardingSphere-82b1b9d5",        0),
    ("Sharding-9833",     "ShardingSphere-9833fb9a",        0),
    ("Sharding-c08f",     "ShardingSphere-c08f4f18",        0),
    ("ZooKeeper",         "ZooKeeper-ef3649f5",             0),
]

bug_conf = [
    ("ACS_Commons",       "ACS_AEM_Commons-374231969",             0),
    ("Artemis_odb",       "Artemis__odb-71816517",                 0),
    ("BungeeCord-1303",   "BungeeCord-130330788",                  0),
    ("Byte-1405",         "Byte_Buddy-140517155",                  0),
    ("Byte_Buddy-9579",   "Byte_Buddy-95795967",                   0),
    ("Dubbo-4166",        "Dubbo-416671625",                       0),
    ("OkHttp-9361(1)",    "OkHttp-93618854",                       0),
    ("OkHttp-9361(2)",    "OkHttp-93618854",                       1),
    ("Petergeneric",      "Petergeneric__Stdlib-290369132",        0),
    ("REST-1546(1)",      "REST_Countries-154683750",              0),
    ("REST-1546(2)",      "REST_Countries-154683750",              1),
    ("REST-1546(3)",      "REST_Countries-154683750",              2),
    ("REST-1546(4)",      "REST_Countries-154683750",              3),
    ("REST-1546(5)",      "REST_Countries-154683750",              4),
    ("REST-2078",         "REST_Countries-207869551",              0),
    ("Universal-1724(1)", "Universal_G__Code_Sender-172454077",    0),
    ("Universal-1724(2)", "Universal_G__Code_Sender-172454077",    1),
    ("Universal-6766",    "Universal_G__Code_Sender-676666184",    0),
    ("Yamcs-1863",        "Yamcs-186324159",                       0),
]

def_conf = [
    ("Cli-30(0)", "Cli-30",  0),
    ("Cli-30(1)", "Cli-30",  1),
    ("Csv-11",    "Csv-11",  0),
    ("Csv-9",     "Csv-9",   0),
    ("Math-70",   "Math-70", 0),
    ("Math-79",   "Math-79", 0),
]

gen_conf = [
    ("Activiti-31c8",   "Activiti-31c8ea16",      0),
    ("Checkstyle-be8",  "Checkstyle-be8a60a4",    0),
    ("DataflowJavaSDK", "DataflowJavaSDK-f42c13c8", 0),
    ("JavaPoet-aee5",   "JavaPoet-aee5f128",      0),
    ("Javaslang-0dab",  "Javaslang-0dab3ed3",     0),
    ("Jongo-9743",      "Jongo-97431a03",         0),
]

bears_conf = [
    ("Bears-189", "Bears-189", 0),
    ("Bears-222", "Bears-222", 0),
    ("Bears-56",  "Bears-56",  0),
    ("Bears-70",  "Bears-70",  0),
    ("Bears-88",  "Bears-88",  0),
]

def build_section(benchmark, conf):
    lines = []
    for label, proj, idx in conf:
        ev, npv = get_vals(benchmark, proj, idx)
        lines.append(f"| {label} | {ev} | {npv} |")
    return "\n".join(lines)

parts = []
parts.append("**Table 2: The reproduction rate results for 25 trials on benchmark projects gathered from the prior studies [3, 21–24]. The projects where all three tools failed to detect NPEs are excluded from this table. Project: The name of the buggy project with its abbreviated NPE-labeling ID (if necessary). The number in a parenthesis represents each unique NPE in the same project.**\n")

# NPEX
parts.append("\n### NPEX\n")
parts.append("\n| Project | EvoSuite | NPETest |")
parts.append("\n| :--- | ---: | ---: |")
parts.append("\n" + build_section("NPEX", npex_conf))

# BugSwarm
parts.append("\n\n### BugSwarm\n")
parts.append("\n| Project | EvoSuite | NPETest |")
parts.append("\n| :--- | ---: | ---: |")
parts.append("\n" + build_section("BugSwarm", bug_conf))

# Defects4J
parts.append("\n\n### Defects4J\n")
parts.append("\n| Project | EvoSuite | NPETest |")
parts.append("\n| :--- | ---: | ---: |")
parts.append("\n" + build_section("Defects4J", def_conf))

# Genesis
parts.append("\n\n### Genesis\n")
parts.append("\n| Project | EvoSuite | NPETest |")
parts.append("\n| :--- | ---: | ---: |")
parts.append("\n" + build_section("Genesis", gen_conf))

# Bears
parts.append("\n\n### Bears\n")
parts.append("\n| Project | EvoSuite | NPETest |")
parts.append("\n| :--- | ---: | ---: |")
parts.append("\n" + build_section("Bears", bears_conf))

output = "".join(parts) + "\n"

with open("/workspace/repro.txt", "w") as out:
    out.write(output)
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
