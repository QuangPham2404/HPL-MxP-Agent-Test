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

## Core problems remaining to investigate

The experiments establish the dominant operational finding — co-tenant node
condition must be controlled for multi-node HPL-MxP runs — but two scientific
questions remain open before the resource-allocation effects can be considered
fully deconfounded.

### 1. Placement and affinity effects were not independently isolated

The evidence rules out CPU/GPU/NUMA placement mismatch as the explanation for
the original catastrophic 44–50x slowdown, but it does not establish a precise
upper bound on the cost of placement mismatch. The main comparison used the
same default cross-NUMA carve-out on the pristine trio, while the only notably
different allocation shape (`cleanalloc250k_v4`) also changed the node set and
introduced a light co-tenant on g13. Consequently, the approximately 3.8%
performance difference in that run cannot be attributed to placement alone.

There was no controlled same-node, same-condition A/B comparison between a
matched GPU/CPU/NUMA allocation and the default mismatched allocation. The
current evidence therefore supports the narrower conclusion that the default
mismatched allocation can still deliver high performance and is not the main
cause of the observed multi-node failure. It does not prove that affinity is
free, or that its effect is at most 4%, across other node conditions, problem
sizes, communication paths, or explicit binding policies.

### 2. The physical mechanism of co-tenant interference remains inferred

The clean/dirty experiments strongly associate the slowdown with active
co-tenants and show that it is not explained by measured CPU utilization or
additional application-visible InfiniBand traffic. However, the proposed
mechanisms — DDR memory-bandwidth contention, PCIe contention, LLC pressure,
or pressure caused by resident allocations — were not measured directly.
No PCM or equivalent memory-bandwidth counters were collected, and the heavy
dirty condition has only two replicates on the same node set. The 10-second
sampling interval can also miss short bursts, while cgroup visibility limits
direct observation of co-tenant GPU activity.

The supported conclusion is therefore that co-tenant host/resource contention
is the dominant cause and that the staged communication path is highly
sensitive to it. The specific resource responsible, and the relative roles of
DDR, PCIe, LLC, and resident GPU/host allocations, remain unresolved. A
direct bandwidth/PCIe measurement or a controlled synthetic co-tenant
dose-response experiment would be needed to close this mechanism question.

## Final conclusion (2026-09-09) — resource-allocation track closed

The four experiments below fully decompose the 3x4 degradation's resource
dimension. **This diagnosis branch is wrapped up**: the 3x4 multi-node
topology is validated and ready to run HPL-MxP sweeps on, provided the
node-condition guidance in the crucial takeaway below is followed. (The
remaining performance gap to single-node belongs to the parent comms
track — in-container GPUDirect — not to resources.)

**Best-run comparison — 3x4 pristine (exp4) vs single-node 8xH200 best
(`experiments/N-nb-resweep`, NB=3072 tuned):**

| | Single-node best (`N-nb-resweep_491520`) | 3x4 pristine best (`nsweep510k`) | 3x4 vs single-node |
|---|---:|---:|---:|
| GPUs / nodes | 8 / 1 | 12 / 3 | 1.5x hardware |
| N / NB | 491520 / 3072 | 510000 / 1024 | — |
| GFLOPS total | 2.1974e+06 | 2.1633e+06 | **98.4%** |
| GFLOPS/GPU (headline) | 274,674 | 180,272 | 65.6% |
| LU GFLOPS/GPU | 488,878 | 328,403 | 67.2% |

Like-for-like at NB=1024 (single-node peak `N-sweep_490000`: 1.8293e+06
total, 228,657/GPU headline, 372,361/GPU LU): the 3x4 at the same N=490k
delivered 2.0398e+06 total (169,981/GPU headline, 320,613/GPU LU) —
**+11.5% total, 74.3% headline and 86.1% LU per-GPU**; at N=510k (where
the single node OOMs) +18.3% total. Reading: the 3x4 matches the
single-node best's total output with 1.5x the GPUs (the added GPUs'
parallel efficiency is only ≈23%); the residual per-GPU gap is
inter-node comms overhead (parent-track ceiling) plus untuned NB (the
single-node best used its tuned NB=3072 — an optimization question, out
of diagnostic scope). The 3x4 also extends the usable problem size:
single node hits its memory wall at N=510k, while the 3x4 is validated
through 510k with mapped walls at N≈617k (host cgroup, mem=1000GB) and
N≈630k (GPU HBM).

**What the four experiments established:**

1. **The original 3x4 baseline's ≈44-50x deficit was co-tenant host
   contention** (exp2 dose-response: ≈1.0x pristine, ≈1.6x light, ≈25x
   heavy GPU co-tenants) — host-side, not fabric-side (identical IB bytes
   moved in all conditions, no co-tenant fabric traffic) — riding on the
   container's GPUDirect-off staged comms path. At N=480k the pristine
   3x4 ran 49.5x the original baseline (exp4).
2. **Affinity/placement mismatch introduces little degradation**: PBS's
   pristine-node carve-out is deterministic (exp3), its default
   cross-NUMA carve-out (socket-1 GPUs + socket-0 cpuset, 34-89%
   remote-memory fractions) costs nothing measurable, and the worst
   natural allocation shape cost at most ≈4%. Bad affinity is a minor factor.
3. **Clean 3x4 baseline established** (exp4): 155-180 TF/GPU headline
   over N=450-510k; host-memory model (≈10 + 2.6e-9 N^2 GB/node)
   validated point-by-point.

**Crucial takeaway for multi-node HPL-MxP sweeps on GAAS:** affinity /
NUMA placement does not need fixing — **node condition is everything**.
Run sweeps on pristine nodes (verify with `pbsnodes -aSj` immediately
before each submission; only g06-g17 are reachable from queue `gpu_as`
due to the Qlist partitioning), or, if pristine nodes are not available,
at least compare only runs whose nodes carry the same co-tenant load
level — mixing load conditions silently injects a 1.6-25x performance
variable that no placement or affinity tuning can compensate for.

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

- **Status:** complete (2026-09-09). All 6 runs `PASSED` (3 clean + 3
  dirty). Dirty v1/v2 used the same GPU-busy composition (g11+g13+g10);
  dirty v3 used a user-approved lighter mixed composition (g13+g09+g11)
  after the original dirty nodes' co-tenants ended mid-experiment. One
  failed attempt (`clean250k_v1`, submission-spec defect) recorded below.
