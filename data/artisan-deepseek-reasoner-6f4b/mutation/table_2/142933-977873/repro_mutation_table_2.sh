#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Method Exit Anomalies**

| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |
| ----------------- | --------------: | --------------: | -----------------: |
| commons-cli       | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| commons-text      | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| joda-money        | ??,??? (??.??%) | ??,??? (??.??%) |     ?,??? (??.??%) |
| jline-reader      | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| commons-validator | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| cdk-data          | ??,??? (??.??%) | ??,??? (??.??%) |     ?,??? (??.??%) |
| spotify-web-api   |  ?,??? (??.??%) |    ??? (??.??%) |          ? (?.??%) |
| commons-codec     | ??,??? (??.??%) |  ?,??? (??.??%) |     ?,??? (??.??%) |
| jfreechart        | ??,??? (??.??%) | ??,??? (??.??%) |    ??,??? (??.??%) |
| dyn4j             | ??,??? (??.??%) | ??,??? (??.??%) |    ??,??? (??.??%) |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10505175
# Section 3: Reproduction commands
# Load Docker image and run container
docker load -i getsankeyamd.tar
docker run -d --init --name sankeyamd --entrypoint bash qinfendeheichi/getsankeyamd:v1 -c 'sleep infinity'
# Execute RQ2Script and format output
{
echo "**Table 2: Method Exit Anomalies**"
echo ""
echo "| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |"
echo "| ----------------- | --------------: | --------------: | -----------------: |"
docker exec sankeyamd python3 RQ2Script.py | awk '
{
    # The input line has 8 fields: prog, total, fail_cnt, fail_pct_with_parens, ano_cnt, ano_pct_with_parens, ora_cnt, ora_pct_with_parens
    prog = $1
    fail_cnt = $3
    # Remove parentheses and spaces from percentage, keep only number
    fail_pct = $4
    gsub(/[()]/, "", fail_pct)  # Remove parentheses
    gsub(/ /, "", fail_pct)     # Remove spaces
    gsub(/%/, "", fail_pct)     # Remove percent sign
    fail_pct = sprintf("%.2f", fail_pct)
    
    ano_cnt = $5
    ano_pct = $6
    gsub(/[()]/, "", ano_pct)
    gsub(/ /, "", ano_pct)
    gsub(/%/, "", ano_pct)
    ano_pct = sprintf("%.2f", ano_pct)
    
    ora_cnt = $7
    ora_pct = $8
    gsub(/[()]/, "", ora_pct)
    gsub(/ /, "", ora_pct)
    gsub(/%/, "", ora_pct)
    ora_pct = sprintf("%.2f", ora_pct)
    
    printf "| %-18s | %10s (%6s%%) | %10s (%6s%%) | %10s (%6s%%) |\n", \
        prog, fail_cnt, fail_pct, ano_cnt, ano_pct, ora_cnt, ora_pct
}
'
} > /workspace/repro.txt
# Clean up container
docker stop sankeyamd && docker rm sankeyamd
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
