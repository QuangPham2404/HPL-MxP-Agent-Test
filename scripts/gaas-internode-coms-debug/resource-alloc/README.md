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

- **Status:** in progress (scripts drafted 2026-09-07:
  `debug-scripts/run_3x4_alloc_variance.pbs` +
  `debug-scripts/capture_node_alloc.sh`; attempts `alloc250k_v1..v5`
  submitted sequentially).
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

(To be recorded here after the experiment runs complete; no results or
analysis yet.)
