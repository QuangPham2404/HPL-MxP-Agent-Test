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

| Attempt | N |
|---|---|
| N-sweep_370000 | 370000 |
| N-sweep_380000 | 380000 |
| N-sweep_390000 | 390000 |
| N-sweep_400000 | 400000 |
| N-sweep_410000 | 410000 |
| N-sweep_420000 | 420000 |
| N-sweep_430000 | 430000 |

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the reported residual is finite and within tolerance;
and a finite HPL-MxP `GFLOPS` performance value is present.

## Runtime error-patching history

(None yet.)