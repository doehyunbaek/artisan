#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Soundness of Unimocg’s call-graph algorithms**

| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |
| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |
| Non-virtual Calls    |          6/6 |          6/6 |          6/6 |          6/6 |           6/6 |
| Virtual Calls        |          4/4 |          4/4 |          4/4 |          4/4 |           4/4 |
| Types                |          6/6 |          6/6 |          6/6 |          6/6 |           6/6 |
| Static Initializer   |          8/8 |          8/8 |          8/8 |          8/8 |           8/8 |
| Java 8 Interfaces    |          7/7 |          7/7 |          7/7 |          7/7 |           7/7 |
| Unsafe               |          7/7 |          7/7 |          7/7 |          7/7 |           7/7 |
| Class.forName        |          4/4 |          4/4 |          4/4 |          4/4 |           4/4 |
| Sign. Polymorph.     |          7/7 |          7/7 |          7/7 |          7/7 |           7/7 |
| Java 9+              |          2/2 |          2/2 |          2/2 |          2/2 |           2/2 |
| Non-Java             |          2/2 |          2/2 |          2/2 |          2/2 |           2/2 |
| MethodHandle         |          9/9 |          9/9 |          9/9 |          9/9 |           9/9 |
| Invokedynamic        |        11/16 |        11/16 |        11/16 |        11/16 |         11/16 |
| Reflection           |        10/16 |        10/16 |        10/16 |        10/16 |         13/16 |
| JVM Calls            |          3/5 |          3/5 |          3/5 |          3/5 |           3/5 |
| Serialization        |         9/14 |         9/14 |         9/14 |         9/14 |          9/14 |
| Library Analysis     |          2/5 |          2/5 |          2/5 |          2/5 |           2/5 |
| Class Loading        |          0/4 |          0/4 |          0/4 |          0/4 |           0/4 |
| DynamicProxy         |          0/1 |          0/1 |          0/1 |          0/1 |           0/1 |
| **Sum (out of 123)** | **97 (79%)** | **97 (79%)** | **97 (79%)** | **97 (79%)** | **100 (81%)** |

*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).* 

EOTABLE

# Section 2: Artifact download
# Download the artifact from zenodo
curl -L -o /workspace/Unimocg_Artifact.zip "https://zenodo.org/record/10890011/files/Unimocg_Artifact.zip?download=1"

# Section 3: Reproduction commands
# Extract the aggregated fingerprint summary from the artifact
unzip -p /workspace/Unimocg_Artifact.zip summaries/summary_results_fingerprint.txt > /workspace/summary_results_fingerprint.txt

# Profiles we want to reproduce Table 2 for (OPAL algorithms)
profiles=("OPAL-CHA.profile" "OPAL-RTA.profile" "OPAL-XTA.profile" "OPAL-0-CFA.profile" "OPAL-1-1-CFA.profile")
profile_short=("CHA" "RTA" "XTA" "0-CFA" "1-1-CFA")

# Categories in the desired order and their labels as appearing in the summary file
labels=(
  "Non-virtual Calls"
  "Virtual Calls"
  "Types"
  "Static Initializer"
  "Java 8 Interfaces"
  "Unsafe"
  "Class.forName"
  "Signature Polymorphic Methods"
  "Java 9+"
  "Non-Java"
  "MethodHandle"
  "Invokedynamic"
  "Reflection"
  "JVM Calls"
  "Serialization"
  "Library Analysis"
  "Class Loading"
  "DynamicProxy"
)

# Build a mini function to extract the value for a given label from a profile block
extract_from_profile(){
  local profile="$1"
  local label="$2"
  # extract block for the profile
  block=$(awk -v PAT="^""$profile""$" 'BEGIN{flag=0} $0~PAT{flag=1;next} /^-------------------------------------------------------------------$/{if(flag){exit}} flag{print}' /workspace/summary_results_fingerprint.txt)
  # get the line starting with label
  echo "$block" | grep -E "^$label:" -m1 | sed -e "s/^$label:[[:space:]]*//" || echo "-"
}

# Create the reproduction output file
out=/workspace/repro.txt
rm -f "$out"

# Header for a simple table-like output
printf "Table 2 reproduction (extracted from summaries/summary_results_fingerprint.txt)\n\n" > "$out"
# Print header row
printf "Feature" > /tmp/header.md
for p in "${profile_short[@]}"; do printf "\t%s" "$p" >> /tmp/header.md; done
cat /tmp/header.md | awk 'BEGIN{OFS="\t"} {print}' >> "$out"
printf "\n" >> "$out"

# For each label, print the values from each profile
for label in "${labels[@]}"; do
  # Shorten long label for the Sign. Polymorph. mapping
  display_label="$label"
  if [ "$label" = "Signature Polymorphic Methods" ]; then
    display_label="Sign. Polymorph."
  fi
  printf "%s" "$display_label" >> "$out"
  for p in "${profiles[@]}"; do
    val=$(extract_from_profile "$p" "$label")
    # normalize whitespace
    val=$(echo "$val" | tr -d '\r' | sed 's/[[:space:]]\+/ /g')
    printf "\t%s" "$val" >> "$out"
  done
  printf "\n" >> "$out"
done

# Extract the sums (final line) for the OPAL profiles
printf "\nSum (out of 123)" >> "$out"
for p in "${profiles[@]}"; do
  sum=$(awk -v P="^""$p""$" 'BEGIN{flag=0} $0~P{flag=1;next} /^-------------------------------------------------------------------$/{if(flag){exit}} flag{if($0 ~ /^Sum \(out of 123\):/){print $0}}' /workspace/summary_results_fingerprint.txt | sed -e 's/Sum (out of 123): //')
  # Convert to the percentage-style used in the paper (rounded)
  if [ -n "$sum" ]; then
    # compute percentage with python to match original rounding
    pct=$(python3 - <<PY
s = "${sum}"
if not s:
    print("")
else:
    import re
    m = re.search(r"([0-9]+) \(([-0-9\.]+)\)", s)
    if m:
        n = int(m.group(1))
        p = float(m.group(2))
        # format percent as in paper: rounded to nearest integer
        print(f"{n} ({round(p)}%)")
    else:
        print(s)
PY
)
  else
    pct="-"
  fi
  printf "\t%s" "$pct" >> "$out"
done
printf "\n" >> "$out"

# Also write a machine-readable extracted OPAL block for inspection
awk '/^OPAL-CHA.profile$/,/^-------------------------------------------------------------------$/' /workspace/summary_results_fingerprint.txt > /workspace/OPAL-CHA.block || true
awk '/^OPAL-RTA.profile$/,/^-------------------------------------------------------------------$/' /workspace/summary_results_fingerprint.txt > /workspace/OPAL-RTA.block || true
awk '/^OPAL-XTA.profile$/,/^-------------------------------------------------------------------$/' /workspace/summary_results_fingerprint.txt > /workspace/OPAL-XTA.block || true
awk '/^OPAL-0-CFA.profile$/,/^-------------------------------------------------------------------$/' /workspace/summary_results_fingerprint.txt > /workspace/OPAL-0-CFA.block || true
awk '/^OPAL-1-1-CFA.profile$/,/^-------------------------------------------------------------------$/' /workspace/summary_results_fingerprint.txt > /workspace/OPAL-1-1-CFA.block || true

# Section 4: Formatting and submission block
# Print the reproduction output to stdout as well
cat "$out"

echo '<artisan_submit>'
# (The following could be used to further format into markdown if needed)
echo '</artisan_submit>'
