# N Sweep

## Purpose

Push N (matrix size) to maximize computation, starting from the validated
370000 baseline and increasing in 10000 steps until performance deteriorates
for three consecutive runs. This re-establishes the clean baseline-vs-N trace
on the baseline configuration (nb=1024, 2x4 row grid, row order).

## Binary and environment

- Container image: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`
- Launcher: `apptainer exec --nv <image> mpirun -np 8 --bind-to none /workspace/hpl-mxp.sh`
- Modules: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`, `gocryptfs/2.5.0`
- MPI: 8 processes, one GPU per process.

## Inputs (fixed basline tuning parameters)

- `--gpu-affinity 0:1:2:3:4:5:6:7`
- `--nprow 2 --npcol 4 --nporder row`
- `--nb 1024`
- `--skip-tests 1` plus GPU monitoring flags (per project convention).

## Resource request

- Queue `gpu_as`, account `hpc_admin`, `select=1:ngpus=8`, `walltime=00:45:00`.

## Run script

- `run_n_sweep.pbs` is parametrized by `N` and `ATTEMPT`. Submit each size with:

```text
qsub -v "N=370000,ATTEMPT=N-sweep_370000" \
     -o outputs/N-sweep_370000.o -e outputs/N-sweep_370000.e \
     run_n_sweep.pbs
```

## Sweep points

N is stepped +10000 from 370000 until the memory wall (510000 OOM). Final
attempt set:

| Attempt | N | Result |
|---|---|---|
| N-sweep_370000 | 370000 | 1.4747e+06 PASSED |
| N-sweep_380000 | 380000 | 1.5274e+06 PASSED |
| N-sweep_390000 | 390000 | 1.2724e+06 PASSED (node noise, re-run) |
| N-sweep_390000_r1 | 390000 | 1.5592e+06 PASSED |
| N-sweep_400000 | 400000 | 1.5739e+06 PASSED |
| N-sweep_410000 | 410000 | 1.6077e+06 PASSED |
| N-sweep_420000 | 420000 | 1.6172e+06 PASSED |
| N-sweep_430000 | 430000 | 1.6407e+06 PASSED |
| N-sweep_440000 | 440000 | 1.6963e+06 PASSED |
| N-sweep_450000 | 450000 | 1.6209e+06 PASSED (node noise, re-run) |
| N-sweep_450000_r1 | 450000 | 1.6995e+06 PASSED |
| N-sweep_460000 | 460000 | 1.7225e+06 PASSED |
| N-sweep_470000 | 470000 | 1.7424e+06 PASSED |
| N-sweep_480000 | 480000 | 1.7619e+06 PASSED |
| N-sweep_490000 | 490000 | 1.8293e+06 PASSED (peak) |
| N-sweep_500000 | 500000 | 1.8152e+06 PASSED |
| N-sweep_510000 | 510000 | OOM (exit 137, cgroup memory limit) |

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the reported residual is finite and within tolerance;
and a finite HPL-MxP `GFLOPS` performance value is present.

## Runtime error-patching history

- `N-sweep_390000` (job 51020, node `hpc-gaas-g13`): reported only ~2.8 GB free
  system memory during the iterative solver vs ~37 GB on other nodes, yielding
  a ~20% slow outlier (1.2724e+06). Confirmed node/co-tenancy noise, not an N
  effect. Re-run as `N-sweep_390000_r1` (job 51031, g11) -> 1.5592e+06.
- `N-sweep_450000` (job 51033, node `hpc-gaas-g13`): same memory starvation
  (~1.8 GB free) produced 1.6209e+06. Re-run as `N-sweep_450000_r1`
  (job 51058, g11) -> 1.6995e+06.
- `N-sweep_510000` (job 51065, node `hpc-gaas-g12`): OOM-killed during matrix
  generation (`cgroup/OOM`, exit 137) after exceeding the ~2000 GB per-node
  cgroup memory budget. Recorded as `failed`/`unknown`; definitive upper wall,
  no patch attempted.