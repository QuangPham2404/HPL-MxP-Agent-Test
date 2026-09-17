# Phase 2 Stage 1 — container/launch preflight

Implements Stage 1 of the Phase 2 plan (`../../README.md` → "Phase 2 plan"):
container and launch preflight for the in-container GPUDirect-RDMA
verification (Track 2.2). Inspection only — one PBS job, 2 host-pinned nodes,
no A/B arms, no measurements.

## What it checks

1. **Container tooling inventory (the opening check, user-required):** is
   `nccl-tests` and `osu-cuda-nvidia-alternative` packaged inside
   `hpc-benchmarks_26.02.sif`, with the Phase 2 binaries
   (`sendrecv_perf`/`broadcast_perf`/`all_reduce_perf`; `osu_bw`/`osu_latency`
   with CUDA support evidence)? → `PHASE2_PREFLIGHT_TOOLING_GATE`
   (PASS / PARTIAL / FAIL).
2. SIF image identity (stat + `apptainer inspect` + guarded sha256).
3. Container stack versions: container MPI (CUDA-awareness via `ompi_info`),
   UCX, NCCL (tiny single-rank `all_reduce_perf -b 8 -e 8` version/transport
   probe — diagnostic only, not a measurement), CUDA/driver view.
4. Container RDMA device/library access (`/dev/infiniband`, `ibv_devices`,
   verbs/UCX/NCCL libs via `ldconfig`).
5. Host GDR module state per node (`lsmod` peermem/gdrdrv, `/dev/gdrdrv`,
   `nvidia-smi topo -m`) — informational only. **gdrdrv presence is NOT a
   pass condition** (per the Phase 2 plan).
6. Container launch-path check: container `mpirun` +
   `rsh_pbsdsh_container.sh` + container `orted` across both nodes — per-rank
   node/GPU mapping and per-rank container device view, then a cross-node MPI
   message-flow test using the container OSU package if present
   (osu_hello → osu_allreduce → osu_bw fallback chain, H H buffers).
   → `PHASE2_PREFLIGHT_LAUNCH_GATE` (PASS / SPAWN_ONLY / FAIL).

Final marker `PHASE2_PREFLIGHT_RESULT=PASS` only when both gates PASS; job
exits 0 then, 1 otherwise. Per the agreed missing-tooling path (2026-09-18),
a tooling-gate failure means **stop and report** — no Stage 2 jobs, no
fallback bind-mounts without user approval.

## Submission sequence

Node rules as the Phase 1 Step 2 campaign: choose the 2 cleanest eligible
nodes from `gpu_as`/`gpu_ded` (matching each node's `resources_available.Qlist`),
host-pinned chunks `ngpus=4:ncpus=48:mem=1000GB` (node isolation even though
the preflight uses 1 rank per node), group `hpc_ebslee`, no `mpiprocs`,
one job at a time. Save a pre-submission scheduler snapshot; after completion
save a post-run snapshot. From this directory on GAAS after synchronization:

~~~bash
mkdir -p ../../outputs/phase2-preflight
pbsnodes -aSj > ../../outputs/phase2-preflight/phase2_preflight_v1_presched.txt
qsub -q <queue> \
  -l "select=host=<node1>:ngpus=4:ncpus=48:mem=1000GB+host=<node2>:ngpus=4:ncpus=48:mem=1000GB" \
  -v "ATTEMPT=phase2_preflight_v1,REQ_HOSTS=<node1>+<node2>" \
  -o ../../outputs/phase2-preflight/phase2_preflight_v1.o \
  -e ../../outputs/phase2-preflight/phase2_preflight_v1.e \
  run_phase2_preflight.pbs
~~~

After completion:

~~~bash
pbsnodes -aSj > ../../outputs/phase2-preflight/phase2_preflight_v1_postsched.txt
~~~

## Validation and failure handling

The preflight passes only when: PBS exits 0, both `.o`/`.e` exist,
`PHASE2_PREFLIGHT_TOOLING_GATE=PASS` (all three nccl-tests binaries +
osu_bw/osu_latency found with CUDA evidence), and
`PHASE2_PREFLIGHT_LAUNCH_GATE=PASS` (spawn/mapping OK + cross-node MPI
message flow rc=0). A `SPAWN_ONLY` launch gate means the OSU package was
missing (tooling gate already forces the stop). Any gate failure or FATAL is
preserved for manual inspection — do not retry, and do not change launcher,
modules, binds, or transport settings without user direction.

## Attempt log

- `phase2_preflight_v1` — submitted 2026-09-18 (see
  `../../outputs/phase2-preflight/phase2_preflight_v1*`); outcome recorded in
  `../../DEBUG_PROGRESS_P2.md` → "Phase 2 — Stage 1".
