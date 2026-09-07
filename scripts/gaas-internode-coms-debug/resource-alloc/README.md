# Host resource-allocation investigation for the 3x4 HPL-MxP degradation

## Motivation

The HPL-MxP baseline on the 3-nodes x 4-GPUs topology (job `57232.gaas`,
2026-09-03, N=480000, NB=1024, 3x4 row grid) finished `PASSED` but extremely
slowly: `GFLOPS = 4.0092e+04` (3340.96 per GPU), LU phase 1634.2 s, total
walltime 42:10 — roughly 44x below the single-node 8xH200 reference
(`scripts/comm_transport_probe_report.md`).

A primary communication-stack cause is already documented and tracked in the
parent debug session (GPUDirect RDMA effectively off: UCX selects the
`cuda_cpy` staging path and the `gdrdrv` kernel module is absent). Evidence
gathered on 2026-09-07, however, shows a second, independent factor that this
directory investigates on its own: **host resource allocation and affinity for
non-full-node GPU jobs**.

Observed allocation facts (evidence: `experiments/3x4-baseline/outputs/`,
`experiments/3x4-smoketest/outputs/`, `scripts/outputs/`):

- A `select=3:ngpus=4` chunk grants 48 CPUs per node, chosen GPU-locally with
  cross-NUMA padding (job `59667.gaas` cpuset on g11: `48-49,56-101`).
- PBS hands out an arbitrary 4-of-8 GPU subset per node, different per node and
  per job: baseline v1 ran socket-0 GPUs on g09/g13 (PCI `1b/3c/4b/5c`) but
  socket-1 GPUs on g15 (`9a/bb/cd/dc`); the smoketest saw a mixed set on g10
  (`5c` + `9a/bb/cd`), socket-0 on g15, socket-1 on g17.
- The container renumbers whichever 4 GPUs were allocated to "0-3", so
  `--gpu-affinity 0:1:2:3` masks the actual physical placement.
- The baseline ran with `--bind-to none`, no CPU/memory affinity, and UCX
  defaults (`UCX_NET_DEVICES=all`), so ranks, host-memory staging buffers, and
  NIC-rail selection all floated freely over a possibly cross-NUMA cpuset.

Hypothesis: improper or heterogeneous host resource allocation/affinity — CPU
cores, host memory placement, NUMA/cross-NUMA placement of GPUs and NIC rails —
is a probable cause of the degradation, worth investigating independently from
the other candidate causes.

Beyond this benchmark, the findings inform GAAS cluster resource-allocation
behavior and optimization/best-practice guidance for other users running
non-full-node GPU jobs (a mis-matched allocation can silently degrade anyone's
job the same way).

## Experiments

### Experiment 1 — Allocation-variance baseline series (N=250k, 5 jobs)

- **Status:** complete (2026-09-08). All 5 attempts ran, `PASSED`, exit 0.
  Scripts: `debug-scripts/run_3x4_alloc_variance.pbs` +
  `debug-scripts/capture_node_alloc.sh`. Raw evidence:
  `outputs/alloc250k_v1..v5.{o,e}` (jobs 59932, 59939, 59943, 59953,
  59959). All 5 landed on the same nodes (g09/g15/g16) with differing
  per-node GPU/CPU carve-outs. Results below under "Analysis".
- **Purpose:** measure run-to-run performance variance under identical job
  requests, and correlate it with the per-job, per-node allocation that PBS
  actually hands out.
- **Method:** 5 sequential jobs, each identical to the 3x4 baseline v1 launch
  (same scheduler request, launch path, flags: `select=3:ngpus=4`,
  `place=scatter`, gpu-affinity `0:1:2:3`, 3x4 row grid, `--skip-tests 1`, GPU
  monitoring flags) except `N=250000` for speed. No binding flags. Sequential
  submission so our own jobs never co-locate and each job samples a fresh
  scheduler allocation.
- **Allocation capture (per node, before each run, via `pbsdsh`):** job cpuset
  (`Cpus_allowed_list`, `Mems_allowed_list`), host `nvidia-smi -L` (all 8 GPUs
  with PCI buses) plus per-GPU `memory.used` (co-tenancy detection), the
  container's visible/renumbered GPU list, `nvidia-smi topo -m`, per-NIC NUMA
  node (`/sys/class/infiniband/*/device/numa_node`), `ibdev2netdev`, and
  per-NUMA CPU lists.
- **In-run evidence:** the existing `--monitor-gpu` flags (per-rank GPU PCI
  bus, clocks, power, PCIe link) and `UCX_LOG_LEVEL=info` (actual
  transport/rail selection per rank).
- **Metrics compared per job:** HPL-MxP GFLOPS (total and per GPU), LU seconds
  (AVG/MAX/MIN with owning rank), iterative-solver seconds, correctness
  (`PASSED`), and rank skew — against each node's recorded GPU socket/NUMA
  placement, cpuset, NIC locality, and co-tenancy.
- **Planned attempts:** `alloc250k_v1` .. `alloc250k_v5`, raw evidence under
  `outputs/` with attempt-specific filenames.

