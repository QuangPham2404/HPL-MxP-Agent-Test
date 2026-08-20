# Affinity sweeps

## Purpose

Test CPU affinity, memory affinity, and OpenMP thread settings after the
GAAS hardware probe, using the fixed validated workload `N=399360`,
`NB=3072`, `4x2` column-major grid, and eight MPI processes.

## Result configurations

The raw output filename is the stable result attempt label. The PBS scripts
currently retain an older echoed `experiment_id`/`attempt` pair, so Step 5
uses the output stem to distinguish these already-completed configurations.

| Attempt | Configuration |
|---|---|
| `mem_aff` | Memory affinity `0:0:0:0:1:1:1:1`; no explicit CPU affinity |
| `cpu_aff_neutral` | CPU affinity `0-11:12-23:24-35:36-49:56-66:67-77:78-89:90-101`; memory affinity `0:0:0:0:1:1:1:1` |
| `cpu_aff_free` | CPU-affinity variant label from the submitted run; the exact launch setting is not echoed in the retained PBS output |
| `cpu_aff_strict` | CPU-affinity variant label from the submitted run; the exact launch setting is not echoed in the retained PBS output |
| `thread_10` | CPU affinity `0-49:0-49:0-49:0-49:56-101:56-101:56-101:56-101`; `OMP_NUM_THREADS=10`, `OMP_PLACES=cores` |

All runs used the container image recorded in `results/metrics.csv`, the
standard GPU monitoring flags, and `--skip-tests 1`. Raw PBS stdout/stderr
files under `outputs/` are authoritative evidence.

## Logged attempts

| Attempt | PBS job | Node | Verification | GFLOP/s | Evidence |
|---|---:|---|---|---:|---|
| `mem_aff` | `50463.gaas` | `hpc-gaas-g11` | PASSED | `1.8428e+06` | `outputs/mem_aff.{o,e}` |
| `cpu_aff_free` | `50476.gaas` | `hpc-gaas-g11` | PASSED | `1.8596e+06` | `outputs/cpu_aff_free.{o,e}` |
| `cpu_aff_strict` | `50479.gaas` | `hpc-gaas-g11` | PASSED | `1.6919e+06` | `outputs/cpu_aff_strict.{o,e}` |
| `cpu_aff_neutral` | `50480.gaas` | `hpc-gaas-g14` | PASSED | `1.8077e+06` | `outputs/cpu_aff_neutral.{o,e}` |
| `thread_10` | `50486.gaas` | `hpc-gaas-g11` | PASSED | `8.7049e+05` | `outputs/thread_10.{o,e}` |
