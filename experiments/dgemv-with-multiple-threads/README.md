# dgemv-with-multiple-threads sweep

## Purpose

Test the `--call-dgemv-with-multiple-threads` flag at the current best
configuration (factorization priority on, separate-stream default), to observe
whether multi-threading the host-side dgemv calls (the iterative-solver / panel
dgemv path) changes end-to-end performance.

The flag (from NVIDIA HPL-MxP tuning parameters):

- `--call-dgemv-with-multiple-threads <int>` — number of rows each host thread
  works on if calling dgemv with multiple threads; `0` indicates using only one
  thread (default `0`).

## Fixed configuration (current best)

- `N=491520`, `NB=3072`, `2x4` row grid, `--gpu-affinity 0:1:2:3:4:5:6:7`.
- No CPU/memory affinity.
- `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`.
- `--fill-device 1 --fill-device-buffer-size 2048 --cuda-host-register-step 2048`.
- `--prioritize-factorization 1` (`--prioritize-trsm` omitted → default `0`).
- `--use-separate-stream-for-gemm` omitted → default `1`.
- `--use-mpi-panel-broadcast` and `--u-panel-chunk-nbs` omitted (defaults `50`/`8`).
- `--skip-tests 1` + GPU monitoring flags.

## Sweep

| Attempt | `--call-dgemv-with-multiple-threads` |
|---|---:|
| `dgemv_0` (control) | 0 |
| `dgemv_128` | 128 |
| `dgemv_256` | 256 |
| `dgemv_384` | 384 |
| `dgemv_512` | 512 |
| `dgemv_640` | 640 |

Run script: `run_dgemv_mt.pbs`. One `ngpus=8` job loops all six attempts; each
writes `outputs/<label>.{o,e}`.

## Logged attempts

| Attempt | dgemv-mt | PBS job | Node | Residual check | GFLOP/s | Evidence |
|---|---:|---|---|---|---|---|
| `dgemv_0` (control) | 0 | `55643.gaas` | `hpc-gaas-g16` | PASSED (`1.609604E-04`) | `2.4252e+06` | `outputs/dgemv_0.{o,e}` |
| `dgemv_128` | 128 | `55643.gaas` | `hpc-gaas-g16` | PASSED (`1.609604E-04`) | `2.1552e+06` | `outputs/dgemv_128.{o,e}` |
| `dgemv_256` | 256 | `55643.gaas` | `hpc-gaas-g16` | PASSED (`1.609604E-04`) | `2.1166e+06` | `outputs/dgemv_256.{o,e}` |
| `dgemv_384` | 384 | `55643.gaas` | `hpc-gaas-g16` | PASSED (`1.609604E-04`) | `2.1940e+06` | `outputs/dgemv_384.{o,e}` |
| `dgemv_512` | 512 | `55643.gaas` | `hpc-gaas-g16` | PASSED (`1.609604E-04`) | `2.3435e+06` | `outputs/dgemv_512.{o,e}` |
| `dgemv_640` | 640 | `55643.gaas` | `hpc-gaas-g16` | PASSED (`1.609604E-04`) | `2.2940e+06` | `outputs/dgemv_640.{o,e}` |

The default `0` is optimal; every non-zero value regresses `-3.4%` to `-12.7%`.

All raw PBS stdout/stderr files under `outputs/` are authoritative evidence.