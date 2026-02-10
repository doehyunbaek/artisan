**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**

|        | Back-end / PPL           | LOC  |                 |
| ---    | ---                      | ---  | ---             |
| Python | Language Server          | 1549 |                 |
| Python | PyMC [51]                | 281  | custom back-end |
| Python | torch.distributions [48] | 67   | shared back-end |
| Python | Pyro [8]                 | 133  |                 |
| Python | BeanMachine [55]         | 95   |                 |
| Julia  | Language Server          | 2175 |                 |
| Julia  | Distributions.jl [7]     | 240  | shared back-end |
| Julia  | Gen [14]                 | 227  |                 |
| Julia  | Turing [21]              | 172  |                 |
