#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Method Exit Anomalies**

| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |
| ----------------- | --------------: | --------------: | -----------------: |
| commons-cli       | 13,965 (60.32%) |  4,216 (30.19%) |     1,728 (40.99%) |
| commons-text      | 17,832 (67.95%) |  4,985 (27.96%) |     1,882 (37.75%) |
| joda-money        | 36,495 (50.68%) | 10,486 (28.73%) |     5,931 (56.56%) |
| jline-reader      | 21,448 (19.36%) |  9,842 (45.89%) |     1,529 (15.54%) |
| commons-validator | 13,340 (51.42%) |  4,947 (37.08%) |     1,159 (23.43%) |
| cdk-data          | 80,398 (45.35%) | 38,550 (47.95%) |     5,717 (14.83%) |
| spotify-web-api   |  2,688 (34.19%) |    677 (25.19%) |          0 (0.00%) |
| commons-codec     | 18,097 (64.04%) |  5,250 (29.01%) |     1,195 (22.76%) |
| jfreechart        | 96,626 (37.92%) | 31,676 (32.78%) |    12,749 (40.25%) |
| dyn4j             | 89,603 (44.43%) | 47,065 (52.53%) |    22,324 (47.43%) |

EOTABLE
# Section 2: Artifact download
# Download the getsankeyamd Docker image (contains precomputed CSV data)
curl -L -o /workspace/getsankeyamd.tar "https://zenodo.org/records/10505175/files/getsankeyamd.tar"
# Load the Docker image
docker load -i /workspace/getsankeyamd.tar

# Section 3: Reproduction commands
# Start the container with infinite sleep
container_id=$(docker run -d --init --entrypoint bash qinfendeheichi/getsankeyamd:v1 -c 'sleep infinity')
# Wait a moment for container to start
sleep 5

# Run the RQ2Script.py that outputs Table 2
docker exec "$container_id" /bin/bash --noprofile --norc -c "cd / && python3 RQ2Script.py" > /workspace/repro.txt 2>&1

# Clean up container
docker stop "$container_id" > /dev/null 2>&1
docker rm "$container_id" > /dev/null 2>&1

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Output the table in the required format
echo "**Table 2: Method Exit Anomalies**"
echo ""
echo "| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |"
echo "| ----------------- | --------------: | --------------: | -----------------: |"
# Parse each line: we need columns 2-7, ignoring the first total number
cat /workspace/repro.txt | while read line; do
    if [[ $line =~ ^[a-z]+-[a-z]+ ]]; then
        # Use awk to parse fields. The line has format:
        # commons-cli           23,153     13,965 ( 60.32%)      4,216 ( 30.19%)      1,728 ( 40.99%)
        # Fields: $1=project, $2=total, $3=#Failed count, $4=(%%), $5=anomaly count, $6=(%%), $7=source count, $8=(%%)
        # But the parentheses are separate fields.
        # Let's use regex to extract properly.
        if [[ $line =~ ^([a-z-]+)\ +([0-9,]+)\ +([0-9,]+)\ \(([ 0-9.]+%\))\ +([0-9,]+)\ \(([ 0-9.]+%\))\ +([0-9,]+)\ \(([ 0-9.]+%\))$ ]]; then
            proj=${BASH_REMATCH[1]}
            failed_count=${BASH_REMATCH[3]}
            failed_pct=${BASH_REMATCH[4]}
            anomaly_count=${BASH_REMATCH[5]}
            anomaly_pct=${BASH_REMATCH[6]}
            source_count=${BASH_REMATCH[7]}
            source_pct=${BASH_REMATCH[8]}
            # Remove leading spaces from percentages
            failed_pct=$(echo "$failed_pct" | sed 's/^ //')
            anomaly_pct=$(echo "$anomaly_pct" | sed 's/^ //')
            source_pct=$(echo "$source_pct" | sed 's/^ //')
            printf "| %-17s | %s (%s) | %s (%s) | %s (%s) |\n" "$proj" "$failed_count" "$failed_pct" "$anomaly_count" "$anomaly_pct" "$source_count" "$source_pct"
        fi
    fi
done
echo '</artisan_submit>'