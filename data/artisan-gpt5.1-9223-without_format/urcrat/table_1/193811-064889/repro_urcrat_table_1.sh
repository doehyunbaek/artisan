#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Benchmark programs**

| Name | C LOC | Rust LOC | #Unions | #Candidates | #Identified |
| --- | --- | --- | --- | --- | --- |
| bc-1.07.1 | ????? | ????? | ? | ? | ? |
| binn-3.0** | ???? | ???? | ? | ? | ? |
| brotli-1.0.9** | ????? | ?????? | ? | ? | ? |
| cflow-1.7 | ????? | ????? | ? | ? | ? |
| compton* | ???? | ????? | ? | ? | ? |
| cpio-2.14 | ????? | ????? | ?? | ? | ? |
| diffutils-3.10 | ????? | ????? | ? | ? | ? |
| enscript-1.6.6 | ????? | ????? | ? | ? | ? |
| findutils-4.9.0 | ????? | ?????? | ?? | ? | ? |
| gawk-5.2.2 | ????? | ?????? | ?? | ?? | ? |
| glpk-5.0 | ????? | ?????? | ?? | ?? | ? |
| gprolog-1.5.0 | ????? | ????? | ? | ? | ? |
| grep-3.11 | ????? | ????? | ?? | ? | ? |
| gzip-1.12 | ????? | ????? | ? | ? | ? |
| hiredis* | ???? | ????? | ? | ? | ? |
| make-4.4.1 | ????? | ????? | ? | ? | ? |
| minilisp* | ??? | ???? | ? | ? | ? |
| mtools-4.0.43 | ????? | ????? | ? | ? | ? |
| nano-7.2 | ????? | ????? | ? | ? | ? |
| nettle-3.9 | ????? | ????? | ? | ? | ? |
| patch-2.7.6 | ????? | ?????? | ? | ? | ? |
| php-rdkafka* | ???? | ????? | ? | ? | ? |
| pocketlang* | ????? | ????? | ? | ? | ? |
| pth-2.0.7 | ???? | ????? | ? | ? | ? |
| raygui* | ???? | ????? | ? | ? | ? |
| rcs-5.10.1 | ????? | ????? | ? | ? | ? |
| screen-4.9.0 | ????? | ????? | ? | ? | ? |
| sed-4.9 | ????? | ????? | ? | ? | ? |
| shairport* | ???? | ????? | ? | ? | ? |
| tar-1.34 | ????? | ?????? | ?? | ?? | ? |
| tinyproxy* | ???? | ????? | ? | ? | ? |
| twemproxy* | ????? | ????? | ? | ? | ? |
| uucp-1.07 | ????? | ????? | ? | ? | ? |
| webdis* | ????? | ????? | ? | ? | ? |
| wget-1.21.4 | ????? | ?????? | ? | ? | ? |
| Total |  |  | ??? | ??? | ?? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/13373683

# Section 3: Reproduction commands (populate from reviewed steps)

# Pull the Docker image specified in the artifact README
docker pull kaistplrg/urcrat:ase2024

# Start a long-running container following the non-interactive pattern
# If a container with the same name exists, remove it first.
if docker ps -a --format '{{.Names}}' | grep -q '^urcrat-ase2024$'; then
  docker rm -f urcrat-ase2024
fi
docker run -d --init --name urcrat-ase2024 --entrypoint bash kaistplrg/urcrat:ase2024 -c 'sleep infinity'

# Run size.sh to get C and Rust LOC
docker exec urcrat-ase2024 /bin/bash --noprofile --norc -c "cd /home/ubuntu && ./bin/size.sh" > /workspace/size_raw.txt

# Run run.sh to get unions, candidates, and identified tag fields
docker exec urcrat-ase2024 /bin/bash --noprofile --norc -c "cd /home/ubuntu && ./bin/run.sh" > /workspace/run_raw.txt

# Parse size.sh output: name -> (C LOC, Rust LOC)
awk 'NR>1 {print $3, $1, $2}' /workspace/size_raw.txt > /workspace/size_parsed.txt

