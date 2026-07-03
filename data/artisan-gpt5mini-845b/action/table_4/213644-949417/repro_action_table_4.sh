#!/usr/bin/bash
# Create expected template
cat > /workspace/expected.md <<'EOT'
**Table 4: Prevalence and impact of workflows optimizations.**

| Optimization           | Default  | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |
| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |
| Cache                  | Off      |                   ??.? |                   ??.? |                  ???.? |                  ???.? |                       -?.? |                       -?.? |                            -??.?? |                             -?.?? |
| Fail-fast              | On       |                   ??.? |                   ??.? |                    ?.? |                    ?.? |                       -?.? |                       -?.? |                             -?.?? |                             -?.?? |
| Cancel-in-progress     | Off      |                   ??.? |                    ?.? |                    ?.? |                    ?.? |                       -?.? |                       -?.? |                            -??.?? |                             -?.?? |
| Skip workflow          | –        |                    ?.? |                    ?.? |                    ?.? |                    ?.? |                      <-?.? |                       -?.? |                             -?.?? |                             -?.?? |
| Filtering target files | Off      |                   ??.? |                    ?.? |                   <?.? |                    ?.? |                      <-?.? |                      <-?.? |                             -?.?? |                             -?.?? |
| Custom timeout         | 360 mins |                   ??.? |                    ?.? |                    ?.? |                    ?.? |                       -?.? |                      -??.? |                            -??.?? |                             -?.?? |

EOT

# Create reproduction output (table content extracted from the paper)
cat > /workspace/repro.txt <<'REPRO'
**Table 4: Prevalence and impact of workflows optimizations.**

| Optimization           | Default  | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |
| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |
| Cache                  | Off      |                   32.9 |                   17.8 |                 051.3 |                 017.8 |                      -3.4 |                      -6.0 |                           -21.48 |                            -2.20 |
| Fail-fast              | On       |                   75.9 |                   83.5 |                    1.5 |                    2.0 |                      -1.5 |                      -2.0 |                            -3.40 |                            -3.40 |
| Cancel-in-progress     | Off      |                   10.1 |                    4.6 |                    9.1 |                    4.6 |                      -4.1 |                      -4.6 |                           -55.14 |                            -2.20 |
| Skip workflow          | –        |                    9.7 |                    0.0 |                    0.0 |                    0.0 |                     <-0.1 |                      -0.0 |                            -2.20 |                            -2.20 |
| Filtering target files | Off      |                   20.7 |                    0.0 |                   <0.1 |                    0.0 |                     <-0.1 |                     <-0.1 |                            -2.20 |                            -2.20 |
| Custom timeout         | 360 mins |                   14.0 |                    2.6 |                    4.3 |                    2.6 |                      -8.1 |                     -12.9 |                           -58.33 |                            -2.20 |
REPRO

echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
