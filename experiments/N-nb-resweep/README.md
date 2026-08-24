# N-NB Resweep (N aligned to NB=3072)

## Purpose

Test whether performance improves when the matrix size is an exact multiple of
the block size (`N % nb == 0`). We fix `nb = 3072` (the peak of the 2026-08-24
NB sweep at N = 490000) and sweep N over multiples of 3072 around the current
best N = 490000, starting at 488448 (= 3072 * 159) and stepping +3072 each run.
The sweep stops after two consecutive GFLOP/s degradations or an OOM failure.

## Binary and environment

- Container image: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`
- Launcher: `apptainer exec --nv <image> mpirun -np 8 --bind-to none /workspace/hpl-mxp.sh`
- Modules: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`, `gocryptfs/2.5.0`
- MPI: 8 processes, one GPU per process.

## Inputs (fixed baseline tuning parameters)

- `--nb 3072` (fixed; NB-sweep peak)
- `--gpu-affinity 0:1:2:3:4:5:6:7`
- `--nprow 2 --npcol 4 --nporder row`
- `--skip-tests 1` plus GPU monitoring flags (per project convention).
- `--n <N>` (swept; multiples of 3072 from 488448 upward)

## Resource request

- Queue `gpu_as`, account `hpc_admin`, `select=1:ngpus=8`, `walltime=00:45:00`.

## Run script

- `run_n_nb_resweep.pbs` is parametrized by `N` and `ATTEMPT`. Submit each size
  with:

```text
qsub -v "N=488448,ATTEMPT=N-nb-resweep_488448" \
     -o outputs/N-nb-resweep_488448.o -e outputs/N-nb-resweep_488448.e \
     run_n_nb_resweep.pbs
```

## Sweep points

To be filled as runs complete; N is stepped +3072 from 488448 until two
consecutive GFLOP/s degradations or an OOM failure.

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the reported residual is finite and within tolerance;
and a finite HPL-MxP `GFLOPS` performance value is present.

## Runtime error-patching history

None yet.