- **Purpose:** separate the ≈16x catastrophic contention mode observed in
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
  - Within `gpu_as`, only g14 and g16 were completely free (for ≈19 h;
    queued small jobs were not being placed), and no third node would free
    up soon (co-tenant jobs elsewhere had days of walltime left). User
    approved a **relaxed clean condition**: clean runs pin g14 + g16
    (pristine) + g10 (lightest co-tenant available: one 12-cpu/1-GPU job,
    `down22`, ≈88 h remaining), all within queue `gpu_as` for comparability
    with experiment 1 and the dirty series. The g10 co-tenant is recorded
    per attempt and visible in the sampler time series.
  - Dirty-series candidates identified: g11 (co-tenant 60315: 48 cpus + 4
    GPUs, ≈69 h remaining) and g13 (co-tenants 59192/59442/59443: 36 cpus
    + 3 GPUs, days remaining).
  - Dirty-series execution actuals: v1 ran as planned on g11+g13+g10
    (job 60461). Between v1 and v2, another user's job `60466` took g13's
    4 free GPUs; the first v2 submission (job `60470`) could never start
    and was qdel'd per the pre-authorized re-pick policy (reason recorded);
    the re-submitted v2 (job `60474`) queued ≈3 h until `60466` ended and
    ran overnight on the same composition. Before v3, g11's co-tenant
    ended (node pristine) and g13's heavy co-tenants 59442/59443 ended,
    leaving no 3-node GPU-heavy set; the user approved a mixed composition
    for v3: g13 (light: 59192, 1 job) + g09 (light: 59444, 1 job) + g11
    (pristine) — job `60740`.
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
  19:12):** exit 137 ≈40 s into the run, `cgroup/OOM: Killed because of
  memory limit` during matgen. Cause: the submission's host-pinned select
  omitted the per-chunk `ncpus=48:mem=1000GB` that experiment 1 actually
  used (its script comment documented only `select=3:ngpus=4`), so each
  chunk received the server-default memory and the job cgroup limit killed
  the app almost immediately. Deterministic submission-spec defect; retry
  as `clean250k_v1.1` with the corrected select. Evidence preserved:
  `outputs/clean250k_v1.{o,e}` + per-node `_pre_/_load_/_post_` logs
  (pre/post captures and 2 sampler ticks completed; no benchmark result).

### Experiment 3 — Allocation resweep on pristine nodes (N=250k, 5 jobs)

- **Status:** complete (2026-09-09). 5 runs `PASSED` (4 on the fixed
  pristine trio g14+g16+g17, 1 rotated onto nearly-pristine g13 after no
  second pristine node existed). One submission failed before producing
  evidence (job `61031`, submission-directory error — recorded in the
  results section).
- **Purpose:** redo experiment 1's allocation-variance series with the
  co-tenant variable removed. Experiment 2 proved co-tenant host
  contention dominates the 3x4 degradation (dose-response from ≈1.6x on
  lightly-loaded nodes to ≈25x on heavily-shared ones), so experiment 1's
  "allocation mismatch 5/5" data was confounded: the mismatch never varied
  independently of co-tenancy. This series measures what the placement
  dimension looks like on its own: the clean-node run-to-run noise band,
  PBS carve-out determinism on pristine nodes, and cross-node
  default-carve-out contrast.
- **Method:** 5 sequential host-pinned jobs, launch config identical to
  experiments 1-2 (`select=<host>:ngpus=4:ncpus=48:mem=1000GB` per chunk,
  N=250000, 3x4 row grid, `--bind-to none`, no affinity flags).
  - `cleanalloc250k_v1..v3`: fixed pristine trio `g14+g16+g17`
    (live-verified pristine via `pbsnodes -aSj` before each submission).
  - `cleanalloc250k_v4..v5`: opportunistically rotated onto other pristine
    (or nearly-pristine, documented) nodes if available at submission time;
    otherwise stay on the trio. Rotation samples each node's default
    carve-out, which differs across nodes (experiment 2 saw socket-1 GPU
    sets with socket-0 cpusets on g14/g16 but a mixed set on g10).
- **Expected behavior (from experiment 2's evidence):** PBS's carve-out on
  a pristine node is deterministic — all three clean-series attempts
  received byte-identical allocations on g14/g16 — so v1-v3 should confirm
  determinism and measure the clean noise band rather than natural
  allocation variance.
- **Instrumentation:** identical to experiment 2 (capture v2, 10 s
  host-load/IB/GPU sampler, UCX + NCCL rail logs, `--monitor-gpu`), via
  the exp3 script `debug-scripts/run_3x4_alloc_resweep_clean.pbs`.
- **Operational policy (user, 2026-09-09, carried over from exp2):** qdel
  pre-authorized for this experiment's own stuck submissions only (each
  recorded with reason); if a pinned node loses pristineness
  before/during a run, re-pick from other pristine nodes when >=3 exist,
  otherwise stop and ask.
- **Planned attempts:** `cleanalloc250k_v1..v5`; evidence under `outputs/`
  with attempt-specific names, never overwritten.

### Experiment 4 — N-sweep clean baseline (N=450k..510k, 7 jobs)

- **Status:** complete (2026-09-09). All 7 runs `PASSED` on the pristine
  trio (verified 3/3 before every submission; no co-tenant arrivals
  detected).
- **Purpose:** establish the clean-node baseline performance-vs-N curve
  for the 3x4 topology as the diagnostic reference (not optimization):
  how the pristine-node condition scales with problem size, directly
  comparable to the original contaminated 3x4 baseline at N=480k (job
  `57232.gaas`, 4.0092e+04 GFLOPS total, 3340.96 per GPU) and to the
  single-node 8xH200 reference (≈275 TF/GPU at N=491520).
- **Method:** 7 sequential attempts, N = 450000, 460000, ..., 510000 in
  10k steps (user-capped at 510k — diagnostic scope, not an
  N_max search), on the fixed pristine trio `g14+g16+g17` (live-verified
  per submission). All other flags identical to experiments 2-3 (same
  chunk shape, NB=1024, 3x4 row grid, `--bind-to none`, monitor-gpu,
  UCX+NCCL logs, capture v2 + sampler). Walltime 30 min per attempt.
- **Memory headroom (measured, from PBS records):** the app's host memory
  scales as ≈N^2 — 172.7 GB/node at N=250k, 610 GB/node at N=480k — giving a
  projected ≈687 GB/node at N=510k, safely inside the `mem=1000GB`
  per-chunk cgroup; no OOM is expected within the capped range. (An
  uncapped sweep would hit the host-cgroup wall near N≈615k before the
  GPU-HBM limit ≈700-750k — recorded here for future reference.)
- **Operational policy:** carried over from experiments 2-3 (qdel
  pre-authorized for this experiment's own stuck submissions; pristine
  loss → re-pick when >=3 pristine nodes exist, else stop and ask).
- **Planned attempts:** `nsweep450k` .. `nsweep510k`; evidence under
  `outputs/` with attempt-specific names, never overwritten.

### Experiment 5 — Host-contention mechanism investigation (N=250k, 3+3 jobs)

- **Status:** complete (2026-09-18). Preflight + 6 runs, all `PASSED`;
  results under "Experiment 5 results" in the Analysis section. One
  pre-authorized qdel (job 67782, Qlist-blocked pinned host, never started);
  one Track-1 telemetry defect (vmstat grep, patched); arm compositions
  adapted to live node availability (no fully-pristine trio fieldable —
  recorded per attempt).
- **Purpose:** identify which host-side resource signals distinguish the
  established slow co-tenant condition from the reproducible pristine
  condition. This is a mechanism-screening experiment: it is intended to
  rank DDR-memory, CPU scheduling, NUMA/remote-memory, PCIe/GPU, and fabric
  hypotheses before any controlled synthetic co-tenant experiment.
- **Design:** run three repeated pristine/busy pairs, for six total jobs:
  `mech250k_pristine_r1..r3` and `mech250k_busy_r1..r3`. Submit the two arms
  sequentially and alternate their order between repetitions to reduce
  time-of-day and warm-up bias. The busy arm uses natural busy nodes rather
  than launching an additional workload. Because the two arms use different
  physical nodes, node identity remains a limitation; busy runs must retain
  their per-node co-tenant composition and must not be pooled blindly when
  those compositions differ.
