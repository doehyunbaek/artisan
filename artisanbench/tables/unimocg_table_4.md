**Table 4: Field Immutability Results for OpenJDK**

| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |
| ---------- | ------: | -----------: | -------: | -------: |
| Ad-hoc CHA |  23 195 |       24 296 |      108 |   46 368 |
| CHA        |  23 195 |       25 252 |       20 |   45 500 |
| RTA        |  23 195 |        7 352 |      316 |   63 104 |
| XTA        |  23 195 |        2 871 |      316 |   67 585 |

*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*
