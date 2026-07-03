#!/usr/bin/bash
# Section 1: Expected table (structure from the paper; values obfuscated)
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

# Section 3: Reproduction commands (generate rq1_result.csv and build numeric Table 2)
cd NPETestArtifact
uvx --from csvkit in2csv rq1_result.xlsx > rq1_result.csv

python - <<'PYCODE'
import csv
import pathlib

csv_path = pathlib.Path("rq1_result.csv")
if not csv_path.exists():
    raise SystemExit(f"Missing {csv_path}")

entries = []
with csv_path.open(newline="") as f:
    r = csv.reader(f)
    header = next(r, None)
    for row in r:
        if not row:
            continue
        bench = row[0].strip()
        proj = row[1].strip()
        clazz = row[2].strip()
        if bench not in {"NPEX","BugSwarm","Defects4J","Genesis","Bears"}:
            continue
        try:
            ev = float(row[6]) if row[6] else 0.0
            np = float(row[7]) if row[7] else 0.0
        except (IndexError, ValueError):
            continue
        entries.append((bench, proj, clazz, ev, np))

def short_label(bench, proj):
    if bench == "NPEX":
        mapping = {
            "Activiti-c45d6c3c": "Activiti-c45",
            "Aries_JPA-97cb979d": "Aries_JPA",
            "Avro-a3e05bee": "Avro",
            "Commons_Configuration-a76a3a65": "Commons_Conf",
            "Commons_DBCP-2ee3c53e": "Commons_DBCP",
            "Commons_Pool-11521c1f": "Commons_Pool",
            "CXF-209407e0": "CXF-2094",
            "Directory_LDAP_API-1aea113c": "Directory",
            "Easy_Rules-d5385af5": "Easy_Rules",
            "Fastjson-650a300f": "Fastjson-650a",
            "Feign-9c5a52d6": "Feign-9c5a",
            "FOP-10e0d1c2": "FOP-10e0d1c2",
            "Hessian_Lite-c5c017dc": "Hessian_Lite",
            "Hivemall-04fa7545": "Hivemall-04fa",
            "HttpComponents_Client-f6333a50": None,
            "IoTDB-9bced7b6": "IoTDB-9bce",
            "Jest-f34fa45e": "Jest-f34f",
            "jsoup-8b837a43": "jsoup-8b83",
            "jsoup-b8411990": "jsoup-b841",
            "JSqlParser-66e44c95": "JSqlParser",
            "Karaf-b92dd7e4": "Karaf-b92d",
            "Log4j_2-5b7b75d5": "Log4j_2-5b7b",
            "Log4j_2-6a233016": "Log4j_2-6a23",
            "Log4j_2-7441d3c3": "Log4j_2-7441",
            "Ninja-16aa9c14": "Ninja-16aa",
            "Nutz-87a4b212": "Nutz-87a4",
            "OpenNLP-60792b8f": "OpenNLP-6079",
            "OpenPDF-a89dfdf5": "OpenPDF-a89d",
            "PDFBox-55586aad": "PDFBox-5558",
            "Qpid_Proton__j-02998b38": None,
            "ShardingSphere-82b1b9d5": "Sharding-82b1",
            "ShardingSphere-9833fb9a": "Sharding-9833",
            "ShardingSphere-c08f4f18": "Sharding-c08f",
            "ZooKeeper-ef3649f5": "ZooKeeper",
        }
        return mapping.get(proj)
    if bench == "BugSwarm":
        mapping = {
            "ACS_AEM_Commons-374231969": "ACS_Commons",
            "Artemis__odb-71816517": "Artemis_odb",
            "BungeeCord-130330788": "BungeeCord-1303",
            "Byte_Buddy-140517155": "Byte-1405",
            "Byte_Buddy-95795967": "Byte_Buddy-9579",
            "Dubbo-416671625": "Dubbo-4166",
            "OkHttp-93618854": "OkHttp-9361",
            "Petergeneric__Stdlib-290369132": "Petergeneric",
            "REST_Countries-154683750": "REST-1546",
            "REST_Countries-207869551": "REST-2078",
            "Universal_G__Code_Sender-172454077": "Universal-1724",
            "Universal_G__Code_Sender-676666184": "Universal-6766",
            "Yamcs-186324159": "Yamcs-1863",
        }
        return mapping.get(proj)
    if bench == "Defects4J":
        mapping = {
            "Cli-30": "Cli-30",
            "Csv-11": "Csv-11",
            "Csv-9": "Csv-9",
            "Math-70": "Math-70",
            "Math-79": "Math-79",
        }
        return mapping.get(proj)
    if bench == "Bears":
        mapping = {
            "Bears-189": "Bears-189",
            "Bears-222": "Bears-222",
            "Bears-56": "Bears-56",
            "Bears-70": "Bears-70",
            "Bears-88": "Bears-88",
        }
        return mapping.get(proj)
    if bench == "Genesis":
        mapping = {
            "Activiti-31c8ea16": "Activiti-31c8",
            "Checkstyle-be8a60a4": "Checkstyle-be8",
            "DataflowJavaSDK-f42c13c8": "DataflowJavaSDK",
            "JavaPoet-aee5f128": "JavaPoet-aee5",
            "Javaslang-0dab3ed3": "Javaslang-0dab",
            "Jongo-97431a03": "Jongo-9743",
        }
        return mapping.get(proj)
    return None

