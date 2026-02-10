**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**

| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |
| --- | --- | --- | --- | --- | --- |
|                 | Initial dataset of Python GitHub projects | 2,224 | - | - | - |
| Data Collection | Filtering inaccessible projects | 2,215 | - | - | - |
|                 | Dependency resolution | 1,644 | 34,864 | 5,617 | 21 |  |
|                 | Partial call graph construction | 1,302 | 21,785 | 3,232 | 17 |
| Data Analysis   | Call graph stitching | 1,302 | 21,785 | 3,232 | 17 |  |
|                 | Reachability analysis | 1,302 | 21,785 | 3,232 | 17 |  |
