# Manual Inspection Error Log

Append-only case log for errors requiring user judgment (Track 2 of
`workflow/05-Workflow-Error-Patching-Procedures.md`). Recording a case or a
proposed fix never authorizes it.

---

## Case 2026-09-17-A: NCCL internal error — 3x4 default-GDR all_reduce_perf

- **Status:** RESOLVED (fix validated by rerun)
- **Workflow:** `scripts/gaas-internode-coms-debug/` Phase 1 — Step 2, NCCL
  GDR A/B collective ladder, attempt `step2_gdr_coll_3x4_v1`, ctrl allreduce
  arm.
- **PBS job:** `67581.gaas` (2026-09-17 22:51–22:54 +08, pinned gpu_ded
  g22+g20+g02, 12 ranks, 4/node, exit 1).
- **Observed error:** all ranks of the ctrl (default NCCL) `all_reduce_perf`
  launch aborted before the first measured size row: `Test NCCL failure
  all_reduce.cu:507 'internal error - please report this issue to the NCCL
  developers'` on hpc-gaas-g20 (mpirun exit 3). Immediately preceded by 6×
  `NCCL WARN NET/IB : Remote {IB|RoCE} device is incompatible with the local
  [8]mlx5_bond_0:1/RoCE / [4]mlx5_4:1/IB. Try selecting NICs of only one
  link type using NCCL_IB_HCA` on g22/g20.
- **Confirmed facts:**
  - Failure is specific to ctrl + allreduce + 12 ranks on this node set: the
    same job's broadcast arms (ctrl and gdroff) and the gdroff allreduce arm
    all passed with valid transport evidence (ctrl bcast 72 IB/24 GDRDMA vs
    gdroff 48/0; ctrl allreduce died before any measurement; gdroff allreduce
    600 IB/0 GDRDMA).
  - The link-type incompatibility WARNs appear ONLY in the failed arm (0
    occurrences in the three passing 3x4 arms).
  - Zero sweep rows completed — the error occurred during communicator/graph
    construction or the first (warmup) collective, not mid-sweep.
  - The 12-rank 1 MiB all-reduce smoke (job `67419.gaas`, nodes
    g01+g22+g20, default NCCL, GDR enabled) PASSED — so 12-rank default-GDR
    allreduce is not inherently broken; this attempt's node set (g02 in the
    trio) and/or the full 8 B–64 MiB sweep differ.
  - NCCL 2.29.3+cuda13.1 (nvhpc/26.3), nccl-tests b4d5bee, H200 × 12,
    `NCCL_TESTS_DEVICE=0`, per-rank `CUDA_VISIBLE_DEVICES`, extended
    `NCCL_DEBUG_SUBSYS` — same launch pattern as all passing arms.
  - RAS `Call to bind failed: Address already in use` warnings also appear
    in passing arms (3x1 ctrl allreduce) — background noise, not the cause.
- **Suspected cause (unconfirmed):** the external IB plugin's graph
  construction for the default-GDR 12-rank allreduce considers the RoCE bond
  (`mlx5_bond_0`) alongside the IB HCAs, hits the mixed-link-type
  incompatibility, and fails with an internal error instead of excluding the
  bond. GDR-off selects a different channel set (600 channels) that avoids
  the bond path.
- **Impact:** one of six GDR A/B cells (3x4 allreduce) is missing its ctrl
  arm → cell recorded FAILED/INCONCLUSIVE. All other cells (P2P 2x1/3x1/3x4,
  broadcast 2x1/3x1/3x4, allreduce 2x1/3x1) are complete and valid.
- **Suggested fixes for user review (NOT applied):**
  1. Retry `step2_gdr_coll_3x4_v1` as v2 unchanged (cheap; tests
     transience — but the signature looks deterministic for this node mix).
  2. Retry with `NCCL_IB_HCA=^mlx5_bond` (exclude the RoCE bond from NET/IB
     selection) — the warning's own suggestion; changes transport scope, so
     it must be a user-approved, documented arm rather than a silent default.
  3. Keep the default arm but test at reduced rank counts (e.g., 3x2) to
     isolate the trigger, as a separate diagnostic job.
  4. Report upstream to NVIDIA (the error string requests it) with the
     preserved logs.
- **Evidence (byte-verified, committed):**
  `scripts/gaas-internode-coms-debug/outputs/phase1-step2/step2_gdr_coll_3x4_v1*`
  (esp. `_ctrl_allreduce.log`, `_gdroff_allreduce.log`,
  `_ctrl_broadcast.log`, `.o`, `.e`, per-node fabric/checkpoint logs).

### Resolution (2026-09-17 ~23:00 +08)

- **Status:** RESOLVED (fix validated by rerun).
- **Authorization:** user-directed investigation request ("investigate the
  error and how to solve it", 2026-09-17).
- **Root cause (confirmed from evidence):** the IBext plugin's channel plan
  for the ctrl 12-rank allreduce on nodes g22+g20+g02 assigned g22 rank 1's
  inter-node links (channels 04/0 and 10/0 toward ranks 7 on g20 and 11 on
  g02) to `mlx5_bond_0` (NCCL Dev 8, RoCE, with GDRDMA) while the peer
  endpoints of the same links used `mlx5_4` (Dev 4, InfiniBand). RoCE vs IB
  is an incompatible link-type pair → the plugin's connect check
  (`ib_plugin.c:1312`) rejected the connection → `transport/net.cc:555`
  returned ncclInternalError(3) → the first (warmup) allreduce aborted with
  zero size rows measured. Only this arm used Dev 8 (broadcast ctrl 72
  channels and both gdroff plans used HCAs 0–7 only); the bond is topology-
  admitted (`keep=1 coll=(null)`) on every run and is only fatal when a
  channel plan actually lands on it asymmetrically — node-mix dependent
  (the 12-rank allreduce smoke on g01+g22+g20 passed).
- **Fix applied:** `NCCL_IB_HCA=mlx5_0,mlx5_1,mlx5_2,mlx5_3,mlx5_4,mlx5_5,
  mlx5_8,mlx5_9` (explicit include of the eight IB HCAs, excluding the RoCE
  bond) applied to BOTH arms for device symmetry — implemented as
  `run_phase1_step2_gdr_coll_3x4_hca.pbs` + a conditional `-x NCCL_IB_HCA`
  passthrough in the shared runner (commit `7cda615`). The plugin reads
  `NCCL_IB_HCA` (verified in its env-var table) and its own warning
  suggests this knob.
- **Validation (`step2_gdr_coll_3x4_v2`, job `67584.gaas`, same trio
  g22+g20+g02, 83 s, exit 0, PASS):** ctrl allreduce now completes — 628
  via-IBext channels with 236 GDRDMA vs gdroff 600/0; zero bond/dev-8
  channel lines in any arm; `ib_hca_filter` recorded in metadata. Recovered
  cell: 3x4 allreduce 64 MiB algbw **43.92 vs 18.86 GB/s (+2.33×)**, busbw
  80.51 vs 34.57; 16 MiB +1.94×; 4 MiB +1.47×; 1 MiB +1.12×. Broadcast
  reproduces v1 (ctrl 72.65 vs gdroff 24.85 GB/s @64 MiB, +2.92×).
- **Remaining concerns:** the unfiltered default remains latent-broken for
  12-rank default-GDR allreduce on node mixes that trigger the asymmetric
  bond rail (an NCCL/plugin robustness gap — the plugin aborts instead of
  excluding the incompatible rail). Worth reporting upstream with the v1
  logs. The GDR A/B campaign cell now carries the documented condition
  "bond excluded" for both arms at 3x4 collective.
