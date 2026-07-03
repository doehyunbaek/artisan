#!/usr/bin/bash
set -euo pipefail

# repro_rust_table_3.sh
# Reproduce Table 3 (RUF impacts) from the artifact.
# This script follows the project's README approach (Docker recommended).
# It: 1) downloads/unpacks the artifact, 2) builds & runs the provided docker image,
# 3) prepares the database (make postgresql, import raw data), and 4) runs SQL queries
# that produce the table outputs. Results are written to /workspace/repro.txt.

OUT=/workspace/repro.txt
ARTIFACT_URL="https://zenodo.org/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip"
ART_ZIP=/workspace/Cargo-Ecosystem-Monitor-ICSE.zip
REPO_DIR=/workspace/Cargo-Ecosystem-Monitor/Cargo-Ecosystem-Monitor

# Section 1: Expected table (for reference)
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Summary of RUF impacts. The table shows how package versions are impacted by different types of RUF and through different dependencies.**

| RUF Type   | Direct Usage | Uncond Impact |  Cond Impact |        Total |
| ---------- | -----------: | ------------: | -----------: | -----------: |
| Accepted   |       24,681 |        17,085 |       21,477 |       38,448 |
| Active     |       55,785 |        77,582 |      207,133 |      237,386 |
| Incomplete |        5,829 |         7,696 |        7,991 |       12,097 |
| Removed    |       14,812 |        50,896 |       53,159 |       61,160 |
| Unknown    |       10,534 |        46,157 |       48,742 |       57,916 |

EOTABLE

# Section 2: Artifact download & unpack
echo "[1/5] Downloading artifact..." | tee "$OUT"
if [ ! -f "$ART_ZIP" ]; then
    curl -sS -L "$ARTIFACT_URL" -o "$ART_ZIP"
else
    echo "Artifact already downloaded: $ART_ZIP" | tee -a "$OUT"
fi

echo "Unpacking artifact..." | tee -a "$OUT"
unzip -oq "$ART_ZIP" -d /workspace || true

# Section 3: Reproduction commands
# NOTE: The following steps assume you have Docker available locally. If you prefer
# to run steps manually (e.g., on a machine with Docker), run the commands below
# one by one following the README in the artifact.

cd "$REPO_DIR"

echo "[2/5] Building docker image (this may take a while)..." | tee -a "$OUT"
# Build docker image (as documented in README)
if command -v docker >/dev/null 2>&1; then
    docker build -t cargo-ecosystem-monitor . || echo "docker build failed (docker may not be available in this environment)" | tee -a "$OUT"
else
    echo "Docker not available - skipping docker build. You should run this script on a machine with Docker to reproduce fully." | tee -a "$OUT"
fi

# Run container detached with sleep infinity as entrypoint (per instructions)
CONTAINER_ID=""
if command -v docker >/dev/null 2>&1; then
    echo "[3/5] Starting container..." | tee -a "$OUT"
    CONTAINER_ID=$(docker run -d --init --entrypoint bash cargo-ecosystem-monitor -c 'sleep infinity' || true)
    if [ -z "$CONTAINER_ID" ]; then
        echo "Failed to run container (image may not exist). You may run the container manually." | tee -a "$OUT"
    else
        echo "Container started: $CONTAINER_ID" | tee -a "$OUT"
    fi
fi

# Prepare database & import raw data - these targets are provided by the project's Makefile
if [ -n "$CONTAINER_ID" ]; then
    echo "[4/5] Setting up postgres and importing raw data inside the container (may take many minutes)..." | tee -a "$OUT"
    docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "set -e; cd /app || true; make postgresql || true; make download_20220811_rawdata || true; make import_20220811_rawdata || true" || echo "One or more make steps failed inside container" | tee -a "$OUT"
else
    echo "Skipping DB setup inside container because no container is running. If you have Docker, re-run this script on a Docker-enabled machine." | tee -a "$OUT"
fi

# Run SQL queries to reproduce Table 3 and write results to OUT
# The SQL queries below are taken from Code/scripts/research_results.sql (Result 3: RUF Impact)

