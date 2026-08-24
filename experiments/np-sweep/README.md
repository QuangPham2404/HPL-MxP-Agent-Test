# NP Sweep (process grid and order)

## Purpose

Sweep `--nprow`, `--npcol`, and `--nporder` with the matrix size and block size
fixed at the current best (N = 491520, NB = 3072, from the 2026-08-24 N-NB
resweep). Test all four grid/order combinations — 2x4 row, 2x4 column, 4x2 row,
4x2 column — while holding every other tuning parameter identical to isolate the
process-grid effect.

## Binary and environment

- Container image: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`
- Launcher: `apptainer exec --nv <image> mpirun -np 8 --bind-to none /workspace/hpl-mxp.sh`
- Modules: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`, `gocryptfs/2.5.0`
- MPI: 8 processes, one GPU per process.

## Inputs (fixed baseline tuning parameters)

- `--n 491520` (fixed; N-NB resweep peak)
- `--nb 3072` (fixed; NB-sweep peak)
- `--gpu-affinity 0:1:2:3:4:5:6:7`
- `--skip-tests 1` plus GPU monitoring flags (per project convention).
- Swept: `--nprow {2,4}`, `--npcol {4,2}`, `--nporder {row,column}`.

## Resource request

- Queue `gpu_as`, account `hpc_admin`, `select=1:ngpus=8`, `walltime=00:45:00`.

## Run script

- `run_np_sweep.pbs` is parametrized by `NPROW`, `NPCOL`, `NPORDER`, and
  `ATTEMPT`. Submit each combination with:

```text
qsub -v "NPROW=2,NPCOL=4,NPORDER=row,ATTEMPT=2x4_row_491k" \
     -o outputs/2x4_row_491k.o -e outputs/2x4_row_491k.e \
     run_np_sweep.pbs
```

| Attempt | `--nprow` | `--npcol` | `--nporder` |
|---|---|---|---|
| 2x4_row_491k | 2 | 4 | row |
| 2x4_col_491k | 2 | 4 | column |
| 4x2_row_491k | 4 | 2 | row |
| 4x2_col_491k | 4 | 2 | column |

The `491k` suffix distinguishes these from the earlier np-sweep recorded at
N = 399360 (attempts `2x4_row`, `4x2_col`, etc.).

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the reported residual is finite and within tolerance;
and a finite HPL-MxP `GFLOPS` performance value is present.

## Runtime error-patching history

None yet.