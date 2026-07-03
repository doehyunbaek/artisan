#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Field Immutability Results for OpenJDK**

| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |
| ---------- | ------: | -----------: | -------: | -------: |
| Ad-hoc CHA |  ?? ??? |       ?? ??? |      ??? |   ?? ??? |
| CHA        |  ?? ??? |       ?? ??? |       ?? |   ?? ??? |
| RTA        |  ?? ??? |        ? ??? |      ??? |   ?? ??? |
| XTA        |  ?? ??? |        ? ??? |      ??? |   ?? ??? |

*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10890011
# Section 3: Reproduction commands (populate from reviewed steps)
# Recreate the directory structure expected by aggregate_opal_immutability.py
mkdir -p /evaluation/results
rm -rf /evaluation/results/immutability
ln -s /workspace/Unimocg_Artifact/evaluation/results/immutability /evaluation/results/immutability
# Regenerate the immutability summary from raw results
python3 /workspace/Unimocg_Artifact/docker/runner/aggregate_opal_immutability.py > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
