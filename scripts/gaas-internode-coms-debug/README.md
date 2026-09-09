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

---

### Phase 1 — status and resume point (updated 2026-09-08)

**Completed:**

- **Step 0 (sanity): PASS** — host launch path (`mpirun` + `rsh_pbsdsh.sh` bridge)
  and CUDA-aware host MPI verified (`phase1_step0_sanity_v1`, job `59640.gaas`).
- **Step 1 Phase A (p2p GDR A/B at 2x1): PASS** — host GPUDirect RDMA works for
  p2p (zero-copy selected, clear A/B deltas, negative control clean)
  (`step1_p2p_2x1_v1`, job `59671.gaas`). CUDA p2p reaches ≈57% of the fabric
  ceiling due to a 74/26 multi-rail split in the 1-GPU-per-node case.
- **Step 1 Phase B (collective GDR A/B ladder): COMPLETE — critical finding.**
  With default UCX (GDR enabled), CUDA collectives with ≥3 ranks are
  **pathologically slow (13-44× slower than staging**; e.g. 3x1 bcast @ 64 MiB:
  0.55 GB/s vs 24.2 GB/s staged). 2-rank collectives unaffected; H H negative
  controls clean. See `DEBUG_PROGRESS.md` Phase B section for full tables,
  protocol evidence, and analysis. Jobs `59931/59933/59934/59935.gaas`.
  - Rail/affinity resolved for 3x4: each GPU has its own PIX-paired NIC
    (rail-optimized 1:1 GPU:NIC) — Phase A's 74/26 was the 1-GPU-per-node
    artifact.

**Pending (user decision required):**

1. **Track 2.2 (decisive next step)**: minimal in-container HPL-MxP test on
   3x4 — default vs `UCX_IB_GPU_DIRECT_RDMA=n` exported into the container —
   plus an NCCL transport check (`NCCL_DEBUG=INFO`). Determines whether the
   app's slowness rides the host-side GDR-collective pathology found in
   Phase B or a separate container/NCCL issue (note: the 2026-09-03 probe
   found a gdrdrv/GDR gap inside the container).
2. **Optional mechanism follow-up**: registration-cache / fenced-write
   investigation of the ≥3-rank GDR collective pathology
   (`UCX_MEMTYPE_CACHE`, rndv thresholds, newer UCX).
3. **Optional**: verify UCX per-rank rail balance at 3x4 (each GPU now has a
   PIX NIC; the 74/26 question may be moot with the real 4-GPU mapping).
4. **Phase 1 test 2 — `nccl-tests` (NCCL path)**: still blocked on the missing
   host `libnccl.so.2` (recorded 2026-09-03); NCCL path verification may
   happen via Track 2.2 in-container instead.

**Resume point:** Phase 1 CUDA-aware-MPI GDR status is consolidated
(p2p works; collectives pathological at ≥3 ranks with GDR on). Awaiting user
instruction on pending item 1 (Track 2.2) and optional items 2-3. All results,
analysis, and evidence pointers are in `DEBUG_PROGRESS.md`; raw evidence in
`outputs/phase1-step0/` and `outputs/phase1-step1/`.



