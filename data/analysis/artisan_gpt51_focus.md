# Focused efficiency analysis: Artisan / gpt-5.1

Run: `artisan-gpt5.1-dbe0`

All times are minutes per instance; costs are USD per instance. Statuses/times use the same manual-effectiveness and artisan.log time corrections as the main analysis. SD is sample standard deviation.

## Overall and success/failure distribution

| Group | n | Cost mean | Cost median | Cost SD | Cost p90 | Cost max | Time mean | Time median | Time SD | Time p90 | Time p95 | Time max |
| :-- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| ALL | 60 | 0.438 | 0.388 | 0.227 | 0.744 | 1.001 | 48.0 | 27.9 | 69.2 | 94.0 | 138.7 | 487.6 |
| SUCCESS | 44 | 0.354 | 0.354 | 0.162 | 0.569 | 0.739 | 36.7 | 24.5 | 38.6 | 71.4 | 121.1 | 185.1 |
| FAILURE | 16 | 0.668 | 0.729 | 0.224 | 0.934 | 1.001 | 79.2 | 50.4 | 114.7 | 122.7 | 225.1 | 487.6 |

## Outcome-level distribution

| Outcome | n | Cost mean | Cost median | Cost SD | Cost p90 | Cost max | Time mean | Time median | Time SD | Time p90 | Time p95 | Time max | Worst-time instance | Worst-cost instance |
| :-- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | :-- | :-- |
| FULL_REPRO | 24 | 0.339 | 0.322 | 0.175 | 0.569 | 0.690 | 40.2 | 20.4 | 49.7 | 116.0 | 153.9 | 185.1 | provenfix-t2-r1 | pythonic-t9-r1 |
| LASTMILE_REPRO | 20 | 0.372 | 0.372 | 0.148 | 0.511 | 0.739 | 32.5 | 29.0 | 18.3 | 59.6 | 62.7 | 75.4 | rust-t3-r1 | unimocg-t1-r1 |
| COPY_REPRO | 2 | 0.292 | 0.292 | 0.004 | 0.295 | 0.295 | 14.5 | 14.5 | 1.2 | 15.1 | 15.2 | 15.3 | action-t6-r1 | action-t6-r1 |
| MISMATCH_ERROR | 10 | 0.689 | 0.669 | 0.204 | 0.964 | 1.001 | 57.0 | 50.4 | 41.5 | 110.8 | 124.2 | 137.6 | action-t5-r1 | npetest-t2-r1 |
| RUNTIME_ERROR | 4 | 0.801 | 0.783 | 0.076 | 0.874 | 0.908 | 167.0 | 70.2 | 214.3 | 364.8 | 426.2 | 487.6 | rust-t2-r1 | unimocg-t2-r1 |

## Longest-running instances

| Rank | Instance | Outcome | Time | Cost | LLM | Exec | Judge wait | Format | LLM judge |
| --: | :-- | :-- | --: | --: | --: | --: | --: | --: | --: |
| 1 | rust-t2-r1 | RUNTIME_ERROR | 487.6 | 0.772 | 14.2 | 472.2 | 1.2 | 0.4 | 0.0 |
| 2 | provenfix-t2-r1 | FULL_REPRO | 185.1 | 0.440 | 7.2 | 147.7 | 30.2 | 1.1 | 0.6 |
| 3 | ppt4j-t2-r1 | FULL_REPRO | 158.8 | 0.123 | 2.0 | 103.1 | 53.7 | 0.3 | 0.3 |
| 4 | action-t5-r1 | MISMATCH_ERROR | 137.6 | 0.876 | 15.3 | 119.7 | 2.5 | 2.7 | 0.3 |
| 5 | provenfix-t3-r1 | FULL_REPRO | 126.2 | 0.253 | 5.3 | 85.8 | 35.1 | 0.2 | 0.2 |
| 6 | axa-t1-r1 | MISMATCH_ERROR | 107.8 | 0.728 | 18.3 | 63.4 | 26.1 | 3.8 | 0.4 |
| 7 | axa-t3-r1 | FULL_REPRO | 92.4 | 0.555 | 12.9 | 68.6 | 10.9 | 1.1 | 0.6 |
| 8 | sctype-t3-r1 | RUNTIME_ERROR | 78.2 | 0.729 | 12.2 | 66.0 | 0.0 | 0.0 | 0.0 |
| 9 | action-t2-r1 | MISMATCH_ERROR | 77.1 | 0.522 | 10.1 | 57.4 | 9.6 | 1.3 | 0.0 |
| 10 | rust-t3-r1 | LASTMILE_REPRO | 75.4 | 0.580 | 10.2 | 63.1 | 2.1 | 1.2 | 0.5 |

## Most expensive instances

| Rank | Instance | Outcome | Cost | Time |
| --: | :-- | :-- | --: | --: |
| 1 | npetest-t2-r1 | MISMATCH_ERROR | 1.001 | 56.0 |
| 2 | rust-t1-r1 | MISMATCH_ERROR | 0.959 | 66.0 |
| 3 | unimocg-t2-r1 | RUNTIME_ERROR | 0.908 | 62.3 |
| 4 | action-t5-r1 | MISMATCH_ERROR | 0.876 | 137.6 |
| 5 | action-t4-r1 | RUNTIME_ERROR | 0.794 | 40.0 |
| 6 | rust-t2-r1 | RUNTIME_ERROR | 0.772 | 487.6 |
| 7 | interference-t2-r1 | MISMATCH_ERROR | 0.741 | 32.9 |
| 8 | unimocg-t1-r1 | LASTMILE_REPRO | 0.739 | 41.9 |
| 9 | sctype-t3-r1 | RUNTIME_ERROR | 0.729 | 78.2 |
| 10 | axa-t1-r1 | MISMATCH_ERROR | 0.728 | 107.8 |

## Sensitivity to longest-running outliers

| Subset | n | Time mean | Time median | Time SD | Time p90 | Time max | Cost mean | Cost median |
| :-- | --: | --: | --: | --: | --: | --: | --: | --: |
| all 60 | 60 | 48.0 | 27.9 | 69.2 | 94.0 | 487.6 | 0.438 | 0.388 |
| exclude top 1 | 59 | 40.6 | 27.6 | 38.5 | 81.0 | 185.1 | 0.432 | 0.385 |
| exclude top 2 | 58 | 38.1 | 26.2 | 33.7 | 77.4 | 158.8 | 0.432 | 0.383 |
| exclude top 3 | 57 | 36.0 | 24.8 | 29.9 | 76.1 | 137.6 | 0.437 | 0.385 |
| exclude top 5 | 55 | 32.5 | 24.6 | 23.9 | 64.5 | 107.8 | 0.433 | 0.385 |
| exclude top 10 | 50 | 27.1 | 23.7 | 17.0 | 56.3 | 66.0 | 0.414 | 0.376 |

## Outlier contribution

- Slowest instance: `rust-t2-r1` (RUNTIME_ERROR), 487.6 min, 16.9% of aggregate per-instance runtime.

- Most expensive instance: `npetest-t2-r1` (MISMATCH_ERROR), $1.001, 3.8% of total cost.
