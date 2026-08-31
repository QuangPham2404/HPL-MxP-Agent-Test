# Dependency-Priority Test

## Purpose

Test the two LU-scheduling dependency-priority flags at the fixed best
configuration, following the communication study's recommendation to move on to
dependency priorities (`--prioritize-trsm`, `--prioritize-factorization`), which
target the panel-readiness stalls seen in the Nsight trace.

The two flags (from NVIDIA HPL-MxP tuning parameters):

- `--prioritize-trsm <int>` — whether GEMMs wait for U TRSMs (default `0`).
- `--prioritize-factorization <int>` — whether GEMMs wait for factorizations
  (default `0`).

All four boolean combinations are tested.

## Fixed configuration

- `N=491520`, `NB=3072`, `2x4` row grid, `--gpu-affinity 0:1:2:3:4:5:6:7`.
- No CPU/memory affinity.
- `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`.
- `--fill-device 1 --fill-device-buffer-size 2048 --cuda-host-register-step 2048`.
- `--use-mpi-panel-broadcast` and `--u-panel-chunk-nbs` are omitted, so the
  package defaults (`50` and `8`) apply (the "best previous run" uses these
  defaults).
- `--skip-tests 1` + GPU monitoring flags.

## Sweep

| Attempt | `--prioritize-trsm` | `--prioritize-factorization` |
|---|---:|---:|
| `fp_0_0` (control) | 0 | 0 |
| `fp_0_1` | 0 | 1 |
| `fp_1_0` | 1 | 0 |
| `fp_1_1` | 1 | 1 |

Run script: `run_factorization_priority.pbs`. One `ngpus=8` job loops all four
combinations; each writes `outputs/<label>.{o,e}`.

## Logged attempts

| Attempt | trsm | fact | PBS job | Node | Residual check | GFLOP/s | Evidence |
|---|---:|---:|---|---|---|---|---|

(completed at runtime; see `results/metrics.csv` for extracted values)

All raw PBS stdout/stderr files under `outputs/` are authoritative evidence.