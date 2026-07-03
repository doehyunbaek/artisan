#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | ??.?? | ????.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | ?.?? | ?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | -??.?? | ????.?? | -?.?? | ?.?? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts

# Ensure the Docker image is available
docker pull mdipenta/rexp

# Start a long-running container with the replication package mounted
docker run -d --init --entrypoint bash --name func_rexp -v"${PWD}":/data mdipenta/rexp -c 'sleep infinity'

# Run the R analysis script inside the container to regenerate all tables, including Table 6
docker exec func_rexp /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Build /workspace/repro.txt in markdown format for Table 6 from the generated LaTeX table
texfile="results/Table-6-RQ1-map.tex"

cat <<'EORMD' > /workspace/repro.txt
**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
EORMD

awk -F'&' '
/^\(Intercept\)/ {
  term="(Intercept)"
  est=$2; se=$3; z=$4; p=$5
  gsub(/\\\\/, "", p)
  gsub(/^[ \t]+|[ \t]+$/, "", est)
  gsub(/^[ \t]+|[ \t]+$/, "", se)
  gsub(/^[ \t]+|[ \t]+$/, "", z)
  gsub(/^[ \t]+|[ \t]+$/, "", p)
  printf("| %s | %s | %s | %s | %s |\n", term, est, se, z, p)
}
/MainFactorp/ {
  term="MainFactorProc"
  est=$2; se=$3; z=$4; p=$5
  gsub(/\\\\/, "", p)
  gsub(/^[ \t]+|[ \t]+$/, "", est)
  gsub(/^[ \t]+|[ \t]+$/, "", se)
  gsub(/^[ \t]+|[ \t]+$/, "", z)
  gsub(/^[ \t]+|[ \t]+$/, "", p)
  printf("| %s | %s | %s | %s | %s |\n", term, est, se, z, p)
}
/UsageFrequency/ {
  term="Usage Freq."
  est=$2; se=$3; z=$4; p=$5
  gsub(/\\\\/, "", p)
  gsub(/^[ \t]+|[ \t]+$/, "", est)
  gsub(/^[ \t]+|[ \t]+$/, "", se)
  gsub(/^[ \t]+|[ \t]+$/, "", z)
  gsub(/^[ \t]+|[ \t]+$/, "", p)
  printf("| %s | %s | %s | %s | %s |\n", term, est, se, z, p)
}
/^[ \t]*Approvals/ {
  term="Approvals"
  est=$2; se=$3; z=$4; p=$5
  gsub(/\\\\/, "", p)
  gsub(/^[ \t]+|[ \t]+$/, "", est)
  gsub(/^[ \t]+|[ \t]+$/, "", se)
  gsub(/^[ \t]+|[ \t]+$/, "", z)
  gsub(/^[ \t]+|[ \t]+$/, "", p)
  printf("| %s | %s | %s | %s | %s |\n", term, est, se, z, p)
}
/StudentTRUE/ {
  term="StudentTrue"
  est=$2; se=$3; z=$4; p=$5
  gsub(/\\\\/, "", p)
  gsub(/^[ \t]+|[ \t]+$/, "", est)
  gsub(/^[ \t]+|[ \t]+$/, "", se)
  gsub(/^[ \t]+|[ \t]+$/, "", z)
  gsub(/^[ \t]+|[ \t]+$/, "", p)
  printf("| %s | %s | %s | %s | %s |\n", term, est, se, z, p)
}
' "$texfile" >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
