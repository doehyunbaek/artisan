#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
### Table 3: Comparing COMET and TRIAD with metrics AP and MAP on systems EBT and LibEST

| | EBT AP | EBT MAP | LibEST AP | LibEST MAP |
| :--- | :--- | :--- | :--- | :--- |
| **$COMET_{map}$** | ??.?? | ??.?? | ??.?? | ??.?? |
| **$COMET_{nuts}$** | ??.?? | ??.?? | **??.??** | ??.?? |
| **$TRIAD_{low}$** | ??.?? | **??.??** | ??.?? | ??.?? |
| **$TRIAD_{high}$** | **??.??** | ??.?? | ??.?? | **??.??** |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10430771 
# Section 3: Reproduction commands (populate from reviewed steps)
{
  echo "name,EBT AP,EBT MAP,LibEST AP,LibEST MAP"
  # Extract rows from RQ1.xlsx (suppress warnings)
  uvx --from csvkit in2csv TRIAD_result/result/RQ1.xlsx --sheet RQ1 2>/dev/null | awk -F',' '
    $1=="ebt"    && $2=="COMET-MAP"{ecm_ap=$3; ecm_map=$4}
    $1=="libest" && $2=="COMET-MAP"{lcm_ap=$3; lcm_map=$4}
    $1=="ebt"    && $2=="COMET-NUTS"{ecn_ap=$3; ecn_map=$4}
    $1=="libest" && $2=="COMET-NUTS"{lcn_ap=$3; lcn_map=$4}
    $1=="ebt"    && $2=="TRIAD"{et_vsm_ap=$3; et_vsm_map=$4; et_lsi_ap=$7; et_lsi_map=$8; et_js_ap=$11; et_js_map=$12}
    $1=="libest" && $2=="TRIAD"{lt_vsm_ap=$3; lt_vsm_map=$4; lt_lsi_ap=$7; lt_lsi_map=$8; lt_js_ap=$11; lt_js_map=$12}
    END{
      # COMET rows
      printf "$COMET_{map}$,%.2f,%.2f,%.2f,%.2f\n", ecm_ap+0, ecm_map+0, lcm_ap+0, lcm_map+0;
      printf "$COMET_{nuts}$,%.2f,%.2f,%.2f,%.2f\n", ecn_ap+0, ecn_map+0, lcn_ap+0, lcn_map+0;
      # TRIAD_low: EBT from JS, LibEST from LSI
      printf "$TRIAD_{low}$,%.2f,%.2f,%.2f,%.2f\n", et_js_ap+0, et_js_map+0, lt_lsi_ap+0, lt_lsi_map+0;
      # TRIAD_high: EBT from VSM, LibEST from JS
      printf "$TRIAD_{high}$,%.2f,%.2f,%.2f,%.2f\n", et_vsm_ap+0, et_vsm_map+0, lt_js_ap+0, lt_js_map+0;
    }
  '
} > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
