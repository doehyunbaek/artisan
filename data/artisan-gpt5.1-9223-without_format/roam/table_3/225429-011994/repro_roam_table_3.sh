#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**

|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |
| -------- | :---------: | :-----------------------: | :----------------------: |
| ReCDroid |      29     |             27            |            30            |
| Yakusu   |       8     |             15            |             4            |
| Roam     |      94     |             96            |            93            |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809

# Section 3: Reproduction commands (populate from reviewed steps)
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > ROAM-Artifact/ROAM-Artifact/Evaluation/results.md

awk -F'|' '
$2 ~ /^[0-9]+$/ {
  ms = $7 + 0

  # Roam (always present)
  roam_tot_all++
  if (ms == 0) roam_tot_nomiss++; else roam_tot_miss++
  rr_roam = $9
  gsub(/^[ \t]+|[ \t]+$/, "", rr_roam)
  rr_roam = tolower(rr_roam)
  if (rr_roam == "success") {
    roam_succ_all++
    if (ms == 0) roam_succ_nomiss++; else roam_succ_miss++
  }

  # ReCDroid (only if cell non-empty)
  rr_recd = $24
  gsub(/^[ \t]+|[ \t]+$/, "", rr_recd)
  rr_recd = tolower(rr_recd)
  if (rr_recd != "") {
    recd_tot_all++
    if (ms == 0) recd_tot_nomiss++; else recd_tot_miss++
    if (rr_recd == "success") {
      recd_succ_all++
      if (ms == 0) recd_succ_nomiss++; else recd_succ_miss++
    }
  }

  # Yakusu (only if cell non-empty)
  rr_yaku = $56
  gsub(/^[ \t]+|[ \t]+$/, "", rr_yaku)
  rr_yaku = tolower(rr_yaku)
  if (rr_yaku != "") {
    yaku_tot_all++
    if (ms == 0) yaku_tot_nomiss++; else yaku_tot_miss++
    if (rr_yaku == "success") {
      yaku_succ_all++
      if (ms == 0) yaku_succ_nomiss++; else yaku_succ_miss++
    }
  }
}
END {
  roam_all_p     = 100 * roam_succ_all    / roam_tot_all
  roam_nomiss_p  = 100 * roam_succ_nomiss / roam_tot_nomiss
  roam_miss_p    = 100 * roam_succ_miss   / roam_tot_miss

  recd_all_p     = 100 * recd_succ_all    / recd_tot_all
  recd_nomiss_p  = 100 * recd_succ_nomiss / recd_tot_nomiss
  recd_miss_p    = 100 * recd_succ_miss   / recd_tot_miss

  yaku_all_p     = 100 * yaku_succ_all    / yaku_tot_all
  yaku_nomiss_p  = 100 * yaku_succ_nomiss / yaku_tot_nomiss
  yaku_miss_p    = 100 * yaku_succ_miss   / yaku_tot_miss

  printf "**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**\n\n"
  printf "|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |\n"
  printf "| -------- | :---------: | :-----------------------: | :----------------------: |\n"
  printf "| ReCDroid |      %.0f     |             %.0f            |            %.0f            |\n", recd_all_p, recd_nomiss_p, recd_miss_p
  printf "| Yakusu   |       %.0f     |             %.0f            |             %.0f            |\n", yaku_all_p, yaku_nomiss_p, yaku_miss_p
  printf "| Roam     |      %.0f     |             %.0f            |            %.0f            |\n", roam_all_p, roam_nomiss_p, roam_miss_p
}' ROAM-Artifact/ROAM-Artifact/Evaluation/results.md > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
