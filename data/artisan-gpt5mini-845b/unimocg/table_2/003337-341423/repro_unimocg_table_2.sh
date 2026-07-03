#!/usr/bin/bash
set -euo pipefail

# Ensure artifact is downloaded
artisan get https://zenodo.org/records/10890011 || true

# Write expected template
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Soundness of Unimocg’s call-graph algorithms**

| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |
| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |
| Non-virtual Calls    |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Virtual Calls        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Types                |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Static Initializer   |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Java 8 Interfaces    |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Unsafe               |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Class.forName        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Sign. Polymorph.     |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Java 9+              |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Non-Java             |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| MethodHandle         |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Invokedynamic        |        ??/?? |        ??/?? |        ??/?? |        ??/?? |         ??/?? |
| Reflection           |        ??/?? |        ??/?? |        ??/?? |        ??/?? |         ??/?? |
| JVM Calls            |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Serialization        |         ?/?? |         ?/?? |         ?/?? |         ?/?? |          ?/?? |
| Library Analysis     |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Class Loading        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| DynamicProxy         |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| **Sum (out of 123)** | **?? (??%)** | **?? (??%)** | **?? (??%)** | **?? (??%)** | **??? (??%)** |

*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*
EOTABLE

SUMMARY="Unimocg_Artifact/summaries/summary_results_fingerprint.txt"
if [ ! -f "$SUMMARY" ]; then
  echo "ERROR: summary file not found: $SUMMARY" >&2
  exit 1
fi

profiles=( "OPAL-CHA.profile" "OPAL-RTA.profile" "OPAL-XTA.profile" "OPAL-0-CFA.profile" "OPAL-1-1-CFA.profile" )

features=( \
  "Non-virtual Calls" "Virtual Calls" "Types" "Static Initializer" "Java 8 Interfaces" "Unsafe" \
  "Class.forName" "Signature Polymorphic Methods" "Java 9+" "Non-Java" "MethodHandle" \
  "Invokedynamic" "Reflection" "JVM Calls" "Serialization" "Library Analysis" "Class Loading" "DynamicProxy" \
)

# New literal extraction using prefix comparison to avoid regex metachar issues
extract_field() {
  local prof="$1" field="$2"
  awk -v prof="$prof" -v field="$field" '
    BEGIN{RS="\n-------------------------------------------------------------------\n"}
    $0 ~ prof {
      n=split($0,lines,"\n")
      for(i=1;i<=n;i++){
        # build prefix of line up to field length + 1 for the ":" char
        if (length(lines[i]) >= length(field) + 1) {
          prefix = substr(lines[i], 1, length(field) + 1)
          if (prefix == field ":") {
            line = lines[i]
            sub("^.*: ","",line)
            print line
            exit
          }
        }
      }
    }' "$SUMMARY"
}

{
  echo "**Table 2: Soundness of Unimocg’s call-graph algorithms**"
  echo
  printf "%s\n" "| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |"
  printf "%s\n" "| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |"

  for feat in "${features[@]}"; do
    vals=()
    for prof in "${profiles[@]}"; do
      v="$(extract_field "$prof" "$feat" || true)"
      if [ -z "$v" ]; then
        v="?/?"
      fi
      vals+=("$v")
    done
    printf "| %-20s | %9s | %9s | %9s | %9s | %9s |\n" "$feat" "${vals[0]}" "${vals[1]}" "${vals[2]}" "${vals[3]}" "${vals[4]}"
  done

  sum_vals=()
  for prof in "${profiles[@]}"; do
    sum_line="$(extract_field "$prof" "Sum (out of 123)" || true)"
    if [ -z "$sum_line" ]; then
      sum_vals+=("?? (??%)")
      continue
    fi
    cnt="$(echo "$sum_line" | awk '{print $1}')"
    perc="$(echo "$sum_line" | sed -n 's/.*(\([0-9.]\+\)).*/\1/p')"
    if [ -z "$perc" ]; then
      formatted="${cnt} (??%)"
    else
      formatted_perc="$(printf "%.2f" "$perc")"
      formatted="${cnt} (${formatted_perc}%)"
    fi
    sum_vals+=("$formatted")
  done

  printf "| **Sum (out of 123)** | **%s** | **%s** | **%s** | **%s** | **%s** |\n" "${sum_vals[0]}" "${sum_vals[1]}" "${sum_vals[2]}" "${sum_vals[3]}" "${sum_vals[4]}"

  echo
  echo "*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*"
} > /workspace/repro.txt

echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