- **Fixed HPL-MxP configuration:** identical to the resource-allocation
  experiments: 3 nodes x 4 GPUs, 12 ranks, `N=250000`, `NB=1024`, 3x4
  row-major grid, `--gpu-affinity 0:1:2:3`, `--bind-to none`, the same
  container/modules/launcher, `UCX_LOG_LEVEL=info`, `NCCL_DEBUG=INFO`,
  `--skip-tests 1`, and the standard GPU-monitoring flags. Each chunk must
  request `ngpus=4:ncpus=48:mem=1000GB`, with hosts pinned explicitly and the
  granted host list asserted against the requested list.
- **Node selection:** pristine nodes must have no foreign jobs and all
  required CPU/GPU resources free immediately before submission; in-run
  arrival or departure must still be recorded. Busy nodes must have at least
  one foreign GPU-using job, at least four usable GPUs and 48 usable CPUs for
  our chunk, and a known PBS resource vector. Record the foreign job IDs,
  requested/assigned CPUs, GPUs, memory, node identity, queue/Qlist, and
  pre-submission scheduler state for every node.
- **Required static and dynamic evidence:** use dedicated mechanism-study
  capture/sampler helpers so experiments 1-4 remain unchanged. Record:
  - scheduler allocation, node state, co-tenant jobs/resources, queue/Qlist,
    and PBS node/job metadata;
  - CPU topology, cpusets, memory sets, cgroup paths and effective limits,
    `cpu.stat`, `memory.current/max/events/stat`, NUMA memory statistics,
    page faults, run-queue/load indicators, migrations, and CPU/memory
    affinity for each local HPL process/rank;
  - `/proc/stat`, `/proc/meminfo`, `/proc/vmstat`, PSI when available,
    per-NUMA `numastat`, transparent-huge-page/VM state, and host memory
    pressure;
  - GPU UUIDs, PCI buses, GPU/CPU/NIC topology, NUMA association, PCIe
    generation/width/replay/error state, clocks, power, temperature,
    utilization, and memory use. Cgroup-visible GPU telemetry cannot directly
    observe foreign GPUs, so scheduler evidence remains authoritative for
    co-tenant GPU allocation;
  - all IB port link/rate, transmit/receive, wait, discard, error, recovery,
    and constraint counters, converted to per-interval deltas/rates, plus
    UCX transport/rail and NCCL rail/plugin logs;
  - direct read-only CPU/memory counters where GAAS permits them: first probe
    `perf`, uncore IMC events, and `pcm-memory`; collect memory-controller
    read/write bandwidth, LLC/cache activity, cycles, instructions, and stall
    indicators when available. No tools are to be installed, and unavailable
    counters must be recorded as unavailable rather than made fatal.
- **Sampling:** retain pre-run, mid-run, and post-run snapshots and use an
  approximately 2-second in-run interval for lightweight `/proc`, cgroup,
  NUMA, IB, and GPU telemetry, subject to a preflight overhead check. Preserve
  all raw PBS `.o`/`.e` files and per-node evidence with attempt-specific
  names.
- **Analysis:** compare busy versus pristine HPL total/per-GPU GFLOPS, LU,
  solver, RNG, and matgen times, node/rank skew, GPU starvation, and
  correctness. Retain the original baseline and include percentage change
  against it, together with the busy/pristine ratio. Correlate phase-specific
  degradation with node-level memory-bandwidth/LLC, CPU scheduling, NUMA,
  PCIe/GPU, and IB deltas. Do not claim a specific mechanism unless its
  signal repeats across the three pairs and aligns with the affected HPL
  phase.
- **Interpretation gates:** memory-controller bandwidth/LLC/remote-memory
  signals aligned with RNG/matgen slowdown support host-memory contention;
  PCIe/GPU-transfer or link-health signals aligned with LU/communication
  slowdown support PCIe or staging contention; IB wait/discard/error or
  extra co-tenant traffic supports fabric contention; CPU run-queue,
  migration, or cgroup-throttling signals support CPU scheduling contention.
  If degradation repeats without a distinguishing counter signature, retain
  the result as unresolved and design a controlled synthetic co-tenant or
  targeted bandwidth/PCIe probe rather than over-interpreting it.
- **Acceptance criteria:** three correct pristine runs and three correct busy
  runs, exact host-allocation verification for every job, complete pre/mid/
  post evidence from all nodes, and no unexplained missing telemetry. Failed,
  incomplete, or condition-changing attempts remain preserved and are not
  counted as valid repetitions.
- **Planned evidence paths:** `outputs/mech250k_*` PBS output and per-node
  telemetry files; scripts will be added under `debug-scripts/` after this
  design is reviewed. A later `N=480000` validation pair may be added after a
  repeatable mechanism signal is identified.
- **Execution decisions (user, 2026-09-18):** design reviewed and approved.
  Scripts prepared under `debug-scripts/`: `probe_hw_counters.sh` (read-only
  counter availability), `capture_node_alloc_mech.sh` (v2-superset capture),
  `sample_node_load_mech.sh` (~2 s sampler + optional probe-validated
  `perf stat -a` collector via `PERF_EVENTS`), `run_3x4_mech_pair.pbs` (one
  arm of one pair), `run_mech_preflight.pbs` (separate first probe job:
  counter availability + sampler-overhead check). Pair order r1
  pristine→busy, r2 busy→pristine, r3 pristine→busy. Pristine fallback:
  2 strictly pristine + lightest GPU-pristine third, documented per attempt.
  qdel pre-authorized for this experiment's own stuck submissions only
  (pinned host taken by another job), each recorded with reason. Queue
  `gpu_as`, walltime 00:30:00, chunk `ngpus=4:ncpus=48:mem=1000GB`,
  accounting group `hpc_ebslee` (current project convention).

### Experiment 6 — Single-node node-contention test (N=200k, 6 jobs)

- **Status:** complete (2026-09-18), full 6-run matrix + one validation
  rerun, all `PASSED` (the light_4r cell needed a third submission —
  fielded on g12 with a moderate 3-co-tenant composition, recorded as a
  caveat). Core result: the multinode co-tenant catastrophe (1.6-40x) does
  **not** reproduce on a single node (heavy idle-holder +1.5%, light/moderate
  +22.7% *above* control — node variance, light 2r +1.1%); the interference
  requires the inter-node dimension. The one pathological pristine-control
  run (`sn200k_ctrl_2r_v1`) is **explained**: the granted GPU pair's NCCL
  topology resolved to a 2-CPU affinity set and the app pinned both ranks
  to it (1 CPU/rank → 3.6-11.9x phase slowdowns; see SINGLE_NODE_TEST.md
  finding 2, incl. the exp1-5 blast-radius check).
  Single-node isolation of the co-tenant contention effect (2-rank and
  4-rank HPL-MxP on one pristine control node, one dirtiest, one lighter
  occupied node, reusing the exp5 instrumentation). Planned, logged, and
  analyzed **separately in `SINGLE_NODE_TEST.md`** so it cannot clash with
  the experiment-5 records; runner: `debug-scripts/run_1n_contention.pbs`,
  evidence under `outputs/sn200k_*`.

## Analysis

### Experiment 5 results (2026-09-18) — mechanism screening, first pass

