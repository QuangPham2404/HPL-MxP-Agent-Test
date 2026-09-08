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

### Experiment 2 — Clean-node vs dirty-node series (N=250k, 3+3 jobs)

- **Status:** interim (2026-09-08). Clean series complete (3/3 `PASSED`);
  dirty v1 `PASSED`; dirty v2 queued (waiting for a pinned node's co-tenant
  job to end); dirty v3 pending. One failed attempt (`clean250k_v1`,
  submission-spec defect) recorded below.
- **Purpose:** separate the ~16x catastrophic contention mode observed in
  experiment 1 (attributed to external co-tenant host/fabric load) from the
  constant CPU/GPU/NUMA placement mismatch, by holding the placement
  dimension fixed-ish and deliberately varying the co-tenant dimension:
  run the identical benchmark on nodes that start completely free vs nodes
  already running other jobs, with in-run host-load and IB-counter sampling
  to time-stamp any co-tenant arrival or departure.
- **Method:** 6 sequential host-pinned jobs, config identical to experiment 1
  (same scheduler chunk shape per node — `select=<host>:ngpus=4:ncpus=48:
  mem=1000GB`, matching experiment 1's actual recorded request; job 59932
  shows `3:ngpus=4:ncpus=48:mem=1000GB` — same launch path, flags,
  N=250000, 3x4 row grid, no binding flags). Nodes are pinned
  explicitly at submission via
  `qsub -l "select=host=A:ngpus=4:ncpus=48:mem=1000GB+..."`
  (hosts chosen from a live `pbsnodes -aSj` check immediately before each
  submission; the run script asserts granted == requested nodes).
  - `clean250k_v1..v3`: nodes completely free at submission (njobs=0, 8/8
    GPUs and 100/100 CPUs free), preferring the g20-g25 range when free
    nodes exist there. Nodes are `default_shared`, so co-tenants may still
    arrive mid-run: the run is completed and the arrival is recorded from
    the sampler time series (user decision 2026-09-08: no whole-node hold,
    keep the experiment-1-identical request).
  - `dirty250k_v1..v3`: nodes already running other jobs, preferring
    GPU-busy nodes (co-tenant jobs using the other GPUs), requiring >=4
    free GPUs and >=48 free CPUs so our chunk fits. Co-tenant job IDs and
    their remaining walltime are recorded at submission, plus an in-job
    `pbsnodes` listing in the pre-run capture.