SQL_BLOCK=$(cat <<'SQL'
\timing
-- Direct Usage (RUF usage items per status)
SELECT 'Direct Usage' AS metric, status, COUNT(*)::text AS count
FROM feature_status
  WHERE name in (SELECT DISTINCT feature FROM version_feature_ori)
GROUP BY status ORDER BY status;

-- Unconditional Impact
WITH uncon_ver AS
  (SELECT id, status FROM version_feature_ori INNER JOIN feature_status
  ON name=feature WHERE conds = '' AND feature is not NULL)
SELECT 'Uncond Impact' AS metric, status, COUNT(DISTINCT version_from)::text AS count FROM uncon_ver INNER JOIN dep_version ON
version_to=id GROUP BY status ORDER BY status;

-- Conditional Impact (cond + indirect propagation)
DROP TABLE IF EXISTS tmp_ruf_impact;
CREATE TABLE tmp_ruf_impact AS (
    SELECT DISTINCT version_from as ver, nightly_feature as ruf, status FROM dep_version_feature 
    INNER JOIN feature_status ON name=nightly_feature 
);
WITH uncon_ver AS
  (SELECT id, name as ruf, status FROM version_feature INNER JOIN feature_status
  ON name=feature WHERE conds = '' AND feature is not NULL)
INSERT INTO tmp_ruf_impact
  SELECT DISTINCT version_from, ruf, status FROM uncon_ver INNER JOIN dep_version ON
  version_to=id;
SELECT 'Cond Impact' AS metric, status, COUNT(DISTINCT ver)::text AS count FROM tmp_ruf_impact GROUP BY status ORDER BY status;

-- Total Impact (Direct + Cond + Uncond)
DROP TABLE IF EXISTS tmp_ruf_impact_total;
CREATE TABLE tmp_ruf_impact_total AS (
    SELECT version_from as ver, nightly_feature as ruf, status FROM dep_version_feature 
    INNER JOIN feature_status ON name=nightly_feature 
);
WITH uncon_ver AS
  (SELECT id, name as ruf, status FROM version_feature INNER JOIN feature_status
  ON name=feature WHERE conds = '' AND feature is not NULL)
INSERT INTO tmp_ruf_impact_total
  SELECT DISTINCT version_from, ruf, status FROM uncon_ver INNER JOIN dep_version ON
  version_to=id;
INSERT INTO tmp_ruf_impact_total
  SELECT  DISTINCT id, feature, status FROM version_feature INNER JOIN feature_status 
  ON name=feature WHERE feature IS NOT NULL;
SELECT 'Total' AS metric, status, COUNT(DISTINCT ver)::text AS count FROM tmp_ruf_impact_total GROUP BY status ORDER BY status;

SQL
)

if [ -n "$CONTAINER_ID" ]; then
    echo "[5/5] Executing SQL inside container and saving results to $OUT" | tee -a "$OUT"
    docker exec -i "$CONTAINER_ID" /bin/bash --noprofile --norc -c "psql -U postgres -d crates -v ON_ERROR_STOP=1" > "$OUT" <<PSQL || true
$SQL_BLOCK
PSQL
else
    echo "No container available: attempting to run psql locally (requires proper DB)" | tee -a "$OUT"
    if command -v psql >/dev/null 2>&1; then
        echo "$SQL_BLOCK" | psql -U postgres -d crates -v ON_ERROR_STOP=1 >> "$OUT" || echo "Local psql execution failed" | tee -a "$OUT"
    else
        echo "psql not available locally. Cannot run SQL. Please run this script on a machine with Docker or with DB/psql configured." | tee -a "$OUT"
    fi
fi

# Final: show the produced results
echo "\n--- Reproduction results (first 200 lines) ---" | tee -a "$OUT"
head -n 200 "$OUT" || true

echo "Script finished. If you ran this on a machine with Docker and enough resources, the SQL queries above should have produced counts for Direct Usage, Uncond Impact, Cond Impact, and Total grouped by RUF status. Compare /workspace/repro.txt with /workspace/expected.md." | tee -a "$OUT"

# copy script as model.patch as requested by the workflow
if [ -d /root ]; then
    cp "$0" /root/model.patch || true
fi

exit 0