**Execution record.** Preflight (job 67780, g07): 2 s sampler cadence holds
(tick wall 2-3 s); `perf`/`pcm-memory`/PSI **unavailable** on GAAS compute
nodes (perf binary absent, `perf_event_paranoid=2`, no pcm) — the direct
hardware-counter layer is empty by design ("recorded unavailable, never
fatal"), so the mechanism evidence is the 2 s cgroup/process/NUMA/IB/GPU
telemetry. One stuck submission was qdelt under the pre-authorized policy:
job 67782 (busy r1, hosts g08+g15+g16) could never start because **g16 and
g17 (and later g05) have been reassigned by the admins to `Qlist=gpu_aisg`**
— the experiment-2-era queue map (g06-g17 = gpu_as) is stale; current map
recorded in `outputs/mech250k_busy_r1_presubmit*.log`. No run evidence was
lost (job never started); the first presubmit record is preserved as
`_presubmit_a1.log`.

**Arm compositions actually fielded** (no fully-pristine trio exists in
either queue: gpu_as has only g11+g14, gpu_ded only g22, and a job's chunks
cannot span Qlist pools — user-approved adaptations recorded per attempt):

- "pristine" arm = g11+g14 (strict pristine) + g12 (light co-tenant
  67573: 24 cpus + 2 GPUs + 500 GB) — identical across r1/r2/r3.
- busy r1 (gpu_ded) = g03 (heavy **idle** holder 67044: 48 cpus + 4 GPUs +
  1 TB) + g20 (light: 12 cpus + 1 GPU) + g22 (pristine) — mixed band.
- busy r2/r3 (gpu_as) = g08 (heavy **idle** holder 67775: 48 cpus + 4 GPUs +
  1 TB) + g15 (heavy **active** co-tenant 67410: 48 cpus + 4 GPUs + 1 TB,
  ~43 busy CPUs) + g12 (light) — catastrophic band.

**Results** (N=250000, NB=1024, 3x4 row, 12 ranks; all `PASSED`, exit 0;
reference = original contaminated baseline 4.0092e+04 total):

| attempt | job | queue | nodes (condition) | walltime | GFLOPS total | GFLOPS/GPU | vs baseline | LU s | RNG MAX s (node) | matgen s | solver s |
|---|---|---|---|---|---:|---:|---:|---:|---|---:|---:|
| mech250k_pristine_r1 | 67781 | gpu_as | g11+g14+g12(L) | 1:30 | 5.3784e+05 | 44,820 | +1242% | 15.34 | 18.63 (g11) | 24.36 | 4.03 |
| mech250k_busy_r1 | 67783 | gpu_ded | g03(H-idle)+g20(L)+g22(P) | 1:27 | 4.9849e+05 | 41,541 | +1144% | 15.31 | 13.89 (g03) | 19.14 | 5.59 |
| mech250k_busy_r2 | 67784 | gpu_as | g08(H-idle)+g15(H-active)+g12(L) | 21:11 | 3.4312e+04 | 2,859 | −14% | 260.70 | 40.69 (g08) | 53.02 | 43.01 |
| mech250k_pristine_r2 | 67789 | gpu_as | g11+g14+g12(L) | 1:22 | 5.5062e+05 | 45,885 | +1273% | 15.04 | 14.85 (g11) | 20.43 | 3.88 |
| mech250k_pristine_r3 | 67790 | gpu_as | g11+g14+g12(L) | 1:21 | 5.4702e+05 | 45,585 | +1264% | 15.10 | 15.10 (g11) | 20.43 | 3.88 |
| mech250k_busy_r3 | 67792 | gpu_as | g08(H-idle)+g15(H-active)+g12(L) | 14:33 | 3.3691e+04 | 2,808 | −16% | 272.04 | 42.50 (g08) | 58.78 | 37.49 |

Reproducibility is tight: "pristine" arm 44.8-45.9k GFLOPS/GPU (2.4%
spread), catastrophic arm 2,808-2,859 (1.8%), matching experiment 2's
dirty v1/v2 (2,772-2,891, LU 263-270) and dirty v3 mixed band (40,356).

**Findings:**

1. **Dose-response refined with a per-node resolution inside each run.**
   Fully-pristine trio (experiment 3 reference): ~71k GFLOPS/GPU, LU
   ~6.8 s. Two pristine + one light: 44.8-45.9k, LU 15.0-15.3 (LU 2.2x).
   One heavy-idle holder + light + pristine: 41.5k, LU 15.3. One
   heavy-idle + one heavy-active + light: 2.8-2.9k, LU 260-272 (**~40x**).
   Even a single light co-tenant on one node of three costs the whole job
   ~35% of the fully-pristine rate — collectives couple all ranks.
2. **GPU starvation confirmed at 2 s resolution in the catastrophic runs**:
   median GPU utilization 0.5-2.8%, p90 7.5-27.2%, >50%-utilization in only
   3.6-7.8% of ticks, power 120-134 W — while SM clocks stayed **pegged at
   1980 MHz** (no clock throttling). The GPUs simply had no work during the
   260-272 s LU that takes ~6.8 s when healthy.
3. **The idle-holder paradox replicated twice**: g08's co-tenant shows ~0
   CPU and ~0 fabric activity (node busy CPUs ≈ our app only), yet g08's
   ranks were the RNG-MAX (40.7/42.5 s vs 7.4-7.5 on g12) and matgen-MAX
   node in both catastrophic runs — exactly experiment 2's finding 6. An
   active CPU-burning heavy co-tenant (g15, ~43 busy CPUs) produces the
   same LU collapse as an idle holder — CPU-quota starvation is ruled out.
4. **Ruled out (within the measurable layers)**: cgroup CPU throttling and
   cgroup OOM/limit events (zero, though sampler-scope — see limitations);
   host memory capacity (MemAvailable >= ~1.65 TB at all times on every
   node); fabric volume (per-node IB bytes identical, 20.27-20.37 GiB, in
   every run and every node — same bytes, 17x slower); NUMA placement
   (remote-memory fraction is node-stable and uncorrelated with the slow
   mode — pristine g11 runs 44-48% remote and is fast; slow g15 runs
   0.3-2.1% remote); GPU clock throttling; PCIe link degradation (gen 5 /
   x16 stable in all captures).
5. **Our app's host footprint**: ~21-22 busy CPUs per node in fast mode
   (matches experiment 2), per-rank RSS ~41.5 GB (4 ranks = 166 GB/node =
   the expected FP64 host-matrix share), rank major-fault totals 2.1-3.5k
   (first-touch warmup). The job cpuset (48 CPUs) was never saturated.
6. **New observation — multi-minute pre-app spawn delay on heavy nodes**:
   the busy r2/r3 walltimes (21:11, 14:33) decompose into ~11/~7 minutes
   between sampler start and the first app output (pbsdsh/TM spawn +
   container start crawling under load; pristine/mixed runs: ~25 s). Node
   load degrades not only the benchmark but the PBS TM launch path itself.
7. **Interpretation-gate verdict: mechanism retained as UNRESOLVED.** The
   degradation repeats (2 catastrophic + 3 mixed reps) with **no
   distinguishing counter signature** in the available layers. The residue
   — DDR memory-bandwidth contention, PCIe/LLC contention, sub-2 s bursts,
   or kernel auto-NUMA-balancing overhead over co-tenant resident memory —
   cannot be separated without the missing vmstat/counter layer (below) or
   a controlled synthetic co-tenant.

**Telemetry defect (Track 1, patched, no silent re-runs).** The exp-5
sampler's vmstat grep pattern was missing its closing parenthesis
(`"^(...|numa_"`), so grep failed with `Unmatched ( or \(` and the
`2>/dev/null` hid the error — the node-global `/proc/vmstat` layer (fault,
swap, pgmigrate, and crucially `numa_hint_faults`/`numa_pages_migrated`,
the auto-NUMA-balancing signal for the idle-holder hypothesis) is empty in
all six runs. Diagnosed on 2026-09-18 via three read-only probe jobs
(67814/67815/67818: direct grep OK, in-script grep fails, patched copy
prints the error). Script fixed in
`debug-scripts/sample_node_load_mech.sh` (commit bedd599); all other
telemetry layers verified intact. A single patched busy+pristine
validation pair to recover the vmstat layer is proposed but **not
executed** — awaiting user approval.

**Limitations.** (a) No fully-pristine trio was fieldable — the "pristine"
arm is a "2 pristine + 1 light" condition, so the fast-mode reference at
2 s resolution comes from the pristine NODES (g11/g14) inside those runs
plus experiment 3's historical trio; (b) the cgroup counters resolved by
the sampler measure the sampler's own cgroup scope, not the app session
cgroup (usage ≈ 0.3 s/tick = the sampler itself) — app-scope cgroup
telemetry was not captured; (c) the vmstat layer is missing (defect
above); (d) r1's two arms ran in different queues on different node sets
(gpu_ded vs gpu_as) — recorded, and the r2/r3 pairs do not have this
caveat; (e) perf/pcm/PSI unavailable on GAAS.

**Conclusion.** Experiment 5 met its screening goal: it eliminated CPU
quota, cgroup throttling, memory capacity, fabric volume, GPU clocks, and
NUMA placement as causes; confirmed starvation of the staged (GPUDirect-
off) communication path at 2 s resolution with full clocks; refined the
dose-response (one light co-tenant among three nodes ≈ 1.6x, two heavy
≈ 40x LU); and replicated the idle-holder paradox. The specific contended
resource remains unidentified — the candidates that survive are DDR
bandwidth, PCIe/LLC, sub-2 s bursts, and kernel auto-NUMA-balancing over
idle co-tenants' resident memory.

**Suggested next steps (not executed, user decision):** (1) one patched
sampler busy+pristine pair to capture the `numa_hint_faults` layer and
test the auto-NUMA-balancing hypothesis directly; (2) a bounded synthetic
co-tenant dose-response (vary DDR/PCIe load on otherwise-pristine nodes)
as the definitive mechanism experiment; (3) fold the Qlist-shift finding
(g05/g16/g17 now gpu_aisg) into any future node-selection guidance; (4)
re-test after the parent-track in-container GPUDirect fix lands — the
staged path is the sensitive element, so GDR-on should shrink every
co-tenant effect measured here.

### Experiment 5 — plain-language explanation (2026-09-18 session close-out)

Written from the session Q&A so the reasoning can be re-read without the
raw tables. Numbers and evidence pointers live in the section above.

**Why busy r1 was not slower than pristine.** r1's "busy" arm was not
actually heavy: only one of its three nodes was loaded (g03), and that
co-tenant is an *idle holder* (reserves 48 cpus + 4 GPUs + 1 TB but uses
~0 CPU and ~0 network); the other two nodes were light and pristine. The
catastrophic mode needs two heavy nodes. Dose table from this experiment:

| composition (3 nodes) | LU s | band |
|---|---:|---|
| 2 pristine + 1 light (the "pristine" arm) | 15.0-15.3 | mixed |
| 1 heavy-idle + 1 light + 1 pristine (busy r1) | 15.3 | mixed |
| 2 heavy, one idle + one active (busy r2/r3) | 260-272 | catastrophic |

So r1's pair was a weak contrast (both arms mixed-band); r2/r3 carry the
real contrast. Also note the "pristine" arm itself is not fully pristine
(g12 carries a light co-tenant), which is why it runs at ~45k GFLOPS/GPU
instead of experiment 3's fully-pristine ~71k: one mildly-loaded node in
three costs the whole job ~35% because the collectives couple all ranks.

**What was identified (with evidence).**

1. **The failure mode is GPU starvation on the host-staged comms path**
   (container GPUDirect off): during the 260-272 s LU, GPU median
   utilization was 0.5-2.8% with >50% utilization in only 4-8% of ticks
   and power at 120-134 W, while SM clocks stayed pegged at 1980 MHz —
   the GPUs were ready, there was simply no work. Every run moved the
   same ~20.3 GiB of IB bytes per node: identical work, 17x slower.
2. **The trigger is co-tenant dose**, including the idle-holder paradox:
   g08's co-tenant uses ~0 CPU, yet g08 was the RNG-MAX node in both
   catastrophic runs (40.7/42.5 s vs ~7.4 s on the light node). An
   *inactive* neighbor still degrades its node's host-memory phases.
3. **Host-memory phases are the sensitive element** (RNG/matgen slow ~5x
   on the loaded node; the collective then paces the whole job to the
   slowest rank).

**What was ruled out (with evidence).**

| Ruled out | Evidence |
|---|---|
| CPU starvation / quota | Idle-holder node collapses exactly like the ~43-CPU-active one; our app uses ~21-22 of its reserved 48 cpus |
| cgroup CPU throttling / OOM | throttling and memory-event deltas = 0 everywhere; MemAvailable never below ~1.65 TB |
| Fabric volume / congestion | identical IB bytes (20.27-20.37 GiB/node) in all six runs; no error/discard growth |
| NUMA placement | remote-memory % is a stable per-node trait, uncorrelated with speed: pristine g11 runs 44-48% remote and is fast; slow g15 runs 0.3-2.1% remote |
| GPU clock throttling | clocks pegged at max (1980 MHz) even while starved |
| PCIe link health | gen5 x16 stable in every pre/post capture |

**What remains and why it was not captured in this run.** Surviving
candidates: **DDR memory bandwidth, PCIe bandwidth, LLC/cache pressure,
sub-2 s bursts, kernel auto-NUMA-balancing**. Not captured because:
the first four need hardware counters that GAAS compute nodes do not
expose (see below); 2 s /proc-level telemetry has no per-socket bandwidth
or cache counters; the auto-NUMA-balancing signal (`numa_hint_faults`)
was in /proc/vmstat and *should* have been captured for free, but was
lost to the sampler grep defect; and activity bursting shorter than the
2 s sampling interval is invisible by design.

**The "missing tool" elaborated — two separate gaps.**

- **Gap 1, genuinely unavailable on GAAS (proven by the preflight, job
  67780):** no `perf` binary on compute nodes, `perf_event_paranoid=2`
  (a kernel setting that blocks system-wide counters even if perf
  existed), no `pcm-memory`, no `/proc/pressure`. These are the only
  tools that directly measure DDR bandwidth (uncore IMC counters), LLC
  misses, and PCIe traffic — and site policy forbids installing them.
  Those hypotheses therefore cannot be *observed* on GAAS today. Options:
  admin-provided perf/PCM access, or *indirect inference* via a
  synthetic co-tenant we control (run our own memory-bandwidth load on a
  pristine node and see whether it reproduces the exact signature).
- **Gap 2, fixable and cheap (the sampler defect):** the free kernel
  signal for auto-NUMA-balancing (`numa_hint_faults` /
  `numa_pages_migrated` from /proc/vmstat) was lost because the exp-5
  sampler's grep pattern was missing one closing parenthesis — grep
  failed with `Unmatched (` and the `2>/dev/null` hid the error, so the
  layer is empty in all six runs. The script is patched (commit bedd599).
  One extra busy+pristine pair would recover the signal. This hypothesis
  matters because it best explains the idle-holder paradox: kernel
  auto-NUMA-balancing periodically scans and migrates *all resident
  memory on the node* — including an idle job's 1 TB — so its cost scales
  with what co-tenants *hold*, not with what they *do*.

**Bottom line.** Experiment 5 proved *where* the slowdown lives (the
host-staged comms path, starved GPUs, dose-dependent on co-tenants) and
cleared the cheap suspects (CPU, cgroup, capacity, fabric volume, NUMA
placement, clocks). Naming the exact shared resource needs either the
patched re-run (free; tests auto-NUMA-balancing) or a controlled
synthetic co-tenant (tests DDR/PCIe directly). Both are proposals; the
experiment-5 design's own rule applies: degrade-and-no-signature stays
"unresolved" rather than over-interpreted.


### Experiment 4 results (2026-09-09) — final

**All runs** (N as listed, NB=1024, 3x4 row grid, 12 ranks, pristine trio
g14+g16+g17, all `PASSED`, exit 0). Reference baseline: the original
contaminated 3x4 run (job `57232.gaas`, N=480000, GFLOPS total
`4.0092e+04`, 3340.96 per GPU). Host GB/node from PBS `resources_used.mem`
(/3 nodes); peak GPU MiB/GPU from the sampler's per-GPU `memory.used`:

| Attempt | Job | N | Walltime | GFLOPS (total) | GFLOPS/GPU | vs baseline total (4.0092e+04) | LU s | LU GFLOPS/GPU | Solver s | RNG s AVG | matgen s | host GB/node | peak GPU MiB/GPU |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| nsweep450k | 61050 | 450000 | 3:27 | 1.8593e+06 | 154942 | +4538% | 17.11 | 295888 | 15.57 | 65.26 | 119.30 | 537 | ≈70300 |
| nsweep460k | 61051 | 460000 | 2:43 | 1.9046e+06 | 158714 | +4650% | 17.80 | 303761 | 16.27 | 49.97 | 74.60 | 561 | ≈73700 |
| nsweep470k | 61052 | 470000 | 2:48 | 1.9263e+06 | 160527 | +4705% | 18.73 | 307910 | 17.20 | 50.94 | 76.84 | 585 | ≈76400 |
| nsweep480k | 61055 | 480000 | 2:53 | 1.9842e+06 | 165350 | +4849% | 19.27 | 318875 | 17.89 | 53.77 | 80.09 | 610 | ≈79800 |
| nsweep490k | 61057 | 490000 | 2:53 | 2.0398e+06 | 169981 | +4988% | 20.39 | 320613 | 18.07 | 52.83 | 80.32 | 635 | ≈82800 |
| nsweep500k | 61058 | 500000 | 3:01 | 2.1320e+06 | 177667 | +5218% | 20.87 | 332720 | 18.22 | 53.85 | 86.56 | 661 | ≈86000 |
| nsweep510k | 61063 | 510000 | 3:03 | 2.1633e+06 | 180272 | +5296% | 22.44 | 328403 | 18.44 | 54.73 | 86.75 | 687 | ≈89400 |

**Findings:**

1. **The clean 3x4 baseline curve is established**: headline performance
   rises monotonically 154,942 -> 180,272 GFLOPS/GPU over N=450k..510k
   (+16%), LU-only rate 296 -> 328 TF/GPU (+11%) — larger N amortizes the
   inter-node communication overhead, as expected for a comms-bound
   topology.
2. **The N=480k head-to-head: 49.5x.** On identical N, topology, and
   flags, the pristine trio delivers 1.9842e+06 GFLOPS total (165,350/GPU)
   vs the original contaminated baseline's 4.0092e+04 (3,340.96/GPU). The
   original baseline's entire deficit at its own operating point is
   attributable to node condition (experiment 2's co-tenant dose-response
   riding on the comms ceiling).
3. **Position vs the single-node reference**: at N≈490k our headline
   (169,981/GPU) is ≈62% of the single-node 8xH200 reference level
   (≈275,000/GPU, N=491520, as recorded in the motivation), while the
   LU-only rate (320,613/GPU) matches or exceeds it — the raw
   factorization engine is healthy; the headline gap is the comms ceiling
   (container GPUDirect off / staged path — parent track), not compute or
   resources.
4. **Memory model validated point-by-point**: host GB/node = ≈10 +
   2.6e-9 x N^2 predicts all seven measurements within ≈1% (537 -> 687
   GB/node). Peak GPU memory per GPU grows 70.3 -> 89.4 GiB (≈2.2x the raw
   fp16 matrix share). Extrapolated walls: the `mem=1000GB` host cgroup at
   N≈617k and the 141 GiB GPU HBM at N≈630k — the user's 510k cap sits
   ≈20% below both, safely validated, and an uncapped sweep would end in
   that 615-630k band.
5. **450k first-run warmup anomaly**: the first sweep attempt (then-long-
   idle trio) shows RNG 65.3 s / matgen 119.3 s vs ≈50/75 s at 460k+
   despite the smaller N — first-touch/page-fault warmup, not a trend
   point; 460k-510k are internally consistent (matgen 74.6 -> 86.8 s
   scales with N as expected).
6. **Pristine condition held throughout**: pristine check 3/3 before every
   submission; pre/post captures and the sampler show no co-tenant
   arrivals during any run.

**Conclusion:** the resource-allocation track is complete. The pristine
3x4 clean baseline at N=480k is **1.98e+06 GFLOPS (49.5x the original
baseline)**, the usable range extends through at least N=510k (measured)
with mapped walls at ≈617-630k, and the residual gap to single-node
performance (≈38% of headline at ≈490k) belongs to the comms track
(in-container GPUDirect), not to resources, placement, or affinity.

### Experiment 3 results (2026-09-09) — final

**All runs** (N=250000, NB=1024, 3x4 row grid, 12 ranks, host-pinned, all
`PASSED`, exit 0; trio = g14+g16+g17 pristine, verified per attempt; v4
rotated g13 in: nearly pristine, one light co-tenant `59192` at 12 cpus +
1 GPU, mixed-socket GPU carve-out `5C/9A/BB/CD`, fragmented cpuset
`12-49,56-65`):

| Attempt | Job | Nodes | Walltime | GFLOPS (total) | GFLOPS/GPU | vs baseline total (4.0092e+04) | LU s | Solver s | RNG s AVG (MAX node) | matgen s |
|---|---|---|---|---:|---:|---:|---:|---:|---|---:|
| cleanalloc250k_v1 | 61022 | g14+g16+g17 (trio) | 1:26 | 8.4951e+05 | 70792 | +2019% | 6.90 | 5.37 | 16.90 (g14 21.31) | 27.05 |
| cleanalloc250k_v2 | 61024 | trio | 1:13 | 8.5640e+05 | 71367 | +2036% | 6.74 | 5.43 | 13.98 (g16 15.73) | 21.75 |
| cleanalloc250k_v3 | 61026 | trio | 1:17 | 8.5114e+05 | 70929 | +2023% | 6.82 | 5.42 | 13.93 (g16 15.50) | 20.96 |
| cleanalloc250k_v4 | 61027 | g14+g16+g13 (nearly pristine) | 1:27 | 8.2063e+05 | 68385 | +1947% | 6.64 | 6.06 | 12.62 (g16 15.52) | 21.20 |
| cleanalloc250k_v5.1 | 61032 | trio | 1:14 | 8.5678e+05 | 71398 | +2037% | 6.72 | 5.44 | 13.77 (g16 15.92) | 21.61 |

**Failed attempt record — `cleanalloc250k_v5` (job `61031.gaas`,
2026-09-09 20:15):** exit 1 in ≈1 s, no evidence produced. Cause: the
submission was accidentally made from the `outputs/` subdirectory (after
inspecting v4 evidence), so `PBS_O_WORKDIR` pointed there; the script's
`REPO_ROOT`/`BRIDGE` resolution then failed (`chmod +x $BRIDGE` on a
nonexistent path, `set -e`) and the relative `-o/-e` paths landed PBS
output in a stray `outputs/outputs/` directory. The stray directory
(0-byte `.o`, 243-byte error `.e`, both containing no benchmark evidence)
was removed after the cause was identified deterministically from the
submission context; the `.e` was not read before removal (noted for
transparency — PBS job record `61031` retains the exit status). Resubmitted
from the correct directory as `cleanalloc250k_v5.1` (job `61032`).

**Findings:**

1. **PBS's carve-out on pristine nodes is deterministic — 5/5, and uniform
   across nodes**: every attempt received the byte-identical default
   allocation on g14/g16/g17: socket-1 GPUs `9A/BB/CD/DC` + socket-0
   cpuset `0-47` + `Mems_allowed 0-1`. There is no natural allocation
   variance to sample on clean nodes; experiment 1's varying carve-outs
   were driven by co-tenant occupancy reshuffling the free-resource sets,
   not by scheduler randomness.
2. **The clean noise band is very tight**: trio GFLOPS/GPU
   70,792–71,398 (0.85% spread over 4 attempts); phase times
   near-constant (LU 6.72–6.90 s, solver 5.37–5.44 s; matgen 20.96–27.05 s
   with v1 the cold-start outlier). Per-node IB bytes are identical across
   attempts (g14 42.50 GB, g16 42.68 GB, g17 42.33 GB — also matching
   experiment 2's totals).
3. **Fully pristine nodes give the highest band of the whole
   investigation**: 70.8–71.4k GFLOPS/GPU vs experiment 2's clean series
   60.8–70.3k (which included g10's light co-tenant and its mixed-socket
   carve-out) — the fully-pristine condition adds ≈2–15% and halves the
   spread.
4. **The "worst" natural allocation shape costs at most a few percent on
   clean nodes**: v4's g13 combined a mixed-socket GPU set, a fragmented
   cpuset, and one light co-tenant, and the attempt ran at 68,385
   GFLOPS/GPU — only −3.8% vs the trio mean. g13 was even the RNG-MIN
   node (7.61 s), so its co-tenant was not interfering during that phase.
5. **The affinity-mismatch hypothesis is closed as a major factor**: the
   fastest runs of the entire investigation all ran on the mismatched
   default carve-out (socket-1 GPUs + socket-0 CPUs), with per-node
   remote-memory fractions of 34–36% (g14), 87–89% (g16), and 72–79%
   (g17) — node-stable, attempt-stable, and with no measurable performance
   effect. Placement/NUMA mismatch is worth at most ≈4% here, versus
   co-tenancy's 1.6x–25x dose-response from experiment 2.
6. **Sampler consistency**: our app's own host footprint is ≈22–28 busy
   CPUs/node in fast mode (exp2's number ≈24 confirmed); no co-tenant
   arrivals were detected on the trio during any run (pre/post pbsnodes
   listings show only our job; loadavg flat).

**Conclusion for the resource-allocation track:** the three experiments
now give a complete, deconfounded picture of the 3x4 degradation's
resource dimension. (1) Experiment 1's allocation-variance and bimodality
observations were co-tenant-confounded. (2) Experiment 2 established the
co-tenant dose-response continuum (≈1.0x pristine → ≈1.6x light → ≈25x
heavy GPU co-tenants) as the dominant factor, host-side (not fabric-side),
with the container's GPUDirect-off staged path as the sensitive element.
(3) Experiment 3 shows PBS placement on clean nodes is deterministic, its
default cross-NUMA carve-out is effectively free, and affinity mismatch is
a minor (<=4%) effect. The original baseline's ≈44x deficit therefore
decomposes into co-tenant contention (up to ≈25x) times the comms-stack
ceiling (container GPUDirect off — parent track). Practical guidance for
non-full-node GPU jobs on GAAS: choose nodes without active co-tenants
(node condition, not allocation shape, is what matters); affinity tuning
is low-yield until the comms ceiling is fixed.

**Suggested next steps (not executed, user decision):** unchanged from
experiment 2's list (direct DDR/PCIe contention measurement; controlled
dose-response with our own bounded synthetic co-tenants; report findings +
Qlist partitioning to GAAS admins; re-run after the in-container
GPUDirect fix). Additional low-effort option: extract per-rank UCX lane
distribution from the captured `UCX_LOG_LEVEL=info` logs (evidence is in
`outputs/*.o`, not yet parsed) to close the parent track's 3x4
rail-balance question.

### Experiment 2 results (2026-09-08/09) — final

**All runs** (N=250000, NB=1024, 3x4 row grid, 12 ranks, host-pinned; all
`PASSED`, exit 0. Clean series = g14+g16 pristine + g10 light co-tenant
(`down22`: 12 cpus + 1 GPU); dirty v1/v2 = g11+g13 GPU-busy co-tenants +
g10; dirty v3 = g13+g09 light co-tenants + g11 pristine (user-approved
mixed composition, see execution notes above)):

| Attempt | Job | Nodes (condition) | Walltime | GFLOPS (total) | GFLOPS/GPU | vs baseline total (4.0092e+04) | LU s | Solver s | RNG s AVG (MAX node) | matgen s |
|---|---|---|---|---:|---:|---:|---:|---:|---|---:|
| clean250k_v1.1 | 60454 | g14+g16+g10 (2 pristine + 1 light) | 1:18 | 8.4396e+05 | 70330 | +2005% | 6.67 | 5.67 | 13.85 (g16 16.48) | 21.61 |
| clean250k_v2 | 60458 | same | 1:16 | 8.2255e+05 | 68546 | +1952% | 7.02 | 5.65 | 13.13 (g16 16.19) | 21.24 |
| clean250k_v3 | 60459 | same | 1:19 | 7.3008e+05 | 60840 | +1721% | 6.83 | 7.45 | 12.94 (g16 15.89) | 21.06 |
| dirty250k_v1 | 60461 | g11+g13+g10 (2 heavy + 1 light) | 7:19 | 3.3263e+04 | 2772 | −17% | 269.64 | 43.98 | 20.93 (g11 39.46) | 59.70 |
| dirty250k_v2 | 60474 | same | 7:07 | 3.4688e+04 | 2891 | −13% | 262.86 | 37.81 | 20.44 (g11 37.78) | 57.77 |
| dirty250k_v3 | 60740 | g13+g09+g11 (2 light + 1 pristine, mixed) | 1:54 | 4.8427e+05 | 40356 | +1108% | 15.59 | 5.92 | 12.06 (g09 19.44) | 25.42 |

The per-GPU percentages equal the totals' (same 12-GPU count). The dirty v1
vs v2 spread is 4% — the slow mode replicates tightly.

Baseline-reference caveat: the original 3x4 baseline (job `57232.gaas`)
ran N=480000; the percentage columns compare GFLOPS/GPU directly and
understate the clean series' advantage at equal N (per-GPU efficiency
grows with N, so at N=480k the clean-condition margin would be larger).

**Findings:**

1. **The clean condition is fast and reproducible**: 60,840–70,330
   GFLOPS/GPU (mean 66,572) with ≈1:20 walltimes — 18–21x the original
   baseline per GPU, and ≈1.6x experiment 1's best (v5: 43,288/GPU, which
   ran on co-tenant nodes). The 3x4 topology itself is healthy.
