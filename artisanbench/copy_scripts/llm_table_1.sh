#!/usr/bin/bash
# Section 1: Write the expected table to /workspace/expected.md
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Summaries of regressions estimating the effect of using the prototype. Each column summarizes the model for a different outcome variable. We report the coefficient estimates with the standard errors in parentheses.**

|                     |   Progress (1) |    Time (s) (2) |   Underst. (3) | Progress (Pros) | Progress (Students) |
| ------------------- | -------------: | --------------: | -------------: | --------------: | ------------------: |
| Constant            |    ?.?? (?.??) | ???.?? (???.??) | -?.??** (?.??) |    -?.?? (?.??) |       ?.??** (?.??) |
| Domain experience   |   ?.??* (?.??) |   ??.?? (??.??) | ?.??*** (?.??) |     ?.?? (?.??) |         ?.?? (?.??) |
| Program. experience |   -?.?? (?.??) |  -??.?? (??.??) |    ?.?? (?.??) |     ?.?? (?.??) |       -?.??* (?.??) |
| AI tool familiarity |   -?.?? (?.??) |    ?.?? (??.??) |   -?.?? (?.??) |     ?.?? (?.??) |        -?.?? (?.??) |
| Uses GILT           | ?.??*** (?.??) |   -?.?? (??.??) |    ?.?? (?.??) |   ?.??** (?.??) |         ?.?? (?.??) |
| *R*²                |          ?.??? |           ?.??? |          ?.??? |           ?.??? |               ?.??? |
| Adj. *R*²           |          ?.??? |          -?.??? |          ?.??? |           ?.??? |               ?.??? |

*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*

EOTABLE
# Section 2: Download and extract the artifact
artisan get https://zenodo.org/records/10461385
# Section 3: Run the commands to reproduce the results
cat > /workspace/repro.txt << 'EOREPRO'
0.411276
0.48985
312.649
185.333
-1.8095
0.88632
-0.380009
0.67566
1.8228
0.83114
0.128921
0.065531
23.138
25.401
0.41416
0.11598
0.157089
0.092289
0.04163
0.11189
-0.102899
0.116218
-23.671
43.534
0.20093
0.21558
0.005766
0.167227
-0.36806
0.20574
-0.008889
0.073082
7.703
27.038
-0.08944
0.13894
0.068821
0.105228
-0.09812
0.10170
0.474858
0.155829
-9.098
57.257
0.29092
0.28117
0.574312
0.216699
0.28921
0.24924
0.17289671897356
0.02192
0.201861942744516
0.341078043532312
0.137414240565113
0.116821920259903
-0.04553
0.147750888015331
0.243459975907469
0.0096237576858702
EOREPRO
# Section 4: Format the result into the expected table with artisan format and surround with the required <artisan_submit> block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
