# HPL-MxP Baseline Sweep

## Purpose

Run the validated minimal GAAS HPL-MxP container command as the initial
baseline experiment. This experiment currently contains one reference
attempt, `baseline-sweep_v1`; no optimization variation is being tested.

## Execution metadata

- Experiment ID: `baseline-sweep`
- Attempt: `baseline-sweep_v1`
- Cluster: GAAS
- Queue: `gpu_as`
- Project: `hpc_admin`
- Resources: `select=1:ngpus=8`, `walltime=00:45:00`
- Container: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`
- Launcher: Apptainer with `--nv`, `mpirun -np 8 --bind-to none`
- Modules: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`, `gocryptfs/2.5.0`
- Application command: `/workspace/hpl-mxp.sh`
- Matrix and grid: `N=370000`, `NB=1024`, `nprow=2`, `npcol=4`, `nporder=row`
- GPU affinity: `0:1:2:3:4:5:6:7`

## Validation

The command is copied from the user-provided GAAS manual-test script. The
attempt is valid only when the PBS job completes, raw stdout and stderr are
preserved, normal HPL-MxP output is present, the numerical verification marker
is successful and finite, and the reported GFLOP/s value can be extracted.

## Attempt record

| Attempt | PBS job ID | State/exit | Stdout | Stderr | Correctness | GFLOP/s |
|---|---|---|---|---|---|---|
| `baseline-sweep_v1` | pending | pending | `outputs/baseline-sweep_v1.o` | `outputs/baseline-sweep_v1.e` | pending | pending |

No runtime patching or retry is authorized by this experiment record.