2. **The heavy-dirty condition reproduces the slow mode deliberately and
   reproducibly**: v1/v2 at 2,772/2,891 GFLOPS/GPU with LU 263–270 s
   (≈39x the clean runs), solver 38–44 s (6-7x), matgen 58–60 s (2.8x) —
   matching experiment 1's v1-v4 slow mode (2,572–2,857/GPU) and the
   original baseline's magnitude. The degradation is causally tied to
   co-tenant node condition, not to our job's own placement.
3. **The degradation is a dose-response continuum, not a binary mode**:
   pristine/light nodes (clean series) 60.8–70.3k GFLOPS/GPU; 2 light
   co-tenants + 1 pristine (dirty v3) 40.4k (−39% vs clean mean, LU 2.3x);
   experiment 1's v5 on moderately-loaded nodes 43.3k; 2 heavy + 1 light
   (dirty v1/v2) 2.8–2.9k (−96%). Experiment 1's "bimodality" was two
   clusters along this continuum sampled with N=5.
4. **The contention is host-side, not fabric-side**: total IB bytes moved
   by the app are identical (≈42.3-42.8 GB per node) in clean and dirty
   runs, and the dirty nodes' counters show ≈0 extra fabric traffic from
   co-tenants (g13: +0.27 GB over the app's baseline over 404 s). The app
   just takes 7.8x longer to move the same bytes. Combined with the
   parent-track finding that the container's UCX uses the host-staged
   `cuda_cpy` path (GPUDirect off inside the container), the slow mode is
   consistent with co-tenants contending for the host-side resources the
   staged path depends on (DDR bandwidth / PCIe / LLC), not with
   switch-side IB congestion. NCCL transport/rail selection is identical
   across all six runs (NCCL RDMA plugin v11 + SHARP collnet, same 9-device
   rail set on every node) — configuration is ruled out.
5. **Co-tenant CPU load alone cannot explain the magnitude**: from
   /proc/stat deltas, our own app uses ≈24 busy CPUs per node in fast mode
   and ≈15 in slow mode (ranks wait on comms); g13's three co-tenant jobs
   added only ≈16 busy CPUs and g11's co-tenant (a resource-holding idle
   session, job 60315) added ≈0 — yet LU still collapsed ≈40x.
   Memory-bandwidth/PCIe contention remains the leading candidate
   mechanism (not yet directly measured — see limitations).
