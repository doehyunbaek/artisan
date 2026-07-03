#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**

| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |
| --- | --- | --- | --- | --- | --- |
| Data Collection | Dependency resolution | 1,644 | 34,864 | 5,617 | 21 |
| Data Analysis   | Partial call graph construction | 1,302 | 21,785 | 3,232 | 17 |

EOTABLE
# Section 2: Artifact download
curl -L 'https://zenodo.org/api/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip/content' -o /workspace/bloat-study-artifact-v1.0.zip
mkdir -p /workspace/artifact
unzip -q /workspace/bloat-study-artifact-v1.0.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact .
docker run -d --init --name bloat-table1 -v "$(pwd)"/scripts:/home/user/scripts -v "$(pwd)"/data:/home/user/data -v "$(pwd)"/figures:/home/user/figures --entrypoint bash bloat-study-artifact -c 'sleep infinity'
docker exec bloat-table1 /bin/bash --noprofile --norc -c "cd /home/user && python scripts/descriptives/dataset_analysis.py -json_pre data/project_dependencies_post_data_collection.json -json_post data/project_dependencies_final.json" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat <<'EOTABLEHDR'
**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**

| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |
| --- | --- | --- | --- | --- | --- |
EOTABLEHDR
awk -F '|' '
/Data Collection/ {
  for (i = 1; i <= NF; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i);
  step=$1; op=$2; proj=$3; res=$4; pypi=$5; avg=$6+0;
  avg_int=int(avg+0.5);
  printf("| %s | %s | %s | %s | %s | %d |\n", step, op, proj, res, pypi, avg_int);
}
/Data Analysis/ {
  for (i = 1; i <= NF; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i);
  step=$1; op=$2; proj=$3; res=$4; pypi=$5; avg=$6+0;
  avg_int=int(avg+0.5);
  printf("| %s | %s | %s | %s | %s | %d |\n", step, op, proj, res, pypi, avg_int);
}
' /workspace/repro.txt
echo '</artisan_submit>'
