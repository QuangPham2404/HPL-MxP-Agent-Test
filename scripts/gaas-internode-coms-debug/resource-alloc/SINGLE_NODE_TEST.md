# Single-node node-contention test (resource-alloc Experiment 6)

Planning and execution log for the single-node arm of the host
resource-allocation investigation. This file is deliberately separate from
`README.md`'s experiment records so it cannot clash with the running
experiment-5 workstream; `README.md` carries only a one-line pointer here.

## Motivation

Experiments 2 and 5 established the co-tenant dose-response on the 3x4
multinode topology (≈1.0x pristine → ≈1.6x light → ≈25-40x heavy GPU
co-tenants) and proved it host-side, not fabric-side. But every measurement so
far spans 3 nodes coupled by inter-node collectives: one slow node drags all
12 ranks, so node-local contention cannot be separated from collective
coupling. The multinode catastrophic mode also rode the container's staged
(GPUDirect-off) inter-node communication path — a path a single-node run does
not use.

This experiment reruns the contention comparison on a single node with 2 and
4 ranks, isolating the node-local effect:

- **H1 (host-memory contention):** the host-memory-bound phases (RNG, matgen)
  slow on dirty nodes even with zero inter-node communication — replicating
  exp5's matgen/RNG findings without collective coupling.
- **H2 (intra-node comms sensitivity):** the LU-phase degradation is smaller
  than the multinode ≈40x if intra-node communication avoids the staged path
  (NVLink/P2P or shared memory); a similarly catastrophic LU would instead
  implicate node-local staged transfers or the same host-side mechanism.
