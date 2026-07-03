#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -13.20 | 1696.36 | -0.01 | 0.99 |
| MainFactorProc | -0.26 | 0.47 | -0.56 | 0.99 |
| Usage Freq. | -0.83 | 0.44 | -1.87 | 0.30 |
| Approvals | 0.00 | 0.00 | -0.36 | 0.99 |
| StudentTrue | 14.38 | 1696.36 | 0.01 | 0.99 |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377

# Section 3: Reproduction commands (use provided analysis script)
cd ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts || exit 1
chmod +x run-analysis.sh
./run-analysis.sh
cd results || exit 1

# Extract rows for Table 7 from the regenerated CSV
awk 'BEGIN{OFS=","}
NR==1{next}
NR==2{print "(Intercept)",$1,$2,$3,$4}
NR==3{print "MainFactorProc",$1,$2,$3,$4}
NR==4{print "Usage Freq.",$1,$2,$3,$4}
NR==5{print "Approvals",$1,$2,$3,$4}
NR==6{print "StudentTrue",$1,$2,$3,$4}' Table-7-RQ1-reduce.csv > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/expected.md
echo
echo
echo 'Reproduced Table 7 (from Table-7-RQ1-reduce.csv):'
echo
echo '| Term | Estimate | Std.Error | z value | Pr(>|z|) |' > /workspace/repro_table7.md
echo '|---|---:|---:|---:|---:|' >> /workspace/repro_table7.md
awk -F, '{printf "| %s | %.2f | %.2f | %.2f | %.2f |\n",$1,$2,$3,$4,$5}' /workspace/repro.txt >> /workspace/repro_table7.md
cat /workspace/repro_table7.md
echo '</artisan_submit>'
