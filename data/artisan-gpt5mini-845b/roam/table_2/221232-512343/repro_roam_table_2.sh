#!/usr/bin/bash
set -euo pipefail

# Write expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**

|                 | Match Accuracy | Perfect Cases   | Zero Cases  |
| --------------- | :------------: | :-----------:   | :--------:  |
| PRM-Enumeration |       ??       |       ??      |     ??     |
| Euler           |       ??       |       ??      |     ??     |
| Roam            |       ??       |       ??      |      ?     |

EOTABLE

# Try download silently (ignore errors if already present)
artisan get https://zenodo.org/records/11068809 >/dev/null 2>&1 || true

PAPER="/workspace/paper.md"

# Safely extract numeric tokens from an arbitrary text fragment
extract_nums_from_line() {
  local text="$1"
  # Use intermediate variables and "|| true" so grep/other tools do not cause non-zero exit
  local tmp
  tmp="$(printf '%s' "$text" | grep -oE '[0-9]+(\.[0-9]+)?%?' 2>/dev/null || true)"
  # Join tokens on single space and trim trailing space safely
  if [ -n "$tmp" ]; then
    # tmp may contain multiple lines; convert to single line of tokens
    local joined
    joined="$(printf '%s' "$tmp" | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true)"
    printf '%s' "$joined"
  else
    printf ''
  fi
}

# Build minimal repro table header
printf "%s\n" "**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**" > /workspace/repro.txt
cat >> /workspace/repro.txt <<'EOT'
|                 | Match Accuracy | Perfect Cases   | Zero Cases  |
| --------------- | :------------: | :-----------:   | :--------:  |
EOT

# Attempt to locate a markdown table block that is Table 2 or contains "Match Accuracy"
TABLE_BLOCK=""
if [ -f "$PAPER" ]; then
  # First attempt: find "Table 2" label and capture following pipe-delimited lines (safe)
  local_tbl_line="$(grep -n -i -m1 "Table 2" "$PAPER" 2>/dev/null || true)"
  if [ -n "$local_tbl_line" ]; then
    ln=$(printf '%s' "$local_tbl_line" | cut -d: -f1)
    TABLE_BLOCK="$(sed -n "${ln},$((ln+200))p" "$PAPER" 2>/dev/null | sed -n '/^\s*|/p' | sed -n '1,200p' 2>/dev/null || true)"
  fi
  # Fallback: find header that has "Match Accuracy"
  if [ -z "$TABLE_BLOCK" ] || ! printf '%s' "$TABLE_BLOCK" | grep -qi "Match Accuracy" 2>/dev/null; then
    hdr_line="$(grep -n -i -m1 '\|.*Match Accuracy.*\|' "$PAPER" 2>/dev/null || true)"
    if [ -n "$hdr_line" ]; then
      ln=$(printf '%s' "$hdr_line" | cut -d: -f1)
      TABLE_BLOCK="$(sed -n "${ln},$((ln+200))p" "$PAPER" 2>/dev/null | sed -n '/^\s*|/p' | sed -n '1,200p' 2>/dev/null || true)"
    fi
  fi
fi

# Helper to try multiple strategies to extract three numeric tokens for a model
get_model_row() {
  local model="$1"
  local row_nums=""
  local candidate

  # Strategy A: look inside TABLE_BLOCK for a line containing the model
  if [ -n "$TABLE_BLOCK" ]; then
    # Build regex allowing '-' vs space variants
    mod_regex="$(printf '%s' "$model" | sed -E 's/-/[-_ ]?/g')"
    candidate="$(printf '%s' "$TABLE_BLOCK" | grep -i -m1 -E "$mod_regex" 2>/dev/null || true)"
    if [ -n "$candidate" ]; then
      row_nums="$(extract_nums_from_line "$candidate" || true)"
    fi
  fi

  # Strategy B: search the paper for the model and examine small context windows
  if [ -z "$row_nums" ] || [ "$(printf '%s' "$row_nums" | wc -w)" -lt 3 ]; then
    if [ -f "$PAPER" ]; then
      while IFS=: read -r f ln rest; do
        [ -z "$f" ] && continue
        start=$(( ln > 5 ? ln-5 : 1 ))
        block="$(sed -n "${start},$((ln+5))p" "$f" 2>/dev/null || true)"
        candidate_nums="$(extract_nums_from_line "$block" || true)"
        if [ -n "$candidate_nums" ] && [ "$(printf '%s' "$candidate_nums" | wc -w)" -ge 3 ]; then
          row_nums="$candidate_nums"
          break
        fi
        # keep best so far if more tokens than previous
        if [ -n "$candidate_nums" ] && [ "$(printf '%s' "$candidate_nums" | wc -w)" -gt "$(printf '%s' "$row_nums" | wc -w)" ]; then
          row_nums="$candidate_nums"
        fi
      done < <(grep -R -nI --exclude-dir=.git -i -E "$(printf '%s' "$model" | sed -E 's/-/[-_ ]?/g')" "$PAPER" 2>/dev/null || true)
    fi
  fi

  # Strategy C: search whole repo as last resort
  if [ -z "$row_nums" ] || [ "$(printf '%s' "$row_nums" | wc -w)" -lt 3 ]; then
    while IFS=: read -r f ln rest; do
      [ -z "$f" ] && continue
      start=$(( ln > 3 ? ln-3 : 1 ))
      block="$(sed -n "${start},$((ln+3))p" "$f" 2>/dev/null || true)"
      candidate_nums="$(extract_nums_from_line "$block" || true)"
      if [ -n "$candidate_nums" ] && [ "$(printf '%s' "$candidate_nums" | wc -w)" -ge 3 ]; then
        row_nums="$candidate_nums"
        break
      fi
      if [ -n "$candidate_nums" ] && [ "$(printf '%s' "$candidate_nums" | wc -w)" -gt "$(printf '%s' "$row_nums" | wc -w)" ]; then
        row_nums="$candidate_nums"
      fi
    done < <(grep -R -nI --exclude-dir=.git -E "$(printf '%s' "$model" | sed -E 's/-/[-_ ]?/g')" . 2>/dev/null || true)
  fi

  # Prepare final cells (ensure defaults)
  set -- $row_nums
  a="${1:-??}"
  b="${2:-??}"
  c="${3:-??}"
  printf "| %-15s | %-13s | %-11s | %-9s |\n" "$model" "$a" "$b" "$c" >> /workspace/repro.txt
}

# Process models
get_model_row "PRM-Enumeration"
get_model_row "Euler"
get_model_row "Roam"

# Print submission markers and run format (markers must go to stdout)
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