- **H3 (dose):** the dirtiest node degrades more than a lightly-occupied node
  (exp5's band structure reproduces at single-node granularity).
- **H4 (rank-count sensitivity):** 2-rank and 4-rank runs degrade
  proportionally, or fewer ranks per node (more host-staging traffic per
  rank) change the dose-response.

## Fixed configuration (all runs)

- HPL-MxP v26.02 container, identical to experiments 1-5
  (`hpc-benchmarks_26.02.sif`), same module set, single-node launch pattern
  (proven by the `experiments/N-*` single-node sweeps: container `mpirun`
  without the multinode rsh bridge).
- `N=200000`, `NB=1024`, `--nporder row`, `--bind-to none`, no affinity
  flags, `--gpu-affinity 0:1` (2 ranks) / `0:1:2:3` (4 ranks),
  `--skip-tests 1`, standard GPU-monitoring flags, `UCX_LOG_LEVEL=info`,
  `NCCL_DEBUG=INFO`.
- Process grid: `nprow=2 npcol=1` (2 ranks), `nprow=2 npcol=2` (4 ranks) —
  fixed across all arms (nprow ≥ npcol convention; not a tuning choice).
- One rank per GPU. Chunk per run, host-pinned at submission:
  - 2 ranks: `select=1:host=X:ngpus=2:ncpus=24:mem=500GB`
  - 4 ranks: `select=1:host=X:ngpus=4:ncpus=48:mem=500GB`
- Memory sizing: the whole FP64 matrix lands on the single node —
  N=200000 ⇒ ~320 GB host + overhead; `mem=500GB` gives ~50% headroom
  (user decision 2026-09-18; the exp-series chunk convention `mem=1000GB`
  was relaxed to widen dirty-node eligibility).
- Queue `gpu_as` preferred (`gpu_ded` if the only suitable dirty nodes live
  there — recorded per attempt, cross-queue caveat as in exp5 r1);
  accounting group `hpc_ebslee`; `place=scatter`; walltime 01:00:00 (a
  40x-style LU inflation on 2 ranks could exceed 30 min).
- The script asserts granted host == requested host and
  `nprow x npcol == ranks` before running.

## Run matrix (single pass, 6 sequential jobs)

| # | Attempt | Condition | Ranks | Grid |
|---|---|---|---|---|
| 1 | `sn200k_ctrl_2r_v1` | pristine control | 2 | 2x1 |
| 2 | `sn200k_ctrl_4r_v1` | pristine control (same node as #1) | 4 | 2x2 |
| 3 | `sn200k_heavy_2r_v1` | dirtiest feasible node | 2 | 2x1 |
| 4 | `sn200k_heavy_4r_v1` | dirtiest feasible node (same as #3) | 4 | 2x2 |
| 5 | `sn200k_light_2r_v1` | lighter occupied node | 2 | 2x1 |
| 6 | `sn200k_light_4r_v1` | lighter occupied node (same as #5) | 4 | 2x2 |

Single pass is a screening design (user decision 2026-09-18): exp2/3 showed
the clean noise band is ~1-4% and the dirty mode replicates within 2-4%, so a
single pass separates large effects; replicate only if the signal is
ambiguous.

## Node-selection policy

- Live `pbsnodes -aSj` + `qstat` immediately before **every** submission
  (also the coordination gate with the concurrent phase-2 workstream: never
  pick a node carrying an active or queued job from that workstream).
- Queues: `gpu_as` / `gpu_ded` only (project queue-scope rule; Qlist pools
  cannot be mixed — exp5's g16/g17→gpu_aisg shift shows the map must be
  read live, not from exp2's table).
- Control node: strictly pristine (no foreign jobs, all GPUs/CPUs free).
- Heavy node: heaviest stable co-tenant load with ≥4 free GPUs, ≥48 free
  CPUs, ≥500 GB free memory; prefer long-remaining-walltime co-tenants
  (idle 1 TB holders are acceptable — exp5's idle-holder paradox is part of
  what we test); record every co-tenant job ID and resource vector. If the
  dirtiest node lacks 4 free GPUs, split (dirtiest-with-≥2 for the 2-rank,
  dirtiest-with-≥4 for the 4-rank) and document the split.
- Light node: occupied but low foreign load, same resource floors.
- Node identity differs between control and test arms by construction (same
  limitation as exp5, recorded per attempt; arms are never pooled blindly).

## Instrumentation

Reuse of the experiment-5 helpers, unmodified (invoked once on the single
node via `pbsdsh`):

- `debug-scripts/capture_node_alloc_mech.sh` pre/post: cpuset, Mems_allowed,
  cgroup path/effective limits/counters, THP/VM state, GPU inventory
  (UUIDs/PCI buses), PCIe link gen/width, topology matrix, per-NIC NUMA,
  IB one-shot counters, numastat, load/PSI, co-tenant `pbsnodes` listing,
  container GPU renumbering view.
- `debug-scripts/sample_node_load_mech.sh` in-run, 2 s interval, 1700-tick
  cap (~56.7 min < 1 h walltime): loadavg, /proc/stat, meminfo, vmstat
  (incl. `numa_hint_faults`/`numa_pages_migrated` — the bedd599 fix),
  PSI, numastat, cgroup counters, all IB port counters, cgroup-visible GPU
  telemetry (util/clocks/power/mem/temp/PCIe), and every 5th tick the local
  `xhpl_mxp` rank CPU/mem affinity, RSS, and fault counters.
- `--monitor-gpu` flags for per-rank GPU PCI bus, clocks, power, PCIe link.
- Known carried-over limitations (exp5): per-GPU sampling cannot observe
  co-tenant GPUs (scheduler evidence authoritative); cgroup counters resolve
  the sampling process's own cgroup scope.

## Analysis plan

Primary denominator: the matching single-node control run (2r vs 2r, 4r vs
4r). Context columns: percentage vs the original contaminated 3x4 baseline
per-GPU figure (3,340.96 GFLOPS/GPU, job `57232.gaas`) and vs the multinode
pristine bands (exp3: ~70.8-71.4k GFLOPS/GPU at N=250k; exp5 "pristine" arm
44.8-45.9k). Compare per-phase times (RNG, matgen, LU, solver), GFLOPS
total/per-GPU, walltime, rank skew, GPU starvation signatures, and the
sampler's memory/NUMA/cgroup/IB layers. A mechanism claim requires the
signal to repeat across heavy and light arms and align with the affected
phase (exp5 interpretation gates).

## Execution log

- 2026-09-18: design approved (user). N=200k/mem=500GB, single pass, full
  execution chain authorized; coordination rule: avoid nodes carrying active
  phase-2 workstream jobs. Runner `debug-scripts/run_1n_contention.pbs`
  prepared; this file created. (Results below.)
- 2026-09-18 (execution, all times +08:00): all runs on the GAAS remote
  clone at commit `1af2085` (runner env-forwarding hardening). Node
  landscape shifted repeatedly during the session (recorded per attempt):
  - `sn200k_ctrl_2r_v1` — first submission `67824` (09:44) could never
    start: `host=g11` must be the full vnode name `hpc-gaas-g11`
    (deterministic Track-1 submission defect; qdelt, never started, no
    evidence lost; snapshot kept as `_presubmit_a1.log`). Resubmitted as
    `67828` (09:49-09:55, g11 pristine, 5:42 walltime).
  - `sn200k_ctrl_4r_v1` — `67835` (09:57-09:59, g11 pristine, 1:26).
  - Heavy-node re-pick: original pick g10 (4 foreign jobs, 48 cpus + 4 GPUs
    in use) lightened before submission — co-tenant 67564 ended between the
    survey and the submit (g10 fell to 24 cpus + 2 GPUs used). Re-picked
    **g03** (`gpu_ded`): the exp5 heavy idle-holder — job 67044 holding
    48 cpus + 4 GPUs + 1000 GB, ~25 h into a 1440 h walltime (maximally
    stable). g10 snapshot kept as `_presubmit_a1.log`; cross-queue caveat
    (gpu_ded vs gpu_as controls) recorded as in exp5 r1.
  - `sn200k_heavy_2r_v1` — `67837` (10:06-10:08, g03, 1:55).
  - `sn200k_heavy_4r_v1` — `67841` (10:13-10:15, g03, 1:23).
  - `sn200k_ctrl_2r_v2` — validation rerun (see anomaly below) `67842`
    (10:16-10:18, g11, 1:33). PBS granted a *different* pristine carve-out
    than v1 (GPUs cd/dc + cpuset 0-23 vs v1's 4b/5c + 48-49,56-77).
  - `sn200k_light_2r_v1` — `67873` (10:36-10:39, g12 light co-tenant 67573:
    24 cpus + 2 GPUs + 500 GB, ~12 h walltime remaining, 2:27).
  - `sn200k_light_4r_v1` — **not fielded**. Attempt a1 (`67880`, g12)
    could never start: new co-tenant 67869 (48 cpus + 4 GPUs + 1 TB) landed
    on g12 between light_2r and light_4r (qdelt, never started; snapshot
    kept as `_presubmit_a1_g12.log`). Attempt a2 (`67882`, g10) could
    never start: g10 went **offline** minutes after submission (qdelt,
    never started; snapshot kept as `_presubmit_a2_g10.log`). At that
    moment no lightly-occupied gpu_as/gpu_ded/gpu_free node could host a
    48-cpu + 4-GPU + 500 GB chunk (g09 also offline, g11 down, g08/g12/g25
    full; only pristine g04/g14/g15/g22 had capacity). Cell left open
    rather than substituting a pristine node (which would not be a
    "light-occupied" test).
- All qdels were of this experiment's own never-started submissions, each
  with recorded reason (exp2/5 precedent policy).

## Results

All six completed runs `PASSED` (finite residual within tolerance), exit 0,
`N=200000, NB=1024`, single node, one rank per GPU, `--bind-to none`.
Reference figures: original contaminated 3x4 baseline per-GPU = 3,340.96
GFLOPS/GPU (job `57232.gaas`); multinode pristine bands for context
(exp3 trio ~70.8-71.4k GF/GPU at N=250k).

| attempt | job | node (condition) | granted GPUs (PCI) | cpuset | walltime | GFLOPS total | GFLOPS/GPU | ×baseline/GPU | RNG s | LU s | solver s |
|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|
| sn200k_ctrl_2r_v1 | 67828 | g11 pristine | 4b/5c (NUMA0) | 48-49,56-77 | 5:42 | 6.0661e+04 | 30,330 | 9.1x | 143.25 | 21.19 | 66.99 |
| sn200k_ctrl_4r_v1 | 67835 | g11 pristine | 9a/bb/cd/dc (NUMA1) | 0-47 | 1:26 | 5.1391e+05 | 128,478 | 38.5x | 26.45 | 4.88 | 5.50 |
| sn200k_ctrl_2r_v2 | 67842 | g11 pristine | cd/dc (NUMA1) | 0-23 | 1:33 | 4.1385e+05 | 206,923 | 61.9x | 40.13 | 7.26 | 5.62 |
| sn200k_heavy_2r_v1 | 67837 | g03 heavy idle-holder | 9a/bb (NUMA1) | 24-47 | 1:55 | 3.3159e+05 | 165,794 | 49.6x | 53.20 | 7.38 | 8.71 |
| sn200k_heavy_4r_v1 | 67841 | g03 heavy idle-holder | 1b/3c/9a/bb (mixed) | 24-47,78-101 | 1:23 | 5.2176e+05 | 130,440 | 39.0x | 19.82 | 4.85 | 5.37 |
| sn200k_light_2r_v1 | 67873 | g12 light | 1b/3c (NUMA0) | 78-101 | 2:27 | 4.1849e+05 | 209,246 | 62.6x | 28.98 | 7.15 | 5.59 |

LU-only rates (GFLOPS/GPU): ctrl_2r_v1 126,002; ctrl_4r 273,421;
ctrl_2r_v2 367,067; heavy_2r 361,519; heavy_4r 274,936; light_2r 372,994.

**Arm comparisons (primary denominator = matching control):**

| comparison | headline GF/GPU | phase deltas (test vs control) |
|---|---|---|
| heavy 4r vs ctrl 4r | 130,440 vs 128,478 = **+1.5% (noise)** | RNG −25%, LU −1%, solver −2% (at or better than control) |
| heavy 2r vs ctrl 2r_v2 | 165,794 vs 206,923 = −19.9% | RNG +33%, LU +2%, solver +55% — but vs the rank-scaling reference (2× the 4-rank control: RNG 52.9 s, LU 9.8 s, solver 11.0 s) heavy_2r is at or better on every phase (53.2/7.38/8.71); healthy 2r RNG varies 29-53 s across nodes (g12/g11/g03), so no reproducible degradation is demonstrable |
| light 2r vs ctrl 2r_v2 | 209,246 vs 206,923 = **+1.1% (noise)** | all phases within noise (RNG 29.0 vs 40.1 — node variance, see below) |

## Findings

1. **The multinode co-tenant catastrophe does not reproduce on a single
   node.** A heavy idle-holder co-tenant (48 cpus + 4 GPUs + 1 TB resident —
   the exact exp5 idle-holder-paradox condition) cost the 4-rank run +1.5%
   (noise) and produced at most a modest, non-reproducible 2-rank effect,
   versus 1.6x-40x on the 3x4 topology. A light co-tenant cost +1.1%
   (noise). **The co-tenant interference mechanism requires the inter-node
   dimension** — it lives in the staged inter-node communication path
   (and/or its interaction with node-local resources), not in local
   resource sharing per se. This is the single most decisive single-node
   result: it rules out "any local resource contention with a co-tenant is
   catastrophic" and narrows the exp5 unresolved mechanism (DDR/PCIe/LLC/
   auto-NUMA candidates) to effects that matter mainly through the
   inter-node path.
2. **The only pathological run was a pristine control** (`ctrl_2r_v1`):
   RNG 3.6x the healthy 2r mean, LU 2.9x, solver 12x. Ruled out so far:
   foreign co-tenants (pre/post captures + in-run sampler show none),
   NUMA-direction placement (light_2r ran the same GPU-NUMA0 + cpuset-NUMA1
   shape as the fastest run of the day), PCIe links (gen5 x16), GPU clocks,
   cgroup memory limits. The healthy rerun (`ctrl_2r_v2`) got a different
   PBS carve-out, so reproducibility of the exact v1 condition is untested.
   Full 2 s telemetry is preserved for all layers (patched-sampler vmstat
   incl. `numa_hint_faults`, numastat, /proc/stat, cgroup counters, GPU
   telemetry — verified populated). Cause unresolved; candidates: transient
   hidden host-side load, first-job-after-long-idle pathology, or a
   reproducible allocation-specific effect (GPU 4b/5c "CPU affinity 48-49"
   pair + 22-of-24 node-1 cpuset).
3. **Healthy single-node band and node variance**: 4r headline 128.5-130.4k
   GF/GPU (1.5% spread, two nodes); 2r headline 165.8-209.2k across three
   nodes (26% spread) with RNG 29-53 s — single-node phase times carry
   substantial node-to-node variance at n=1 per cell, wider than the
   exp3 multinode trio noise band (0.85%).
4. **Placement mixing again costs nothing** (confirms exp3): heavy_4r ran
   a fully mixed allocation (GPUs from both sockets, cpuset spanning both
   NUMA nodes) at full speed.

## Limitations

- Screening design: n=1 per cell; the 2r "heavy" readout is
  reference-dependent (−20% vs the best control, ~0% vs the rank-scaling
  reference) and cannot be resolved without repetitions.
- Control and test arms ran on different nodes (node-identity confound,
  as in exp5); heavy arm cross-queue (gpu_ded) vs controls/light (gpu_as).
- The 2r control has two divergent attempts (v1 anomalous, v2 healthy);
  v2 used as the 2r reference, v1 documented as an unresolved anomaly.
- `sn200k_light_4r_v1` could not be fielded (cluster churn: g12 filled by
  a new co-tenant, g10/g09 went offline, g11 down); the light arm is 2r
  only. The 4r arm comparison (control vs heavy) is complete.
- RNG scaling 2r-vs-4r is sublinear and node-dependent (29-53 s for 2r vs
  19.8-26.5 s for 4r) — not investigated here.

## Suggested next steps (not executed, user decision)

1. Offline analysis of the `ctrl_2r_v1` anomaly (2 s telemetry vs v2 and
   light_2r) — requires `ANALYSE_RESULTS` authorization; the evidence is
   the strongest unexplained signal from this experiment.
2. Reproduce the v1 allocation (repeated 2-GPU requests on a pristine node
   until PBS grants the NUMA0-GPU + NUMA1-cpuset carve-out) to test whether
   the pathology is reproducible — directly relevant to exp3's "affinity is
   free" conclusion.
3. Field `sn200k_light_4r_v1` when cluster churn settles (needs any
   lightly-occupied gpu_as/gpu_ded/gpu_free node with ≥4 free GPUs, ≥48
   free CPUs, ≥500 GB).
4. Fold finding 1 into the parent-track mechanism question: the co-tenant
   effect requires the inter-node staged path, so the in-container
   GPUDirect fix (Track 2.2) should collapse it — a post-GDR multinode
   pristine/busy pair would confirm.

## Provenance

- Evidence: `outputs/sn200k_*` PBS `.o`/`.e` plus per-node `_pre_`/`_load_`/
  `_post_` logs and `_presubmit*` snapshots (40 files, attempt-specific
  names, never overwritten; failed-submission snapshots kept as
  `_presubmit_a*.log`). Jobs: 67828, 67835, 67837, 67841, 67842, 67873
  (ran); 67824, 67880, 67882 (never started, qdelt with recorded reason).
- Runner: `debug-scripts/run_1n_contention.pbs` (executed at `1af2085`);
  instrumentation reused from experiment 5 (`capture_node_alloc_mech.sh`,
  `sample_node_load_mech.sh` with the bedd599 vmstat fix).
- Parent records: `README.md` (experiments 1-5), `DEBUG_PROGRESS.md`,
  `DEBUG_PROGRESS_P2.md`.
