# GAAS GPUDRMA-direct Debugging Progress    

## Phase 1 — Step 0: host-native launch sanity check (2026-09-07) — PASS

**Attempt:** `phase1_step0_sanity_v1` — PBS job `59640.gaas`, 2 nodes × 1 GPU
(`hpc-gaas-g06`, `hpc-gaas-g07`, 1× NVIDIA H200 each), host-native HPC-X 2.25.1
OpenMPI v4.1.9a1 (`module nvhpc/26.3`), launched via host `mpirun` +
`multi-node-test/rsh_pbsdsh.sh` pbsdsh bridge (canonical flags).
**Evidence:** `outputs/phase1-step0/phase1_step0_sanity_v1.{o,e}` (retrieved
locally, byte-identical); script `debug-scripts/phase1-step0/run_phase1_step0_sanity.pbs`.

**Result: `STEP0_RESULT=PASS`** — all four checks exit 0.

- **A — host OpenMPI CUDA-awareness: PASS.** `opal_built_with_cuda_support=true`,
  `opal_cuda_support=true`, built `--with-cuda`, MPI extensions include `cuda`
  (74 CUDA-related `ompi_info --all` lines).
- **B — rank placement + GPU visibility (informational): PASS.** 2 ranks, one
  per node, each rank sees exactly 1 H200.
- **C — `osu_hello` cross-node through the bridge launch path: PASS** (v7.4,
  2 processes).
