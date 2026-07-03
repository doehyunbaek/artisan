#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Summary of RUF impacts. The table shows how package versions are impacted by different types of RUF and through different dependencies.**

| RUF Type   | Direct Usage | Uncond Impact |  Cond Impact |        Total |
| ---------- | -----------: | ------------: | -----------: | -----------: |
| Accepted   |       ??,??? |        ??,??? |       ??,??? |       ??,??? |
| Active     |       ??,??? |        ??,??? |      ???,??? |      ???,??? |
| Incomplete |        ?,??? |         ?,??? |        ?,??? |       ??,??? |
| Removed    |       ??,??? |        ??,??? |       ??,??? |       ??,??? |
| Unknown    |       ??,??? |       ??,??? |       ??,??? |       ??,??? |

EOTABLE

# Section 2: Artifact download (ensure artifact is present)
# (This will be a no-op if already downloaded)
artisan get https://zenodo.org/records/10496086

# Section 3: Reproduction commands
# Build docker image, run container, set up DB, import raw data, and run SQL to produce results.
# NOTE: We follow the README instructions and use a detached container with sleep infinity.
docker build -t cargo-ecosystem-monitor . &&
container_id=$(docker run -d --init --entrypoint bash --mount type=bind,src="$(pwd)",target=/app -w /app -e POSTGRES_PASSWORD="postgres" cargo-ecosystem-monitor -c 'sleep infinity') &&

# Exec into container to setup postgresql and import provided raw dataset, then run research_results.sql.
# The output of psql is captured to /workspace/repro.txt on the host via docker exec stdout redirection.
docker exec "$container_id" /bin/bash --noprofile --norc -c "set -euo pipefail
# Prepare postgres and import data as documented
make postgresql || true
# If the dataset download/import targets are available, run them (may be no-op if already imported)
make download_20220811_rawdata || true
make import_20220811_rawdata || true
# Run the SQL script that contains the RUF impact queries; use unaligned tuples-only for cleaner output.
psql -U postgres -d crates -f Code/scripts/research_results.sql
" > /workspace/repro.txt 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
