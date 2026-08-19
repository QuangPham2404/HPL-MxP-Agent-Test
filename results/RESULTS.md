# Results Report

This report records validated raw result data only. No optimization analysis or ranking is included.

| Experiment | Attempt | N | NB | Pgrid | Order | Correctness | GFLOP/s | Stdout |
|---|---|---|---|---|---|---|---|---|
| N-sweep | N-sweep_399k | 399360 | 1024 | 2x4 | row | PASSED | 1.4918e+06 | experiments/N-sweep/outputs/N-sweep_399k.o |
| N-sweep | N-sweep_400k | 400384 | 1024 | 2x4 | row | PASSED | 1.5751e+06 | experiments/N-sweep/outputs/N-sweep_400k.o |
| N-sweep | N-sweep_401k | 401408 | 1024 | 2x4 | row | PASSED | 1.5821e+06 | experiments/N-sweep/outputs/N-sweep_401k.o |
| N-sweep | N-sweep_402k | 402423 | 1024 | 2x4 | row | PASSED | 7.6797e+05 | experiments/N-sweep/outputs/N-sweep_402k.o |
| N-sweep | N-sweep_404k | 404000 | 1024 | 2x4 | row | PASSED | 1.4871e+06 | experiments/N-sweep/outputs/N-sweep_404k.o |
| N-sweep | N-sweep_v1 | 400000 | 1024 | 2x4 | row | PASSED | 1.5569e+06 | experiments/N-sweep/outputs/N-sweep_v1.o |
| baseline-sweep | baseline-sweep_v1 | 370000 | 1024 | 2x4 | row | PASSED | 1.4432e+06 | experiments/baseline-sweep/outputs/baseline-sweep_v1.o |
| nb-sweep | n-resweep_399k | 399360 | 3072 | 2x4 | row | PASSED | 1.8177e+06 | experiments/nb-sweep/outputs/n-resweep_399k.o |
| nb-sweep | n-resweep_402k | 402432 | 3072 | 2x4 | row | PASSED | 1.6981e+06 | experiments/nb-sweep/outputs/n-resweep_402k.o |
| nb-sweep | nb-sweep_1024 | 401408 | 1024 | 2x4 | row | PASSED | 1.5782e+06 | experiments/nb-sweep/outputs/nb-sweep_1024.o |
| nb-sweep | nb-sweep_2048 | 401408 | 2048 | 2x4 | row | PASSED | 1.7879e+06 | experiments/nb-sweep/outputs/nb-sweep_2048.o |
| nb-sweep | nb-sweep_3072 | 401408 | 3072 | 2x4 | row | PASSED | 1.8209e+06 | experiments/nb-sweep/outputs/nb-sweep_3072.o |
| nb-sweep | nb-sweep_4096 | 401408 | 4096 | 2x4 | row | PASSED | 1.8040e+06 | experiments/nb-sweep/outputs/nb-sweep_4096.o |
| nb-sweep | nb-sweep_5120 | 401408 | 5120 | 2x4 | row | PASSED | 1.7569e+06 | experiments/nb-sweep/outputs/nb-sweep_5120.o |
| nb-sweep | nb-sweep_8192 | 401408 | 8192 | 2x4 | row | PASSED | 1.7445e+06 | experiments/nb-sweep/outputs/nb-sweep_8192.o |
| np-sweep | 2x4_col | 399360 | 3072 | 2x4 | column | PASSED | 1.7625e+06 | experiments/np-sweep/outputs/2x4_col.o |
| np-sweep | 2x4_row | 399360 | 3072 | 2x4 | row | PASSED | 1.7302e+06 | experiments/np-sweep/outputs/2x4_row.o |
| np-sweep | 4x2_col | 399360 | 3072 | 4x2 | column | PASSED | 1.8441e+06 | experiments/np-sweep/outputs/4x2_col.o |
| np-sweep | 4x2_row | 399360 | 3072 | 4x2 | row | PASSED | 1.8126e+06 | experiments/np-sweep/outputs/4x2_row.o |

Source: `results/metrics.csv`.
