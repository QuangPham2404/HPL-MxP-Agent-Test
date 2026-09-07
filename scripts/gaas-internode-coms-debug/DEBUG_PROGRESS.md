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

**Transport evidence (UCX_PROTO_INFO in job log):**

- Control `D D`: `rendezvous zero-copy read from remote — 74% on
  rc_mlx5/mlx5_2:1 + 26% on rc_mlx5/mlx5_0:1` (from `cuda/GPU0`) → **GDR
  zero-copy, multi-rail, but unevenly split 74/26**.
- GDR-off `D D`: `rendezvous cuda_copy, fenced write to remote, frag host` on
  50%/50% rails → **host staging**, as designed.
- Control `H H`: zero-copy, **50%/50%** on two rails → 87.9 GB/s ≈ 2×400G
  NDR rails = the fabric ceiling.
- Topology evidence: 8× mlx5 HCAs (+1 bond) per node; GPU0 has PIX (single
  PCIe bridge) affinity only to `mlx5_2`; all other HCAs are NODE distance.

**Findings:**

1. **Host GPUDirect RDMA works.** Control run selects zero-copy GDR paths for
   CUDA memory; the GDR-off run measurably degrades `D D` bandwidth (−20%) and
   latency (+60% @ 4 MiB) and its logs switch to `cuda_copy` host staging.
2. **GPU traffic reaches only ~57% of the fabric ceiling** (50.4 vs 87.9 GB/s).
   Root cause visible in the logs: **uneven multi-rail split for CUDA memory
   (74/26) vs even (50/50) for host memory** — consistent with GPU0↔NIC PCIe
   proximity (PIX `mlx5_2` gets 74%) driving UCX lane scoring. A 50/50 cuda
   split would plausibly recover most of the gap.
3. `D H` shows no GDR benefit (37.9 ≈ 41.4 GB/s) — same 74/26 rail split
   limits it; direction asymmetry noted.
4. `H H` unchanged between runs — the A/B comparison was clean.

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

- Investigate the CUDA 74/26 rail split — potential ~40% more inter-node GPU
  bandwidth at 2x1; check whether other GPUs/topologies (3x4) show the same.
- Phase B collective ladder as planned (2x1 → 2x2 → 3x1 → 3x4).
- Per the debug plan, host GDR working means Track 2.2 (test the same
  capability inside the HPL-MxP container) remains the eventual branch.

