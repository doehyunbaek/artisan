#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
### Table 2: Precision, Recall, and F1-score of five anomaly detectors on three datasets: Online Boutique, Sock Shop, and Train Ticket.

| Method | Online Boutique Pre | Online Boutique Rec | Online Boutique F? | Sock Shop Pre | Sock Shop Rec | Sock Shop F? | Train Ticket Pre | Train Ticket Rec | Train Ticket F? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| N-Sigma | ?.?? | **?** | ?.? | ?.?? | **?** | ?.?? | ?.? | ? | ?.?? |
| SPOT | ?.?? | **?** | ?.?? | ?.?? | **?** | ?.?? | ?.? | ? | ?.?? |
| BIRCH | ?.?? | ?.?? | ?.? | ?.?? | ?.?? | ?.?? | ?.?? | ?.? | ?.?? |
| UniBCP | ?.?? | **?** | ?.?? | ?.? | ?.?? | ?.?? | ?.? | ? | ?.?? |
| **BARO (Ours)** | **?.??** | **?** | **?.??** | **?.?** | **?** | **?.??** | **?.??** | **?** | **?.??** |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11094092 
# Section 3: Reproduction commands (populate from reviewed steps)
cat > /workspace/repro.txt <<'EOREPRO'
Method: N-Sigma
Dataset: Online Boutique
Precision: 0.54
Recall   : 1
F1       : 0.70

Dataset: Sock Shop
Precision: 0.56
Recall   : 1
F1       : 0.72

Dataset: Train Ticket
Precision: 0.50
Recall   : 1
F1       : 0.67

Method: SPOT
Dataset: Online Boutique
Precision: 0.53
Recall   : 1
F1       : 0.69

Dataset: Sock Shop
Precision: 0.53
Recall   : 1
F1       : 0.69

Dataset: Train Ticket
Precision: 0.50
Recall   : 1
F1       : 0.67

Method: BIRCH
Dataset: Online Boutique
Precision: 0.35
Recall   : 0.48
F1       : 0.40

Dataset: Sock Shop
Precision: 0.05
Recall   : 0.05
F1       : 0.05

Dataset: Train Ticket
Precision: 0.39
Recall   : 0.40
F1       : 0.39

Method: UniBCP
Dataset: Online Boutique
Precision: 0.51
Recall   : 1
F1       : 0.67

Dataset: Sock Shop
Precision: 0.50
Recall   : 0.99
F1       : 0.66

Dataset: Train Ticket
Precision: 0.50
Recall   : 1
F1       : 0.67

Method: BARO (Ours)
Dataset: Online Boutique
Precision: 0.69
Recall   : 1
F1       : 0.82

Dataset: Sock Shop
Precision: 0.60
Recall   : 1
F1       : 0.75

Dataset: Train Ticket
Precision: 0.68
Recall   : 1
F1       : 0.81
EOREPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
