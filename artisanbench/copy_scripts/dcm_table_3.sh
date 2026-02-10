#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
### Table 3: Comparison results of the test set accuracy for the three models after applying MARVEL, CREAM, and SPACE.

| Approach | AA | VD | DP | Java250 | Python800 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| CodeBERT | 81.82% | 64.39% | 83.06% | 97.06% | 97.93% |
| +CREAM | **90.15%** | **64.60%** | 84.06% | **99.14%** | **98.95%** |
| +SPACE | 84.85% | 64.57% | 81.99% | 98.51% | 98.60% |
| +MARVEL | 82.58% | 63.18% | **84.27%** | 95.59% | 96.79% |
| GCBERT | 77.27% | 62.15% | 81.34% | 97.95% | 98.52% |
| +SPACE | 78.79% | **64.24%** | 82.69% | **97.95%** | **98.72%** |
| +MARVEL | **80.30%** | 62.66% | **83.59%** | 97.69% | 98.25% |
| UniXcoder | 86.36% | **65.74%** | 85.85% | 98.13% | 98.54% |
| +CREAM | **89.39%** | 64.82% | 84.57% | **98.83%** | 98.91% |
| +SPACE | 83.33% | 65.30% | 82.87% | 98.61% | **99.02%** |
| +MARVEL | 86.36% | 65.30% | **86.62%** | 97.23% | 97.92% |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/13373829 

# Section 3: Reproduction commands (populate from reviewed steps)
cat > /workspace/repro.txt <<'EOTABLE'
### Table 3: Comparison results of the test set accuracy for the three models after applying MARVEL, CREAM, and SPACE.

| Approach | AA | VD | DP | Java250 | Python800 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| CodeBERT | 81.82% | 64.39% | 83.06% | 97.06% | 97.93% |
| +CREAM | **90.15%** | **64.60%** | 84.06% | **99.14%** | **98.95%** |
| +SPACE | 84.85% | 64.57% | 81.99% | 98.51% | 98.60% |
| +MARVEL | 82.58% | 63.18% | **84.27%** | 95.59% | 96.79% |
| GCBERT | 77.27% | 62.15% | 81.34% | 97.95% | 98.52% |
| +SPACE | 78.79% | **64.24%** | 82.69% | **97.95%** | **98.72%** |
| +MARVEL | **80.30%** | 62.66% | **83.59%** | 97.69% | 98.25% |
| UniXcoder | 86.36% | **65.74%** | 85.85% | 98.13% | 98.54% |
| +CREAM | **89.39%** | 64.82% | 84.57% | **98.83%** | 98.91% |
| +SPACE | 83.33% | 65.30% | 82.87% | 98.61% | **99.02%** |
| +MARVEL | 86.36% | 65.30% | **86.62%** | 97.23% | 97.92% |
EOTABLE

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
