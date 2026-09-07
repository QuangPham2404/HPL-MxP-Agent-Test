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
