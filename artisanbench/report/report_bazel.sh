docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
#!/usr/bin/bash
curl -L -o artifact.zip "https://zenodo.org/records/10553683/files/build-downgrade.zip?download=1"

echo "Extracting artifact..."
unzip -q artifact.zip

cd /workspace/build-downgrade/
echo "Processing data with uvx/csvkit..."
uvx --from csvkit in2csv --sheet "Labeled data" study/3.thematic-analysis/bazel-abandonment-labels.xlsx \
| uvx --from csvkit csvcut -c "ID","replaced-by" \
| uvx --from csvkit csvformat -T \
| tail -n +2 \
| awk -F "\\t" '
  function ltrim(s){ sub(/^[[:space:]]+/, "", s); return s }
  function rtrim(s){ sub(/[[:space:]]+$/, "", s); return s }
  function trim(s){ return rtrim(ltrim(s)) }
  BEGIN{ IGNORECASE=1 }
  {
    id = trim($1)
    val = trim($2)
    if (val == "") next
    v = tolower(val)

    has_cmake = (v ~ /cmake/)
    has_make_token = (v ~ /(^|[^a-z])make([^a-z]|$)/)
    has_go_build = (v ~ /(^|[^a-z])go[[:space:]]+build([^a-z]|$)/)

    if (has_cmake) c["CMake"]++
    if (has_make_token && !has_cmake) c["Make"]++
    if (has_go_build && !has_cmake && !has_make_token) c["Go Build"]++

    if (v ~ /(^|[^a-z])swift[[:space:]]*pm([^a-z]|$)/) c["SPM"]++
    if (v ~ /(^|[^a-z])mage([^a-z]|$)/) c["Mage"]++
    if (v ~ /(^|[^a-z])sbt([^a-z]|$)/) c["SBT"]++
    if (v ~ /(^|[^a-z])gradle([^a-z]|$)/) c["Gradle"]++
    if (v ~ /(^|[^a-z])setuptools([^a-z]|$)/) c["Setuptools"]++
    if (v ~ /(^|[^a-z])nix([^a-z]|$)/) c["Nix"]++
    if (v ~ /google[[:space:]]+cloud[[:space:]]+build/) c["Google Cloud Build"]++

    seen[id]=1
  }
  END{
    print "Go Build: " (c["Go Build"]+0)
    print "SPM: " (c["SPM"]+0)
    print "Mage: " (c["Mage"]+0)
    print "SBT: " (c["SBT"]+0)
    print "Gradle: " (c["Gradle"]+0)
    print "Setuptools: " (c["Setuptools"]+0)
    print "CMake: " (c["CMake"]+0)
    print "Make: " (c["Make"]+0)
    print "Nix: " (c["Nix"]+0)
    print "Google Cloud Build: " (c["Google Cloud Build"]+0)
    total=0
    for (k in seen) total++
    print "Total Unique IDs: " total+0
  }
  ' > /workspace/repro.txt

# --- Section 3: Output the result ---
echo "Reproduction complete. Contents of repro.txt:"
cat /workspace/repro.txt

EOF