def fmt(p):
    return str(int(round(p)))

out_lines = []
out_lines.append("**Table 2: The reproduction rate results for 25 trials on benchmark projects gathered from the prior studies [3, 21–24]. The projects where all three tools failed to detect NPEs are excluded from this table. Project: The name of the buggy project with its abbreviated NPE-labeling ID (if necessary). The number in a parenthesis represents each unique NPE in the same project.**\n\n")

# --- NPEX ---
npex = [e for e in entries if e[0] == "NPEX"]
http_rows = [e for e in npex if e[1] == "HttpComponents_Client-f6333a50"]
qpid_rows = [e for e in npex if e[1] == "Qpid_Proton__j-02998b38"]
npex_map = {}
for b, p, c, ev, np in npex:
    if p in {"HttpComponents_Client-f6333a50","Qpid_Proton__j-02998b38"}:
        continue
    lab = short_label(b, p)
    if lab:
        npex_map[lab] = (ev, np)
http_labels = ["Http-f633(1)", "Http-f633(2)", "Http-f633(3)", "Http-f633(4)"]
for idx, row in enumerate(http_rows):
    if idx < len(http_labels):
        lab = http_labels[idx]
        npex_map[lab] = (row[3], row[4])
qpid_labels = ["Qpid-0299 (1)", "Qpid-0299 (2)"]
for idx, row in enumerate(qpid_rows):
    if idx < len(qpid_labels):
        lab = qpid_labels[idx]
        npex_map[lab] = (row[3], row[4])

npex_order = [
    "Activiti-c45","Aries_JPA","Avro","Commons_Conf","Commons_DBCP",
    "Commons_Pool","CXF-2094","Directory","Easy_Rules","Fastjson-650a",
    "Feign-9c5a","FOP-10e0d1c2","Hessian_Lite","Hivemall-04fa",
    "Http-f633(1)","Http-f633(2)","Http-f633(3)","Http-f633(4)",
    "IoTDB-9bce","Jest-f34f","jsoup-8b83","jsoup-b841","JSqlParser",
    "Karaf-b92d","Log4j_2-5b7b","Log4j_2-6a23","Log4j_2-7441",
    "Ninja-16aa","Nutz-87a4","OpenNLP-6079","OpenPDF-a89d",
    "PDFBox-5558","Qpid-0299 (1)","Qpid-0299 (2)","Sharding-82b1",
    "Sharding-9833","Sharding-c08f","ZooKeeper",
]

out_lines.append("### NPEX\n\n")
out_lines.append("| Project | EvoSuite | NPETest |\n")
out_lines.append("| :--- | ---: | ---: |\n")
for lab in npex_order:
    ev, np = npex_map.get(lab, (0.0, 0.0))
    out_lines.append(f"| {lab} | {fmt(ev)} | {fmt(np)} |\n")

# --- BugSwarm ---
bugs = [e for e in entries if e[0] == "BugSwarm"]
proj_groups = {}
for b, p, c, ev, np in bugs:
    key = short_label(b, p)
    if key is None:
        continue
    proj_groups.setdefault(key, []).append((c, ev, np))

