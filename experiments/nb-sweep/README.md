# Sweep NB

## Purpose

Sweep NB (panel/block size) with the matrix size fixed at N = 490000 — the peak
from the 2026-08-21 N sweep — to find the NB that maximizes GFLOP/s. NB is
stepped from 1024 in +1024 increments until performance degrades for two
consecutive runs. All other tuning parameters are held identical to the N sweep
so the comparison isolates NB only.

## Binary and environment

- Container image: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`
- Launcher: `apptainer exec --nv <image> mpirun -np 8 --bind-to none /workspace/hpl-mxp.sh`
- Modules: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`, `gocryptfs/2.5.0`
- MPI: 8 processes, one GPU per process.

## Inputs (fixed baseline tuning parameters)

- `--n 490000` (fixed; peak of the N sweep)
- `--gpu-affinity 0:1:2:3:4:5:6:7`
- `--nprow 2 --npcol 4 --nporder row`
- `--skip-tests 1` plus GPU monitoring flags (per project convention).
- `--nb <NB>` (swept; 1024, 2048, 3072, ... until two consecutive degradations)

## Resource request

- Queue `gpu_as`, account `hpc_admin`, `select=1:ngpus=8`, `walltime=00:45:00`.

## Run script

- `run_nb_sweep.pbs` is parametrized by `NB` and `ATTEMPT`. Submit each block
  size with:

```text
qsub -v "NB=1024,ATTEMPT=nb-sweep_1024_490k" \
     -o outputs/nb-sweep_1024_490k.o -e outputs/nb-sweep_1024_490k.e \
     run_nb_sweep.pbs
```

Attempt stems encode the swept NB and the fixed N (`<nb>_490k`) so they do not
collide with the earlier NB sweep recorded at N = 401408.

## Sweep points

To be filled as runs complete; NB is stepped +1024 from 1024 until two
consecutive GFLOP/s degradations are observed.

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the reported residual is finite and within tolerance;
and a finite HPL-MxP `GFLOPS` performance value is present.

## Runtime error-patching history

None yet.