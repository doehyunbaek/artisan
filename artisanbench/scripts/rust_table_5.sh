#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o Cargo-Ecosystem-Monitor-ICSE.zip https://zenodo.org/api/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip/content
unzip Cargo-Ecosystem-Monitor-ICSE.zip -d Cargo-Ecosystem-Monitor-ICSE
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
mkdir -p data
if [ ! -f data/Release-20220811.zip ]; then
  curl 'https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1' --output data/Release-20220811.zip
fi
cd data
unzip -o Release-20220811.zip >/dev/null
csv_path="Release-20220811/ResearchResults/mitigation_results.csv"
total=$(tail -n +2 "$csv_path" | wc -l)
before_fail=$(awk -F, 'NR>1 && $2=="failure"{c++} END{print c+0}' "$csv_path")
after_fail=$(awk -F, 'NR>1 && $3=="failure"{c++} END{print c+0}' "$csv_path")
fmt_commas() {
  printf "%s" "$1" | rev | sed 's/.../&,/g' | rev | sed 's/^,//'
}
total_fmt=$(fmt_commas "$total")
before_fail_fmt=$(fmt_commas "$before_fail")
after_fail_fmt=$(fmt_commas "$after_fail")
cat > /workspace/repro.txt <<EOREPRO
**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | $total_fmt |              $before_fail_fmt |
| After Mitigation  | $total_fmt |               $after_fail_fmt |

EOREPRO

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
