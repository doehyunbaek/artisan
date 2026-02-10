**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**

| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |
| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |
| Deactivate scheduled workflows after k consecutive failures (k=3) | 4.5% (<0.1%) of all runs<br>17.2% (1.0%) of scheduled runs |  3.2% (<0.1%) of all runs time<br>21.3% (4.9%) of scheduled runs time |                         -125.72 (-1.55) |
| Deactivate scheduled workflows during repository inactivity       |  4.5% (0.6%) of all runs<br>17.1% (1.4%) of scheduled runs | <0.1% (<0.1%) of all runs time<br>0.1% (0.1%) of scheduled runs time |                          -99.78 (-3.81) |
| Run previously failed jobs first                                  |     1.0% (0.8%) of all runs<br>29.5% (7.7%) of failed runs |    1.1% (<0.1%) of all runs time<br>31.6% (45.3%) of failed runs time |                          -17.89 (-0.77) |
| Project-specific timeouts                                         |                                   0.5% (<0.1%) of all runs |                                          3.5% (2.2%) of all runs time |                        -173.71 (-47.49) |

* measurement for paid tier (measurement for free tier)
