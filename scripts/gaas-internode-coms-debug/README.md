# GAAS INTERNODE COMMUNICATION SET UP DEBUG

## Debug plan overview:

Initial observation: HPL-MxP is extremely slow for the baseline N=490k, 3 nodes x 4 gpus run. This indicate a high possiblity of a set up problem for inter-node communication on the cluster. However, keep in mind that it may be of some other problems, such as affinity issues, rank allocation, etc. However, comms still stands as the most probable cause.

Debug plan overview is as follows:
1. Test GPUDirect RDMA on the host first.
    - This establishes whether the cluster itself can do GPU↔NIC↔GPU direct communication.
2. Branch immediately:
    - Host GDRDMA fails → Track 2.1: go downward into RDMA/GPU-memory/driver/hardware layers.
    - Host GDRDMA works → Track 2.2: test the same capability inside the HPL-MxP container.
3. Track 2.1 — Host stack failure
    - Find the first broken layer: GPU memory registration → RDMA stack → NIC/fabric/topology.
    - Container is irrelevant until host capability works.
4. Track 2.2 — Container integration
    - Host works, container fails → likely container/userspace ↔ host-driver integration problem.   
    - Host works, container works → communication infrastructure is fundamentally healthy, so move upward into HPL-MxP/NCCL/MPI behavior.
5. If both host and container GDRDMA are healthy, investigate application/configuration causes next:
    - First: launch script / MPI / NCCL / UCX settings AND CPU/MEM/NUMA binding issues (4/8 H200s are allocated randomly, cross numa node can lead to a very bad results)
    - Second: GPU↔NIC / NUMA / rank affinity and multi-rail usage.
    - Then: synchronization / HPL-MxP-specific communication behavior.

## Debug plan details

### Phase 1: Test GPUDirect RDMA on the host first

HPL-MxP uses both **CUDA-aware MPI** and **NCCL**, so test GPUDirect RDMA through both paths.

Start simple:

```text id="h11vwe"
2 nodes × 1 GPU per node
```

---

#### 0. Sanity check — validate the tooling before measuring

**Goal:** Confirm the measurement infrastructure itself works, so that any later GDR-test failure can be attributed to the GDR path rather than to the launch machinery or a non-CUDA-aware MPI build. In short: test the tool before using the tool.

**Test:**

* Run host-native 2-node `osu_hello` / `osu_allreduce` through the exact launch path the later tests use (host `mpirun` + `rsh_pbsdsh.sh` PBS bridge: `plm_rsh_no_tree_spawn 1`, `plm_rsh_num_concurrent 1`, `routed direct`, `--bind-to none`). Only process spawn was validated previously; this confirms real cross-node message flow.
* Run `ompi_info --all | grep -i cuda` to confirm the host OpenMPI build is CUDA-aware, a prerequisite for the device-buffer (`D D`) OSU tests.

**Pass criteria:**

* Both OSU jobs run to completion across 2 nodes with normal output.
* `ompi_info` reports CUDA support.

**If it fails:** debug the launcher/bridge or MPI build first; do not trust or interpret later GDR bandwidth results.

---

#### 1. `osu-cuda` — CUDA-aware MPI

**Goal:** Check whether MPI/UCX can move GPU buffers directly over InfiniBand using GPUDirect RDMA.

**Test:**

* Run OSU GPU-to-GPU bandwidth test across 2 nodes.
* Enable UCX debug logging.
* Compare:

  * normal/default run
  * GPUDirect RDMA deliberately disabled

**Record:**

* Bandwidth
* UCX-selected transport/HCA
* GPU-memory/GDR-related log messages
* Difference between default and GDR-disabled runs

**GDRDMA likely working if:**

* UCX uses mlx5/InfiniBand RDMA
* logs indicate GPU memory is used through the RDMA path
* bandwidth is high
* disabling GDR causes a clear path/performance change

**GDRDMA likely not working if:**

* GPU buffers are staged through host memory
* UCX falls back from the GPU-RDMA path
* disabling GDR causes little/no difference

---

#### 2. `nccl-tests` — NCCL

**Goal:** Check whether NCCL uses GPUDirect RDMA for inter-node GPU communication.

**Test:**

* Run `sendrecv` first on 2 nodes × 1 GPU.
* Optionally test broadcast afterward because HPL-MxP uses panel broadcasts.
* Enable NCCL network/topology debug logs.
* Compare:

  * normal/default run
  * GDR deliberately disabled

**Record:**

