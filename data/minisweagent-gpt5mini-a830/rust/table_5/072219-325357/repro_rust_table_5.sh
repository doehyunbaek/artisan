#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | 259,540 |              70,913 |
| After Mitigation  | 259,540 |               6,978 |

EOTABLE

# Section 2: Artifact download
curl -sSL "https://zenodo.org/records/10496086" -o /workspace/zenodo_record.html
url=$(grep -oP 'href="[^"]+"' /workspace/zenodo_record.html | grep '/records/10496086/files/' | sed -E 's/href="([^"]+)".*/\1/' | head -n1)
curl -L "$( [[ "$url" = http* ]] && echo "$url" || echo "https://zenodo.org${url}" )" -o /workspace/artifact.zip

# Section 3: Reproduction commands (populate from reviewed steps)
unzip -o /workspace/artifact.zip -d /workspace/artifact
csv=/workspace/artifact/Cargo-Ecosystem-Monitor/Code/nightly_propagation/ruf_mitigation_analysis/mitigation_results.csv

if [ ! -f "$csv" ]; then
  echo "ERROR: mitigation_results.csv not found at expected path: $csv" > /workspace/repro.txt
  exit 1
fi

total=$(($(wc -l < "$csv") - 1))
before=$(awk -F, 'NR>1 && $2=="failure"{c++}END{print c+0}' "$csv")
after=$(awk -F, 'NR>1 && $3=="failure"{c++}END{print c+0}' "$csv")

cat > /workspace/repro.txt <<EOTRESULT
RUF impact mitigation reproduction results
| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | $total | $before |
| After Mitigation  | $total | $after |
EOTRESULT

# Section 4: Formatting and submission block
cat > /workspace/repro_table.md <<'EOTABLE2'
**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | $total | $before |
| After Mitigation  | $total | $after |
EOTABLE2

echo '<artisan_submit>'
cat /workspace/repro_table.md
echo '</artisan_submit>'
chmod +x /workspace/repro_rust_table_5.sh
