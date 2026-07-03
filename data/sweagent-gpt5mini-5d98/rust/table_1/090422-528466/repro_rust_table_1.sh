#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Resolution accuracy.**

| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |
| ------------ | ------------: | --------: | -----: | ------: |
| Random       |        99.39% |    99.76% | 98.93% |  99.35% |
| Popular      |        99.50% |    100.00% | 99.17% |  99.58% |
| Mostdep      |        97.04% |    99.96% | 97.49% |  98.71% |

EOTABLE

# Section 2: Artifact download
curl -L -o /workspace/Cargo-Ecosystem-Monitor-ICSE.zip "https://zenodo.org/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip?download=1"

# Section 3: Reproduction commands
# Unzip artifact
unzip -q /workspace/Cargo-Ecosystem-Monitor-ICSE.zip -d /workspace/Cargo-Ecosystem-Monitor
# Extract evaluation bundle
unzip -q /workspace/Cargo-Ecosystem-Monitor/Cargo-Ecosystem-Monitor/Code/accuracy_evaluation/EDG_Evaluation_20220811.zip -d /workspace/Cargo-Ecosystem-Monitor/Cargo-Ecosystem-Monitor/Code/accuracy_evaluation/output || true

# Parse results and print reproduction table to /workspace/repro.txt
cat > /workspace/repro.txt <<'REPRO'
**Table 1: Resolution accuracy.**

| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |
| ------------ | ------------: | --------: | -----: | ------: |
REPRO

for ds in random popular mostdep; do
  resfile="/workspace/Cargo-Ecosystem-Monitor/Cargo-Ecosystem-Monitor/Code/accuracy_evaluation/output/results_2000/${ds}/results.txt"
  if [ -f "$resfile" ]; then
    tree=$(grep -i "Tree Accuracy" -n "$resfile" | awk -F"=" '{print $2}' | tr -d ' %')
    prec=$(grep -i "Precision" -n "$resfile" | awk -F"=" '{print $2}' | tr -d ' %')
    rec=$(grep -i "Recall" -n "$resfile" | awk -F"=" '{print $2}' | tr -d ' %')
    f1=$(grep -i "F1Score" -n "$resfile" | awk -F"=" '{print $2}' | tr -d ' %')
    # Format to two decimal places and append %
    treef=$(printf "%.2f%%" "$tree")
    precf=$(printf "%.2f%%" "$prec")
    recf=$(printf "%.2f%%" "$rec")
    f1f=$(printf "%.2f%%" "$f1")
    # Capitalize dataset name for output matching expected
    name="${ds^}"
    # Special case: mostdep -> Mostdep
    if [ "$ds" = "mostdep" ]; then name="Mostdep"; fi
    printf "| %-12s | %11s | %8s | %6s | %7s |\n" "$name" "$treef" "$precf" "$recf" "$f1f" >> /workspace/repro.txt
  else
    echo "# Missing results for dataset $ds" >> /workspace/repro.txt
  fi
done

# Section 4: Formatting and submission block
echo '<artisan_submit>' >> /workspace/repro.txt
cat /workspace/repro.txt
echo '</artisan_submit>' >> /workspace/repro.txt