* Bandwidth
* NCCL network backend
* selected HCA
* GDR-related log messages
* Difference between default and GDR-disabled runs

**GDRDMA likely working if:**

* NCCL uses InfiniBand
* logs show a GPU↔NIC GDR path
* bandwidth is high
* disabling GDR causes a clear degradation/change

**GDRDMA likely not working if:**

* NCCL falls back to Socket/TCP
* InfiniBand is used but GPU data is host-staged
* NCCL reports GDR unavailable/disabled
* disabling GDR makes little/no difference

---

#### Phase 1 decision

| OSU  | NCCL | Conclusion                                        |
| ---- | ---- | ------------------------------------------------- |
| Pass | Pass | Host GDRDMA works → test inside HPL-MxP container |
| Fail | Fail | Go down the host RDMA/GPU-memory stack            |
| Pass | Fail | Investigate NCCL path                             |
| Fail | Pass | Investigate MPI/UCX path                          |

---

### Phase 1 — Step 1: GPUDirect RDMA verification design (agreed 2026-09-07)

Executed in two phases, P2P first.

#### Phase A — P2P at 2 nodes × 1 GPU (single job, both runs on the same nodes)

Tests per run:

* `osu_bw` with all four buffer combos: `D D` (full GDR path, both ends — the HPL-MxP app pattern), `D H` (sender-side GDR only), `H D` (receiver-side GDR only), `H H` (fabric/CPU ceiling, no GPU involvement)
* `osu_latency` with `D D` and `H H`
* `ucx_perftest -m cuda` vs `-m host` cross-check (control run only)

Run conditions:

* Control run (default UCX) vs GDR-off run (`UCX_IB_GPU_DIRECT_RDMA=n`) in the same job on the same nodes and placement
* UCX tracing in both runs (`UCX_LOG_LEVEL=info`, `UCX_PROTO_INFO=y`); UCX_* variables explicitly forwarded with `-x` so both nodes provably see them
* No CPU binding (`--bind-to none`, matching real HPL-MxP runs); `nvidia-smi topo -m`, rank affinity, and `ucx_info -t` recorded as evidence only

Interpretation: healthy GDR ⇒ all four `osu_bw` combos near line rate; staged ⇒ `D D` < `D H`/`H D` < `H H`; one-sided fault ⇒ `D H` and `H D` diverge. `H H` is also the negative control: it must not change between the two runs.

#### Phase B — collectives at 2x1 → 2x2 → 3x1 → 3x4 (one job per topology, both runs per job)

Collective ladder, one job per rung, submitted one at a time: 2x1 (minimal inter-node pair) → 2x2 (first intra-node GPU mix: NVLink/IPC locally + IB across nodes) → 3x1 (pure inter-node at the baseline node count) → 3x4 (the actual HPL-MxP baseline topology). Cross-rung diffs separate the intra-node (NVLink) from inter-node (IB/GDR) contributions.

Tests per run:

* `osu_bcast` with host buffers (`H H`) and CUDA buffers (`-d cuda`), both with `-m 67108864` (up to 64 MiB — HPL-MxP panel-scale traffic)
* `osu_allreduce` with host buffers (`H H`) and CUDA buffers (`-d cuda`), default sizes (max 1 MiB)
* `H H` variants = collective fabric baseline + negative control; `-d cuda` variants = the HPL-MxP panel-broadcast / reduction analogs

Run conditions:

* Control run (default UCX) vs GDR-off run (`UCX_IB_GPU_DIRECT_RDMA=n`) in the same job on the same nodes and placement; GDR-off disables only inter-node GPU-RDMA (intra-node NVLink IPC still works), so the A/B delta isolates the inter-node GPU path inside the collective
* GPU per rank = `CUDA_VISIBLE_DEVICES=$OMPI_COMM_WORLD_LOCAL_RANK`
* No CPU binding (`--bind-to none`, matching real HPL-MxP runs); rank affinity + visible GPUs, per-node `ucx_info -d` and `nvidia-smi topo -m` recorded as evidence only
* UCX tracing in both runs (`UCX_LOG_LEVEL=info`, `UCX_PROTO_INFO=y`); UCX_* variables explicitly forwarded with `-x` so all nodes provably see them
* No `ucx_perftest` (dropped after the Phase A cross-check proved void and redundant)

