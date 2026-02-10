#!/usr/bin/env bash
set -euo pipefail

# Fresh log / main output capture
: > /workspace/repro.txt

git clone https://github.com/kupl/NPETestArtifact >> /workspace/repro.txt 2>&1 || true
python3 -m pip install --quiet --upgrade pandas matplotlib matplotlib-venn

cd /workspace/NPETestArtifact/result

curl -L -o evosuite_result.zip "https://zenodo.org/records/13738493/files/evosuite_opt_result.zip?download=1"
unzip -o evosuite_result.zip
mkdir -p evosuite
rm -rf evosuite/evosuite_opt_result || true
mv -f evosuite_opt_result evosuite/

curl -L -o npetest_result.zip "https://zenodo.org/records/13738493/files/npetest_result.zip?download=1"
unzip -o npetest_result.zip
mkdir -p npetest
rm -rf npetest/npetest_result || true
mv -f npetest_result npetest/

cd /workspace/NPETestArtifact
./scripts/get_main_results.sh

# Use main_result.txt as the single source of tool outputs
cp /workspace/NPETestArtifact/result/main_result.txt /workspace/repro.txt

echo "<artisan_submit>"
python3 - <<'PY'
import re
from collections import defaultdict

MAIN = "/workspace/repro.txt"

# Embedded expected table template (no separate expected.md file)
EXPECTED_MD = r"""**Table 2: The reproduction rate results for 25 trials on benchmark projects gathered from the prior studies [3, 21–24]. The projects where all three tools failed to detect NPEs are excluded from this table. Project: The name of the buggy project with its abbreviated NPE-labeling ID (if necessary). The number in a parenthesis represents each unique NPE in the same project.**

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
| Cli-30(1) | ?? | ??? |
| Cli-30(2) | ?? | ??? |
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
"""

def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", s.lower())

def tokens(s: str):
    return [t for t in re.split(r"[^A-Za-z0-9]+", s.lower()) if t]

# --------
# Parse embedded expected markdown into sections -> ordered project names
# --------
sec_order = []
sec_to_projects = defaultdict(list)

cur_sec = None
in_table = False

for line in EXPECTED_MD.splitlines():
    line = line.rstrip("\n")
    m = re.match(r"^###\s+(.+?)\s*$", line)
    if m:
        cur_sec = m.group(1).strip()
        sec_order.append(cur_sec)
        in_table = False
        continue
    if cur_sec is None:
        continue
    if line.strip().startswith("| Project "):
        in_table = True
        continue
    if in_table:
        if not line.strip().startswith("|"):
            in_table = False
            continue
        if re.match(r"^\|\s*:?-{3,}", line):
            continue
        parts = [p.strip() for p in line.split("|")[1:-1]]
        if not parts:
            continue
        proj = parts[0]
        if proj and proj.lower() != "project":
            sec_to_projects[cur_sec].append(proj)

# --------
# Parse main_result.txt (pandas-like sections)
# sec -> {project_key: (evosuite, npetest)}
# --------
sec_to_vals = defaultdict(dict)
cur = None
row_re = re.compile(r"^(\S+)\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)\s*$")

with open(MAIN, "r", encoding="utf-8", errors="replace") as f:
    for raw in f:
        line = raw.rstrip("\n")
        m = re.match(r"^\s*([A-Za-z0-9_]+)\s*:\s*$", line)
        if m:
            cur = m.group(1)
            continue
        if cur is None:
            continue
        if not line.strip():
            continue
        if line.strip().startswith("Tool") or line.strip().startswith("Project"):
            continue
        m = row_re.match(line)
        if not m:
            continue
        key, e, n = m.group(1), float(m.group(2)), float(m.group(3))
        sec_to_vals[cur][key] = (e, n)

def parse_variant(proj: str):
    p = proj.strip()
    m = re.search(r"\((\d+)\)\s*$", p)
    if m:
        v1 = int(m.group(1))          # paper is 1-based
        base = re.sub(r"\s*\(\d+\)\s*$", "", p).strip()
        v0 = v1 - 1                   # convert to log's 0-based
        return base, v0
    return p, None

def best_match(sec: str, proj: str):
    keys = list(sec_to_vals.get(sec, {}).keys())
    if not keys:
        return None

    base, v0 = parse_variant(proj)
    base_tokens = tokens(base)
    base_norm = norm(base)

    best = None
    best_score = -1

    for k in keys:
        kn = norm(k)
        score = 0
        kl = k.lower()

        # token overlap
        hit = sum(1 for t in base_tokens if t and t in kl)
        score += hit * 10

        # base substring match
        if base_norm and base_norm in kn:
            score += 50 + min(len(base_norm), 50)

        # prefer exact converted variant (paper->log)
        if v0 is not None and k.endswith(f"({v0})"):
            score += 400

        # fallback: if no variant exists in the log for this project,
        # still allow matching by base name
        score -= min(len(k), 200) * 0.01

        if score > best_score:
            best_score = score
            best = k

    if base_tokens and best_score < 10:
        return None
    return best

def fmt_pct(x):
    return f"{int(round(float(x)))}"

print("**Table 2: The reproduction rate results for 25 trials on benchmark projects gathered from the prior studies [3, 21–24]. The projects where all three tools failed to detect NPEs are excluded from this table. Project: The name of the buggy project with its abbreviated NPE-labeling ID (if necessary). The number in a parenthesis represents each unique NPE in the same project.**\n")

for sec in sec_order:
    sec_key = sec
    if sec.lower() == "bugswarm":
        sec_key = "BugSwarm"
    elif sec.lower() == "defects4j":
        sec_key = "Defects4J"

    print(f"### {sec}\n")
    print("| Project | EvoSuite | NPETest |")
    print("| :--- | ---: | ---: |")

    for proj in sec_to_projects.get(sec, []):
        mk = best_match(sec_key, proj)
        if mk is None:
            e = n = ""
        else:
            e, n = sec_to_vals[sec_key][mk]
            e, n = fmt_pct(e), fmt_pct(n)
        print(f"| {proj} | {e} | {n} |")
    print()
PY
echo "</artisan_submit>"
