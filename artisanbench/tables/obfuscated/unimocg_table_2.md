**Table 2: Soundness of Unimocg’s call-graph algorithms**

| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |
| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |
| Non-virtual Calls    |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Virtual Calls        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Types                |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Static Initializer   |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Java 8 Interfaces    |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Unsafe               |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Class.forName        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Sign. Polymorph.     |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Java 9+              |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Non-Java             |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| MethodHandle         |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Invokedynamic        |        ??/?? |        ??/?? |        ??/?? |        ??/?? |         ??/?? |
| Reflection           |        ??/?? |        ??/?? |        ??/?? |        ??/?? |         ??/?? |
| JVM Calls            |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Serialization        |         ?/?? |         ?/?? |         ?/?? |         ?/?? |          ?/?? |
| Library Analysis     |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Class Loading        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| DynamicProxy         |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| **Sum (out of 123)** | **?? (??%)** | **?? (??%)** | **?? (??%)** | **?? (??%)** | **??? (??%)** |

*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*
