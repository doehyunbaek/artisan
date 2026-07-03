#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary of RUF usage**

| Type       | RUF Count | Package Versions | RUF Usage Items |
| ---------- | ---------:| ----------------:| ---------------:|
| Accepted   |       382 |           24,681 |          38,858 |
| Active     |       381 |           55,785 |         101,494 |
| Incomplete |         7 |            5,829 |           5,926 |
| Removed    |        41 |           14,812 |          21,096 |
| Unknown    |       189 |           10,534 |          14,652 |

EOTABLE
# Section 2: Artifact download
mkdir -p /workspace/artifact
curl -L -o /workspace/artifact.zip 'https://zenodo.org/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip?download=1'
unzip -q /workspace/artifact.zip -d /workspace/artifact

# Section 3: Reproduction commands (populate from reviewed steps)
# Note: The following follows the README instructions. It builds the docker image,
# runs a detached container (sleeping), sets up PostgreSQL, and executes the SQL queries
# relevant to Table 2. Execution may be long or require network/files; commands are best-effort.
cd /workspace/artifact/Cargo-Ecosystem-Monitor || exit 1

# Ensure submodules (may be needed)
make submodule || true

# Build the Docker image (preferred per README)
docker build -t cargo-ecosystem-monitor . || true

# Run the container detached (replace interactive run as requested)
CID=$(docker run -d --init --entrypoint bash cargo-ecosystem-monitor -c 'sleep infinity') || true
sleep 2

# Setup PostgreSQL inside container (as README suggests)
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /app || true; make postgresql" || true

# Try to run the three SQL queries that produce Table 2 and write to /workspace/repro.txt
# Queries:
Q1="SELECT status, COUNT(*) FROM feature_status WHERE name in (SELECT DISTINCT feature FROM version_feature_ori) GROUP BY status;"
Q2="SELECT status, COUNT(DISTINCT id) FROM version_feature_ori INNER JOIN feature_status ON name=feature GROUP BY status;"
Q3="SELECT status, COUNT(*) FROM version_feature_ori INNER JOIN feature_status ON name=feature GROUP BY status;"

# Execute queries inside container and capture output to host /workspace/repro.txt
docker exec "$CID" /bin/bash --noprofile --norc -c "psql -U postgres -d crates -t -A -F',' -c \"$Q1\"; echo '---'; psql -U postgres -d crates -t -A -F',' -c \"$Q2\"; echo '---'; psql -U postgres -d crates -t -A -F',' -c \"$Q3\"" > /workspace/repro.txt || true

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submission.txt
echo 'Reproduction output (raw CSV-like):' >> /workspace/repro_submission.txt
cat /workspace/repro.txt >> /workspace/repro_submission.txt
echo '</artisan_submit>' >> /workspace/repro_submission.txt

# End script
