#!/usr/bin/bash
set -e

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -15.80 | 1383.44 | 0.01 | 0.99 |
| MainFactorProc | -0.06 | 0.40 | -0.16 | 0.99 |
| Usage Freq. | -0.18 | 0.33 | -0.54 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.76 | 0.99 |
| StudentTrue | 15.56 | 1383.44 | 0.01 | 0.99 |

EOTABLE

# Section 2: Artifact download
cd /workspace
curl -L 'https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content' -o ICSE2024-funcConstructs-Artifacts.zip

# Section 3: Reproduction commands (populate from reviewed steps)
# Ensure a clean extraction directory to avoid interactive unzip prompts
rm -rf /workspace/ICSE2024-funcConstructs-Artifacts
unzip -oq ICSE2024-funcConstructs-Artifacts.zip -d /workspace
cd /workspace/ICSE2024-funcConstructs-Artifacts

# Ensure the Docker image used in the README is available
docker pull mdipenta/rexp:latest

# Run the R analysis inside Docker to regenerate all tables, including Table 8
sh run-analysis.sh

# Format the regenerated Table 8 into /workspace/repro.txt as Markdown
tmp_body=/workspace/repro_body_tmp.md
rm -f "$tmp_body"

awk -F',' '
NR==1 { next }                          # skip header
NR==2 { term="(Intercept)" }
NR==3 { term="MainFactorProc" }
NR==4 { term="Usage Freq." }
NR==5 { term="Approvals" }
NR==6 { term="StudentTrue" }
NR>=2 && NR<=6 {
  printf "| %s | %.2f | %.2f | %.2f | %.2f |\n", term, $1, $2, $3, $4
}
' results/Table-8-RQ1-filter.csv > "$tmp_body"

cat > /workspace/repro.txt <<'EOTOP'
**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
EOTOP

cat "$tmp_body" >> /workspace/repro.txt
rm -f "$tmp_body"

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
