# Separate-Stream-for-GEMM Toggle

## Purpose

Test the `--use-separate-stream-for-gemm` toggle at the current best
configuration (which includes `--prioritize-factorization 1`), to observe
whether giving GEMMs their own CUDA stream changes end-to-end performance.

The flag (from NVIDIA HPL-MxP tuning parameters):

- `--use-separate-stream-for-gemm <int>` — whether to use a separate stream for
  GEMMs (default `1`).

## Fixed configuration (current best)

- `N=491520`, `NB=3072`, `2x4` row grid, `--gpu-affinity 0:1:2:3:4:5:6:7`.
- No CPU/memory affinity.
- `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`.
- `--fill-device 1 --fill-device-buffer-size 2048 --cuda-host-register-step 2048`.
- `--prioritize-factorization 1` (`--prioritize-trsm` omitted → default `0`).
- `--use-mpi-panel-broadcast` and `--u-panel-chunk-nbs` omitted (defaults `50`/`8`).
- `--skip-tests 1` + GPU monitoring flags.

## Sweep

| Attempt | `--use-separate-stream-for-gemm` |
|---|---:|
| `ss_1` (control = current best) | 1 |
| `ss_0` | 0 |

Run script: `run_separate_stream.pbs`. One `ngpus=8` job loops both attempts;
each writes `outputs/<label>.{o,e}`.

## Logged attempts

| Attempt | separate-stream | PBS job | Node | Residual check | GFLOP/s | Evidence |
|---|---:|---|---|---|---|---|
| `ss_1` (control = current best) | 1 | `55620.gaas` | `hpc-gaas-g16` | PASSED (`1.609604E-04`) | `2.4162e+06` | `outputs/ss_1.{o,e}` |
| `ss_0` | 0 | `55620.gaas` | `hpc-gaas-g16` | PASSED (`1.609604E-04`) | `2.3705e+06` | `outputs/ss_0.{o,e}` |

Keeping the separate GEMM stream enabled (default `1`) is better: `ss_0`
(`--use-separate-stream-for-gemm 0`) loses `-1.89%` end-to-end.

All raw PBS stdout/stderr files under `outputs/` are authoritative evidence.