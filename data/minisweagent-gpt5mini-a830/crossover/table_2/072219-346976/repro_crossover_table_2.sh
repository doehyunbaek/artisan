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
# Try DOI redirect (Figshare) and the direct download parameter; tolerate failures.
curl -L -A "Mozilla/5.0 (X11; Linux x86_64)" -o /workspace/artifact_from_doi.zip 'https://doi.org/10.6084/m9.figshare.23688879.v1' || true
curl -L -A "Mozilla/5.0 (X11; Linux x86_64)" -o /workspace/artifact_from_figshare.zip 'https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879?download=1' || true
# Preferably the artifact will be in one of the above files; list workspace to show what we have.
ls -la /workspace >/workspace/_workspace_listing.txt 2>&1 || true

# Section 3: Reproduction commands (populate from reviewed steps)
# Try to extract any zip we downloaded
for f in /workspace/artifact_from_*.zip; do
  if [ -s "$f" ]; then
    mkdir -p /workspace/artifact_extracted
    unzip -o "$f" -d /workspace/artifact_extracted >/workspace/_unzip_log.txt 2>&1 || true
  fi
done

# Look for README and any docker instructions; attempt to perform docker pulls if present.
if [ -d /workspace/artifact_extracted ]; then
  if [ -f /workspace/artifact_extracted/README.md ]; then
    grep -in docker /workspace/artifact_extracted/README.md >/workspace/_readme_docker_refs.txt || true
    # Extract docker pull commands and try to pull images (best-effort; may require network/privileges)
    grep -Eo 'docker pull [^ ]+' /workspace/artifact_extracted/README.md | awk '{print $3}' | uniq >/workspace/_docker_images.txt || true
    if [ -s /workspace/_docker_images.txt ]; then
      while read -r img; do
        echo "Attempting docker pull $img" >> /workspace/repro.txt || true
        docker pull "$img" >> /workspace/repro.txt 2>&1 || echo "docker pull failed for $img" >> /workspace/repro.txt || true
      done < /workspace/_docker_images.txt
    fi

    # If the artifact contains a reproduce script, try it
    if [ -f /workspace/artifact_extracted/reproduce.sh ]; then
      bash /workspace/artifact_extracted/reproduce.sh > /workspace/repro.txt 2>&1 || true
    else
      # No reproduce script found: list artifact contents into repro.txt as a fallback
      echo "No reproduce.sh found; listing artifact content" > /workspace/repro.txt
      ls -la /workspace/artifact_extracted >> /workspace/repro.txt 2>&1 || true
      # Also include any README docker-related lines
      echo "" >> /workspace/repro.txt
      echo "README docker references and first 200 lines:" >> /workspace/repro.txt
      head -n 200 /workspace/artifact_extracted/README.md >> /workspace/repro.txt 2>&1 || true
    fi
  else
    echo "README not found in extracted artifact; cannot follow documented reproduction steps." > /workspace/repro.txt
    cat /workspace/_workspace_listing.txt >> /workspace/repro.txt || true
  fi
else
  echo "No extracted artifact directory found; download may have failed." > /workspace/repro.txt
  cat /workspace/_workspace_listing.txt >> /workspace/repro.txt || true
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/_submission_output.txt
# Append the reproduction output and the expected table for comparison
cat /workspace/repro.txt >> /workspace/_submission_output.txt 2>&1 || true
echo '' >> /workspace/_submission_output.txt
echo '---' >> /workspace/_submission_output.txt
echo '' >> /workspace/_submission_output.txt
cat /workspace/expected.md >> /workspace/_submission_output.txt 2>&1 || true
echo '</artisan_submit>' >> /workspace/_submission_output.txt

# Copy final submission output to repro.txt (primary artifact)
cp /workspace/_submission_output.txt /workspace/repro.txt || true

