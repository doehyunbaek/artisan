# Overall efficiency distributions

Cost values are in USD per instance. Time values are minutes per instance. SD is the sample standard deviation and is shown as `--` for n=1. Rows use corrected times/statuses (manual effectiveness overrides and artisan.log time correction).

| Table | Approach | Model | Ablation | Group | n | Cost mean | Cost median | Cost SD | Cost max | Time mean | Time median | Time SD | Time p90 | Time max | Worst-time instance |
| :-- | :-- | :-- | :-- | :-- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | :-- |
| ablation | Artisan | gpt-5.1 | w/o Format | ALL | 60 | 0.451 | 0.401 | 0.218 | 1.049 | 52.0 | 27.0 | 89.1 | 85.9 | 483.1 | rust-t1-r1 |
| ablation | Artisan | gpt-5.1 | w/o Format | SUCCESS | 35 | 0.369 | 0.363 | 0.169 | 0.765 | 47.8 | 25.0 | 83.8 | 73.1 | 473.4 | urcrat-t1-r1 |
| ablation | Artisan | gpt-5.1 | w/o Format | FAILURE | 25 | 0.565 | 0.633 | 0.231 | 1.049 | 57.8 | 31.8 | 97.5 | 77.8 | 483.1 | rust-t1-r1 |
| ablation | Artisan | gpt-5.1 | w/o Method Judge | ALL | 60 | 0.420 | 0.372 | 0.223 | 1.043 | 32.0 | 24.0 | 31.3 | 68.1 | 185.3 | ppt4j-t2-r1 |
| ablation | Artisan | gpt-5.1 | w/o Method Judge | SUCCESS | 27 | 0.359 | 0.335 | 0.160 | 0.751 | 32.9 | 20.9 | 39.9 | 80.2 | 185.3 | ppt4j-t2-r1 |
| ablation | Artisan | gpt-5.1 | w/o Method Judge | FAILURE | 33 | 0.469 | 0.393 | 0.255 | 1.043 | 31.3 | 24.4 | 22.7 | 47.9 | 108.4 | provenfix-t4-r1 |
| ablation | Artisan | gpt-5.1 | w/o Output Judge | ALL | 60 | 0.273 | 0.238 | 0.108 | 0.615 | 12.3 | 10.0 | 10.0 | 21.5 | 61.3 | ppt4j-t2-r1 |
| ablation | Artisan | gpt-5.1 | w/o Output Judge | SUCCESS | 27 | 0.267 | 0.235 | 0.114 | 0.615 | 13.3 | 11.1 | 11.8 | 23.2 | 61.3 | ppt4j-t2-r1 |
| ablation | Artisan | gpt-5.1 | w/o Output Judge | FAILURE | 33 | 0.279 | 0.242 | 0.105 | 0.526 | 11.6 | 8.7 | 8.4 | 20.0 | 40.1 | action-t6-r1 |
| baseline | Artisan | DeepSeek |  | ALL | 60 | 0.036 | 0.033 | 0.014 | 0.065 | 63.1 | 25.1 | 116.6 | 91.2 | 499.9 | urcrat-t1-r1 |
| baseline | Artisan | DeepSeek |  | SUCCESS | 19 | 0.031 | 0.028 | 0.013 | 0.056 | 48.8 | 20.4 | 110.0 | 49.0 | 499.9 | urcrat-t1-r1 |
| baseline | Artisan | DeepSeek |  | FAILURE | 41 | 0.038 | 0.034 | 0.014 | 0.065 | 69.7 | 27.4 | 120.3 | 96.4 | 482.8 | rust-t5-r1 |
| baseline | Artisan | gpt-5-mini |  | ALL | 60 | 0.110 | 0.104 | 0.069 | 0.293 | 42.9 | 23.2 | 69.6 | 72.2 | 463.9 | urcrat-t1-r1 |
| baseline | Artisan | gpt-5-mini |  | SUCCESS | 24 | 0.063 | 0.051 | 0.041 | 0.166 | 52.8 | 20.5 | 99.8 | 120.1 | 463.9 | urcrat-t1-r1 |
| baseline | Artisan | gpt-5-mini |  | FAILURE | 36 | 0.141 | 0.128 | 0.066 | 0.293 | 36.3 | 24.2 | 39.0 | 53.8 | 172.2 | provenfix-t3-r1 |
| baseline | Artisan | gpt-5.1 |  | ALL | 60 | 0.438 | 0.388 | 0.227 | 1.001 | 48.0 | 27.9 | 69.2 | 94.0 | 487.6 | rust-t2-r1 |
| baseline | Artisan | gpt-5.1 |  | SUCCESS | 44 | 0.354 | 0.354 | 0.162 | 0.739 | 36.7 | 24.5 | 38.6 | 71.4 | 185.1 | provenfix-t2-r1 |
| baseline | Artisan | gpt-5.1 |  | FAILURE | 16 | 0.668 | 0.729 | 0.224 | 1.001 | 79.2 | 50.4 | 114.7 | 122.7 | 487.6 | rust-t2-r1 |
| baseline | OpenHands | DeepSeek |  | ALL | 60 | 0.035 | 0.035 | 0.010 | 0.064 | 12.8 | 9.6 | 9.1 | 20.3 | 62.5 | ppt4j-t2-r1 |
| baseline | OpenHands | DeepSeek |  | SUCCESS | 3 | 0.046 | 0.044 | 0.016 | 0.064 | 9.2 | 9.0 | 1.3 | 10.3 | 10.6 | pythonic-t4-r1 |
| baseline | OpenHands | DeepSeek |  | FAILURE | 57 | 0.034 | 0.034 | 0.009 | 0.054 | 13.0 | 9.6 | 9.3 | 20.6 | 62.5 | ppt4j-t2-r1 |
| baseline | OpenHands | gpt-5-mini |  | ALL | 60 | 0.043 | 0.040 | 0.032 | 0.136 | 23.1 | 8.7 | 25.4 | 62.7 | 62.9 | rust-t3-r1 |
| baseline | OpenHands | gpt-5-mini |  | SUCCESS | 1 | 0.027 | 0.027 | -- | 0.027 | 4.2 | 4.2 | -- | 4.2 | 4.2 | bloat-t2-r1 |
| baseline | OpenHands | gpt-5-mini |  | FAILURE | 59 | 0.043 | 0.040 | 0.032 | 0.136 | 23.4 | 8.9 | 25.5 | 62.7 | 62.9 | rust-t3-r1 |
| baseline | OpenHands | gpt-5.1 |  | ALL | 60 | 0.239 | 0.235 | 0.149 | 0.581 | 21.6 | 14.7 | 18.6 | 62.8 | 63.9 | bloat-t3-r1 |
| baseline | OpenHands | gpt-5.1 |  | SUCCESS | 12 | 0.304 | 0.310 | 0.132 | 0.509 | 23.7 | 19.2 | 19.7 | 60.1 | 63.9 | bloat-t3-r1 |
| baseline | OpenHands | gpt-5.1 |  | FAILURE | 48 | 0.223 | 0.230 | 0.149 | 0.581 | 21.1 | 13.9 | 18.5 | 53.2 | 63.7 | mutation-t2-r1 |
| baseline | SWE-agent | DeepSeek |  | ALL | 60 | 0.030 | 0.026 | 0.017 | 0.088 | 8.9 | 8.6 | 4.2 | 14.9 | 22.1 | axa-t2-r1 |
| baseline | SWE-agent | DeepSeek |  | SUCCESS | 1 | 0.040 | 0.040 | -- | 0.040 | 6.5 | 6.5 | -- | 6.5 | 6.5 | bloat-t1-r1 |
| baseline | SWE-agent | DeepSeek |  | FAILURE | 59 | 0.029 | 0.026 | 0.017 | 0.088 | 8.9 | 8.7 | 4.2 | 14.9 | 22.1 | axa-t2-r1 |
| baseline | SWE-agent | gpt-5-mini |  | ALL | 60 | 0.047 | 0.035 | 0.051 | 0.236 | 3.1 | 2.2 | 3.4 | 7.5 | 13.7 | action-t1-r1 |
| baseline | SWE-agent | gpt-5-mini |  | SUCCESS | 0 | -- | -- | -- | -- | -- | -- | -- | -- | -- |  |
| baseline | SWE-agent | gpt-5-mini |  | FAILURE | 60 | 0.047 | 0.035 | 0.051 | 0.236 | 3.1 | 2.2 | 3.4 | 7.5 | 13.7 | action-t1-r1 |
| baseline | SWE-agent | gpt-5.1 |  | ALL | 60 | 0.316 | 0.258 | 0.224 | 1.085 | 6.5 | 4.3 | 5.0 | 13.8 | 19.5 | action-t4-r1 |
| baseline | SWE-agent | gpt-5.1 |  | SUCCESS | 3 | 0.321 | 0.237 | 0.255 | 0.608 | 9.2 | 7.6 | 7.8 | 15.6 | 17.6 | roam-t5-r1 |
| baseline | SWE-agent | gpt-5.1 |  | FAILURE | 57 | 0.316 | 0.268 | 0.224 | 1.085 | 6.4 | 4.2 | 4.9 | 13.2 | 19.5 | action-t4-r1 |
| baseline | mini-swe-agent | DeepSeek |  | ALL | 60 | 0.027 | 0.023 | 0.014 | 0.069 | 50.4 | 15.1 | 117.3 | 46.6 | 482.0 | rust-t1-r1 |
| baseline | mini-swe-agent | DeepSeek |  | SUCCESS | 5 | 0.034 | 0.024 | 0.019 | 0.066 | 14.3 | 11.7 | 8.2 | 22.0 | 28.7 | roam-t2-r1 |
| baseline | mini-swe-agent | DeepSeek |  | FAILURE | 55 | 0.026 | 0.023 | 0.014 | 0.069 | 53.7 | 15.3 | 122.0 | 50.1 | 482.0 | rust-t1-r1 |
| baseline | mini-swe-agent | gpt-5-mini |  | ALL | 60 | 0.062 | 0.057 | 0.030 | 0.165 | 33.1 | 8.7 | 91.1 | 36.6 | 486.0 | urcrat-t1-r1 |
| baseline | mini-swe-agent | gpt-5-mini |  | SUCCESS | 0 | -- | -- | -- | -- | -- | -- | -- | -- | -- |  |
| baseline | mini-swe-agent | gpt-5-mini |  | FAILURE | 60 | 0.062 | 0.057 | 0.030 | 0.165 | 33.1 | 8.7 | 91.1 | 36.6 | 486.0 | urcrat-t1-r1 |
| baseline | mini-swe-agent | gpt-5.1 |  | ALL | 60 | 0.258 | 0.240 | 0.101 | 0.494 | 13.8 | 10.8 | 11.4 | 25.6 | 53.0 | provenfix-t2-r1 |
| baseline | mini-swe-agent | gpt-5.1 |  | SUCCESS | 14 | 0.287 | 0.263 | 0.115 | 0.494 | 10.7 | 9.2 | 8.2 | 21.2 | 31.5 | roam-t5-r1 |
| baseline | mini-swe-agent | gpt-5.1 |  | FAILURE | 46 | 0.249 | 0.234 | 0.096 | 0.464 | 14.7 | 12.5 | 12.1 | 30.5 | 53.0 | provenfix-t2-r1 |
