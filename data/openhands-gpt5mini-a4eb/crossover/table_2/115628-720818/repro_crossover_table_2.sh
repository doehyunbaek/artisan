#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**

| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |
| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |
| Ant     |     0.561 |     0.923 |        0.459 |        0.124 |        0.493 |        0.069 |
| BCEL    |     0.283 |     0.512 |        0.660 |        0.347 |        0.756 |        0.286 |
| Closure |     0.742 |     0.717 |        0.661 |        0.101 |        0.712 |        0.094 |
| Maven   |     0.446 |     0.589 |        0.404 |        0.497 |        0.399 |        0.453 |
| Nashorn |     0.622 |     0.646 |        0.548 |        0.117 |        0.591 |        0.132 |
| Rhino   |     0.611 |     0.502 |        0.599 |        0.263 |        0.643 |        0.255 |
| Tomcat  |     0.322 |     0.775 |        0.350 |        0.276 |        0.328 |        0.279 |

EOTABLE

# Section 2: Artifact download
# Note: This section attempts to use the Figshare API to download artifact files
# for article id 23688879. If the environment has no network access this will fail.
mkdir -p /workspace/artifact_files
echo "Fetching Figshare file list for article 23688879..." >/workspace/repro.log

# Try using jq if available, otherwise use python to parse JSON
if command -v jq >/dev/null 2>&1; then
  curl -s "https://api.figshare.com/v2/articles/23688879/files" | jq -r '.[].download_url' | while read -r url; do
    fname=$(basename "$url")
    echo "Downloading $url -> /workspace/artifact_files/$fname" >>/workspace/repro.log
    curl -L -o "/workspace/artifact_files/$fname" "$url" || { echo "Failed to download $url" >>/workspace/repro.log; exit 1; }
  done
else
  python3 - <<'PY'
import json,sys,subprocess,urllib.request
url='https://api.figshare.com/v2/articles/23688879/files'
try:
    data=json.load(urllib.request.urlopen(url))
except Exception as e:
    print('ERROR: could not fetch file list from Figshare API:',e,file=sys.stderr)
    sys.exit(2)
for f in data:
    durl=f.get('download_url')
    if not durl:
        continue
    fname=durl.split('/')[-1]
    out='/workspace/artifact_files/'+fname
    print('Downloading',durl,'->',out)
    try:
        urllib.request.urlretrieve(durl,out)
    except Exception as e:
        print('ERROR downloading',durl,e,file=sys.stderr)
        sys.exit(3)
PY
fi

# Unpack any archives we got
for f in /workspace/artifact_files/*; do
  [ -e "$f" ] || continue
  case "$f" in
    *.zip) unzip -o "$f" -d /workspace/artifact_files/unpacked || true ;;
    *.tar.gz|*.tgz) mkdir -p /workspace/artifact_files/unpacked && tar -xzf "$f" -C /workspace/artifact_files/unpacked || true ;;
    *.tar) mkdir -p /workspace/artifact_files/unpacked && tar -xf "$f" -C /workspace/artifact_files/unpacked || true ;;
  esac
done

# Section 3: Reproduction commands (populate from reviewed steps)
# We will search the unpacked artifact for README files and for any scripts
# that reference Table 2 or reproduction steps.

ARTDIR=/workspace/artifact_files/unpacked
if [ -d "$ARTDIR" ]; then
  echo "Searching artifact for README and reproduction scripts..." >>/workspace/repro.log
  find "$ARTDIR" -maxdepth 3 -type f -iname "README*" -print > /workspace/readme_paths.txt || true
  find "$ARTDIR" -type f \( -iname "*repro*" -o -iname "*table*" -o -iname "run*" -o -iname "*script*" \) -print > /workspace/candidate_scripts.txt || true
fi

# Grep for docker instructions inside README files
if [ -s /workspace/readme_paths.txt ]; then
  while read -r r; do
    echo "---- $r ----" >>/workspace/repro.log
    grep -in "docker" "$r" >>/workspace/repro.log || true
    grep -in "Table 2" "$r" >>/workspace/repro.log || true
  done < /workspace/readme_paths.txt
else
  echo "No README files found in artifact (or artifact not downloaded)." >>/workspace/repro.log
fi

# Attempt to follow Docker instructions if present. The following commands are
# conservative: they will pull images mentioned, load tar images, import archives,
# and build Dockerfiles present in the artifact. The README should be inspected
# manually to confirm the correct image names and run commands.

# Docker operations (no-op if docker not available)
if command -v docker >/dev/null 2>&1; then
  echo "Docker is installed; attempting to process Docker artifacts..." >>/workspace/repro.log
  # Pull images listed in README (naively parse 'docker pull' occurrences)
  if [ -s /workspace/readme_paths.txt ]; then
    awk '/docker pull/ {print $3}' $(cat /workspace/readme_paths.txt) 2>/dev/null | sort -u | while read -r img; do
      [ -z "$img" ] && continue
      echo "docker pull $img" >>/workspace/repro.log
      docker pull "$img" || echo "pull failed: $img" >>/workspace/repro.log || true
    done
  fi
  # Load any docker image tar files found
  find /workspace/artifact_files -type f \( -iname "*.tar" -o -iname "*.tar.gz" -o -iname "*.tgz" \) -print | while read -r tarf; do
    echo "Attempting docker load from $tarf" >>/workspace/repro.log
    docker load -i "$tarf" || true
  done
  # Build Dockerfiles if present
  find /workspace/artifact_files -maxdepth 3 -type f -name Dockerfile -print | while read -r df; do
    ddir=$(dirname "$df")
    imagename="artifact_build_$(basename "$ddir")"
    echo "docker build -t $imagename $ddir" >>/workspace/repro.log
    docker build -t "$imagename" "$ddir" || true
  done
else
  echo "Docker not available in this environment; skipping Docker steps." >>/workspace/repro.log
fi

# Look for a script that explicitly computes Table 2. If none found, attempt to
# run a generic reproduce script if provided.
if [ -s /workspace/candidate_scripts.txt ]; then
  while read -r s; do
    echo "Found candidate script: $s" >>/workspace/repro.log
    case "$s" in
      *.sh)
        chmod +x "$s" || true
        echo "Running $s" >>/workspace/repro.log
        # Run the script and capture output
        ("$s") > /workspace/repro_output_$(basename "$s").txt 2>&1 || true
        ;;
      *.py)
        echo "Running python $s" >>/workspace/repro.log
        python3 "$s" > /workspace/repro_output_$(basename "$s").txt 2>&1 || true
        ;;
      *)
        echo "Skipping unknown candidate script type: $s" >>/workspace/repro.log
        ;;
    esac
  done < /workspace/candidate_scripts.txt
else
  echo "No candidate reproduction scripts found in artifact." >>/workspace/repro.log
fi

# Section 4: Formatting and submission block
# The expected output for this task is /workspace/repro.txt containing the
# reproduced Table 2. If reproduction could not be performed, we include notes.
if [ -s /workspace/repro_output_table2.txt ]; then
  cp /workspace/repro_output_table2.txt /workspace/repro.txt
else
  echo "REPRODUCTION_NOT_RUN_OR_FAILED" > /workspace/repro.txt
  echo "See /workspace/repro.log for details and any downloaded artifact files." >> /workspace/repro.txt
fi

# Print out a simple marker for the grader
echo '<artisan_submit>'
cat /workspace/repro.txt || true
echo '</artisan_submit>'

echo "Script completed. See /workspace/repro.txt and /workspace/repro.log" >&2
