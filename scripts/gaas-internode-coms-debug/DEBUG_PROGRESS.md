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


