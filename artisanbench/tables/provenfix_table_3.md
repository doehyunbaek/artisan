**Table 3. Experimental results for repairing 10 C projects, comparing with SAVER and FootPatch. Columns marked as # are numbers of the total true positives found by Infer-v1.1.0 and PROVENFIX, summarised from Table 2. The numbers of false positives reported by Infer-v0.9.3 are marked as +n.**

| Project              |   NPD # | NPD ProveNFix |    ML # |  ML ProveNFix |   RL # |  RL ProveNFix |      Time | Infer-v0.9.3 #ML |          SAVER | Infer-v0.9.3 #RL |   FootPatch |
| -------------------- | ------: | ------------: | ------: | ------------: | -----: | ------------: | --------: | ---------------: | -------------: | ---------------: | ----------: |
| Swoole               |      53 |            53 |      32 |            28 |     19 |            19 |     4.33s |             15+3 |             11 |              6+1 |           6 |
| lxc                  |      26 |            24 |      23 |            22 |     10 |            10 |    3.882s |              3+5 |              3 |              2+1 |           0 |
| WavPack              |      44 |            41 |      12 |            12 |      0 |             0 |   11.435s |              1+2 |              0 |                2 |           1 |
| flex                 |      18 |            18 |       4 |             4 |      1 |             1 |    39.38s |              3+4 |              0 |                0 |           0 |
| p11-kit              |       5 |             4 |      28 |            27 |      6 |             6 |    2.452s |             33+9 |             24 |                2 |           1 |
| x264                 |       0 |             0 |      17 |            14 |      5 |             5 |    6.375s |               10 |             10 |                0 |           0 |
| recutils-1.8         |      33 |            30 |      42 |            36 |      8 |             8 |    1.261s |            10+11 |              8 |                1 |           0 |
| inetutils-1.9.4      |      15 |            13 |      19 |            17 |      6 |             6 |    1.517s |              4+5 |              4 |              2+1 |           1 |
| snort-2.9.13         |      78 |            67 |      42 |            13 |      2 |             2 |    10.57s |            16+27 |             10 |                0 |           0 |
| grub                 |      18 |            11 |       1 |             1 |      0 |             0 |   40.626s |                0 |              0 |                0 |           0 |
| **Total (Fix Rate)** | **290** | **261 (90%)** | **220** | **174 (79%)** | **57** | **57 (100%)** | **2m 2s** |        **95+66** | **70 (73.7%)** |         **15+3** | **9 (60%)** |