bs_map = {}
for key, data in proj_groups.items():
    if key == "OkHttp-9361":
        for i, (_, ev, np) in enumerate(data):
            bs_map[f"OkHttp-9361({i+1})"] = (ev, np)
    elif key == "REST-1546":
        for i, (_, ev, np) in enumerate(data):
            bs_map[f"REST-1546({i+1})"] = (ev, np)
    elif key == "Universal-1724":
        for i, (_, ev, np) in enumerate(data):
            bs_map[f"Universal-1724({i+1})"] = (ev, np)
    else:
        _, ev, np = data[0]
        bs_map[key] = (ev, np)

bs_order = [
    "ACS_Commons","Artemis_odb","BungeeCord-1303","Byte-1405","Byte_Buddy-9579",
    "Dubbo-4166","OkHttp-9361(1)","OkHttp-9361(2)","Petergeneric",
    "REST-1546(1)","REST-1546(2)","REST-1546(3)","REST-1546(4)","REST-1546(5)",
    "REST-2078","Universal-1724(1)","Universal-1724(2)","Universal-6766","Yamcs-1863",
]

out_lines.append("\n### BugSwarm\n\n")
out_lines.append("| Project | EvoSuite | NPETest |\n")
out_lines.append("| :--- | ---: | ---: |\n")
for lab in bs_order:
    ev, np = bs_map.get(lab, (0.0, 0.0))
    out_lines.append(f"| {lab} | {fmt(ev)} | {fmt(np)} |\n")

# --- Defects4J ---
d4j = [e for e in entries if e[0] == "Defects4J"]
dmap = {}
for b, p, c, ev, np in d4j:
    key = short_label(b, p)
    dmap.setdefault(key, []).append((c, ev, np))

dvals = {}
for key, data in dmap.items():
    if key == "Cli-30":
        for i, (_, ev, np) in enumerate(data):
            dvals[f"Cli-30({i})"] = (ev, np)
    else:
        _, ev, np = data[0]
        dvals[key] = (ev, np)

d4j_order = ["Cli-30(0)","Cli-30(1)","Csv-11","Csv-9","Math-70","Math-79"]

out_lines.append("\n### Defects4J\n\n")
out_lines.append("| Project | EvoSuite | NPETest |\n")
out_lines.append("| :--- | ---: | ---: |\n")
for lab in d4j_order:
    ev, np = dvals.get(lab, (0.0, 0.0))
    out_lines.append(f"| {lab} | {fmt(ev)} | {fmt(np)} |\n")

# --- Genesis ---
gen = [e for e in entries if e[0] == "Genesis"]
gmap = {}
for b, p, c, ev, np in gen:
    lab = short_label(b, p)
    if lab:
        gmap[lab] = (ev, np)

gen_order = ["Activiti-31c8","Checkstyle-be8","DataflowJavaSDK","JavaPoet-aee5","Javaslang-0dab","Jongo-9743"]

out_lines.append("\n### Genesis\n\n")
out_lines.append("| Project | EvoSuite | NPETest |\n")
out_lines.append("| :--- | ---: | ---: |\n")
for lab in gen_order:
    ev, np = gmap.get(lab, (0.0, 0.0))
    out_lines.append(f"| {lab} | {fmt(ev)} | {fmt(np)} |\n")

# --- Bears ---
bears = [e for e in entries if e[0] == "Bears"]
bmap = {}
for b, p, c, ev, np in bears:
    lab = short_label(b, p)
    if lab:
        bmap[lab] = (ev, np)

bears_order = ["Bears-189","Bears-222","Bears-56","Bears-70","Bears-88"]

out_lines.append("\n### Bears\n\n")
out_lines.append("| Project | EvoSuite | NPETest |\n")
out_lines.append("| :--- | ---: | ---: |\n")
for lab in bears_order:
    ev, np = bmap.get(lab, (0.0, 0.0))
    out_lines.append(f"| {lab} | {fmt(ev)} | {fmt(np)} |\n")

out_path = pathlib.Path("/workspace/repro.txt")
out_path.write_text("".join(out_lines))
PYCODE

# Section 4: Formatting and submission block
cd /workspace
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
