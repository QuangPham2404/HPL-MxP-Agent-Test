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
  2.87 µs @ 4 B rising to 104.72 µs @ 1 MiB. Small-message ~3 µs is consistent
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
same nodes/placement. 12/12 A/B tests completed (rc=0), ~7 min.
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
     sender-side GDR is rail-limited (~40-50 GB/s, see below) while the staged
     pipeline also runs ~40 GB/s. Same speed, different mechanism — which is
     why protocol logs, not just deltas, were captured.

**Analysis — the CUDA multi-rail imbalance (74/26):**

- **Hardware context** (`nvidia-smi topo -m` evidence): each node has 8 IB
  HCAs (rails) plus an Ethernet bond. GPU0 has **PIX** affinity (single PCIe
  bridge — the closest possible relationship) to exactly one NIC, `mlx5_2`;
  every other HCA is **NODE** distance (reachable, but crossing PCIe host
  bridges).
- **UCX multi-rail behavior**: host memory → clean **50/50** across two rails
  → 87.9 GB/s ≈ 2×400G NDR at ~88% efficiency ⇒ each rail carries ~44 GB/s.
  CUDA memory → **74% `mlx5_2` / 26% `mlx5_0`** → 50.4 GB/s.
- **Why the split is uneven for CUDA**: UCX scores each lane by estimated
  cost. Host memory looks symmetric from the process → tie → 50/50. GPU memory
  is asymmetric: `mlx5_2` sits on GPU0's own PCIe switch (PIX), `mlx5_0`
  needs extra hops (NODE) → the far rail is scored worse and gets less
  traffic.
- **The arithmetic of the gap**: with a 74/26 split, both rails run in
  parallel but the 74%-loaded rail finishes last — it must carry 74% of the
  bytes at ~44 GB/s, bounding the transfer at ~44/0.74 ≈ 59 GB/s theoretical;
  50.4 GB/s observed. A balanced 50/50 would approach ~87 GB/s (the host
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
  single rail (e.g. `UCX_TLS=rc_mlx5_2`) to confirm ~44 GB/s per rail; check
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

**Negative controls (H H) are clean everywhere** — bcast @ 64 MiB ctrl/GDR-off:
797/800 (2x1), 2768/3175 (2x2), 2622/2554 (3x1), 4512/4428 (3x4); allreduce
@ 1 MiB: 98/105, 135/141, 104/103, 193/222. The A/B is valid; the pathology
is specific to CUDA buffers + GDR enabled + ≥3 ranks.

**Findings:**

1. **With default UCX (GDR enabled), CUDA-aware MPI collectives with ≥3 ranks
   are pathologically slow — 13× to 44× slower than staging.** Effective bcast
   rate at 3x1: control 0.55 GB/s vs GDR-off 24.2 GB/s (≈ H H 25.6 GB/s). The
   2-rank case (2x1) is unaffected (33.5 GB/s).
2. **The degradation is linear in message size** (~1.9 µs/KB from ~32-64 KiB
   onset; e.g. 3x1 ctrl bcast: 1 MiB → 1,751 µs, 64 MiB → 120,941 µs) — a
   per-fragment/per-page fixed cost dominates, consistent with either uncached
   GPU-memory re-registration per message or fenced GDR writes with
   per-fragment synchronization. Exact internal mechanism is a follow-up; the
   empirical conclusion stands regardless.
3. **Protocol evidence**: control-run logs show a mix of staged
   (`cuda_copy, frag host`, 50/50 rails) and zero-copy GDR (74/26 rails)
   selections across UCC/UCP contexts; the exercised ≥3-rank collective path
   pays the ~1.9 µs/KB cost while the GDR-off run's staged path runs at
   ~0.04 µs/KB. Phase A showed the same zero-copy GDR path is *fast* for pure
   2-rank p2p (50 GB/s) — so this is a collective-path interaction, not broken
   GDR per se.
4. **Rail/affinity (3x4 nvtopo, 4 GPUs visible)**: each GPU has its own
   PIX-paired NIC (g15: GPU0↔`mlx5_3`, GPU1↔`mlx5_4`, GPU2↔`mlx5_8`,
   GPU3↔`mlx5_9`; NV18 between all GPUs) — the platform is rail-optimized
   1:1 GPU:NIC. Phase A's 74/26 imbalance was the 1-GPU-per-node artifact;
   balanced rails are architecturally available at 3x4 (UCX's per-rank rail
   choice still unverified — kept with the Phase A follow-up).

**Implication for the HPL-MxP debug**: a 3×4 CUDA-aware-MPI collective with
default GDR-enabled UCX runs at ~2 GB/s instead of ~25 GB/s — if any of the
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