Interpretation (as designed): healthy collective GDR ⇒ `-d cuda` close to `H H` and clearly above the GDR-off run; `H H` must not change between the two runs. Actual outcome: the opposite for CUDA buffers at ≥3 ranks — GDR-enabled CUDA collectives ran 13-44× *slower* than staging while all `H H` negative controls stayed clean (critical finding; full tables and protocol evidence in `DEBUG_PROGRESS.md`, Phase B section).

---

### Phase 1 — Step 1, Phase B2: collectives diagnostic replication on pristine nodes (designed 2026-09-09)

Replicates the full Phase B collective GDR A/B ladder (all four rungs:
2x1 → 2x2 → 3x1 → 3x4, one job per rung, submitted sequentially) with two
deltas: added coll/pml/UCC selection diagnostics, and pristine host-pinned
nodes. Motivation: Phase B found CUDA collectives pathological at ≥3 ranks
with GDR on (13-44× slower than staged), but those jobs ran on uncontrolled
nodes; resource-alloc exp2/exp3 later proved co-tenant host contention causes
a ≈16× dose-response degradation on its own. B2 answers both open questions
at once: does the collective pathology reproduce without contention, and
what does MPI actually choose/execute on the pathological path.

Diagnostic settings: keep `UCX_LOG_LEVEL=info` + `UCX_PROTO_INFO=y`; add
`UCC_LOG_LEVEL=info`, `--mca coll_base_verbose 100`, `--mca pml_base_verbose
10`, `--mca mpi_common_cuda_verbose 10`, `--mca mpi_common_cuda_warning 1`;
all relevant env vars forwarded with `-x` so every rank receives them. No
`UCX_LOG_LEVEL=debug` or per-message tracing in the measurement runs.
`ompi_info --all` captured once per job before the benchmarks.

Measurements per job (both GDR modes, same-job A/B as Phase B): `osu_bcast`
H H and `-d cuda` with `-m 67108864` (full sweep; contains the 1/8/32/64 MiB
rows of interest); `osu_allreduce` H H and `-d cuda`, default sizes (≤1 MiB).
Recorded per rank: host, global/local rank, `CUDA_VISIBLE_DEVICES`, visible
GPU UUID (explicit device-identity verification), CPU and memory affinity,
effective UCX/UCC environment.

Clean-node controls: `pbsnodes -aSj` immediately before each submission, then
pin the selected nodes via `qsub -l select=host=...` chunks in the
allocation-study shape (`ngpus=4:ncpus=48:mem=1000GB` per chunk; omitting
ncpus/mem triggers the server-default cgroup OOM — resource-alloc job
60453). Preferred trio: g14+g16+g17 (2-node rungs use g14+g16), fallback to
other pristine `gpu_as` nodes, documented. Recorded per job: pre-run
scheduler occupancy (saved evidence), in-job co-tenant state (pbsdsh
checkpoints at pre/prectrl/mid/post per node: loadavg, PSI, meminfo, cpuset,
visible GPUs, in-job `pbsnodes` listing), and post-run state — a clean
pre-submission snapshot alone is insufficient because another job may arrive
before or during execution.

Interpretation: GDR-on still catastrophically slower than GDR-off on clean
nodes ⇒ collective pathology confirmed independently of host contention.
Slowdown disappears ⇒ earlier Phase B result was contaminated by host
resource contention. Logs showing UCC-related selection/execution ⇒ next
single-variable test is GDR-on with `--mca coll ^ucc`; if UCC is not
selected, investigate the CUDA collective wrapper or UCX GPU rendezvous path
instead. `UCC_UCP_CONTEXT` alone is not proof that UCC executed the measured
collective; `coll_base_verbose` selection output is required.

Scope: observational only — no UCC disablement, UCX threshold changes,
affinity changes, or transport restrictions in this round. Operational
policy carried over from resource-alloc exp2/exp3: qdel pre-authorized for
this experiment's own stuck/failed submissions, pristine-loss re-pick with
documented reasons. Scripts:
`debug-scripts/phase1-step1/run_phase1_step1_collb2_{2x1,2x2,3x1,3x4}.pbs`
+ `collb2_node_snapshot.sh` (per-node checkpoint helper).

Attempt log: `step1_collb2_2x1_v1` (job `61084.gaas`, g16+g17) completed
8/8 tests but the per-node `ucxdev`/`nvtopo` evidence files were silently
lost — the script dropped Phase B's `export OUTDIR`, so `-x OUTDIR`
forwarded nothing and the evidence block's trailing `true` masked the
redirect failure (Track 1 defect; measurements unaffected). Patched
(`export OUTDIR` + missing-file guard) and rerun as
`step1_collb2_2x1_v2`.