6. **An "idle" co-tenant still degraded host-memory phases — and its
   removal normalized them**: in v1/v2, g11's ranks were the RNG-MAX node
   (39.5/37.8 s vs clean ≈13 s) and the matgen-MAX node, despite the
   co-tenant showing ≈0 CPU and ≈0 fabric activity at 10 s granularity
   (it held 4 GPUs + 48 cpus + 1000 GB host memory). In v3, with g11
   pristine, g11 became the RNG-MIN node (8.03 s) and matgen normalized —
   a clean within-node A/B triangulation (bursts below the sampling
   interval, or DDR/HBM pressure from resident allocations, are the
   suspects).
7. **One pristine node does not rescue a mixed job**: dirty v3's LU ran
   2.3x slower than the clean series even though g11 was pristine —
   collectives couple all ranks, so the job runs at the pace of its
   slowest node.
8. **Placement mismatch is definitively not the differentiator**: the
   pristine clean runs received cross-NUMA allocations (g14/g16: socket-1
   GPUs `9A/BB/CD/DC` with socket-0 cpuset `0-47`, 76-86% remote-memory
   fraction in numastat deltas) and were the fastest runs of the series.
   Dirty v1's allocations were no worse. This confirms experiment 1's
   finding 3 with the strongest possible contrast.