- **D — `osu_allreduce` host buffers: PASS.** Full sweep 4 B → 1 MiB completed:
  2.87 µs @ 4 B rising to 104.72 µs @ 1 MiB. Small-message ≈3 µs is consistent
  with a healthy low-latency inter-node path (transport identity is *not*
  proven here — that is Step 1's job).

**Analysis:** The measurement infrastructure is sound. The host `mpirun` +
`pbsdsh`-bridge launch path completes real cross-node MPI message flow
(spawn → `MPI_Init` → collective), and the host MPI is CUDA-aware. Any Step 1
failure can now be attributed to the GPUDirect RDMA path itself rather than
the launch machinery.

**Next step (Phase 1, Step 1 — primary GDR test):** `osu_bw D D` vs `H H` and
`osu_latency D D` on 2 nodes × 1 GPU (`CUDA_VISIBLE_DEVICES=0`), with UCX debug
logging, and a default-vs-GDR-disabled comparison (e.g. restrict `UCX_TLS` to
drop the GPU-RDMA path); then `ucx_perftest -m host` vs `-m cuda` for transport
confirmation. Note: Phase 1 test 2 (`nccl-tests`) still has the unresolved host
`libnccl.so.2` blocker recorded on 2026-09-03.

## Phase 1 — Step 1, Phase A: p2p GDR A/B at 2x1 (2026-09-07) — GDR WORKS; rail imbalance found

**Attempt:** `step1_p2p_2x1_v1` — PBS job `59671.gaas`, 2 nodes × 1 GPU
(`hpc-gaas-g06`, `hpc-gaas-g10`, H200), host HPC-X 2.25.1 OMPI v4.1.9a1 +
UCX 1.20.0, `rsh_pbsdsh.sh` bridge, `--bind-to none` (record-only). Control run
(default UCX) vs GDR-off run (`UCX_IB_GPU_DIRECT_RDMA=n`) in the same job,
same nodes/placement. 12/12 A/B tests completed (rc=0), ≈7 min.
**Evidence:** `outputs/phase1-step1/step1_p2p_2x1_v1.{o,e}` (+ nvtopo/ucxtrans
logs); script `debug-scripts/phase1-step1/run_phase1_step1_p2p_2x1.pbs`.

**Results — `osu_bw` at 4 MiB (MB/s):**

| Test | Control | GDR-off | Control gain |
|---|---|---|---|
| `D D` (GPU→GPU) | 50,422 | 40,249 | +25% |
| `D H` (GPU→host) | 37,925 | 41,446 | −8% |
| `H D` (host→GPU) | 51,525 | 37,687 | +37% |
| `H H` (host→host, negative control) | 87,874 | 88,158 | −0.3% |

**Results — `osu_latency`:** `D D` @ 8 B: 10.15 µs (ctrl) vs 20.00 µs (GDR-off);
`D D` @ 4 MiB: 107.8 µs vs 173.2 µs. `H H` identical in both runs (2.37 µs @ 8 B,
58.7 µs @ 4 MiB) — negative control clean, A/B valid.

**Analysis — why the evidence proves host GPUDirect RDMA works (4 layers):**

1. **Direct proof — protocol selection logs.** The control run selects
   `rendezvous zero-copy read from remote` from `cuda/GPU0` over `rc_mlx5`
   (real InfiniBand RDMA, not TCP). "Zero-copy" means the payload is never
   staged through host memory — the NIC reads/writes GPU memory directly, which
   *is* GPUDirect RDMA by definition. The GDR-off run selects
   `rendezvous cuda_copy, fenced write to remote, frag host` — explicit host
   staging. The knob flipped the data path exactly as designed.
2. **Consequence proof — A/B performance deltas.** `D D` bandwidth @ 4 MiB:
   50.4 → 40.2 GB/s (−20% with GDR off); `D D` latency @ 8 B: 10.2 → 20.0 µs
   (staging pays a GPU→host→wire→host→GPU copy chain on every small message);
   `H D`: 51.5 → 37.7 GB/s (receiver-side GPU-direct works). If GDR were
   broken, control ≈ GDR-off everywhere; they clearly separate.
3. **Validity proof — negative controls.** `H H` identical in both runs
   (87,874 vs 88,158 MB/s, 0.3% noise) → the knob only touched the GPU-memory
   path and nothing else drifted (same job, nodes, placement). Step 0 already
   established the instrument is sound (launch path + CUDA-aware MPI), so a
   good result here means the GDR path is good, not that the tool is broken.
4. **The combo matrix reads "working on both ends".** `H D` +37% shows
   receiver-side GPU registration works; `D D` +25% shows the full GPU→GPU
   chain; no combo collapses to its GDR-off twin — which is the signature of a
   total or one-sided GDR failure.
   - *Nuance — `D H` shows no gain (37.9 vs 41.4 GB/s):* not evidence against
     GDR (the logs still show zero-copy on that path). Two different
     bottlenecks coincidentally land at the same number: the control's
     sender-side GDR is rail-limited (≈40-50 GB/s, see below) while the staged
     pipeline also runs ≈40 GB/s. Same speed, different mechanism — which is
     why protocol logs, not just deltas, were captured.

**Analysis — the CUDA multi-rail imbalance (74/26):**

- **Hardware context** (`nvidia-smi topo -m` evidence): each node has 8 IB
  HCAs (rails) plus an Ethernet bond. GPU0 has **PIX** affinity (single PCIe
  bridge — the closest possible relationship) to exactly one NIC, `mlx5_2`;
  every other HCA is **NODE** distance (reachable, but crossing PCIe host
  bridges).
- **UCX multi-rail behavior**: host memory → clean **50/50** across two rails
  → 87.9 GB/s ≈ 2×400G NDR at ≈88% efficiency ⇒ each rail carries ≈44 GB/s.
  CUDA memory → **74% `mlx5_2` / 26% `mlx5_0`** → 50.4 GB/s.
- **Why the split is uneven for CUDA**: UCX scores each lane by estimated
  cost. Host memory looks symmetric from the process → tie → 50/50. GPU memory
  is asymmetric: `mlx5_2` sits on GPU0's own PCIe switch (PIX), `mlx5_0`
  needs extra hops (NODE) → the far rail is scored worse and gets less
  traffic.
- **The arithmetic of the gap**: with a 74/26 split, both rails run in
  parallel but the 74%-loaded rail finishes last — it must carry 74% of the
  bytes at ≈44 GB/s, bounding the transfer at ≈44/0.74 ≈ 59 GB/s theoretical;
  50.4 GB/s observed. A balanced 50/50 would approach ≈87 GB/s (the host
  ceiling). So the imbalance — not a broken GDR path — caps GPU traffic at 57%
  of the fabric.
- **Relevance to HPL-MxP**: the app's inter-node traffic is GPU-resident; if
  the container's stack (UCX, or NCCL — which selects NICs independently)
  makes a similar-or-worse rail choice, inter-node comms could run at roughly
  half the available bandwidth — a plausible contributor to the slow 3x4
  baseline.
- **Caveat — do not over-infer**: this test had only **1 GPU visible per
  node** (PBS cgroup), so all traffic funneled through GPU0's viewpoint. In
  the real 3x4 topology, each rank/GPU would plausibly prefer its own
  PIX-paired NIC, and the rail picture may look different (better, or
  differently bad). NCCL inside the container is a separate rail
  decision-maker (Track 2.2). **Kept for further investigation.**

**Void items (recorded, not rerun):** (a) `ucx_perftest` cross-check is void —
a script bug let it inherit `UCX_IB_GPU_DIRECT_RDMA=n` from the GDR-off suite,
and a server/client startup race caused `Connection refused` on the cuda
attempt (the host attempt then paired with the wrong server instance); the OSU
results + UCX proto logs are definitive without it. (b) `ucx_info -t` evidence
command used wrong syntax (needs `-d`); HCA inventory came from
`nvidia-smi topo -m` instead.

**Decision per README Phase 1 matrix:** OSU p2p = **PASS** (host GDR works).
Per session plan: reporting now; Phase B (collectives ladder) or further p2p
debugging (e.g. the 74/26 rail split) awaits user instruction.

**Suggested follow-ups (not executed):**

- **Rail-split investigation** (with the 1-GPU-per-node caveat above): force a
  single rail (e.g. `UCX_TLS=rc_mlx5_2`) to confirm ≈44 GB/s per rail; check
  rail-count/selection knobs (e.g. `UCX_MAX_RNDV_RAILS`, to be verified
  against `ucx_info -c` before use); check whether the 3x4 per-GPU mapping
  naturally produces balanced rails.
- Phase B collective ladder as planned (2x1 → 2x2 → 3x1 → 3x4).
- Per the debug plan, host GDR working means Track 2.2 (test the same
  capability inside the HPL-MxP container) remains the eventual branch.

## Phase 1 — Step 1, Phase B: collective GDR A/B ladder (2026-09-07/08) — CRITICAL FINDING: GDR-enabled CUDA collectives pathological at ≥3 ranks

**Attempts:** `step1_coll_2x1_v1` (job `59931.gaas`, g08+g09), `step1_coll_2x2_v1`
(job `59933.gaas`, g08+g10), `step1_coll_3x1_v1` (job `59934.gaas`, g08+g10+g15),
`step1_coll_3x4_v1` (job `59935.gaas`, g09+g15+g16). Host HPC-X 2.25.1 OMPI
v4.1.9a1 + UCX 1.20.0, `rsh_pbsdsh.sh` bridge, `--bind-to none` (record-only),
control run (default UCX) vs GDR-off run (`UCX_IB_GPU_DIRECT_RDMA=n`) per job,
same nodes/placement. Per run: `osu_bcast` H H + `-d cuda` (up to 64 MiB) and
`osu_allreduce` H H + `-d cuda` (default sizes, max 1 MiB). GPU per rank =
local rank. **All 32 tests completed (rc=0).**
**Evidence:** `outputs/phase1-step1/step1_coll_{2x1,2x2,3x1,3x4}_v1.{o,e}` +
per-node nvtopo/ucxdev logs; scripts
`debug-scripts/phase1-step1/run_phase1_step1_coll_*.pbs`.

**Results — CUDA-buffer collectives, control vs GDR-off (µs, max-size row;
bcast @ 64 MiB, allreduce @ 1 MiB):**

| Topo | bcast cuda ctrl | bcast cuda GDR-off | slowdown | allreduce cuda ctrl | allreduce cuda GDR-off | slowdown |
|---|---|---|---|---|---|---|
| 2x1 | 2,003 | 1,988 | 1.0× | 129 | 129 | 1.0× |
| 2x2 | 91,185 | 2,522 | **36×** | 1,545 | 138 | **11×** |
| 3x1 | 120,941 | 2,772 | **44×** | 4,311 | 146 | **30×** |
| 3x4 | 29,671 | 2,286 | **13×** | 591 | 154 | **3.8×** |
| 2x1 @ 32 MiB | 1,018 | 1,009 | 1.0× | — | — | — |
| 2x1 @ 8 MiB | 279 | 277 | 1.0× | — | — | — |
| 2x1 @ 1 MiB | 66 | 66 | 1.0× | — | — | — |
| 2x2 @ 32 MiB | 45,821 | 1,288 | **35.6×** | — | — | — |
| 2x2 @ 8 MiB | 10,040 | 406 | **24.7×** | — | — | — |
| 2x2 @ 1 MiB | 1,276 | 100 | **12.7×** | — | — | — |
| 3x1 @ 32 MiB | 59,209 | 1,420 | **41.7×** | — | — | — |
| 3x1 @ 8 MiB | 13,927 | 412 | **33.8×** | — | — | — |
| 3x1 @ 1 MiB | 1,751 | 106 | **16.6×** | — | — | — |
| 3x4 @ 32 MiB | 14,134 | 1,181 | **12.0×** | — | — | — |
| 3x4 @ 8 MiB | 3,579 | 336 | **10.7×** | — | — | — |
| 3x4 @ 1 MiB | 508 | 105 | **4.8×** | — | — | — |

Rows appended 2026-09-08 to show the bcast `-d cuda` size progression behind
the linear-degradation claim (finding 2): the GDR-off latency is nearly flat
in size (staged, ≈25-30 GB/s effective) while the control grows linearly with
bytes, so the slowdown itself grows with message size (3x1: 16.6× @ 1 MiB →
33.8× @ 8 MiB → 41.7× @ 32 MiB → 44× @ 64 MiB; 2x2: 12.7× → 24.7× → 35.6× →
36×; 3x4: 4.8× → 10.7× → 12.0× → 13×; 2x1 stays 1.0× at every size).

**Negative controls (H H) are clean everywhere** — bcast @ 64 MiB ctrl/GDR-off:
797/800 (2x1), 2768/3175 (2x2), 2622/2554 (3x1), 4512/4428 (3x4); allreduce
@ 1 MiB: 98/105, 135/141, 104/103, 193/222. The A/B is valid; the pathology
is specific to CUDA buffers + GDR enabled + ≥3 ranks.

**Findings:**

1. **With default UCX (GDR enabled), CUDA-aware MPI collectives with ≥3 ranks
   are pathologically slow — 13× to 44× slower than staging.** Effective bcast
   rate at 3x1: control 0.55 GB/s vs GDR-off 24.2 GB/s (≈ H H 25.6 GB/s). The
   2-rank case (2x1) is unaffected (33.5 GB/s).
2. **The degradation is linear in message size** (≈1.9 µs/KB from ≈32-64 KiB
   onset; e.g. 3x1 ctrl bcast: 1 MiB → 1,751 µs, 64 MiB → 120,941 µs) — a
   per-fragment/per-page fixed cost dominates, consistent with either uncached
   GPU-memory re-registration per message or fenced GDR writes with
   per-fragment synchronization. Exact internal mechanism is a follow-up; the
   empirical conclusion stands regardless.
3. **Protocol evidence**: control-run logs show a mix of staged
   (`cuda_copy, frag host`, 50/50 rails) and zero-copy GDR (74/26 rails)
   selections across UCC/UCP contexts; the exercised ≥3-rank collective path
   pays the ≈1.9 µs/KB cost while the GDR-off run's staged path runs at
   ≈0.04 µs/KB. Phase A showed the same zero-copy GDR path is *fast* for pure
   2-rank p2p (50 GB/s) — so this is a collective-path interaction, not broken
   GDR per se.
4. **Rail/affinity (3x4 nvtopo, 4 GPUs visible)**: each GPU has its own
   PIX-paired NIC (g15: GPU0↔`mlx5_3`, GPU1↔`mlx5_4`, GPU2↔`mlx5_8`,
   GPU3↔`mlx5_9`; NV18 between all GPUs) — the platform is rail-optimized
   1:1 GPU:NIC. Phase A's 74/26 imbalance was the 1-GPU-per-node artifact;
   balanced rails are architecturally available at 3x4 (UCX's per-rank rail
   choice still unverified — kept with the Phase A follow-up).

**Implication for the HPL-MxP debug**: a 3×4 CUDA-aware-MPI collective with
default GDR-enabled UCX runs at ≈2 GB/s instead of ≈25 GB/s — if any of the
app's inter-node traffic rides this path, it fully explains an "extremely
slow" baseline. Caveat: HPL-MxP runs in the container and primarily uses NCCL
for collectives, and the 2026-09-03 comm-transport probe found a gdrdrv/GDR
gap *inside* the container — so whether the container stack (its own
UCX/NCCL) hits this pathology or a different one is exactly what Track 2.2
must decide. **This is the strongest root-cause lead so far.**

**Suggested follow-ups (not executed, user decision):**

1. **Track 2.2 (decisive)**: minimal in-container test on 3x4 — default vs
   `UCX_IB_GPU_DIRECT_RDMA=n` (exported into the container) — plus an NCCL
   transport check (`NCCL_DEBUG=INFO`). If the baseline's slowness tracks this
   knob, root cause confirmed + mitigation found.
2. **Mitigation trade-off note**: disabling GDR loses the Phase A p2p gain
   (50→40 GB/s) but avoids the 13-44× collective catastrophe — clearly
   favorable for collective-heavy workloads on this stack.
3. **Mechanism follow-up (optional)**: registration-cache / fenced-write
   investigation (e.g., `UCX_MEMTYPE_CACHE`, rndv thresholds, newer UCX).

## Phase 1 — Step 1, Phase B2: collective diagnostic replication on clean pinned nodes (2026-09-09) — PHASE B CATASTROPHE = CONTENTION ARTIFACT; two residual GDR anomalies isolated; UCC executes collectives

**Attempts:** `step1_collb2_2x1_v2` (job `61090.gaas`, g16+g17),
`step1_collb2_2x2_v1` (job `61091.gaas`, g16+g17), `step1_collb2_3x1_v1`
(job `61102.gaas`, g16+g17+g13), `step1_collb2_3x4_v1` (job `61104.gaas`,
g16+g17+g13). Superseded `step1_collb2_2x1_v1` (job `61084.gaas`, g16+g17):
8/8 tests completed but the per-node `ucxdev`/`nvtopo` evidence was silently
lost to a script defect (Phase B's `export OUTDIR` was dropped, so `-x OUTDIR`
forwarded nothing and the evidence block's trailing `true` masked the redirect
failure) — Track 1 patched (`export OUTDIR` + missing-file guard) and rerun as
v2; v1 measurements are valid and consistent with v2. Host HPC-X 2.25.1 OMPI
4.1.9a1 + UCX 1.20.0, `rsh_pbsdsh.sh` bridge, `--bind-to none`,
`CUDA_VISIBLE_DEVICES=local rank`, control (default UCX) vs GDR-off
(`UCX_IB_GPU_DIRECT_RDMA=n`, `-x`) in the same job on the same pinned nodes;
chunks `host=X:ngpus=4:ncpus=48:mem=1000GB` (allocation-study shape). Exact
Phase B test matrix (`osu_bcast` H H + `-d cuda` `-m 67108864`; `osu_allreduce`
H H + `-d cuda`, default sizes). B2 diagnostics: `UCC_LOG_LEVEL=info` (`-x`),
`--mca coll_base_verbose 100`, `pml_base_verbose 10`,
`mpi_common_cuda_verbose 10`, `mpi_common_cuda_warning 1`; `ompi_info --all`
once per job; per-rank GPU-UUID/affinity/UCX-UCC-env evidence; pbsdsh
clean-node checkpoints (pre/prectrl/mid/post) + pre/post scheduler snapshots.
**All 32 tests rc=0.**
**Evidence:** `outputs/phase1-step1/step1_collb2_*` (`.o`/`.e` + per-node
ompiinfo/ucxdev/nvtopo + checkpoint logs + `presched`/`postsched` snapshots);
scripts `debug-scripts/phase1-step1/run_phase1_step1_collb2_*.pbs` +
`collb2_node_snapshot.sh`.

**Clean-node record:** B2 waited for resource-alloc exp4 (N-sweep, jobs
61055+) to release the trio; g14 was then taken by another user's 12h
full-node job (61071), so the 2-node rungs ran on pristine g16+g17 and the
3-node rungs on g16+g17+g13 — g13 nearly pristine (one light co-tenant, job
59192: 12 CPUs + 1 GPU, present and stable at all 8 checkpoints, loadavg
~17/100 CPUs), user-approved fallback. g20 briefly appeared pristine globally
but is `gpu_ded`-partitioned (Qlist, unreachable from `gpu_as`; also taken by
job 61097). In-job checkpoints recorded no foreign co-tenants on g16/g17 and
only 59192 on g13; all H H negative controls are clean in every rung and mode.

**Results — CUDA-buffer collectives, ctrl vs GDR-off (µs; ratio ctrl/gdroff;
bcast sizes 1/8/32/64 MiB, allreduce 64K/256K/512K/1M):**

| Rung | bcast cuda ctrl | bcast cuda gdroff | bcast ratio | allred cuda ctrl | allred gdroff | allred ratio |
|---|---|---|---|---|---|---|
| 2x1 | 29.1 / 176.3 / 678.1 / 1359.8 | 64.1 / 273.6 / 993.8 / 1975.9 | 0.5 / 0.6 / 0.7 / 0.7× | 29.1 / 35.5 / 44.4 / 54.8 | 67.2 / 77.5 / 100.2 / 122.5 | 0.4–0.5× |
| 2x2 | 48.8 / 289.7 / 1118.8 / 2210.5 | 98.0 / 371.3 / 1314.9 / 2658.8 | 0.5 / 0.8 / 0.9 / 0.8× | 39.4 / 45.5 / 52.9 / 75.9 | 87.5 / 92.8 / 103.2 / 134.2 | 0.5–0.6× |
| 3x1 | 47.8 / 250.1 / 938.9 / 1855.3 | 105.6 / 438.2 / 1450.5 / 2795.7 | 0.5 / 0.6 / 0.6 / 0.7× | 36.3 / 41.0 / 50.7 / **1127.3** | 84.0 / 91.0 / 108.1 / 146.3 | 0.4 / 0.5 / 0.5 / **7.7×** |
| 3x4 | 67.6 / 651.7 / 2897.5 / **5864.9** | 103.2 / 331.1 / 1152.0 / 2294.2 | 0.7 / **2.0× / 2.5× / 2.6×** | 82.7 / 85.9 / 93.5 / 109.4 | 137.7 / 134.2 / 136.2 / 153.5 | 0.6–0.7× |

H H negative controls: 0.8–1.1× at every size on every rung (bcast @64 MiB
ctrl/gdroff: 805/804, 4093/3934, 2887/2868, 4520/4787 µs) — the A/B is valid
throughout.

**Comparison with Phase B (jobs 59931–59935, uncontrolled nodes):**

| Cell | Phase B | B2 | Verdict |
|---|---|---|---|
| bcast @64 MiB 2x2 | 91,185 µs (36×) | 2,210 µs (0.8×) | catastrophe gone |
| bcast @64 MiB 3x1 | 120,941 µs (44×) | 1,855 µs (0.7×) | catastrophe gone |
| bcast @64 MiB 3x4 | 29,671 µs (13×) | 5,865 µs (**2.6×**) | reduced 5× — residual |
| allreduce @1 MiB 2x2 | 1,545 µs (11×) | 75.9 µs (0.6×) | catastrophe gone |
| allreduce @1 MiB 3x1 | 4,311 µs (30×) | 1,127 µs (**7.7×**) | reduced 4× — residual |
| allreduce @1 MiB 3x4 | 591 µs (3.8×) | 109.4 µs (0.7×) | gone |

**Findings:**

1. **Phase B's catastrophic ≥3-rank GDR collective pathology (13–44×) does
   not reproduce on clean nodes.** Six of eight rung×collective cells are now
   *healthy* GDR — ctrl is 1.4–2.5× **faster** than staged (e.g. 3x1 bcast
   @64 MiB: 1855 vs 2796 µs ≈ 36 vs 24 GB/s effective), the expected zero-copy
   gain. Phase B ran on uncontrolled nodes; together with resource-alloc
   exp2/exp3 (co-tenant dose-response 1.0×→1.6×→25×), **Phase B's collective
   tables were contention-inflated and must be reinterpreted: the host GDR
   path itself is healthy for collectives; the catastrophe required
   co-tenancy.**
2. **Two residual, reproducible GDR-on anomalies survive contention removal**
   (clean H H controls in the same runs):
   - **3x4 bcast cuda ≥8 MiB: 2.0–2.6× slower than staged** (5865 vs 2294 µs
     @64 MiB; ~11.4 vs ~29.3 GB/s). This is the HPL-MxP baseline topology and
     the panel-broadcast analog — the remaining host-stack suspect.
   - **3x1 allreduce cuda @1 MiB: 7.7×** (1127 vs 146 µs), healthy at ≤512 KiB
     — a sharp size threshold (onset between 512 KiB and 1 MiB).
3. **What MPI actually chooses (the B2 diagnostic aim):** `pml = ucx`
   (priority 51 over ob1 20; `select: component ucx selected`, every rank,
   every run). Coll stack enabled on MPI_COMM_WORLD (coll_base_verbose →
   stderr `.e` files): **ucc=100, hcoll=90, cuda=78, tuned=30, libnbc=10,
   basic=10** (han/adapt disabled). **UCC executes the measured collectives in
   both modes** — a UCC team is created and destroyed per test (66 score-map
   lines × 8 tests in every rung) and the score map claims
   `Cuda: {0..inf}:TL_UCP:10`. Per the B2 design, this rests on the
   `comm_select` lines, not on `UCC_UCP_CONTEXT` presence alone.
4. **Protocol evidence (UCX_PROTO_INFO):** ctrl cuda path = rendezvous
   zero-copy over `rc_mlx5` (true GDR); gdroff = staged `cuda_copy, frag
   host`. In the 3x4 bcast ctrl case the inter-node zero-copy selection is
   **single-rail** (`rc_mlx5/mlx5_5` or `mlx5_9` per context) — a candidate
   mechanism for the 2.6× residual (single 400G rail GDR vs multi-lane
   staging). Intra-node cuda IPC zero-copy appears in both modes.
5. Node facts: with `ngpus=4` chunks every rank sees the 4-GPU carve-out
   (renumbered 0–3); per-rank `nvidia-smi -L` UUID evidence records the exact
   physical devices (e.g. 3x1: g16 GPU0-a0650fac, g17 GPU0-0890a8d9, g13
   first carve-out GPU); cpuset/NUMA and effective UCX/UCC env recorded per
   rank.

**Implications for the HPL-MxP debug:** the app's slow 3x4 baseline is now
attributed primarily to (a) the in-container GPUDirect gap (`cuda_cpy`
staging, `gdrdrv` absent — 2026-09-03 probe; pristine-node in-container runs
still ~6× below the single-node reference) and (b) co-tenant host contention
(resource-alloc exp2/exp3). The host-side Phase B "collective catastrophe" is
largely an artifact — **but the new 3x4 bcast ≥8 MiB residual (2.6× under
UCC/zero-copy GDR) sits exactly on the app's panel-broadcast pattern at the
baseline topology** and is the strongest remaining host-stack lead.

**Suggested follow-ups (not executed, user decision):**

1. **Single-variable test per the B2 interpretation rule (UCC is selected):**
   GDR-on with `--mca coll ^ucc` at 3x4 and 3x1 — separates the UCC-executed
   path (hcoll/tuned fallback) for both residuals.
2. **3x4 bcast residual mechanism:** rail behavior of the zero-copy selection
   (single-rail `mlx5_5/9` observed) — multi-rail knobs (e.g.
   `UCX_MAX_RNDV_RAILS`, verify against `ucx_info -c`), `UCX_MEMTYPE_CACHE`,
   rndv thresholds.
3. **Track 2.2 re-scoped:** the decisive in-container test should now also
   look for the 2–3× bcast-shaped residual on clean nodes rather than the
   13–44× catastrophe.

### Phase B2 — Anomaly resweep (2026-09-10): both residual anomalies are MECHANISM, not noise

**The two anomaly cases (from Phase B2, restated):**

- **Case A — 3x4 `osu_bcast -d cuda`:** GDR-on (ctrl) slower than staged
  (gdroff) at ≥8 MiB; original measurement −2.0×/−2.5×/−2.6× at 8/32/64 MiB,
  healthy +1.5× at 1 MiB; single-rail zero-copy GDR selection.
- **Case B — 3x1 `osu_allreduce -d cuda`:** GDR-on slower at 1 MiB only;
  original measurement −7.7× @1 MiB, healthy +2.1–2.3× at ≤512 KiB.

**What was run:** a two-arm repetition series to separate mechanism from
noise and from the original 3-node set's light co-tenant. Per case: 3
repetitions on the **orig arm** (g16+g17+g13 — exactly the original anomaly
conditions, g13's co-tenant 59192 present and stable at every checkpoint) and
3 repetitions on the **pristine arm** (strictly pristine g14+g16+g17, freed
overnight; zero foreign co-tenants at every checkpoint). Each repetition is a
separate PBS job with a fresh allocation (per-rep GPU UUID evidence records
the carve-out) running the case's cuda test + its H H negative control in the
same-job A/B (ctrl vs `UCX_IB_GPU_DIRECT_RDMA=n`) with the full Phase B2
diagnostic instrumentation. 12 jobs, 48 test executions, **all rc=0**
(orig arm jobs `61419–61424.gaas`, pristine arm jobs `61425–61430.gaas`;
script `debug-scripts/phase1-step1/run_phase1_step1_collb2_resweep.pbs`,
parameterized `CASE/ATTEMPT/REQ_HOSTS`).

**Ratio convention (from this subsection onward): `+N` = GDR-on N× faster
than GDR-off; `−N` = GDR-on N× slower.**

**Results — Case A, 3x4 `osu_bcast -d cuda` (µs, ctrl vs gdroff → signed
ratio; sizes 8/32/64 MiB):**

| Rep | Arm | 8 MiB | 32 MiB | 64 MiB |
|---|---|---|---|---|
| v1 | orig (g16+g17+g13) | 653.2/329.9 → −1.98× | 2914.9/1159.2 → −2.51× | 5917.3/2269.6 → −2.61× |
| v2 | orig | 660.4/331.8 → −1.99× | 2904.1/1156.1 → −2.51× | 5886.9/2263.6 → −2.60× |
| v3 | orig | 642.4/327.8 → −1.96× | 2899.0/1162.3 → −2.49× | 5911.9/2268.9 → −2.61× |
| v1 | pristine (g14+g16+g17) | 590.1/342.1 → −1.72× | 2864.2/1114.8 → −2.57× | 6394.0/2160.8 → −2.96× |
| v2 | pristine | 570.4/337.9 → −1.69× | 2891.0/1111.1 → −2.60× | 6359.0/2128.6 → −2.99× |
| v3 | pristine | 588.6/336.5 → −1.75× | 2908.9/1127.4 → −2.58× | 6326.6/2143.5 → −2.95× |

H H negative controls: ±1.00–1.04× in every rep of both arms.

**Results — Case B, 3x1 `osu_allreduce -d cuda` (µs, ctrl vs gdroff → signed
ratio; sizes 256K/512K/1M):**

| Rep | Arm | 256 KiB | 512 KiB | 1 MiB |
|---|---|---|---|---|
| v1 | orig | 41.1/90.8 → +2.21× | 51.0/125.8 → +2.47× | 1247.3/149.0 → −8.37× |
| v2 | orig | 40.9/90.6 → +2.22× | 50.7/108.1 → +2.13× | 1779.3/166.9 → −10.66× |
| v3 | orig | 41.4/91.7 → +2.21× | 50.7/108.0 → +2.13× | 1229.8/245.9 → −5.00× |
| v1 | pristine | 37.4/85.3 → +2.28× | 47.3/100.6 → +2.13× | 1128.5/141.7 → −7.96× |
| v2 | pristine | 37.3/84.3 → +2.26× | 47.1/100.8 → +2.14× | 1117.0/139.9 → −7.99× |
| v3 | pristine | 37.5/84.2 → +2.25× | 47.0/100.8 → +2.15× | 1310.0/140.3 → −9.34× |

H H negative controls: ±1.00–1.08× in every rep of both arms.

**Verdicts:**

1. **Case A (3x4 bcast cuda ≥8 MiB): MECHANISM, co-tenant-independent.**
   6/6 repetitions reproduce (orig arm −2.49…−2.61× @64 MiB, stable to ~±1%;
   pristine arm −2.95…−2.99×, slightly *stronger* — g13's co-tenant is not a
   contributor). The single-rail zero-copy GDR selection persists in every
   rep (e.g. pris v1 on g14: `rc_mlx5` zero-copy across `mlx5_4/5/8/9`
   depending on rank pair); UCC selection evidence identical per rep
   (ucc=100 enabled, 264 score-map lines, UCC team per test).
2. **Case B (3x1 allreduce cuda @1 MiB): MECHANISM.** 6/6 repetitions
   reproduce (orig −5.0…−10.7×, pristine −7.96…−9.34× @1 MiB). The healthy
   sub-512 KiB behavior is highly consistent (+2.13…+2.28× everywhere). The
   pathological 1 MiB ctrl latency varies across reps (1117–1779 µs) — the
   magnitude is less stable than Case A, but the direction never flips and
   the staged arm stays ~140–250 µs.
3. The original Phase B2 single-run measurements were therefore accurate
   samples of stable behavior, not outliers; the two residuals join the
   confirmed-fact base and remain the host-stack suspects for the app's
   panel-broadcast-shaped traffic.

**Evidence:** `outputs/phase1-step1/step1_collb2_resweep_*` (`.o`/`.e`,
ompiinfo/ucxdev/nvtopo, pre/prectrl/mid/post checkpoint logs, presched/
postsched snapshots; all byte-verified against GAAS).

### Phase B2 — UCC ablation (2026-09-10): SPLIT VERDICT — Case B (3x1 allreduce @1 MiB) is UCC-causal and disappears; Case A (3x4 bcast) persists and is NOT UCC

**What was run:** the two confirmed anomaly cases repeated with UCC excluded
from the coll framework (`--mca coll ^ucc` on every mpirun — the single delta
vs the anomaly resweep; everything else unchanged: pinned pristine nodes,
rank/GPU mapping, launcher, full B2 diagnostics, H H controls, same-job
GDR-on/GDR-off A/B). 6 jobs, 3 reps per case, all on strictly pristine
g14+g16+g17 (3/3 pristine verified before every submission, zero foreign
co-tenants at every checkpoint), all 24 test executions rc=0. Case A jobs
`61694/61695/61715.gaas`, Case B jobs `61717/61718/61719.gaas`; script
`debug-scripts/phase1-step1/run_phase1_step1_collb2_uccabl.pbs`.

**UCC-exclusion proof (as designed):** `.e` files show ucc entirely absent
from `coll:base:comm_select` availability on MPI_COMM_WORLD (vs "component
available: ucc, priority: 100" in every resweep/B2 run), with the fallback
stack **hcoll(90) > cuda(78) > tuned(30) > libnbc(10) > basic(10)** enabled;
`.o` files contain **zero** UCC team/score-map lines (vs 264 per resweep
case-A job). Both proofs present in all 6 attempts.

**Results — Case A, 3x4 `osu_bcast -d cuda` (µs, ctrl vs gdroff → signed
ratio; sizes 1/8/32/64 MiB):**

| Rep | 1 MiB | 8 MiB | 32 MiB | 64 MiB |
|---|---|---|---|---|
| v1 | 104.0/143.0 → +1.37× | 2652.7/944.2 → −2.81× | 13614.1/3800.0 → −3.58× | 29087.1/7596.9 → −3.83× |
| v2 | 105.7/140.0 → +1.32× | 2371.2/943.1 → −2.51× | 13173.6/3913.9 → −3.37× | 29095.7/7639.0 → −3.81× |
| v3 | 103.3/140.7 → +1.36× | 2462.9/1001.3 → −2.46× | 13354.8/3764.4 → −3.55× | 29337.2/7657.2 → −3.83× |

**Results — Case B, 3x1 `osu_allreduce -d cuda` (µs, ctrl vs gdroff → signed
ratio; sizes 256K/512K/1M):**

| Rep | 256 KiB | 512 KiB | 1 MiB |
|---|---|---|---|
| v1 | 46.0/94.2 → +2.05× | 56.1/110.3 → +1.96× | 74.7/141.5 → **+1.89×** |
| v2 | 46.0/93.8 → +2.04× | 56.1/110.3 → +1.97× | 74.5/141.1 → **+1.89×** |
| v3 | 46.0/93.9 → +2.04× | 62.1/117.5 → +1.89× | 75.0/147.4 → **+1.97×** |

H H negative controls: Case A ±1.00–1.06× at ≥8 MiB (−1.27…−1.30× at 1 MiB in
v2/v3 — small-size noise); Case B ±1.00–1.08×.

**Verdicts (per the ablation design's interpretation rules):**

1. **Case B (3x1 allreduce cuda @1 MiB): anomaly DISAPPEARS with GDR enabled
   → UCC/TL_UCP is causal.** Without UCC the 1 MiB ctrl drops from
   1117–1310 µs (resweep pristine) to 74.5–75.0 µs — a 15–17× improvement —
   flipping the ratio from −7.96…−9.34× to +1.89…+1.97× (healthy GDR, and
   faster than even H H at ~131 µs). The healthy sub-512 KiB gains survive
   (+1.89…+2.05×, slightly below the with-UCC +2.13…+2.28×). This is
   in-job evidence: both A/B arms ran the same (UCC-free) coll stack.
2. **Case A (3x4 bcast cuda ≥8 MiB): anomaly REMAINS (worse) → UCC is not
   the primary cause.** The in-job A/B still shows GDR-on 2.5–3.8× slower
   than staged at ≥8 MiB under the UCC-free stack, so the cause sits at or
   below the UCX transport-selection layer. Per the design, the next step
   for Case A is UCX rail/rendezvous-threshold testing.
3. **UCC-exclusion is NOT a viable global mitigation:** excluding UCC
   degrades *everything* at 3x4 — cuda bcast ctrl @64 MiB 29,087–29,337 µs
   vs 6,326–6,394 µs with UCC (−4.6×), staged cuda 7,597–7,657 vs
   2,129–2,161 µs (−3.5×), and even host H H bcast 13,315–13,637 vs
   4,344–4,419 µs (−3.1×). UCC provides large collective value on this
   stack; any mitigation must be per-collective/topology-aware (or UCC-side
   tuning), not a blanket exclusion.

**Evidence:** `outputs/phase1-step1/step1_collb2_uccabl_*` (`.o`/`.e`,
ompiinfo/ucxdev/nvtopo, checkpoint logs, presched/postsched snapshots; all
byte-verified against GAAS).