# Parse run.sh output: name -> (Unions, Candidates, Identified)
awk '{print $12, $1, $2, $3}' /workspace/run_raw.txt > /workspace/run_parsed.txt

# Build Table 1 in /workspace/repro.txt
cat > /workspace/repro.txt <<'TABLEHDR'
**Table 1: Benchmark programs**

| Name | C LOC | Rust LOC | #Unions | #Candidates | #Identified |
| --- | --- | --- | --- | --- | --- |
TABLEHDR

# Use bash to join the parsed data and compute totals
/usr/bin/bash <<'INNERSCRIPT'
set -euo pipefail

declare -A CLOC RLOC UNIONS CANDS IDS

# Load LOC data
while read -r name cloc rloc; do
  CLOC["$name"]="$cloc"
  RLOC["$name"]="$rloc"
done < /workspace/size_parsed.txt

# Load union data
while read -r name u c i; do
  UNIONS["$name"]="$u"
  CANDS["$name"]="$c"
  IDS["$name"]="$i"
done < /workspace/run_parsed.txt

outfile="/workspace/repro.txt"

totalU=0
totalC=0
totalI=0

append_row() {
  local base="$1"
  local display="$2"
  local cloc="${CLOC[$base]}"
  local rloc="${RLOC[$base]}"
  local u="${UNIONS[$base]}"
  local c="${CANDS[$base]}"
  local i="${IDS[$base]}"

  echo "| ${display} | ${cloc} | ${rloc} | ${u} | ${c} | ${i} |" >> "${outfile}"

  totalU=$(( totalU + u ))
  totalC=$(( totalC + c ))
  totalI=$(( totalI + i ))
}

# Append rows in the order of Table 1, mapping to the base benchmark names
append_row "bc-1.07.1"      "bc-1.07.1"
append_row "binn-3.0"       "binn-3.0**"
append_row "brotli-1.0.9"   "brotli-1.0.9**"
append_row "cflow-1.7"      "cflow-1.7"
append_row "compton"        "compton*"
append_row "cpio-2.14"      "cpio-2.14"
append_row "diffutils-3.10" "diffutils-3.10"
append_row "enscript-1.6.6" "enscript-1.6.6"
append_row "findutils-4.9.0" "findutils-4.9.0"
append_row "gawk-5.2.2"     "gawk-5.2.2"
append_row "glpk-5.0"       "glpk-5.0"
append_row "gprolog-1.5.0"  "gprolog-1.5.0"
append_row "grep-3.11"      "grep-3.11"
append_row "gzip-1.12"      "gzip-1.12"
append_row "hiredis"        "hiredis*"
append_row "make-4.4.1"     "make-4.4.1"
append_row "minilisp"       "minilisp*"
append_row "mtools-4.0.43"  "mtools-4.0.43"
append_row "nano-7.2"       "nano-7.2"
append_row "nettle-3.9"     "nettle-3.9"
append_row "patch-2.7.6"    "patch-2.7.6"
append_row "php-rdkafka"    "php-rdkafka*"
append_row "pocketlang"     "pocketlang*"
append_row "pth-2.0.7"      "pth-2.0.7"
append_row "raygui"         "raygui*"
append_row "rcs-5.10.1"     "rcs-5.10.1"
append_row "screen-4.9.0"   "screen-4.9.0"
append_row "sed-4.9"        "sed-4.9"
append_row "shairport"      "shairport*"
append_row "tar-1.34"       "tar-1.34"
append_row "tinyproxy"      "tinyproxy*"
append_row "twemproxy"      "twemproxy*"
append_row "uucp-1.07"      "uucp-1.07"
append_row "webdis"         "webdis*"
append_row "wget-1.21.4"    "wget-1.21.4"

# Append the Total row: only union-related columns are totaled, LOC columns remain blank
echo "| Total |  |  | ${totalU} | ${totalC} | ${totalI} |" >> "${outfile}"
INNERSCRIPT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
