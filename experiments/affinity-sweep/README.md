# Affinity sweeps (CPU and memory affinity)

## Purpose

Sweep `--cpu-affinity` (and validate `--mem-affinity`) on the current best
workload: N = 491520, NB = 3072, 2x4 row grid, `--gpu-affinity 0:1:2:3:4:5:6:7`,
eight MPI processes. The goal is to find the CPU-core binding (span/pinning) and
memory-NUMA placement that maximize GFLOP/s after N, NB, and grid are fixed.

## Binary and environment

- Container image: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`
- Launcher: `apptainer exec --nv <image> mpirun -np 8 --bind-to none /workspace/hpl-mxp.sh`
- Modules: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`, `gocryptfs/2.5.0`
- MPI: 8 processes, one GPU per process.

## Fixed inputs

- `--n 491520`, `--nb 3072`
- `--nprow 2 --npcol 4 --nporder row`
- `--gpu-affinity 0:1:2:3:4:5:6:7`
- `--skip-tests 1` plus GPU monitoring flags (per project convention).

## Topology

2 sockets / 2 NUMA nodes: node 0 CPUs 0-55, node 1 CPUs 56-111; 56 cores per
socket, 1 thread per core. GPUs 0-3 attach to NUMA node 0, GPUs 4-7 to NUMA
node 1. `--mem-affinity` has one valid placement: `0:0:0:0:1:1:1:1`.

## Run script

- `run_affinity_sweep.pbs` is parametrized by `ATTEMPT`, and optional
  `CPU_AFFINITY` / `MEM_AFFINITY`. A flag is omitted when its variable is unset
  or `none`.

```text
qsub -v "ATTEMPT=mem_aff_491k,MEM_AFFINITY=0:0:0:0:1:1:1:1" \
     -o outputs/mem_aff_491k.o -e outputs/mem_aff_491k.e \
     run_affinity_sweep.pbs
```

## Planned attempts

| Attempt | `--cpu-affinity` (cores/rank) | `--mem-affinity` |
|---|---|---|
| `mem_off_491k` | none | none |
| `mem_aff_491k` | none | `0:0:0:0:1:1:1:1` |
| `cpu_strict2_491k` | `0-1:2-3:4-5:6-7:56-57:58-59:60-61:62-63` (2) | (decided by step 1) |
| `cpu_4cores_491k` | `0-3:4-7:8-11:12-15:56-59:60-63:64-67:68-71` (4) | " |
| `cpu_8cores_491k` | `0-7:8-15:16-23:24-31:56-63:64-71:72-79:80-87` (8) | " |
| `cpu_slice12_491k` | `0-11:12-23:24-35:36-47:56-67:68-79:80-91:92-103` (12) | " |
| `cpu_socket_491k` | `0-55:0-55:0-55:0-55:56-111:56-111:56-111:56-111` (full socket) | " |

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the reported residual is finite and within tolerance;
and a finite HPL-MxP `GFLOPS` performance value is present.

## Result

`--mem-affinity` was −1.45% vs none, so it was dropped; `--cpu-affinity` was
neutral to negative. No affinity is best.

| Attempt | cpu cores/rank | mem | GFLOP/s |
|---|---|---:|---:|
| `mem_off_491k` | none | none | 2.1980e+06 PASSED (best) |
| `mem_aff_491k` | none | `0:0:0:0:1:1:1:1` | 2.1662e+06 PASSED |
| `cpu_strict2_491k` | 2 | none | 2.7974e+05 PASSED |
| `cpu_4cores_491k` | 4 | none | 1.7972e+06 PASSED |
| `cpu_8cores_491k` | 8 | none | 2.1778e+06 PASSED |
| `cpu_slice12_491k_r1` | 12 | none | 2.1919e+06 PASSED |
| `cpu_socket_491k_r1` | full socket | none | 2.1746e+06 PASSED |

## Runtime error-patching history

- `cpu_slice12_491k` and `cpu_socket_491k` (jobs 52310/52311) failed at launch:
  `numactl` rejected CPU ranges reaching `92-103` / `0-55` because the container
  cpuset only exposes `0-49` and `56-101` (96 CPUs). Corrected the ranges and
  re-ran as `cpu_slice12_491k_r1` / `cpu_socket_491k_r1` (jobs 52315/52316).