**Anomaly resweep (2026-09-10, part of Phase B2):** repetition series for
the two residual anomalies — Case A (3x4 `osu_bcast -d cuda`, GDR-on −2×…
−3× at ≥8 MiB) and Case B (3x1 `osu_allreduce -d cuda`, GDR-on −5×…−11× at
1 MiB). Two arms × 3 reps per case (12 jobs, all rc=0): orig arm on
g16+g17+g13 (original conditions) and pristine arm on strictly pristine
g14+g16+g17. **Both anomalies are mechanism, not noise** — 6/6 reproduction
each; Case A is co-tenant-independent (pristine arm slightly stronger,
−2.95…−2.99× @64 MiB). Results, signed-ratio tables (+ = GDR faster), and
verdicts in `DEBUG_PROGRESS.md` → Phase B2 → "Anomaly resweep"; script
`run_phase1_step1_collb2_resweep.pbs`.

**UCC ablation (2026-09-10, part of Phase B2):** the two anomaly cases
repeated with `--mca coll ^ucc` (single delta; 6 jobs on pristine
g14+g16+g17, all rc=0; UCC exclusion proven from comm_select + zero
score-map lines; fallback stack hcoll(90)/cuda(78)/tuned(30)). **Split
verdict: Case B (3x1 allreduce @1 MiB) disappears (+1.89…+1.97×, healthy) →
UCC/TL_UCP causal; Case A (3x4 bcast ≥8 MiB) persists (−2.5…−3.8×) → not
UCC, next is UCX rail/rendezvous-threshold testing.** UCC-exclusion is NOT a
viable global mitigation (degrades everything at 3x4 by 3-4.6×, including
host-buffer collectives). Details in `DEBUG_PROGRESS.md` → Phase B2 → "UCC
ablation"; script `run_phase1_step1_collb2_uccabl.pbs`.

---

### Phase 1 — status and resume point (updated 2026-09-16, OSU-CUDA closure)

**Completed:**

- **Step 0 (sanity): PASS** — host launch path (`mpirun` + `rsh_pbsdsh.sh` bridge)
  and CUDA-aware host MPI verified (`phase1_step0_sanity_v1`, job `59640.gaas`).
- **Step 1 Phase A (p2p GDR A/B at 2x1): PASS** — host GPUDirect RDMA works for
  p2p (zero-copy selected, clear A/B deltas, negative control clean)
  (`step1_p2p_2x1_v1`, job `59671.gaas`). CUDA p2p reaches ~57% of the fabric
  ceiling due to a 74/26 multi-rail split in the 1-GPU-per-node case.
- **Step 1 Phase B (collective GDR A/B ladder, uncontrolled nodes):** found
  CUDA collectives with ≥3 ranks pathologically slow (13-44×) with GDR on —
  jobs `59931/59933/59934/59935.gaas`. **Superseded by B2: shown to be
  contention-inflated** (see below).
- **Step 1 Phase B2 (collective diagnostic replication on clean pinned
  nodes): COMPLETE — Phase B catastrophe reinterpreted.** Full Phase B matrix
  (4 rungs × 8 tests, all rc=0; jobs `61090/61091/61102/61104.gaas`, chunks
  `host=X:ngpus=4:ncpus=48:mem=1000GB`, pristine g16+g17 + nearly-pristine g13
  for 3-node rungs). Six of eight rung×collective cells are *healthy* GDR
  (ctrl 1.4-2.5× faster than staged). Two reproducible residuals survive:
  **3x4 bcast cuda ≥8 MiB (2.0-2.6× slower than staged)** and **3x1 allreduce
  cuda @1 MiB (7.7×)**. Diagnostic answer: `pml=ucx`; coll stack
  **ucc(100) > hcoll(90) > cuda(78) > tuned(30)**; **UCC (TL_UCP) executes the
  collectives in both modes** (comm_select + per-test team create/destroy
  evidence). Full tables and protocol evidence in `DEBUG_PROGRESS.md` Phase B2.
- **Step 1 Phase B2 anomaly resweep: COMPLETE — both residuals are
  MECHANISM.** 12 jobs (2 cases × orig/pristine arms × 3 reps, all rc=0;
  jobs `61419-61430.gaas`). Case A reproduces 6/6 (orig −2.5…−2.6×,
  pristine −2.95…−2.99× @64 MiB — co-tenant-independent); Case B reproduces
  6/6 (−5.0…−10.7× @1 MiB). Signed-ratio tables in `DEBUG_PROGRESS.md`
  Phase B2 → "Anomaly resweep".
