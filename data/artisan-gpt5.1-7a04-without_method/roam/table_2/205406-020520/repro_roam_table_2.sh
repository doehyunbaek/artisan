#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**

|                 | Match Accuracy | Perfect Cases   | Zero Cases  |
| --------------- | :------------: | :-----------:   | :--------:  |
| PRM-Enumeration |       ??       |       ??      |     ??     |
| Euler           |       ??       |       ??      |     ??     |
| Roam            |       ??       |       ??      |      ?     |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809
# Section 3: Reproduction commands
uvx --from pymupdf4llm python -c 'import sys,pymupdf4llm as p; sys.stdout.write(p.to_markdown("ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf"))' > /workspace/eval_results.md
awk -F'|' '
function round(x){ return int(x + 0.5) }
NR>4 && $2!=""{
  r=$8;  p=$20; e=$22;
  if(r!=""){rc++; rs+=r+0; if(r+0==1) rperf++; if(r+0==0) rzero++}
  if(p!=""){pc++; ps+=p+0; if(p+0==1) pperf++; if(p+0==0) pzero++}
  if(e!=""){ec++; es+=e+0; if(e+0==1) eperf++; if(e+0==0) ezero++}
}
END{
  rAvg = rs/rc*100; pAvg = ps/pc*100; eAvg = es/ec*100;
  rPerfPct = rperf/rc*100; rZeroPct = rzero/rc*100;
  pPerfPct = pperf/pc*100; pZeroPct = pzero/pc*100;
  ePerfPct = eperf/ec*100; eZeroPct = ezero/ec*100;

  printf "**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**\n\n";
  printf "|                 | Match Accuracy | Perfect Cases   | Zero Cases  |\n";
  printf "| --------------- | :------------: | :-----------:   | :--------:  |\n";
  printf "| PRM-Enumeration |      %2d       |      %2d       |     %2d     |\n", round(pAvg), round(pPerfPct), round(pZeroPct);
  printf "| Euler           |      %2d       |      %2d       |     %2d     |\n", round(eAvg), round(ePerfPct), round(eZeroPct);
  printf "| Roam            |      %2d       |      %2d       |     %2d     |\n", round(rAvg), round(rPerfPct), round(rZeroPct);
}' /workspace/eval_results.md > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
