# Mutation tests (does the testbench actually catch bugs?)

| Injected bug | Expected symptom | Testbench result |
|---|---|---|
| FULL compare without inverting top 2 bits of synced read pointer | wrong full flag, wrong word count | FAILED (full after reset, DEPTH writes, data order) |
| EMPTY never asserted (always 0) | reads from empty FIFO | FAILED (empty after reset) |
| Write pointer ignores FULL (overwrites) | overflow / data loss | FAILED (DEPTH writes, full flag, data order) |

The unmodified design passes all 8 tests in all 5 clock-ratio configurations.