- **Step 1 Phase B2 UCC ablation: COMPLETE — split verdict.** 6 pristine
  jobs (`61694/61695/61715/61717/61718/61719.gaas`, all rc=0). **Case B
  (3x1 allreduce @1 MiB) is UCC-causal** — disappears without UCC
  (+1.89…+1.97×, healthy GDR; 15-17× faster ctrl). **Case A (3x4 bcast ≥8
  MiB) is NOT UCC** — persists (−2.46…−3.83×) under the hcoll/cuda/tuned
  fallback. UCC-exclusion degrades everything at 3x4 by 3-4.6× → not a
  viable global mitigation. Details in `DEBUG_PROGRESS.md` Phase B2 →
  "UCC ablation".
- **Case B (3x1 allreduce @1 MiB): CLOSED for the host GPUDirect-RDMA
  track (2026-09-10, user-confirmed).** Root-caused to UCC/TL_UCP's ≥1 MiB
  allreduce path; with UCC excluded the GDR-on path is healthy (+1.9×) and
  outperforms host buffers (74.5–75.0 µs vs H H ~131 µs) — the host GDR
  setup is cleared for this case. Optional non-host-track follow-up:
  per-collective UCC tuning (blanket `coll ^ucc` ruled out). Full closure
  rationale in `DEBUG_PROGRESS.md` Phase B2 → "Case B closure".
- **Phase 1 — Step 1 (`osu-cuda`): CLOSED as the current host CUDA-aware-MPI
  investigation (2026-09-16, user-directed).** Host p2p GDR is proven, the
  original collective catastrophe is reclassified as co-tenant contention,
  and Case B is root-caused to UCC. Case A remains preserved as a deferred
  host UCX follow-up; it is not being claimed as solved or discarded.

**Deferred follow-ups (not the immediate next step):**

1. **Case A (3x4 bcast ≥8 MiB) — deferred host-track item; rail hypothesis
   REFUTED, UCX experiment retained for later:** the 2026-09-10 follow-up
   probe (see
   `DEBUG_PROGRESS.md` Phase B2 → "Case A follow-up probe") verified the
   build's rail knobs (`UCX_MAX_RNDV_RAILS=2` default,
   `UCX_MULTI_LANE_MAX_RATIO=4.0` filter, `UCX_RNDV_PERF_DIFF=1.0` protocol
   choice) and showed the GDR data path is **already 2-rail 50/50** (the
   earlier "single-rail zero-copy" claims were mis-parsed proto rows and are
   superseded — performance numbers and verdicts stand). Queued next
   experiment: rendezvous-scheme/chunk test on the normal UCC-enabled path —
   V0 base / V1 `UCX_RNDV_SCHEME=put` / V2 `UCX_MIN_RNDV_CHUNK_SIZE=256K`
   (or 1M) / C gdroff control, same resweep structure, `UCX_MAX_RNDV_RAILS=2`
   kept. The literal rail test remains unnecessary because it is a no-op by
   construction.
2. **Track 2.2 (re-scoped, deferred):** minimal in-container HPL-MxP test on 3x4 —
   default vs `UCX_IB_GPU_DIRECT_RDMA=n` exported into the container +
   `NCCL_DEBUG=INFO` — looking for the bcast-shaped residual (known
   UCC-independent) on clean nodes; the 2026-09-03 probe found the
   in-container gdrdrv/GDR gap.
3. *(Optional, non-host-track)* Case B UCC-side tuning: per-collective
   algorithm/threshold selection for allreduce ≥1 MiB.
4. **Phase 1 test 2 — `nccl-tests` (NCCL path)** is now the immediate pivot,
   with host-only scope. The existing host `all_reduce_perf` is still blocked
   on missing `libnccl.so.2`; no NCCL job has been submitted yet.

### Phase 1 — Step 1 closure and Step 2 pivot (2026-09-16)

Phase 1 — Step 1 (`osu-cuda`) is closed for now. No more host OSU-CUDA
collective experiments will be started in the immediate workflow. This is a
scope closure, not a claim that every UCX/UCC behavior is fixed.

- Closed evidence: host launch sanity, host p2p GPUDirect RDMA, clean-node
  collective replication, anomaly resweep, and UCC ablation.
- Case B is closed for the host-GDR track as UCC/TL_UCP-causal.
- Case A is deferred with its evidence and queued UCX scheme/chunk idea
  preserved for a later decision.
