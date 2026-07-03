# Outcome-level efficiency distributions

Cost values are in USD per instance. Time values are minutes per instance. SD is the sample standard deviation and is shown as `--` for n=1. Rows use corrected times/statuses (manual effectiveness overrides and artisan.log time correction).

| Table | Approach | Model | Ablation | Outcome | n | Cost mean | Cost median | Cost SD | Cost max | Time mean | Time median | Time SD | Time p90 | Time max | Worst-time instance |
| :-- | :-- | :-- | :-- | :-- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | :-- |
| ablation | Artisan | gpt-5.1 | w/o Format | FULL_REPRO | 17 | 0.380 | 0.321 | 0.220 | 0.765 | 69.1 | 26.2 | 117.3 | 158.4 | 473.4 | urcrat-t1-r1 |
| ablation | Artisan | gpt-5.1 | w/o Format | LASTMILE_REPRO | 18 | 0.360 | 0.371 | 0.107 | 0.608 | 27.7 | 22.9 | 14.7 | 46.3 | 52.5 | neurojit-t3-r1 |
| ablation | Artisan | gpt-5.1 | w/o Format | COPY_REPRO | 9 | 0.436 | 0.353 | 0.222 | 0.765 | 31.8 | 31.2 | 19.4 | 52.9 | 65.8 | axa-t1-r1 |
| ablation | Artisan | gpt-5.1 | w/o Format | MISMATCH_ERROR | 13 | 0.683 | 0.648 | 0.188 | 1.049 | 46.1 | 31.7 | 54.4 | 76.6 | 216.9 | provenfix-t2-r1 |
| ablation | Artisan | gpt-5.1 | w/o Format | RUNTIME_ERROR | 2 | 0.543 | 0.543 | 0.141 | 0.643 | 263.5 | 263.5 | 310.6 | 439.2 | 483.1 | rust-t1-r1 |
| ablation | Artisan | gpt-5.1 | w/o Format | STATIC_ERROR | 1 | 0.231 | 0.231 | -- | 0.231 | 32.5 | 32.5 | -- | 32.5 | 32.5 | action-t6-r1 |
| ablation | Artisan | gpt-5.1 | w/o Method Judge | FULL_REPRO | 9 | 0.314 | 0.342 | 0.135 | 0.515 | 39.8 | 11.8 | 58.9 | 98.6 | 185.3 | ppt4j-t2-r1 |
| ablation | Artisan | gpt-5.1 | w/o Method Judge | LASTMILE_REPRO | 18 | 0.381 | 0.333 | 0.171 | 0.751 | 29.5 | 23.5 | 27.6 | 63.4 | 108.3 | action-t1-r1 |
| ablation | Artisan | gpt-5.1 | w/o Method Judge | COPY_REPRO | 21 | 0.379 | 0.301 | 0.204 | 0.836 | 32.6 | 23.6 | 26.9 | 67.1 | 108.4 | provenfix-t4-r1 |
| ablation | Artisan | gpt-5.1 | w/o Method Judge | MISMATCH_ERROR | 8 | 0.626 | 0.573 | 0.235 | 1.043 | 23.2 | 21.2 | 12.5 | 37.8 | 48.4 | axa-t3-r1 |
| ablation | Artisan | gpt-5.1 | w/o Method Judge | RUNTIME_ERROR | 3 | 0.732 | 0.876 | 0.364 | 1.002 | 39.8 | 38.6 | 3.3 | 42.6 | 43.5 | roam-t2-r1 |
| ablation | Artisan | gpt-5.1 | w/o Method Judge | STATIC_ERROR | 1 | 0.321 | 0.321 | -- | 0.321 | 42.8 | 42.8 | -- | 42.8 | 42.8 | action-t6-r1 |
| ablation | Artisan | gpt-5.1 | w/o Output Judge | FULL_REPRO | 13 | 0.226 | 0.216 | 0.083 | 0.403 | 13.6 | 9.9 | 15.6 | 21.2 | 61.3 | ppt4j-t2-r1 |
| ablation | Artisan | gpt-5.1 | w/o Output Judge | LASTMILE_REPRO | 14 | 0.305 | 0.321 | 0.128 | 0.615 | 13.0 | 11.1 | 7.4 | 23.8 | 30.3 | rust-t5-r1 |
| ablation | Artisan | gpt-5.1 | w/o Output Judge | COPY_REPRO | 1 | 0.265 | 0.265 | -- | 0.265 | 10.2 | 10.2 | -- | 10.2 | 10.2 | action-t2-r1 |
| ablation | Artisan | gpt-5.1 | w/o Output Judge | MISMATCH_ERROR | 19 | 0.281 | 0.252 | 0.111 | 0.494 | 11.2 | 8.6 | 7.9 | 19.6 | 36.4 | provenfix-t3-r1 |
| ablation | Artisan | gpt-5.1 | w/o Output Judge | RUNTIME_ERROR | 13 | 0.276 | 0.231 | 0.104 | 0.526 | 12.2 | 10.8 | 9.6 | 19.8 | 40.1 | action-t6-r1 |
| baseline | Artisan | DeepSeek |  | FULL_REPRO | 11 | 0.031 | 0.030 | 0.012 | 0.051 | 62.2 | 20.1 | 145.4 | 37.0 | 499.9 | urcrat-t1-r1 |
| baseline | Artisan | DeepSeek |  | LASTMILE_REPRO | 8 | 0.031 | 0.027 | 0.014 | 0.056 | 30.4 | 31.8 | 15.4 | 49.0 | 49.3 | roam-t5-r1 |
| baseline | Artisan | DeepSeek |  | COPY_REPRO | 4 | 0.040 | 0.034 | 0.015 | 0.062 | 47.2 | 27.0 | 42.5 | 85.8 | 110.9 | neurojit-t3-r1 |
| baseline | Artisan | DeepSeek |  | MISMATCH_ERROR | 15 | 0.041 | 0.042 | 0.015 | 0.064 | 44.7 | 36.1 | 29.6 | 89.1 | 96.4 | sctype-t3-r1 |
| baseline | Artisan | DeepSeek |  | RUNTIME_ERROR | 5 | 0.045 | 0.047 | 0.017 | 0.065 | 44.8 | 49.7 | 17.2 | 56.7 | 58.5 | roam-t4-r1 |
| baseline | Artisan | DeepSeek |  | STATIC_ERROR | 17 | 0.033 | 0.030 | 0.013 | 0.059 | 104.5 | 19.0 | 181.1 | 482.6 | 482.8 | rust-t5-r1 |
| baseline | Artisan | gpt-5-mini |  | FULL_REPRO | 15 | 0.069 | 0.060 | 0.046 | 0.166 | 73.7 | 24.2 | 122.6 | 186.0 | 463.9 | urcrat-t1-r1 |
| baseline | Artisan | gpt-5-mini |  | LASTMILE_REPRO | 9 | 0.055 | 0.046 | 0.032 | 0.125 | 18.1 | 14.9 | 12.8 | 37.1 | 41.4 | roam-t5-r1 |
| baseline | Artisan | gpt-5-mini |  | COPY_REPRO | 6 | 0.075 | 0.082 | 0.043 | 0.128 | 21.3 | 19.0 | 15.3 | 36.8 | 49.6 | roam-t3-r1 |
| baseline | Artisan | gpt-5-mini |  | MISMATCH_ERROR | 24 | 0.146 | 0.134 | 0.060 | 0.288 | 42.0 | 24.6 | 46.1 | 116.1 | 172.2 | provenfix-t3-r1 |
| baseline | Artisan | gpt-5-mini |  | RUNTIME_ERROR | 6 | 0.183 | 0.164 | 0.068 | 0.293 | 28.7 | 23.7 | 11.3 | 42.1 | 48.4 | dypybench-t3-r1 |
| baseline | Artisan | gpt-5.1 |  | FULL_REPRO | 24 | 0.339 | 0.322 | 0.175 | 0.690 | 40.2 | 20.4 | 49.7 | 116.0 | 185.1 | provenfix-t2-r1 |
| baseline | Artisan | gpt-5.1 |  | LASTMILE_REPRO | 20 | 0.372 | 0.372 | 0.148 | 0.739 | 32.5 | 29.0 | 18.3 | 59.6 | 75.4 | rust-t3-r1 |
| baseline | Artisan | gpt-5.1 |  | COPY_REPRO | 2 | 0.292 | 0.292 | 0.004 | 0.295 | 14.5 | 14.5 | 1.2 | 15.1 | 15.3 | action-t6-r1 |
| baseline | Artisan | gpt-5.1 |  | MISMATCH_ERROR | 10 | 0.689 | 0.669 | 0.204 | 1.001 | 57.0 | 50.4 | 41.5 | 110.8 | 137.6 | action-t5-r1 |
| baseline | Artisan | gpt-5.1 |  | RUNTIME_ERROR | 4 | 0.801 | 0.783 | 0.076 | 0.908 | 167.0 | 70.2 | 214.3 | 364.8 | 487.6 | rust-t2-r1 |
| baseline | OpenHands | DeepSeek |  | FULL_REPRO | 3 | 0.046 | 0.044 | 0.016 | 0.064 | 9.2 | 9.0 | 1.3 | 10.3 | 10.6 | pythonic-t4-r1 |
| baseline | OpenHands | DeepSeek |  | MISMATCH_ERROR | 6 | 0.037 | 0.034 | 0.010 | 0.054 | 12.7 | 10.1 | 7.5 | 19.9 | 27.8 | axa-t3-r1 |
| baseline | OpenHands | DeepSeek |  | RUNTIME_ERROR | 6 | 0.044 | 0.044 | 0.007 | 0.053 | 9.9 | 9.6 | 1.4 | 11.3 | 12.5 | lasapp-t2-r1 |
| baseline | OpenHands | DeepSeek |  | STATIC_ERROR | 45 | 0.033 | 0.032 | 0.008 | 0.051 | 13.4 | 9.7 | 10.0 | 20.7 | 62.5 | ppt4j-t2-r1 |
| baseline | OpenHands | gpt-5-mini |  | LASTMILE_REPRO | 1 | 0.027 | 0.027 | -- | 0.027 | 4.2 | 4.2 | -- | 4.2 | 4.2 | bloat-t2-r1 |
| baseline | OpenHands | gpt-5-mini |  | COPY_REPRO | 1 | 0.056 | 0.056 | -- | 0.056 | 20.8 | 20.8 | -- | 20.8 | 20.8 | sctype-t3-r1 |
| baseline | OpenHands | gpt-5-mini |  | MISMATCH_ERROR | 25 | 0.051 | 0.052 | 0.031 | 0.136 | 15.3 | 4.8 | 21.3 | 62.5 | 62.8 | pythonic-t9-r1 |
| baseline | OpenHands | gpt-5-mini |  | RUNTIME_ERROR | 15 | 0.038 | 0.040 | 0.022 | 0.068 | 26.2 | 12.1 | 26.9 | 62.7 | 62.7 | action-t5-r1 |
| baseline | OpenHands | gpt-5-mini |  | STATIC_ERROR | 18 | 0.035 | 0.015 | 0.040 | 0.119 | 32.5 | 13.5 | 28.0 | 62.8 | 62.9 | rust-t3-r1 |
| baseline | OpenHands | gpt-5.1 |  | FULL_REPRO | 5 | 0.350 | 0.368 | 0.103 | 0.477 | 21.4 | 9.5 | 24.1 | 45.6 | 63.8 | ppt4j-t2-r1 |
| baseline | OpenHands | gpt-5.1 |  | LASTMILE_REPRO | 7 | 0.272 | 0.302 | 0.148 | 0.509 | 25.2 | 20.6 | 17.8 | 41.6 | 63.9 | bloat-t3-r1 |
| baseline | OpenHands | gpt-5.1 |  | COPY_REPRO | 4 | 0.179 | 0.123 | 0.168 | 0.420 | 15.3 | 17.2 | 6.2 | 19.9 | 20.2 | unimocg-t1-r1 |
| baseline | OpenHands | gpt-5.1 |  | MISMATCH_ERROR | 12 | 0.303 | 0.311 | 0.120 | 0.473 | 17.5 | 10.1 | 18.1 | 43.1 | 63.7 | mutation-t2-r1 |
| baseline | OpenHands | gpt-5.1 |  | RUNTIME_ERROR | 5 | 0.235 | 0.271 | 0.123 | 0.338 | 24.3 | 12.2 | 22.6 | 48.5 | 62.7 | pythonic-t4-r1 |
| baseline | OpenHands | gpt-5.1 |  | STATIC_ERROR | 27 | 0.192 | 0.197 | 0.156 | 0.581 | 23.0 | 15.8 | 19.4 | 54.9 | 63.6 | rust-t3-r1 |
| baseline | SWE-agent | DeepSeek |  | LASTMILE_REPRO | 1 | 0.040 | 0.040 | -- | 0.040 | 6.5 | 6.5 | -- | 6.5 | 6.5 | bloat-t1-r1 |
| baseline | SWE-agent | DeepSeek |  | MISMATCH_ERROR | 6 | 0.043 | 0.034 | 0.025 | 0.088 | 12.5 | 15.0 | 5.0 | 16.3 | 16.5 | pythonic-t4-r1 |
| baseline | SWE-agent | DeepSeek |  | RUNTIME_ERROR | 7 | 0.027 | 0.024 | 0.012 | 0.051 | 8.5 | 6.2 | 4.5 | 14.4 | 15.8 | pythonic-t7-r1 |
| baseline | SWE-agent | DeepSeek |  | STATIC_ERROR | 46 | 0.028 | 0.026 | 0.016 | 0.072 | 8.5 | 8.6 | 4.0 | 13.1 | 22.1 | axa-t2-r1 |
| baseline | SWE-agent | gpt-5-mini |  | COPY_REPRO | 9 | 0.036 | 0.033 | 0.027 | 0.092 | 2.1 | 2.2 | 0.7 | 2.8 | 3.1 | interference-t2-r1 |
| baseline | SWE-agent | gpt-5-mini |  | MISMATCH_ERROR | 10 | 0.056 | 0.056 | 0.025 | 0.097 | 4.9 | 2.8 | 4.2 | 12.0 | 13.0 | ppt4j-t2-r1 |
| baseline | SWE-agent | gpt-5-mini |  | RUNTIME_ERROR | 10 | 0.082 | 0.075 | 0.045 | 0.170 | 4.8 | 3.6 | 3.7 | 10.7 | 12.4 | action-t5-r1 |
| baseline | SWE-agent | gpt-5-mini |  | STATIC_ERROR | 31 | 0.036 | 0.001 | 0.059 | 0.236 | 2.3 | 0.7 | 3.1 | 7.0 | 13.7 | action-t1-r1 |
| baseline | SWE-agent | gpt-5.1 |  | LASTMILE_REPRO | 3 | 0.321 | 0.237 | 0.255 | 0.608 | 9.2 | 7.6 | 7.8 | 15.6 | 17.6 | roam-t5-r1 |
| baseline | SWE-agent | gpt-5.1 |  | COPY_REPRO | 4 | 0.205 | 0.185 | 0.142 | 0.368 | 4.5 | 2.3 | 4.8 | 9.0 | 11.7 | axa-t3-r1 |
| baseline | SWE-agent | gpt-5.1 |  | MISMATCH_ERROR | 15 | 0.320 | 0.226 | 0.220 | 0.813 | 3.3 | 2.4 | 2.4 | 6.6 | 9.6 | roam-t4-r1 |
| baseline | SWE-agent | gpt-5.1 |  | RUNTIME_ERROR | 8 | 0.348 | 0.236 | 0.328 | 1.085 | 2.8 | 2.3 | 2.0 | 4.4 | 7.4 | pmsat-t6-r1 |
| baseline | SWE-agent | gpt-5.1 |  | STATIC_ERROR | 30 | 0.321 | 0.282 | 0.209 | 0.759 | 9.1 | 8.8 | 4.9 | 16.3 | 19.5 | action-t4-r1 |
| baseline | mini-swe-agent | DeepSeek |  | FULL_REPRO | 3 | 0.022 | 0.023 | 0.001 | 0.024 | 10.8 | 11.7 | 1.7 | 11.8 | 11.9 | pythonic-t9-r1 |
| baseline | mini-swe-agent | DeepSeek |  | LASTMILE_REPRO | 2 | 0.050 | 0.050 | 0.022 | 0.066 | 19.4 | 19.4 | 13.2 | 26.9 | 28.7 | roam-t2-r1 |
| baseline | mini-swe-agent | DeepSeek |  | COPY_REPRO | 5 | 0.030 | 0.016 | 0.024 | 0.063 | 24.5 | 25.5 | 13.6 | 37.6 | 44.6 | ppt4j-t2-r1 |
| baseline | mini-swe-agent | DeepSeek |  | MISMATCH_ERROR | 16 | 0.028 | 0.025 | 0.012 | 0.063 | 18.9 | 15.8 | 10.9 | 31.6 | 43.0 | axa-t2-r1 |
| baseline | mini-swe-agent | DeepSeek |  | RUNTIME_ERROR | 3 | 0.043 | 0.031 | 0.022 | 0.069 | 48.3 | 18.3 | 54.6 | 92.8 | 111.4 | provenfix-t2-r1 |
| baseline | mini-swe-agent | DeepSeek |  | STATIC_ERROR | 31 | 0.023 | 0.021 | 0.011 | 0.062 | 76.9 | 13.4 | 158.7 | 480.9 | 482.0 | rust-t1-r1 |
| baseline | mini-swe-agent | gpt-5-mini |  | COPY_REPRO | 4 | 0.072 | 0.070 | 0.029 | 0.104 | 130.6 | 17.1 | 233.7 | 344.2 | 481.0 | dypybench-t3-r1 |
| baseline | mini-swe-agent | gpt-5-mini |  | MISMATCH_ERROR | 39 | 0.059 | 0.049 | 0.031 | 0.165 | 21.0 | 9.5 | 42.0 | 31.6 | 258.8 | pmsat-t5-r1 |
| baseline | mini-swe-agent | gpt-5-mini |  | RUNTIME_ERROR | 13 | 0.069 | 0.070 | 0.031 | 0.127 | 11.2 | 7.4 | 9.4 | 18.7 | 37.1 | action-t5-r1 |
| baseline | mini-swe-agent | gpt-5-mini |  | STATIC_ERROR | 4 | 0.061 | 0.073 | 0.026 | 0.077 | 125.2 | 6.3 | 240.5 | 342.4 | 486.0 | urcrat-t1-r1 |
| baseline | mini-swe-agent | gpt-5.1 |  | FULL_REPRO | 9 | 0.293 | 0.330 | 0.112 | 0.457 | 7.4 | 8.4 | 3.4 | 10.9 | 11.1 | pmsat-t4-r1 |
| baseline | mini-swe-agent | gpt-5.1 |  | LASTMILE_REPRO | 5 | 0.276 | 0.251 | 0.133 | 0.494 | 16.5 | 17.6 | 11.4 | 28.0 | 31.5 | roam-t5-r1 |
| baseline | mini-swe-agent | gpt-5.1 |  | COPY_REPRO | 12 | 0.255 | 0.251 | 0.114 | 0.413 | 17.9 | 12.6 | 17.6 | 45.6 | 53.0 | provenfix-t2-r1 |
| baseline | mini-swe-agent | gpt-5.1 |  | MISMATCH_ERROR | 22 | 0.243 | 0.203 | 0.086 | 0.405 | 11.1 | 7.4 | 8.4 | 19.6 | 37.0 | action-t5-r1 |
| baseline | mini-swe-agent | gpt-5.1 |  | RUNTIME_ERROR | 9 | 0.247 | 0.236 | 0.114 | 0.464 | 18.0 | 17.4 | 11.7 | 28.5 | 42.7 | ppt4j-t2-r1 |
| baseline | mini-swe-agent | gpt-5.1 |  | STATIC_ERROR | 3 | 0.275 | 0.247 | 0.072 | 0.356 | 18.7 | 19.1 | 2.2 | 20.4 | 20.7 | provenfix-t3-r1 |
