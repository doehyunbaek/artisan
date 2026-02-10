**Table 2: The reproduction rate results for 25 trials on benchmark projects gathered from the prior studies [3, 21–24]. The projects where all three tools failed to detect NPEs are excluded from this table. Project: The name of the buggy project with its abbreviated NPE-labeling ID (if necessary). The number in a parenthesis represents each unique NPE in the same project.**

### NPEX

| Project       | Randoop | EvoSuite | NPETest |
| ------------- | ------: | -------: | ------: |
| Activiti-c45  |       0 |        0 |      24 |
| Aries_JPA     |       0 |      100 |      80 |
| Avro          |     100 |      100 |     100 |
| Commons_Conf  |     100 |      100 |     100 |
| Commons_DBCP  |     100 |       16 |     100 |
| Commons_Pool  |       0 |       92 |     100 |
| CXF-2094      |     100 |       56 |      84 |
| Directory     |       0 |       80 |     100 |
| Easy_Rules    |       0 |       64 |     100 |
| Fastjson-650a |       0 |        8 |      64 |
| Feign-9c5a    |       0 |        0 |      28 |
| FOP-10e0d1c2  |     100 |       40 |     100 |
| Hessian_Lite  |       0 |      100 |      96 |
| Hivemall-04fa |       0 |       68 |     100 |
| Http-f633(1)  |       0 |        0 |      88 |
| Http-f633(2)  |       0 |        0 |      76 |
| Http-f633(3)  |       0 |       72 |      84 |
| Http-f633(4)  |       0 |       72 |      84 |
| IoTDB-9bce    |       0 |       40 |      40 |
| Jest-f34f     |       0 |        8 |       0 |
| jsoup-8b83    |     100 |       40 |     100 |
| jsoup-b841    |       0 |      100 |     100 |
| JSqlParser    |       0 |       68 |      96 |
| Karaf-b92d    |       0 |        0 |      28 |
| Log4j_2-5b7b  |       0 |        0 |      16 |
| Log4j_2-6a23  |     100 |      100 |     100 |
| Log4j_2-7441  |     100 |      100 |     100 |
| Ninja-16aa    |     100 |       64 |     100 |
| Nutz-87a4     |       0 |       76 |     100 |
| OpenNLP-6079  |       0 |      100 |     100 |
| OpenPDF-a89d  |       0 |      100 |     100 |
| PDFBox-5558   |     100 |      100 |     100 |
| Qpid-0299 (1) |       0 |        0 |      16 |
| Qpid-0299 (2) |       0 |        0 |      88 |
| Sharding-82b1 |       0 |        0 |       4 |
| Sharding-9833 |       0 |       40 |     100 |
| Sharding-c08f |       0 |        8 |       8 |
| ZooKeeper     |       0 |       16 |      32 |

### BugSwarm

| Project           | Randoop | EvoSuite | NPETest |
| ----------------- | ------: | -------: | ------: |
| ACS_Commons       |       0 |        0 |      64 |
| Artemis_odb       |     100 |      100 |      76 |
| BungeeCord-1303   |       0 |      100 |     100 |
| Byte-1405         |     100 |       92 |     100 |
| Byte_Buddy-9579   |     100 |      100 |     100 |
| Dubbo-4166        |     100 |       88 |     100 |
| OkHttp-9361(1)    |       0 |       88 |     100 |
| OkHttp-9361(2)    |       0 |       96 |     100 |
| Petergeneric      |       0 |      100 |     100 |
| REST-1546(1)      |       0 |       28 |      88 |
| REST-1546(2)      |     100 |       20 |      92 |
| REST-1546(3)      |     100 |      100 |     100 |
| REST-1546(4)      |     100 |      100 |     100 |
| REST-1546(5)      |     100 |      100 |     100 |
| REST-2078         |       0 |       40 |     100 |
| Universal-1724(1) |     100 |        0 |      56 |
| Universal-1724(2) |     100 |        0 |      64 |
| Universal-6766    |       0 |       64 |      72 |
| Yamcs-1863        |       0 |       76 |     100 |

### Defects4J

| Project | Randoop | EvoSuite | NPETest |
| ------- | ------: | -------: | ------: |
| Cli-30  |       0 |       28 |     100 |
| Cli-30  |       0 |       32 |      80 |
| Csv-11  |       0 |       80 |      72 |
| Csv-9   |     100 |       72 |      92 |
| Math-70 |     100 |      100 |     100 |
| Math-79 |       0 |       76 |     100 |

### Genesis

| Project         | Randoop | EvoSuite | NPETest |
| --------------- | ------: | -------: | ------: |
| Activiti-31c8   |       0 |       24 |      92 |
| Checkstyle-be8  |       0 |       60 |      80 |
| DataflowJavaSDK |       0 |        0 |       8 |
| JavaPoet-aee5   |     100 |      100 |     100 |
| Javaslang-0dab  |     100 |      100 |     100 |
| Jongo-9743      |       0 |        0 |       4 |

### Bears

| Project   | Randoop | EvoSuite | NPETest |
| --------- | ------: | -------: | ------: |
| Bears-189 |       0 |      100 |     100 |
| Bears-222 |       0 |       20 |      40 |
| Bears-56  |     100 |      100 |     100 |
| Bears-70  |       0 |        0 |      28 |
| Bears-88  |       0 |      100 |      92 |

**Average**: Randoop 33.7% EvoSuite 56.9% NPETest 78.9%
