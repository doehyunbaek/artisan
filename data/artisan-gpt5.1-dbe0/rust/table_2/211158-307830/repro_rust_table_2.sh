#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary of RUF usage**

| Type       | RUF Count | Package Versions | RUF Usage Items |
| ---------- | ---------:| ----------------:| ---------------:|
| Accepted   |       ??? |           ??,??? |          ??,??? |
| Active     |       ??? |           ??,??? |         ???,??? |
| Incomplete |         ? |            ?,??? |           ?,??? |
| Removed    |        ?? |           ??,??? |          ??,??? |
| Unknown    |       ??? |           ??,??? |          ??,??? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10496086

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor

# Ensure submodules and Docker image are ready
make submodule
docker build -t cargo-ecosystem-monitor .

# Run Docker container in the recommended detached mode
CID=$(docker run -d --init --entrypoint bash \
  -p 127.0.0.1:12345:5432 \
  -e POSTGRES_PASSWORD="postgres" \
  -w /app \
  --mount type=bind,src="$(pwd)",target=/app \
  cargo-ecosystem-monitor -c 'sleep infinity')

# Initialize PostgreSQL inside the container
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /app && make postgresql"

# Download and import the 2022-08-11 ecosystem raw data (once)
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /app && make download_20220811_rawdata"
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /app && make import_20220811_rawdata"

# Run the official SQL aggregations via psql and export to CSV
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /app && \
  PGPASSWORD=postgres psql -U postgres -d crates -t -A -F',' \
    -c \"COPY ( \
      WITH ruf AS ( \
        SELECT status, COUNT(*) AS ruf_count \
        FROM feature_status \
        WHERE name IN (SELECT DISTINCT feature FROM version_feature_ori) \
        GROUP BY status \
      ), \
      pkg AS ( \
        SELECT status, COUNT(DISTINCT id) AS pkg_vers \
        FROM version_feature_ori \
        INNER JOIN feature_status ON name = feature \
        GROUP BY status \
      ), \
      usage AS ( \
        SELECT status, COUNT(*) AS usage_items \
        FROM version_feature_ori \
        INNER JOIN feature_status ON name = feature \
        GROUP BY status \
      ) \
      SELECT ruf.status, ruf_count, pkg_vers, usage_items \
      FROM ruf \
      JOIN pkg ON pkg.status = ruf.status \
      JOIN usage ON usage.status = ruf.status \
      ORDER BY CASE ruf.status \
        WHEN 'accepted' THEN 1 \
        WHEN 'active' THEN 2 \
        WHEN 'incomplete' THEN 3 \
        WHEN 'removed' THEN 4 \
        WHEN 'unknown' THEN 5 \
        ELSE 6 \
      END \
    ) TO STDOUT WITH CSV HEADER;\" > table2_raw.csv"

# Optionally stop the container to free resources
docker stop "$CID" >/dev/null 2>&1 || true

# Convert the raw CSV into the Markdown table expected for Table 2
awk -F',' '
NR==1 {
  print "**Table 2: Summary of RUF usage**"
  print ""
  print "| Type       | RUF Count | Package Versions | RUF Usage Items |"
  print "| ---------- | ---------:| ----------------:| ---------------:|"
  next
}
function commify(x, s, n) {
  n = x + 0
  if (n < 1000) return n
  while (n >= 1000) {
    s = sprintf(",%03d%s", n % 1000, s)
    n = int(n / 1000)
  }
  return sprintf("%d%s", n, s)
}
{
  status = $1
  rc = $2 + 0
  pc = $3 + 0
  uc = $4 + 0

  if (status == "accepted")      t = "Accepted"
  else if (status == "active")   t = "Active"
  else if (status == "incomplete") t = "Incomplete"
  else if (status == "removed")  t = "Removed"
  else if (status == "unknown")  t = "Unknown"
  else                           t = status

  printf("| %-9s | %9d | %16s | %15s |\n", t, rc, commify(pc), commify(uc))
}
' table2_raw.csv > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
