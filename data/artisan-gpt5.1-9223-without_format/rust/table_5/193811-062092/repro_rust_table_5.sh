#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | ???,??? |              ??,??? |
| After Mitigation  | ???,??? |               ?,??? |

EOTABLE
# Section 2: Artifact download
# Download and extract the main artifact containing the Cargo-Ecosystem-Monitor project
artisan get https://zenodo.org/records/10496086
# Section 3: Reproduction commands (populate from reviewed steps)
# Download the 2022-08-11 ecosystem raw data archive used for RUF mitigation results
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
mkdir -p data
if [ ! -f data/Release-20220811.zip ]; then
  curl 'https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1' --output data/Release-20220811.zip
fi
cd data
unzip -o Release-20220811.zip >/dev/null
csv_path="Release-20220811/ResearchResults/mitigation_results.csv"
# Compute total package versions and compilation failures before/after mitigation
total=$(tail -n +2 "$csv_path" | wc -l)
before_fail=$(awk -F, 'NR>1 && $2=="failure"{c++} END{print c+0}' "$csv_path")
after_fail=$(awk -F, 'NR>1 && $3=="failure"{c++} END{print c+0}' "$csv_path")
# Helper to format integers with thousands separators
fmt_commas() {
  printf "%s" "$1" | rev | sed 's/.../&,/g' | rev | sed 's/^,//'
}
total_fmt=$(fmt_commas "$total")
before_fail_fmt=$(fmt_commas "$before_fail")
after_fail_fmt=$(fmt_commas "$after_fail")
# Write the reproduced Table 5 to /workspace/repro.txt
cat > /workspace/repro.txt <<EOREPRO
**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | $total_fmt |              $before_fail_fmt |
| After Mitigation  | $total_fmt |               $after_fail_fmt |

EOREPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
