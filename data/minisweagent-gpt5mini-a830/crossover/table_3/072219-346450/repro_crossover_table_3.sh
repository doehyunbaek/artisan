#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**

| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |
| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |
| BeDiv-Simple |     755.0 |  899.0 |     1435.5 |     1846.5 |      9328.0 |     11863.5 |    590.5 |      738.0 |     3008.5 |     3319.5 |     2952.0 |     3235.5 |     274.5 |     341.0 |
| BeDiv-Struct |     786.5 |  896.5 |     1412.5 |     1876.5 |      9336.5 |     11904.5 |    578.5 |      641.5 |     2993.5 |     3092.0 |     2915.5 |     3237.0 |     161.0 |     242.5 |
| RLCheck      |     769.0 |  889.0 |          — |          — |      8262.5 |      9480.5 |    579.0 |      663.0 |     1298.0 |     1298.0 |     2627.0 |     2730.0 |     299.0 |     338.0 |
| Zest         |     820.0 |  927.0 |     1516.5 |     1909.5 |      9782.5 |     12352.0 |    778.5 |     1098.5 |     2654.5 |     2717.0 |     3108.5 |     3408.0 |     295.0 |     340.0 |
| Zeugma-X     |     835.5 |  911.0 |     1480.5 |     1927.0 |     10274.5 |     12251.0 |    873.0 |     1138.0 |     4259.0 |     7411.0 |     3169.0 |     3551.5 |     297.5 |     345.0 |
| Zeugma-1PT   |     828.0 |  909.5 |     1489.0 |     1917.0 |     10237.5 |     12153.5 |    855.5 |     1138.0 |     4166.0 |     7369.5 |     3169.0 |     3572.5 |     294.0 |     344.0 |
| Zeugma-2PT   |     819.5 |  910.0 |     1472.0 |     1915.0 |     10284.0 |     12038.0 |    797.0 |     1134.0 |     3962.5 |     7310.0 |     3143.0 |     3549.0 |     291.0 |     341.5 |
| Zeugma-Link  | **845.5** |  911.5 | **1541.5** | **1959.0** | **10395.5** | **12709.0** |    906.0 | **1138.0** | **5568.5** | **7654.0** | **3233.5** | **3703.0** | **295.5** | **345.0** |
