**Table 2. Experimental results for analyzing 10 C projects, comparing with Infer-v1.1.0. Columns **#NPD**, **#ML**, **#RL** record the numbers of null pointer dereferences, memory leaks, and resource leaks, respectively. The number of false positives found by Infer and more true positives found by PROVENFIX are represented by +n and +n respectively. Colunns in #Time record the analysis time spent.**

| Project          |        kLoC | #NPD<br>Infer | #NPD<br>ProveNFix | #ML<br>Infer | #ML<br>ProveNFix | #RL<br>Infer | #RL<br>ProveNFix | Time<br>Infer | Time<br>ProveNFix |
| ---------------- | ----------: | ------------: | ----------------: | -----------: | ---------------: | -----------: | ---------------: | ------------- | ----------------- |
| Swoole(a4256e4)  |        44.5 |          30+7 |             30+23 |         16+4 |            12+16 |         13+1 |             13+6 | 2m 50s        | 39.54s            |
| lxc(72cc48f)     |        63.3 |           7+9 |              5+19 |         11+6 |            10+12 |          5+1 |              5+5 | 55.62s        | 1m 28s            |
| WavPack(22977b2) |        36.0 |          23+7 |             20+21 |            3 |              3+9 |          0+2 |                0 | 27.99s        | 23.77s            |
| flex(d3de49f)    |        23.9 |          14+4 |              14+4 |            3 |              3+1 |            0 |              0+1 | 32.25s        | 47.75s            |
| p11-kit          |        76.2 |           3+5 |               2+2 |         13+3 |            12+15 |            5 |              5+1 | 1m 57s        | 1m 4s             |
| x264(d4099dd)    |        67.7 |             0 |                 0 |           12 |             11+5 |            2 |              2+3 | 2m 33s        | 23.168s           |
| recutils-1.8     |        81.9 |            25 |              22+8 |        13+10 |            11+29 |            1 |              1+7 | 9m 10s        | 38.29s            |
| inetutils-1.9.4  |       117.2 |           7+4 |               5+8 |          9+3 |             7+10 |            1 |              1+5 | 30.26s        | 1m 5s             |
| snort-2.9.13     |       378.2 |         44+12 |             33+34 |         26+4 |            15+16 |          1+2 |              1+1 | 8m 49s        | 3m 13s            |
| grub(c6b9a0a)    |       331.1 |         13+12 |               6+5 |            1 |                1 |          0+3 |                0 | 3m 27s        | 1m 1s             |
| **Total**        | **1,220.0** |    **166+60** |       **137+124** |   **107+30** |       **85+113** |     **26+9** |        **27+29** | **31m 12s**   | **10m 44s**       |