- **Execution findings and approved design change (2026-09-08):**
  - GAAS nodes are partitioned by a `Qlist` queue-affinity resource:
    g06-g17 serve queue `gpu_as`; g01-g05/g20-g22 serve `gpu_ded`;
    g18/g19/g23/g24 serve `gpu_aisg`; g25 serves `gpu_free`. The `gpu_as`
    queue forces `default_chunk.Qlist=gpu_as`, so jobs in `gpu_as` can
    never be pinned to the g20-g25 range — that range looks idle precisely
    because it belongs to other queues. First submission (job `60449.gaas`,
    pinned to g22+g16+g14) could never start ("Insufficient amount of
    resource: Qlist") and was deleted; no run evidence lost.
  - Within `gpu_as`, only g14 and g16 were completely free (for ~19 h;
    queued small jobs were not being placed), and no third node would free
    up soon (co-tenant jobs elsewhere had days of walltime left). User
    approved a **relaxed clean condition**: clean runs pin g14 + g16
    (pristine) + g10 (lightest co-tenant available: one 12-cpu/1-GPU job,
    `down22`, ~88 h remaining), all within queue `gpu_as` for comparability
    with experiment 1 and the dirty series. The g10 co-tenant is recorded
    per attempt and visible in the sampler time series.
  - Dirty-series candidates identified: g11 (co-tenant 60315: 48 cpus + 4
    GPUs, ~69 h remaining) and g13 (co-tenants 59192/59442/59443: 36 cpus
    + 3 GPUs, days remaining).
- **New instrumentation vs experiment 1** (per the professor's suggested
  measurements, all verified available on GAAS):
  1. In-run per-node sampler (`debug-scripts/sample_node_load.sh`,
     background pbsdsh, 10 s interval, sentinel stop + tick-cap failsafe):
     `/proc/loadavg`, `/proc/stat`, meminfo/vmstat subsets, `/proc/pressure`
     if present, per-NUMA `numastat` (local vs remote memory activity), all
     mlx5 IB port counters from sysfs (xmit/rcv bytes+packets, discards,
     wait, error/recovery counters), and per-GPU
     utilization/power/clocks/memory for the 4 allocated GPUs. The
     node-global metrics intentionally include co-tenant load — that is the
     quantity under test. Per-GPU sampling still cannot see co-tenant GPUs
     (cgroup limitation, same as experiment 1).
  2. Pre-run and post-run per-node capture v2
     (`debug-scripts/capture_node_alloc_v2.sh`): the full experiment-1
     capture (cpuset, Mems_allowed, NUMA cpulists, GPU inventory with PCI
     buses + UUIDs, topo matrix, ibdev2netdev, per-NIC NUMA, container GPU
     view) plus a one-shot IB counter baseline, per-port link state/rate,
     numastat, load/PSI snapshot, and an in-job `pbsnodes` co-tenant
     listing — written to per-node files instead of interleaved stdout.
  3. `NCCL_DEBUG=INFO` (full) exported into the container next to
     `UCX_LOG_LEVEL=info`: UCX logs cover only the MPI side; NCCL is the
     likely main HPL-MxP communication path and its transport/rail choice
     is recorded per rank.
- **Operational decisions (user, 2026-09-08):** dirty = GPU-busy nodes
  preferred; clean = identical request (no `ngpus=8` hold), record mid-run
  arrivals; NCCL full INFO; qdel pre-authorized for this experiment's own
  stuck submissions only (host taken by another job), each recorded with
  reason.
- **Planned attempts:** `clean250k_v1..v3`, `dirty250k_v1..v3`; evidence
  under `outputs/` with attempt-specific names (`.o`/`.e` plus per-node
  `_pre_`/`_load_`/`_post_` logs, never overwritten).
- **Failed attempt record — `clean250k_v1` (job `60453.gaas`, 2026-09-08,
  19:12):** exit 137 ~40 s into the run, `cgroup/OOM: Killed because of
  memory limit` during matgen. Cause: the submission's host-pinned select
  omitted the per-chunk `ncpus=48:mem=1000GB` that experiment 1 actually
  used (its script comment documented only `select=3:ngpus=4`), so each
  chunk received the server-default memory and the job cgroup limit killed
  the app almost immediately. Deterministic submission-spec defect; retry
  as `clean250k_v1.1` with the corrected select. Evidence preserved:
  `outputs/clean250k_v1.{o,e}` + per-node `_pre_/_load_/_post_` logs
  (pre/post captures and 2 sampler ticks completed; no benchmark result).

## Analysis

### Experiment 2 interim results (2026-09-08)

**Runs so far** (N=250000, NB=1024, 3x4 row grid, 12 ranks, host-pinned;
clean = g14+g16 pristine + g10 light co-tenant; dirty v1 = g11+g13 heavy
GPU co-tenants + g10; all `PASSED`, exit 0):

| Attempt | Job | Walltime | GFLOPS (total) | GFLOPS/GPU | vs baseline total (4.0092e+04) | vs baseline per GPU (3340.96) | LU s | Solver s | RNG s AVG (MAX node) | matgen s |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---:|
| clean250k_v1.1 | 60454 | 1:18 | 8.4396e+05 | 70330 | +2005% | +2005% | 6.67 | 5.67 | 13.85 (g16 16.48) | 21.61 |
| clean250k_v2 | 60458 | 1:16 | 8.2255e+05 | 68546 | +1952% | +1951% | 7.02 | 5.65 | 13.13 (g16 16.19) | 21.24 |
| clean250k_v3 | 60459 | 1:19 | 7.3008e+05 | 60840 | +1721% | +1721% | 6.83 | 7.45 | 12.94 (g16 15.89) | 21.06 |
| dirty250k_v1 | 60461 | 7:19 | 3.3263e+04 | 2772 | −17% | −17% | 269.64 | 43.98 | 20.93 (g11 39.46) | 59.70 |

Baseline-reference caveat: the original 3x4 baseline (job `57232.gaas`)
ran N=480000; the percentage columns compare GFLOPS/GPU directly and
understate the clean series' advantage at equal N (per-GPU efficiency
grows with N, so at N=480k the clean-condition margin would be larger).