## Analysis

### Experiment 1 results (2026-09-08)

**Performance per attempt** (N=250000, NB=1024, 3x4 row grid, 12 ranks; all
`PASSED`, exit 0):

| Attempt | Job | Walltime | GFLOPS (total) | GFLOPS/GPU | LU s | Solver s | RNG s AVG (MAX node / MIN node) | matgen s |
|---|---|---|---:|---:|---:|---:|---|---:|
| v1 | 59932 | 8:23 | 3.4290e+04 | 2857 | 247.6 | 56.6 | 41.1 (g09 88.8 / g16 13.9) | 140.4 |
| v2 | 59939 | 7:49 | 3.0866e+04 | 2572 | 285.3 | 52.7 | 27.2 (g09 55.8 / g15 7.9) | 85.1 |
| v3 | 59943 | 7:10 | 3.2840e+04 | 2737 | 265.0 | 52.5 | 27.4 (g09 56.9 / g15 12.5) | 70.4 |
| v4 | 59953 | 7:07 | 3.3735e+04 | 2811 | 262.3 | 46.8 | 25.9 (g09 54.2 / g15 11.3) | 74.0 |
| v5 | 59959 | 2:37 | **5.1946e+05** | **43288** | **15.3** | **4.8** | 11.1 (g16 13.3 / g09 9.2) | 18.7 |

v5 was **15.8x faster** overall than the v1-v4 mean (GFLOPS), with comms-bound
phases improving most (LU 17.3x, solver 11.0x) and host-bound phases 2.5-7.5x.

**Recorded allocation per attempt** (physical GPU sockets from PCI buses:
`1b/3c/4b/5c` = socket 0, `9a/bb/cd/dc` = socket 1; container renumbers the 4
allocated GPUs to 0-3):

| Attempt | g09 | g15 | g16 |
|---|---|---|---|
| v1 | GPUs 0-3 (s0), cpuset 48-49,56-101 (s1) — mismatch | GPUs 3,4,6,7 (mixed), cpuset 0-23,36-49,56-65 (fragmented, both) — mismatch | GPUs 4-7 (s1), cpuset 0-47 (s0) — mismatch |
| v2 | same as v1 | same as v1 | same as v1 |
| v3 | same as v1 | GPUs 4-7 (s1), cpuset 0-47 (s0) — mismatch | GPUs 4-7 (s1), cpuset 0-47 (s0) — mismatch |
| v4 | same as v1 | same as v3 | same as v3 |
| v5 | GPUs 1,2,3 (s0) + 5 (s1) mixed, cpuset 24-35,48-49,56-89 (fragmented) | same as v3 | same as v3 |

**Findings:**

1. **Allocation chaos confirmed (5/5 attempts):** PBS never co-located the
   4-GPU set with same-socket CPUs for `select=3:ngpus=4`; cpusets were
   fragmented (holes imply co-tenant CPU jobs on the same nodes); GPU sets
   could even be mixed-socket (v1/v5 g15/g09). The host job environment only
   sees the 4 allocated GPUs (cgroup), so this is invisible without the PCI
   bus capture.
2. **UCX rail selection is identical across attempts:** every rank built
   multi-rail configs over all 9 devices (`mlx5_0-5,8,9` + `mlx5_bond_0`),
   with no locality filtering. Not the differentiator between fast/slow runs.
3. **Performance is bimodal, and the recorded allocation variables do not
   explain it:** v5's placement was no better than v1-v4's (still mismatched
   and fragmented), yet comms-bound phases jumped 11-17x. The
   communication-free RNG phase shows the node-local state flip directly:
   g09 ranks took 54-89 s in v1-v4 vs 9.2-13.3 s in v5 — pointing to external
   contention (co-tenant host/fabric load) during v1-v4 rather than our job's
   own placement.
4. **GPU monitoring corroborates the slow mode:** v1-v4 GPUs sat at ~125 W
   median (near-idle) for the whole 8-minute run — comms-starved. Even v5
   (43.3 TF/GPU) remains ~6x below the single-node 8xH200 per-GPU reference
   (~275 TF/GPU at N=491520), consistent with the still-unfixed GPUDirect
   off / `cuda_cpy` staging ceiling.
5. **Limitations:** co-tenant load was inferred (cpuset holes, RNG flip), not
   measured — the capture lacks host load and NIC counter snapshots; the
   in-job host `nvidia-smi` sees only allocated GPUs, so co-tenant GPU state
   is unobservable from inside the job.

**Implications:** all three factors coexist for non-full-node GPU jobs on
GAAS: (a) the comms-stack ceiling (GPUDirect off, separate workstream),
(b) a ~16x catastrophic contention mode that comes and goes with external
node/fabric load, and (c) pervasive CPU/GPU/NUMA placement mismatch that is
constant in this series and likely compounds both. A follow-up capture with
host load + IB counters would separate (b) from (c) directly.

**Suggested next steps (not executed):** add loadavg/IB-counter sampling to
the capture; enlarge the sample to estimate the slow-mode frequency; re-run
this series after GPUDirect is fixed to isolate the placement factor.

