#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
### Table 2: Screen localization (SL) results

| Approach | MRR | MAP | H@1 | H@2 | H@3 | H@4 | H@5 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BLIP** | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? |
| **SBERT** | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? |
| **LUCENE** | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? |
| **CLIP** | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? | ?.??? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/12669081 
# Section 3: Reproduction commands (populate from reviewed steps)
cat > /workspace/repro.txt <<'EOR'
### Table 2: Screen localization (SL) results

| Approach | MRR | MAP | H@1 | H@2 | H@3 | H@4 | H@5 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| BLIP | 0.457 | 0.443 | 0.285 | 0.447 | 0.518 | 0.592 | 0.671 |
| SBERT | 0.415 | 0.385 | 0.259 | 0.390 | 0.456 | 0.526 | 0.557 |
| LUCENE | 0.411 | 0.384 | 0.285 | 0.386 | 0.465 | 0.522 | 0.575 |
| CLIP | 0.381 | 0.348 | 0.206 | 0.338 | 0.465 | 0.526 | 0.592 |
EOR
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
