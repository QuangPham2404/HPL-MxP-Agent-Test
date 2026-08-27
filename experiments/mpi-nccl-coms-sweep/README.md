# MPI/NCCL Communication Sweep

## Purpose

Study how HPL-MxP's panel-broadcast transport mix responds to different
communication load. Two parameters are swept, and only those two:

- `--use-mpi-panel-broadcast <int>` — percentage of panel-broadcast steps that
  use MPI (0 = NCCL only; positive = MPI percentage policy).
- `--u-panel-chunk-nbs <int>` — U-panel chunk size in units of `NB` blocks.

The aim is **observation, not optimization**: characterize how MPI versus NCCL
behaves as the panel-broadcast policy and the U-panel chunk granularity change
the amount and shape of panel traffic. Phase 1 sweeps the broadcast policy;
Phase 2 takes the two best Phase-1 values and sweeps the chunk size.

## Fixed config

The previous best run (register-step and buffer both 2048), held constant for
every attempt:

- `--n 491520 --nb 3072`, `--nprow 2 --npcol 4 --nporder row`.
- `--gpu-affinity 0:1:2:3:4:5:6:7`, no `--cpu-affinity` / `--mem-affinity`.
- `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`.
- `--fill-device 1 --fill-device-buffer-size 2048 --cuda-host-register-step 2048`.
- `--skip-tests 1` + GPU monitoring flags (`--monitor-gpu 1`,
  `--monitor-gpu-interval 10`, `--monitor-gpu-pcie-width-warning 16`,
  `--monitor-gpu-pcie-gen-warning 5`).

Container: `hpc-benchmarks_26.02.sif`; `apptainer exec --nv`; `mpirun -np 8
--bind-to none`.

Note: the launcher currently resolves to `--use-mpi-panel-broadcast=50` and
`--u-panel-chunk-nbs=8` when those flags are not passed, so `50`/`8` are the
effective control (the previous best) even though prior run scripts did not set
them explicitly. Both are passed explicitly here for determinism. The
`baseline_*` labels are explicit re-runs of the previous best (n=491520/nb=3072
with register-step and buffer 2048).

## Phase 1 — broadcast policy sweep

`run_broadcast_sweep.pbs` loops a single node-matched job over, with chunk held
at `8`:

| label | `--use-mpi-panel-broadcast` | `--u-panel-chunk-nbs` |
|---|---:|---:|
| `baseline_a` | 50 | 8 |
| `bc_0` | 0 | 8 |
| `bc_25` | 25 | 8 |
| `bc_50` | 50 | 8 |
| `bc_75` | 75 | 8 |
| `bc_100` | 100 | 8 |
| `baseline_b` | 50 | 8 |

The two `baseline_*` runs bracket the sweep so node drift can be read; `bc_50`
is the same config tagged as the in-sweep 50 point.

## Phase 2 — U-panel chunk sweep

`run_chunk_sweep.pbs` sweeps `--u-panel-chunk-nbs` = `4, 8, 16` at the two
broadcast values selected as best from Phase 1 (top-2 by end-to-end GFLOP/s),
bracketed by a `baseline_*` control.

Phase 1 selected `--use-mpi-panel-broadcast = 75` (2.3570e+06) and `50`
(2.3291e+06) as the top-2 broadcast values.

## Run scripts

```text
cd experiments/mpi-nccl-coms-sweep
qsub run_broadcast_sweep.pbs      # Phase 1
# after Phase 1, inspect GFLOP/s, then:
qsub run_chunk_sweep.pbs          # Phase 2 (top-2 values baked in)
```

Each attempt writes attempt-specific evidence to `outputs/<label>.{o,e}`.

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the residual is finite and within tolerance; and a
finite HPL-MxP `GFLOPS` value is present. For the study, LU time, iterative
solver time, and residual are also recorded per attempt.

## Logged attempts

### Phase 1 — broadcast policy (node hpc-gaas-g13, job 53508)

| Attempt | broadcast | chunk | GFLOP/s | LU s | Solver s | Residual check | Evidence |
|---|---:|---:|---:|---:|---:|---|---|
| `baseline_a` | 50 | 8 | 2.2771e+06 | 20.43 | 14.33 | PASSED | `outputs/baseline_a.{o,e}` |
| `bc_0` | 0 | 8 | 2.3045e+06 | 21.05 | 13.30 | PASSED | `outputs/bc_0.{o,e}` |
| `bc_25` | 25 | 8 | 2.3179e+06 | 20.63 | 13.53 | PASSED | `outputs/bc_25.{o,e}` |
| `bc_50` | 50 | 8 | 2.3291e+06 | 20.60 | 13.39 | PASSED | `outputs/bc_50.{o,e}` |
| `bc_75` | 75 | 8 | 2.3570e+06 | 20.35 | 13.23 | PASSED | `outputs/bc_75.{o,e}` |
| `bc_100` | 100 | 8 | 2.3251e+06 | 20.57 | 13.48 | PASSED | `outputs/bc_100.{o,e}` |
| `baseline_b` | 50 | 8 | 2.3372e+06 | 20.50 | 13.37 | PASSED | `outputs/baseline_b.{o,e}` |

All seven runs passed; residual `1.609604E-04` throughout. The two baselines
(`2.2771e+06` → `2.3372e+06`) show ~2.6% same-node drift across the job, so
differences below that scale are not separable. Phase-1 top-2 by GFLOP/s: `75`
and `50`.

### Phase 2 — U-panel chunk sweep

Filled in after Phase 2 completes.