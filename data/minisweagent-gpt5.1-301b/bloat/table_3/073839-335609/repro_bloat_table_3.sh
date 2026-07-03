#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**

| PR status | # of PRs | # of BD removed |
| --------- | -------: | --------------: |
| Merged    |       30 |              35 |
| Approved  |        1 |               1 |
| Rejected  |        1 |               1 |
| Pending   |        4 |               5 |
| **Total** |   **36** |          **42** |

EOTABLE

# Section 2: Artifact download
cd /workspace
# Download artifact ZIP from Zenodo (id: 11095274)
curl -L -o bloat-study-artifact-v1.0.zip "https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip?download=1"
# Unzip artifact (quietly overwrite if already present)
unzip -o -q bloat-study-artifact-v1.0.zip

# Section 3: Reproduction commands (populate from reviewed steps)
# Build the Docker image from the provided Dockerfile
cd /workspace/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact .

# Ensure any old container with the same name is removed
if docker ps -a --format '{{.Names}}' | grep -q '^bloat-study-artifact-container$'; then
  docker rm -f bloat-study-artifact-container
fi

# Run the container in detached mode with the prescribed volume mounts
docker run -d --init --entrypoint bash \
  --name bloat-study-artifact-container \
  -v "$(pwd)/scripts:/home/user/scripts" \
  -v "$(pwd)/data:/home/user/data" \
  -v "$(pwd)/figures:/home/user/figures" \
  bloat-study-artifact -c 'sleep infinity'

# Execute the RQ4 script inside the container to reproduce Table 3
docker exec bloat-study-artifact-container /bin/bash --noprofile --norc -c \
  "cd /home/user && python scripts/rq4.py data/results/qualitative_results.json --table3" \
  > /workspace/repro.txt

# Optional: stop and remove the container after use
docker rm -f bloat-study-artifact-container >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - <<'PY'
import pathlib

repro_path = pathlib.Path("/workspace/repro.txt")
text = repro_path.read_text(encoding="utf-8").splitlines()

rows = []
for line in text:
    line = line.rstrip()
    if not line.startswith("|"):
        continue
    if "PR Status" in line or "Number of PRs" in line or "Number of  BD removed" in line:
        continue
    if set(line.replace("|", "").strip()) in ({"+", "-","="}, {"+","-"}, {"="}):
        continue
    parts = [p.strip() for p in line.strip().strip("|").split("|")]
    if len(parts) != 3:
        continue
    status, n_prs, n_bd = parts
    if status in ("Merged", "Approved", "Pending", "Rejected", "Total"):
        rows.append((status, n_prs, n_bd))

status_order = ["Merged", "Approved", "Rejected", "Pending", "Total"]
rows_dict = {s: (s, n1, n2) for (s, n1, n2) in rows}

print("**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**\n")
print("| PR status | # of PRs | # of BD removed |")
print("| --------- | -------: | --------------: |")

for status in status_order:
    if status not in rows_dict:
        continue
    s, n_prs, n_bd = rows_dict[status]
    if status == "Total":
        print(f"| **{s}** |   **{n_prs}** |          **{n_bd}** |")
    else:
        print(f"| {s:<9} | {int(n_prs):7d} | {int(n_bd):14d} |")
PY
echo '</artisan_submit>'