**Findings so far:**

1. **The clean condition is fast and reproducible**: 60,840–70,330
   GFLOPS/GPU with ~1:20 walltimes — 18–21x the original baseline per GPU,
   and ~1.6x experiment 1's best (v5: 43,288/GPU, which ran on co-tenant
   nodes). The 3x4 topology itself is healthy.
2. **The dirty condition reproduces the slow mode deliberately**: 2,772
   GFLOPS/GPU, LU 269.6 s (40x the clean runs), solver 44.0 s (7x), RNG
   MAX 39.5 s on the co-tenant node (3x), matgen 59.7 s (2.8x) — matching
   experiment 1's v1-v4 slow mode (2,572-2,857/GPU) and the original
   baseline's magnitude. The bimodality is now causally tied to co-tenant
   node condition, not to our job's own placement.
3. **The contention is host-side, not fabric-side**: total IB bytes moved
   by the app are identical (~42.3-42.8 GB per node) in clean and dirty
   runs, and the dirty nodes' counters show ≈0 extra fabric traffic from
   co-tenants (g13: +0.27 GB over the app's baseline over 404 s). The app
   just takes 7.8x longer to move the same bytes. Combined with the
   parent-track finding that the container's UCX uses the host-staged
   `cuda_cpy` path (GPUDirect off inside the container), the slow mode is
   consistent with co-tenants contending for the host-side resources the
   staged path depends on (DDR bandwidth / PCIe / LLC), not with
   switch-side IB congestion.
4. **Co-tenant CPU load alone was modest**: from /proc/stat deltas, our
   own app uses ~24 busy CPUs per node in fast mode and ~15 in slow mode
   (ranks wait on comms); g13's three co-tenant jobs added only ~16 busy
   CPUs and g11's co-tenant (a resource-holding idle session, job 60315)
   added ≈0 — yet LU still collapsed 40x. CPU-cycle starvation cannot
   explain the magnitude; memory-bandwidth/PCIe contention remains the
   leading candidate mechanism (not yet directly measured — see
   limitations).
5. **Placement mismatch is definitively not the differentiator**: the
   pristine clean runs received cross-NUMA allocations (g14/g16: socket-1
   GPUs `9A/BB/CD/DC` with socket-0 cpuset `0-47`, 76-86% remote-memory
   fraction in numastat deltas) and were the fastest runs of the series.
   Dirty v1's allocations were no worse. This confirms experiment 1's
   finding 3 with the strongest possible contrast.
6. **GPU starvation signature reproduced**: sampler medians show the
   allocated GPUs near-idle (~117-131 W, 0% utilization medians) through
   the 7-minute dirty run — the exp1 monitor observation, now with
   per-node in-run evidence.

**Limitations (interim):** memory-bandwidth contention is inferred
(consistent resource arithmetic), not directly measured — no PCM/MBW
counters were sampled; the dirty series has 1 of 3 replicates; g10
participates in both conditions (light co-tenant; its clean-series
behavior bounds its impact — the clean series was fast with g10 in it);
PSI was unavailable (`/proc/pressure` absent on GAAS compute nodes).

**Pending:** dirty v2 (queued behind co-tenant job `60466` on g13, ETA
~22:30), dirty v3, final analysis update.

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

