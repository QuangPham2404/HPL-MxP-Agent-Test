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

N is stepped +3072 from 488448 until two consecutive degradations or OOM. The
sweep hit the OOM wall at 506880 / 509952.

| Attempt | N | GFLOP/s |
|---|---:|---:|
| N-nb-resweep_488448 | 488448 | 2.1675e+06 PASSED |
| N-nb-resweep_491520 | 491520 | 2.1974e+06 PASSED (peak) |
| N-nb-resweep_494592 | 494592 | 2.1867e+06 PASSED |
| N-nb-resweep_497664 | 497664 | 2.1520e+06 PASSED |
| N-nb-resweep_500736 | 500736 | 2.1936e+06 PASSED |
| N-nb-resweep_503808 | 503808 | 2.1708e+06 PASSED |
| N-nb-resweep_506880 | 506880 | OOM (exit 137) |
| N-nb-resweep_509952 | 509952 | OOM (exit 137) |

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the reported residual is finite and within tolerance;
and a finite HPL-MxP `GFLOPS` performance value is present.

## Runtime error-patching history

- `N-nb-resweep_506880` and `N-nb-resweep_509952`: OOM-killed during matrix
  generation (`cgroup/OOM`, exit 137) after device memory filled (~134.6 of
  ~139.8 GB) and the per-process cgroup budget was exceeded. Recorded as
  `failed`/`unknown`; definitive memory wall at nb = 3072, no patch attempted.