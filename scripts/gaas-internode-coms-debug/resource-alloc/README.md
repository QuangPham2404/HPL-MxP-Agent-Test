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

- **Status:** complete (2026-09-09). All 6 runs `PASSED` (3 clean + 3
  dirty). Dirty v1/v2 used the same GPU-busy composition (g11+g13+g10);
  dirty v3 used a user-approved lighter mixed composition (g13+g09+g11)
  after the original dirty nodes' co-tenants ended mid-experiment. One
  failed attempt (`clean250k_v1`, submission-spec defect) recorded below.
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
  - Dirty-series execution actuals: v1 ran as planned on g11+g13+g10
    (job 60461). Between v1 and v2, another user's job `60466` took g13's
    4 free GPUs; the first v2 submission (job `60470`) could never start
    and was qdel'd per the pre-authorized re-pick policy (reason recorded);
    the re-submitted v2 (job `60474`) queued ~3 h until `60466` ended and
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
  19:12):** exit 137 ~40 s into the run, `cgroup/OOM: Killed because of
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
  contention dominates the 3x4 degradation (dose-response from ~1.6x on
  lightly-loaded nodes to ~25x on heavily-shared ones), so experiment 1's
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
  single-node 8xH200 reference (~275 TF/GPU at N=491520).
- **Method:** 7 sequential attempts, N = 450000, 460000, ..., 510000 in
  10k steps (user-capped at 510k — diagnostic scope, not an
  N_max search), on the fixed pristine trio `g14+g16+g17` (live-verified
  per submission). All other flags identical to experiments 2-3 (same
  chunk shape, NB=1024, 3x4 row grid, `--bind-to none`, monitor-gpu,
  UCX+NCCL logs, capture v2 + sampler). Walltime 30 min per attempt.
- **Memory headroom (measured, from PBS records):** the app's host memory
  scales ~N^2 — 172.7 GB/node at N=250k, 610 GB/node at N=480k — giving a
  projected ~687 GB/node at N=510k, safely inside the `mem=1000GB`
  per-chunk cgroup; no OOM is expected within the capped range. (An
  uncapped sweep would hit the host-cgroup wall near N~615k before the
  GPU-HBM limit ~700-750k — recorded here for future reference.)
- **Operational policy:** carried over from experiments 2-3 (qdel
  pre-authorized for this experiment's own stuck submissions; pristine
  loss → re-pick when >=3 pristine nodes exist, else stop and ask).
- **Planned attempts:** `nsweep450k` .. `nsweep510k`; evidence under
  `outputs/` with attempt-specific names, never overwritten.

## Analysis

### Experiment 4 results (2026-09-09) — final

**All runs** (N as listed, NB=1024, 3x4 row grid, 12 ranks, pristine trio
g14+g16+g17, all `PASSED`, exit 0). Reference baseline: the original
contaminated 3x4 run (job `57232.gaas`, N=480000, GFLOPS total
`4.0092e+04`, 3340.96 per GPU). Host GB/node from PBS `resources_used.mem`
(/3 nodes); peak GPU MiB/GPU from the sampler's per-GPU `memory.used`:

| Attempt | Job | N | Walltime | GFLOPS (total) | GFLOPS/GPU | vs baseline total (4.0092e+04) | LU s | LU GFLOPS/GPU | Solver s | RNG s AVG | matgen s | host GB/node | peak GPU MiB/GPU |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| nsweep450k | 61050 | 450000 | 3:27 | 1.8593e+06 | 154942 | +4538% | 17.11 | 295888 | 15.57 | 65.26 | 119.30 | 537 | ~70300 |
| nsweep460k | 61051 | 460000 | 2:43 | 1.9046e+06 | 158714 | +4650% | 17.80 | 303761 | 16.27 | 49.97 | 74.60 | 561 | ~73700 |
| nsweep470k | 61052 | 470000 | 2:48 | 1.9263e+06 | 160527 | +4705% | 18.73 | 307910 | 17.20 | 50.94 | 76.84 | 585 | ~76400 |
| nsweep480k | 61055 | 480000 | 2:53 | 1.9842e+06 | 165350 | +4849% | 19.27 | 318875 | 17.89 | 53.77 | 80.09 | 610 | ~79800 |
| nsweep490k | 61057 | 490000 | 2:53 | 2.0398e+06 | 169981 | +4988% | 20.39 | 320613 | 18.07 | 52.83 | 80.32 | 635 | ~82800 |
| nsweep500k | 61058 | 500000 | 3:01 | 2.1320e+06 | 177667 | +5218% | 20.87 | 332720 | 18.22 | 53.85 | 86.56 | 661 | ~86000 |
| nsweep510k | 61063 | 510000 | 3:03 | 2.1633e+06 | 180272 | +5296% | 22.44 | 328403 | 18.44 | 54.73 | 86.75 | 687 | ~89400 |

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
3. **Position vs the single-node reference**: at N~490k our headline
   (169,981/GPU) is ~62% of the single-node 8xH200 reference level
   (~275,000/GPU, N=491520, as recorded in the motivation), while the
   LU-only rate (320,613/GPU) matches or exceeds it — the raw
   factorization engine is healthy; the headline gap is the comms ceiling
   (container GPUDirect off / staged path — parent track), not compute or
   resources.
4. **Memory model validated point-by-point**: host GB/node = ~10 +
   2.6e-9 x N^2 predicts all seven measurements within ~1% (537 -> 687
   GB/node). Peak GPU memory per GPU grows 70.3 -> 89.4 GiB (~2.2x the raw
   fp16 matrix share). Extrapolated walls: the `mem=1000GB` host cgroup at
   N~617k and the 141 GiB GPU HBM at N~630k — the user's 510k cap sits
   ~20% below both, safely validated, and an uncapped sweep would end in
   that 615-630k band.
5. **450k first-run warmup anomaly**: the first sweep attempt (then-long-
   idle trio) shows RNG 65.3 s / matgen 119.3 s vs ~50/~75 s at 460k+
   despite the smaller N — first-touch/page-fault warmup, not a trend
   point; 460k-510k are internally consistent (matgen 74.6 -> 86.8 s
   scales with N as expected).
6. **Pristine condition held throughout**: pristine check 3/3 before every
   submission; pre/post captures and the sampler show no co-tenant
   arrivals during any run.

**Conclusion:** the resource-allocation track is complete. The pristine
3x4 clean baseline at N=480k is **1.98e+06 GFLOPS (49.5x the original
baseline)**, the usable range extends through at least N=510k (measured)
with mapped walls at ~617-630k, and the residual gap to single-node
performance (~38% of headline at ~490k) belongs to the comms track
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
2026-09-09 20:15):** exit 1 in ~1 s, no evidence produced. Cause: the
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
   carve-out) — the fully-pristine condition adds ~2–15% and halves the
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
   effect. Placement/NUMA mismatch is worth at most ~4% here, versus
   co-tenancy's 1.6x–25x dose-response from experiment 2.
6. **Sampler consistency**: our app's own host footprint is ~22–28 busy
   CPUs/node in fast mode (exp2's number ~24 confirmed); no co-tenant
   arrivals were detected on the trio during any run (pre/post pbsnodes
   listings show only our job; loadavg flat).

**Conclusion for the resource-allocation track:** the three experiments
now give a complete, deconfounded picture of the 3x4 degradation's
resource dimension. (1) Experiment 1's allocation-variance and bimodality
observations were co-tenant-confounded. (2) Experiment 2 established the
co-tenant dose-response continuum (~1.0x pristine → ~1.6x light → ~25x
heavy GPU co-tenants) as the dominant factor, host-side (not fabric-side),
with the container's GPUDirect-off staged path as the sensitive element.
(3) Experiment 3 shows PBS placement on clean nodes is deterministic, its
default cross-NUMA carve-out is effectively free, and affinity mismatch is
a minor (<=4%) effect. The original baseline's ~44x deficit therefore
decomposes into co-tenant contention (up to ~25x) times the comms-stack
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
   GFLOPS/GPU (mean 66,572) with ~1:20 walltimes — 18–21x the original
   baseline per GPU, and ~1.6x experiment 1's best (v5: 43,288/GPU, which
   ran on co-tenant nodes). The 3x4 topology itself is healthy.
2. **The heavy-dirty condition reproduces the slow mode deliberately and
   reproducibly**: v1/v2 at 2,772/2,891 GFLOPS/GPU with LU 263–270 s
   (~39x the clean runs), solver 38–44 s (6-7x), matgen 58–60 s (2.8x) —
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
   by the app are identical (~42.3-42.8 GB per node) in clean and dirty
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
   /proc/stat deltas, our own app uses ~24 busy CPUs per node in fast mode
   and ~15 in slow mode (ranks wait on comms); g13's three co-tenant jobs
   added only ~16 busy CPUs and g11's co-tenant (a resource-holding idle
   session, job 60315) added ≈0 — yet LU still collapsed ~40x.
   Memory-bandwidth/PCIe contention remains the leading candidate
   mechanism (not yet directly measured — see limitations).
6. **An "idle" co-tenant still degraded host-memory phases — and its
   removal normalized them**: in v1/v2, g11's ranks were the RNG-MAX node
   (39.5/37.8 s vs clean ~13 s) and the matgen-MAX node, despite the
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
   allocated GPUs near-idle (~117-131 W, 0% utilization medians) through
   the 7-minute heavy-dirty runs — the exp1 monitor observation, now with
   per-node in-run evidence.

**Conclusions for the 3x4 degradation:** the original baseline's ~44x
deficit decomposes into (a) a co-tenant host-contention factor that ranges
from ~1.0x (pristine nodes) through ~1.6x (light load) to ~25x (heavy GPU
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