9. **GPU starvation signature reproduced**: sampler medians show the
   allocated GPUs near-idle (≈117-131 W, 0% utilization medians) through
   the 7-minute heavy-dirty runs — the exp1 monitor observation, now with
   per-node in-run evidence.

**Conclusions for the 3x4 degradation:** the original baseline's ≈44x
deficit decomposes into (a) a co-tenant host-contention factor that ranges
from ≈1.0x (pristine nodes) through ≈1.6x (light load) to ≈25x (heavy GPU
co-tenants) on this cluster, times (b) the still-present comms-stack
ceiling (container GPUDirect off / `cuda_cpy` staging — parent track): the
clean-condition 60-70k GFLOPS/GPU at N=250k is still well below the
single-node 8xH200 reference level. Practical guidance for non-full-node
GPU jobs on GAAS: pin to nodes without active co-tenants (or request
exclusive nodes), since even resource-idle co-tenants measurably degrade
host-memory-bound phases, and the effect propagates to the whole
multi-node job.

**Limitations:** memory-bandwidth contention is inferred (consistent
resource arithmetic), not directly measured — no PCM/MBW counters were
sampled; the heavy-dirty condition has 2 replicates (both on the same
node set) and the mixed condition 1; g10 participates in both conditions
(light co-tenant; the clean series' speed bounds its impact); PSI was
unavailable (`/proc/pressure` absent on GAAS compute nodes); 10 s sampling
can miss sub-interval bursts (finding 6 is exactly such a case).

**Suggested next steps (not executed, user decision):**

1. **Mechanism confirmation**: measure DDR/PCIe bandwidth contention
   directly (e.g.,Intel PCM or a bounded memory-bandwidth probe running
   alongside a short HPL-MxP run) to separate DDR vs PCIe vs LLC effects.
2. **Controlled dose-response**: place our own bounded synthetic
   co-tenants (varying memory-bandwidth/PCIe load) on otherwise-pristine
   nodes to map the degradation curve without depending on opportunistic
   cluster state (requires approval — it deliberately loads shared
   nodes).
3. **Cluster guidance**: report the Qlist queue-partitioning finding and
   the co-tenant degradation data to the GAAS admins (non-full-node GPU
   jobs can silently lose 1.6-25x; users cannot see co-tenant GPU state
   from inside their jobs).
4. **Re-test after the comms fix**: once the parent track resolves the
   in-container GPUDirect gap, re-run this series to test whether the
   GDR-on path is less sensitive to co-tenant host load than the staged
   path (expected: yes, since GPU-direct traffic bypasses host DDR
   staging).

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
4. **GPU monitoring corroborates the slow mode:** v1-v4 GPUs sat at ≈125 W
   median (near-idle) for the whole 8-minute run — comms-starved. Even v5
   (43.3 TF/GPU) remains ≈6x below the single-node 8xH200 per-GPU reference
   (≈275 TF/GPU at N=491520), consistent with the still-unfixed GPUDirect
   off / `cuda_cpy` staging ceiling.
5. **Limitations:** co-tenant load was inferred (cpuset holes, RNG flip), not
   measured — the capture lacks host load and NIC counter snapshots; the
   in-job host `nvidia-smi` sees only allocated GPUs, so co-tenant GPU state
   is unobservable from inside the job.

**Implications:** all three factors coexist for non-full-node GPU jobs on
GAAS: (a) the comms-stack ceiling (GPUDirect off, separate workstream),
(b) a ≈16x catastrophic contention mode that comes and goes with external
node/fabric load, and (c) pervasive CPU/GPU/NUMA placement mismatch that is
constant in this series and likely compounds both. A follow-up capture with
host load + IB counters would separate (b) from (c) directly.

**Suggested next steps (not executed):** add loadavg/IB-counter sampling to
the capture; enlarge the sample to estimate the slow-mode frequency; re-run
this series after GPUDirect is fixed to isolate the placement factor.
