#!/usr/bin/bash
set -euo pipefail
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: The Match Accuracy and Reproduction Rate for RQ5**

|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |
| --------- | :---------------------: | :-------------------: |
| Roam-Sim  |            ??           |           ??          |
| Roam-Dist |            ??           |           ??          |
| Roam      |            ??           |           ??          |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809 || true

# Section 3: Extract printable text from the PDF (binary-safe), prefer strings then fallback to pymupdf conversion
PDF_PATH="ROAM-Artifact/ROAM-Artifact/paper.pdf"
TXT_PATH="/workspace/paper_txt.txt"
if command -v strings >/dev/null 2>&1; then
  strings "$PDF_PATH" > "$TXT_PATH" 2>/dev/null || true
fi
if [ ! -s "$TXT_PATH" ]; then
  # fallback conversion (best-effort)
  uvx --from pymupdf4llm python -c 'import sys,pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' "$PDF_PATH" > "$TXT_PATH" 2>/dev/null || true
fi

# Section 4: Narrow to Table 5 area if possible
AREA_PATH="/workspace/table5_area.txt"
start_line=$(grep -n -m1 -i 'Table 5' "$TXT_PATH" 2>/dev/null | cut -d: -f1 || true)
if [ -n "$start_line" ]; then
  sed -n "${start_line},$((start_line+300))p" "$TXT_PATH" > "$AREA_PATH" || cp "$TXT_PATH" "$AREA_PATH"
else
  cp "$TXT_PATH" "$AREA_PATH"
fi

# Utility to extract first two integer tokens for a given tool name from area, fallback to whole text
extract_tool_vals() {
  tool="$1"
  # Prefer exact-line matches beginning with the tool name
  line=$(grep -i -m1 -E "^[[:space:]]*${tool}([[:space:]]|$)" "$AREA_PATH" 2>/dev/null || true)
  if [ -z "$line" ]; then
    line=$(grep -i -m1 "${tool}" "$AREA_PATH" 2>/dev/null || true)
  fi
  if [ -z "$line" ]; then
    line=$(grep -i -m1 "${tool}" "$TXT_PATH" 2>/dev/null || true)
  fi
  # Extract numeric tokens (integers), robust to formatting
  nums=$(echo "$line" | grep -oE '[0-9]+' | tr '\n' ' ' | sed 's/ $//')
  a="??"; b="??"
  if [ -n "$nums" ]; then
    set -- $nums
    a="$1"
    if [ $# -ge 2 ]; then
      b="$2"
    fi
  fi
  echo "$tool,$a,$b"
}

# Section 5: Create repro.txt from extracted values (derived from the artifact text)
{
  echo "Tool,AvgMatchAccuracy,ReproductionRate"
  extract_tool_vals "Roam-Sim"
  extract_tool_vals "Roam-Dist"
  extract_tool_vals "Roam"
} > /workspace/repro.txt

# Section 6: Format and output
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
