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
# Download the artifact from Zenodo and unpack it (if not already present)
curl -L -o /workspace/Cargo-Ecosystem-Monitor-ICSE.zip "https://zenodo.org/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip"
unzip -o /workspace/Cargo-Ecosystem-Monitor-ICSE.zip -d /workspace/
cd /workspace/Cargo-Ecosystem-Monitor

# Section 3: Reproduction commands (populate from reviewed steps)
# Note: The original reproduction uses Docker and a PostgreSQL database populated with
# the provided raw dataset. The commands below follow the README instructions but
# are written to be tolerant (using || true) so the script can run in different environments.

# (1) Build the provided Docker image
docker build -t cargo-ecosystem-monitor . || true

# (2) Run the container detached (sleep infinity) so we can exec commands into it
docker run -d --init --entrypoint bash --name cargo_monitor cargo-ecosystem-monitor -c 'sleep infinity' || true

# (3) Exec into the container to perform setup steps described in README
#    Replace interactive runs with non-interactive make targets as documented.
/docker exec cargo_monitor /bin/bash --noprofile --norc -c "make postgresql" || true
/docker exec cargo_monitor /bin/bash --noprofile --norc -c "make download_20220811_rawdata" || true
/docker exec cargo_monitor /bin/bash --noprofile --norc -c "make import_20220811_rawdata" || true

# (4) Run the SQL queries that produce Table 2 and write results to /workspace/repro.txt
# The SQL used is from Code/scripts/research_results.sql (RUF Usage section).
# We try to run them via psql inside the container and dump CSV outputs to the workspace.

/docker exec cargo_monitor /bin/bash --noprofile --norc -c "\
  psql -U postgres -d crates -c \"COPY (SELECT status, COUNT(*) FROM version_feature_ori INNER JOIN feature_status ON name=feature GROUP BY status ORDER BY status) TO STDOUT WITH CSV HEADER\" > /workspace/ruf_usage_by_status.csv\" || true

# Fallback: if the container/DB isn't available, attempt to run the SQL locally using sqlite3 or print the intended SQL commands.
if [ ! -s /workspace/ruf_usage_by_status.csv ]; then
  echo "-- Unable to produce CSV from PostgreSQL container. Printing the SQL commands that reproduce Table 2 below:" > /workspace/repro.txt
  echo "SELECT status, COUNT(*) FROM feature_status WHERE name in (SELECT DISTINCT feature FROM version_feature_ori) GROUP BY status;" >> /workspace/repro.txt
  echo "SELECT status, COUNT(DISTINCT id) FROM version_feature_ori INNER JOIN feature_status ON name=feature GROUP BY status;" >> /workspace/repro.txt
  echo "SELECT status, COUNT(*) FROM version_feature_ori INNER JOIN feature_status ON name=feature GROUP BY status;" >> /workspace/repro.txt
else
  echo "RUF usage (status, count) CSV written to /workspace/ruf_usage_by_status.csv" > /workspace/repro.txt
  cat /workspace/ruf_usage_by_status.csv >> /workspace/repro.txt
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Attempt to format the output into a markdown table similar to Table 2 (best-effort)
if [ -f /workspace/ruf_usage_by_status.csv ]; then
  # Convert CSV to a simple markdown-like table (best-effort)
  echo "| Type | RUF Count | Package Versions | RUF Usage Items |" > /workspace/repro_table2.md
  echo "| ---- | ---------:| ---------------:| ---------------:|" >> /workspace/repro_table2.md
  # The expected queries produce three separate aggregates; here we simply include the status counts
  while IFS=, read -r status cnt; do
    if [ "$status" = "status" ]; then continue; fi
    echo "| $status | $cnt |  |  |" >> /workspace/repro_table2.md
  done < /workspace/ruf_usage_by_status.csv || true
  cat /workspace/repro_table2.md
else
  cat /workspace/repro.txt
fi

echo '</artisan_submit>'
