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
  prepared; this file created. (Results appended below as runs complete.)

## Results

(to be filled from `outputs/sn200k_*` after runs complete)

## Provenance

- Evidence: `outputs/sn200k_*` PBS `.o`/`.e` plus per-node `_pre_`/`_load_`/
  `_post_` logs, attempt-specific names, never overwritten.
- Runner: `debug-scripts/run_1n_contention.pbs`; instrumentation reused from
  experiment 5 (`capture_node_alloc_mech.sh`, `sample_node_load_mech.sh`).
- Parent records: `README.md` (experiments 1-5), `DEBUG_PROGRESS.md`,
  `DEBUG_PROGRESS_P2.md`.
