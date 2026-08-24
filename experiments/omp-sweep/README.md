# OMP Sweep (OMP_NUM_THREADS, OMP_PLACES, OMP_PROC_BIND)

## Purpose

Sweep OpenMP thread controls on the current best workload — N = 491520,
NB = 3072, 2x4 row grid, `--gpu-affinity 0:1:2:3:4:5:6:7`, eight MPI processes,
no `--cpu-affinity` / `--mem-affinity` — to find the OpenMP host-thread
configuration that maximizes GFLOP/s. Runs in two phases:

1. **`OMP_NUM_THREADS` sweep** (1, 2, 4, 8, 10, then +2 per run), stopping after
   two consecutive GFLOP/s decreases relative to the previous run.
2. **`OMP_PLACES` × `OMP_PROC_BIND` scan** at the best `OMP_NUM_THREADS`:
   `places ∈ {cores, sockets}` × `bind ∈ {TRUE, FALSE, CLOSE, SPREAD}`.

## Binary and environment

- Container image: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`
- Launcher: `apptainer exec --nv <image> mpirun -np 8 --bind-to none -x <omp...> /workspace/hpl-mxp.sh`
- Modules: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`, `gocryptfs/2.5.0`
- MPI: 8 processes, one GPU per process.

## Fixed inputs

- `--n 491520`, `--nb 3072`
- `--nprow 2 --npcol 4 --nporder row`
- `--gpu-affinity 0:1:2:3:4:5:6:7`
- No `--cpu-affinity`, no `--mem-affinity`.
- `--skip-tests 1` plus GPU monitoring flags (per project convention).

## Swept variables (OpenMP)

- `OMP_NUM_THREADS`: 1, 2, 4, 8, 10, 12, 14, … (phase 1).
- `OMP_PLACES`: `cores`, `sockets` (phase 2; unset in phase 1).
- `OMP_PROC_BIND`: `TRUE`, `FALSE`, `CLOSE`, `SPREAD` (phase 2; unset in phase 1).

## Topology

2 sockets / 2 NUMA nodes (0: CPUs 0-55, 1: CPUs 56-111). The container cpuset
exposes 96 CPUs: `0-49` and `56-101`. GPUs 0-3 → NUMA 0, GPUs 4-7 → NUMA 1.
With 8 MPI ranks, total host threads = 8 × `OMP_NUM_THREADS`; 96 threads total
is reached at 12 threads/rank, beyond which the node is oversubscribed.

## Run script

`run_omp_sweep.pbs` is parametrized by `ATTEMPT`, `OMP_NT` (thread count), and
optional `OMP_PLACES` / `OMP_PROC_BIND`. The thread count is passed under `OMP_NT`
because PBS forces `OMP_NUM_THREADS` to the allocated core count (96) and ignores
a `qsub -v` override; the script re-exports `OMP_NUM_THREADS` from `OMP_NT` after
`module purge`.

```text
qsub -v "ATTEMPT=omp_t2,OMP_NT=2" \
     -o outputs/omp_t2.o -e outputs/omp_t2.e \
     run_omp_sweep.pbs

qsub -v "ATTEMPT=omp_t12_cores_spread,OMP_NT=12,OMP_PLACES=cores,OMP_PROC_BIND=SPREAD" \
     -o outputs/omp_t12_cores_spread.o -e outputs/omp_t12_cores_spread.e \
     run_omp_sweep.pbs
```

## Planned attempts

Phase 1 (`OMP_NUM_THREADS`): `omp_t1`, `omp_t2`, `omp_t4`, `omp_t8`, `omp_t10`,
then `omp_t12`, `omp_t14`, … stopping on two consecutive decreases.

Phase 2 (`OMP_PLACES` × `OMP_PROC_BIND` at best threads `T`):

| `OMP_PLACES` | `TRUE` | `FALSE` | `CLOSE` | `SPREAD` |
|---|---|---|---|---|
| `cores` | `omp_t<T>_cores_true` | `omp_t<T>_cores_false` | `omp_t<T>_cores_close` | `omp_t<T>_cores_spread` |
| `sockets` | `omp_t<T>_sockets_true` | `omp_t<T>_sockets_false` | `omp_t<T>_sockets_close` | `omp_t<T>_sockets_spread` |

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the reported residual is finite and within tolerance;
and a finite HPL-MxP `GFLOPS` performance value is present.

## Result

(to be recorded after the sweep)

## Runtime error-patching history

- First sweep (jobs 52360–52381) was invalid: `OMP_NUM_THREADS` was forced to 96
  by PBS at job start (a `qsub -v "OMP_NUM_THREADS=..."` override is silently
  ignored), so every "phase 1" run actually ran at 96 threads/rank and the
  observed variation was node noise, not a thread-count effect. The script now
  accepts the thread count as `OMP_NT` and re-exports `OMP_NUM_THREADS` after
  `module purge`. The invalid `.o`/`.e` evidence was removed and the sweep
  re-run.