- Phase 1 — Step 2 now starts with **host-only `nccl-tests`** so the NCCL
  communication path can be evaluated separately from the paused OSU/UCX
  branch. Container tests are intentionally excluded from this handoff.
- The first Step 2 action is dependency resolution for host
  `libnccl.so.2`; after that, begin with a small host `sendrecv` test and
  record NCCL transport, HCA/rail, GDR status, and A/B behavior.

**Resume point:** Phase 1 CUDA-aware-MPI GDR status consolidated post-B2:
p2p GDR works; collective GDR is healthy in most clean cases; Phase B's
catastrophe was co-tenant contamination; Case B is UCC-causal; and Case A is
the deferred host UCX item. The immediate resume point is host-only NCCL
dependency resolution, with no container mixing. All results, analysis, and
evidence pointers are in `DEBUG_PROGRESS.md`; raw evidence is in
`outputs/phase1-step0/` and `outputs/phase1-step1/`.

**User-confirmed final OSU-CUDA conclusion (2026-09-16, closure addendum):**
CUDA-aware MPI GPUDirect RDMA is **proven working on the host path, for both
P2P and tested collective traffic**. The remaining OSU-CUDA work concerns
performance anomalies in particular collective paths, not basic confirmation
of whether GPUDirect RDMA is functional.

- **Strongest proof — the P2P experiment:** with default settings,
  `UCX_PROTO_INFO=y` reported rendezvous zero-copy read from remote over
  `rc_mlx5`; with `UCX_IB_GPU_DIRECT_RDMA=n` the protocol changed to
  CUDA-copy/host-staging paths; GPU-to-GPU bandwidth and latency improved
  with GDR enabled; host-to-host tests stayed effectively unchanged
  (negative control) (script
  `debug-scripts/phase1-step1/run_phase1_step1_p2p_2x1.pbs:79-80`; output
  `outputs/phase1-step1/step1_p2p_2x1_v1.o:50`).
- **Collective-side equivalent evidence:** the clean 3×4 Case A output
  contains the same rendezvous zero-copy read-from-remote rows with 50/50
  rail selection, while its GDR-off portion shows staging-related
  `cuda_copy` paths (output
  `outputs/phase1-step1/step1_collb2_resweep_3x4bcast_pris_v1.o:225`; test
  setup `debug-scripts/phase1-step1/run_phase1_step1_collb2_3x4.pbs:156-157`).
- **Diagnostic roles:** `UCX_PROTO_INFO=y` is the direct evidence of the
  selected UCX data path (with `UCX_LOG_LEVEL=info`, zero-copy RDMA vs
  CUDA/host staging); `--mca coll_base_verbose 100` identifies the
  collective implementation (UCC selected in normal B2 runs) but does not
  itself prove GDR; `--mca pml_base_verbose 10` shows Open MPI selected the
  UCX PML but does not independently prove GDR.
- **Qualification:** working GPUDirect RDMA does not mean every collective
  algorithm, message size, or software path performs well with it. Case B is
  associated with the UCC collective path (anomaly disappeared when UCC was
  excluded); Case A still used the zero-copy GDR protocol but performed
  poorly — a performance/algorithm/protocol issue, not failed GPUDirect
  RDMA. `UCX_PROTO_INFO` is a protocol-configuration report, not a
  packet-by-packet trace; the same-job GDR-on/GDR-off comparison and the
  host-only control are what make the conclusion strong.


### Phase 1 Step 2 status update — 2026-09-17

The host nccl-tests build and v3 single-node smoke passed in PBS job
67034.gaas on hpc-gaas-g06. All three all_reduce_perf arms completed with
zero-error markers. The default NCCL log selected the IBext network plugin
and reported GDR enabled. Since this smoke launched one rank, it validated
local MPI/NCCL startup only; it did not test inter-node traffic.

Ran the host NCCL sendrecv tests for 2x1 and 3x1 (jobs 67037.gaas and
67038.gaas) using the Phase 1 Step 1 host mpirun + pbsdsh bridge pattern and
the HPL-MxP launch model's explicit hostfile, rank-to-local-GPU mapping, no
binding, and per-node evidence. MPI and correctness checks passed, but the
`NCCL_IB_DISABLE=1` arm still selected `NET/IBext_v11`, so the socket-floor
transport check failed. The 3x4 run is held until the Socket selection is
verified. See `debug-scripts/phase1-step2/README.md` for job evidence.
