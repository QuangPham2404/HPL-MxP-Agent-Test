# Analysis: CPU/memory affinity re-sweep at N=491520

## 1. Concise summary

We re-tested `--cpu-affinity` and `--mem-affinity` on the current best workload
(N = 491520, NB = 3072, 2x4 row, `--gpu-affinity 0:1:2:3:4:5:6:7`), following the
two-stage order: validate `--mem-affinity` first, then sweep `--cpu-affinity`.

Neither flag improves performance. The best setting is to use **no CPU affinity
and no memory affinity** (the OS/default placement): 2.1980e+06 GFLOP/s
(+52.30% over the original 1.4432e+06 baseline). Explicit CPU binding is neutral
to slightly negative at 8–12 cores/rank and **catastrophically worse** with
fewer cores (4 cores/rank −18%, 2 cores/rank −87%), because HPL-MxP's host
threads (`--mpi-use-host-threads 1`) starve when the core budget is small.
Memory affinity alone gave −1.45% (within node noise), so it was not carried
forward.

## 2. Scope and evaluation criteria

- **Source/package**: NVIDIA HPC Benchmarks v26.02 container
  (`hpc-benchmarks_26.02.sif`), HPL-MxP 26.2.0.
- **Environment**: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`,
  `gocryptfs/2.5.0`; `mpirun -np 8 --bind-to none` (one GPU per rank).
- **Hardware**: 1 node, 8x NVIDIA H200; 2 sockets (NUMA 0 CPUs 0-55, NUMA 1
  CPUs 56-111). The container cpuset exposes 96 CPUs: `0-49` (NUMA 0) and
  `56-101` (NUMA 1) per `nvidia-smi`. GPUs 0-3 → NUMA 0, GPUs 4-7 → NUMA 1.
- **Workload**: fixed N = 491520, NB = 3072, 2x4 row,
  `--gpu-affinity 0:1:2:3:4:5:6:7`, `--skip-tests 1` plus GPU monitoring.
- **Swept variables**: `--mem-affinity` (off vs `0:0:0:0:1:1:1:1`), then
  `--cpu-affinity` (free, 2/4/8/12 cores per rank, and full socket).
- **Baseline for comparison**: original `baseline-sweep_v1` (1.4432e+06
  GFLOP/s). Secondary reference: the no-affinity control `mem_off_491k`
  (2.1980e+06) and `np-sweep/2x4_row_491k` (2.2067e+06).
- **Correctness**: every run that launched reported `PASSED` with a finite
  residual; two attempts (`cpu_slice12_491k`, `cpu_socket_491k`) failed at
  launch with out-of-range CPU arguments and were corrected and re-run as
  `_r1`.
- **Metric**: the reported HPL-MxP GFLOP/s performance marker.

## 3. Data and analysis

### 3.1 Memory affinity (no CPU affinity)

| Attempt | `--mem-affinity` | Node | GFLOP/s | % vs baseline (1.4432e6) | % vs `mem_off` |
|---|---|---:|---:|---:|---:|
| `mem_off_491k` | none | g15 | 2.1980e+06 | +52.30% | 0.00% |
| `mem_aff_491k` | `0:0:0:0:1:1:1:1` | g16 | 2.1662e+06 | +50.10% | −1.45% |

Memory affinity is a mild decrease (−1.45%) relative to no affinity, though the
two runs land on different nodes (g15 vs g16), so the difference is within the
~±1–2% node/run noise. It does not improve performance, so per the agreed rule
the `--mem-affinity` flag is **not** carried into the CPU sweep.

### 3.2 CPU affinity (no memory affinity)

| Attempt | cores/rank | Node | GFLOP/s | % vs baseline (1.4432e6) | % vs `cpu_free` |
|---|---|---:|---:|---:|---:|---:|
| `cpu_free` (`mem_off_491k`) | (no binding) | g15 | 2.1980e+06 | **+52.30%** | 0.00% |
| `cpu_slice12_491k_r1` | 12 | g15 | 2.1919e+06 | +51.88% | −0.28% |
| `cpu_8cores_491k` | 8 | g17 | 2.1778e+06 | +50.90% | −0.92% |
| `cpu_socket_491k_r1` | full socket | g16 | 2.1746e+06 | +50.68% | −1.06% |
| `cpu_4cores_491k` | 4 | g16 | 1.7972e+06 | +24.53% | −18.23% |
| `cpu_strict2_491k` | 2 | g15 | 2.7974e+05 | −80.62% | −87.27% |

The "free" (unbound) configuration is the best. 12 and 8 cores/rank are within
~1% of free, the full-socket spread is ~1% below, and anything below 8 cores is
a severe regression. The 2-core case collapses to 2.7974e+05 (only ~13% of the
free result), confirming that HPL-MxP's host threads need a generous core
budget. On the comparable g15 node, `cpu_free` (2.1980e+06) and 12-core slice
(2.1919e+06) are essentially tied.

### 3.3 Launch errors (preserved, then corrected)

`cpu_slice12_491k` and `cpu_socket_491k` were first submitted with CPU ranges
that reached `92-103` and `0-55` respectively; `numactl` rejected them
("cpu argument out of range") because the container cpuset only exposes
`0-49` and `56-101`. They were corrected to `0-11:...:90-101` and
`0-49:...:56-101` and re-run as `_r1` (jobs 52315/52316).

## 4. Insights gained

1. **No affinity is the best affinity.** At N = 491520 / NB = 3072 / 2x4 row,
   both `--cpu-affinity` and `--mem-affinity` are neutral or negative. The best
   configuration is the plain default (no CPU/memory binding), matching exactly
   what all prior sweeps in this project already used.
2. **Host threads need ≥8 cores/rank.** `--mpi-use-host-threads 1` means the
   CPU budget is a hard constraint: 4 cores/rank costs −18%, 2 cores/rank −87%.
   Any future affinity work must keep ≥8 cores per rank.
3. **Memory affinity is neutral-to-slightly-negative** (−1.45%, within noise),
   consistent with the earlier N = 399360 finding (−0.07%).
4. **The container cpuset is 96 CPUs** (`0-49`, `56-101`), not the full
   112 (`0-55`, `56-111`); CPU-affinity strings must respect this boundary.
5. **Diminishing returns confirmed.** Placement tuning adds nothing beyond the
   N + NB + grid wins already found; the project is at a performance plateau of
   ~2.20e+06 GFLOP/s on this configuration.

## 5. Suggested next section

1. **Adopt the no-affinity configuration** (N = 491520, NB = 3072, 2x4 row,
   no `--cpu-affinity`, no `--mem-affinity`) as the shipping configuration.
2. **If further gains are pursued**, focus on the remaining orthogonal levers
   not yet revisited at N = 491520 — notably the matrix-placement controls
   (`--fill-device-buffer-size`, register step) that previously reached
   ~2.20e+06 at smaller N.
3. **Treat affinity as closed** for this workload; do not re-tune `--cpu/mem`
   unless the workload N/NB/grid changes substantially.

These are recommendations for review, not authorization to execute.

## 6. Provenance

- Source CSV: `results/metrics.csv` (103 rows; 9 new `affinity-sweep` attempts,
  of which 7 completed and 2 failed-then-corrected).
- Experiment: `experiments/affinity-sweep/` (`README.md`, `run_affinity_sweep.pbs`,
  `outputs/*_491k{.o,.e}`).
- Baseline reference: `baseline-sweep_v1` (metrics.csv), 1.4432e+06 GFLOP/s.
- Secondary reference: `np-sweep/2x4_row_491k`, 2.2067e+06 GFLOP/s.
- PBS jobs: 52305–52311, 52315–52316.
- Analysis date: 2026-08-24.