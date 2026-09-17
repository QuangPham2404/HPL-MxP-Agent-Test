# GAAS In-Container GDR Debugging Progress — Phase 2 (Track 2.2)

This file records Phase 2 (in-container GPUDirect RDMA verification) results,
analysis, and next steps. Phase 1 (host GDR verification, CLOSED 2026-09-17)
is recorded in `DEBUG_PROGRESS.md`, which is now a frozen historical record —
new content goes here. Plan: `README.md` → "Phase 2 plan" plus the execution
decisions of 2026-09-18 (full test set at both Stage-2 rungs; stop-and-report
on missing container tooling; bond-abort contingency pre-authorized for the
container NCCL 3x4 allreduce, signature-matched only).

Stage overview (per the plan):

| Stage | Scope | Status |
|---|---|---|
| 1 | Container/launch preflight (tooling inventory + versions + device access + launch-path check) | **COMPLETE 2026-09-18 — tooling gate PARTIAL → STOPPED for user decision** |
| 2 | Container-native OSU/NCCL GDR A/B (2x1 then 3x4, full test set) | blocked on Stage 1 tooling decision |
| 3 | HPL-MxP integration A/B at N=480000/NB=1024 vs `3x4-baseline_v1` | not started |

## Phase 2 — Stage 1: container/launch preflight (2026-09-18) — COMPLETE; tooling gate PARTIAL (stop point)

**Scored attempt:** `phase2_preflight_v3` — PBS job `67795.gaas` (2026-09-18,
~4 min), pinned `gpu_ded` nodes hpc-gaas-g22 (pristine) + hpc-gaas-g20 (one
co-tenant, 67357), chunks `ngpus=4:ncpus=48:mem=1000GB`, group `hpc_ebslee`,
script `debug-scripts/phase2-preflight/run_phase2_preflight.pbs`.
**Final gates: `PHASE2_PREFLIGHT_TOOLING_GATE=PARTIAL`,
`PHASE2_PREFLIGHT_LAUNCH_GATE=PASS`,
`PHASE2_PREFLIGHT_RESULT=ACTION_REQUIRED`.** Per the agreed missing-tooling
path (2026-09-18), Stage 2 is NOT started; options below await user decision.

Attempt chain (all Track 1 script-machinery fixes, evidence preserved):

- `phase2_preflight_v1` — job `67791.gaas`: OSU search checked only the
  `osu_mpi_tests` directory surface + depth≤5 from `/` (the binaries live at
  depth 6); host-GDR pbsdsh capture empty (bare `bash` + local redirect —
  pbsdsh task output does not return to the caller).
- `phase2_preflight_v2` — job `67793.gaas`: found the OSU package; CUDA
  capability decided by a `--help` grep that false-positived on the generic
  PAPI help text ("OMB must be configured with CUDA support"); global find
  still capped at depth 6. Its `TOOLING_GATE=PASS` marker was overstated and
  is superseded by v3.
- `phase2_preflight_v3` — job `67795.gaas` (scored): unrestricted
  whole-container search; CUDA capability decided by ldd linkage only.

### Finding 1 — tooling inventory (the opening check, user-required)

- **nccl-tests: COMPLETE.** `/workspace/microbenchmarks/nccl_tests/` holds
  `sendrecv_perf`, `broadcast_perf`, `all_reduce_perf` (the three Phase 2
  needs) plus all_gather/alltoall/gather/reduce/reduce_scatter/scatter/
  hypercube and `*_mpi` variants (symlinks to `/usr/local/bin`). ldd:
  `libcudart.so.13` + container `libnccl.so.2` (with one
  `libverifiable.so.0 => not found` — a container packaging quirk that did
  not affect the probe run).
- **OSU: packaged but NOT CUDA-capable.** The only OSU install is
  `/workspace/microbenchmarks/osu_mpi_tests/` — **OSU Micro-Benchmarks v7.5**
  (pt2pt incl. `osu_bw`/`osu_latency`, full collective suite incl.
  `osu_allreduce`/`osu_bcast`, one-sided) whose binaries link only
  `libmpi.so.40` (container HPC-X OMPI) — no `libcuda`/`libcudart`, no
  accelerator/`-d` options. **An unrestricted whole-container find (osu_bw
  anywhere, `*osu*` dirs, `*cuda-nvidia*` names) found no CUDA-capable
  osu_bw/osu_latency anywhere.**
- **"osu-cuda-nvidia-alternative" is NOT packaged in the container** — no
  file or directory with that (or any `cuda-nvidia`) name exists. The
  container's bundled HPC-X (same 2.25.1 OMPI 4.1.9a1 family as the host
  stack) does not ship its osu test suite at all (`/opt/hpcx/ompi/tests`
  absent — unlike the host nvhpc/26.3, which provides
  `osu-micro-benchmarks-cuda`). The OSU source package exists at
  `/workspace/source_code/osu_mpi/osu_mpi.tar.gz` (contents not enumerated).

**Consequence:** Stage 2's MPI/UCX arm (osu_bw/osu_latency `D D`) cannot run
with container-native binaries. Stage 2's NCCL arm (sendrecv/broadcast/
all_reduce) is fully equipped.

### Finding 2 — container launch-path check: PASS

Container `mpirun` + `rsh_pbsdsh_container.sh` bridge + container `orted`
across g22+g20 (Approach 1, validated flags, `-x PATH -x LD_LIBRARY_PATH`,
`--bind-to none`): 2 ranks on 2 distinct hosts; each rank sees its node's 4
allocated H200s (UUIDs recorded; CVD auto-set by apptainer `--nv`) and all 9
HCAs (`/dev/infiniband` + `ibv_devices` per rank); cpus/mems affinity
recorded. Cross-node MPI message flow via the packaged osu_bw (H H): rc=0,
full default sweep, ~88 GB/s at 4 MiB — matching the host `H H` fabric
ceiling from Phase 1 (healthy inter-node container MPI path).

### Finding 3 — container stack versions (evidence: `*_container_versions.log`)

- MPI: Open MPI 4.1.9a1 (HPC-X v2.25.1, `--with-cuda`, `pml=ucx`, coll stack
  incl. hcoll/ucc/cuda; `opal_built_with_cuda_support=true`) — CUDA-aware.
- UCX: 1.20.0 at `/opt/hpcx` (configured `--with-cuda --with-gdrcopy`,
  `--without-knem`, xpmem) — same UCX version family as the host stack.
- NCCL: 2.29.2+cuda13.1 (`/usr/lib/x86_64-linux-gnu/libnccl.so.2`; container
  label `2.29.stable.20260109`) — one minor release behind host 2.29.3.
- CUDA 13.1 toolkit (nvcc 13.1.115); driver 580.126.20; 4x H200 per node.

### Finding 4 — NCCL in-container version/transport probe (8 B, 2 iters — not a measurement)

The container NCCL loads the **same external network plugin family as the
host campaign** ("NCCL RDMA Plugin v11" → `Using network IBext_v11`),
enumerates all 9 HCAs (8x 400G IB + the RoCE bond) and reports
`GPU Direct RDMA (nvidia-peermem) enabled` and `(DMABUF) enabled` per HCA —
container-side GDR registration capability is present, and host
`nvidia_peermem` is proven live today from inside the container. Relevant
for Stage 2: the `NCCL_NET_GDR_LEVEL=LOC` control and the per-channel
`/GDRDMA` evidence chain apply to this same 2.29.x + IBext_v11 stack.

### Finding 5 — SIF image identity

`hpc-benchmarks_26.02.sif`: 5,307,924,480 bytes, mtime 2026-05-06,
sha256 `123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628`,
base `nvcr.io/nvidia/hpc-benchmarks:26.02` (ubuntu 24.04, docker bootstrap),
NVIDIA NCCL label 2.29.stable.20260109, CUDA 13.1-era libs.

### Finding 6 — host GDR module state (informational; gdrdrv not a gate)

The pbsdsh-based per-node capture failed silently in all three attempts (two
different capture patterns; root cause not chased — recorded as a known
limitation of this preflight script; the per-node `*_hostgdr_*.log` files are
empty). Compensating evidence: (a) today's in-container NCCL probe (Finding
4) proves `nvidia_peermem` loaded and GDR-capable on g22; (b) the Phase 1
Step 2 fabric logs for the SAME node pair (2026-09-17,
`outputs/phase1-step2/step2_gdr_p2p_2x1_v2_fabric_hpc-gaas-g{22,20}.log`)
record `nvidia_peermem` loaded, 8-HCA inventory, `/dev/gdrdrv` absent (the
known 2026-09-03 gap — a GDR-Copy-path clue only, not an RDMA-path failure),
and GPU topology. gdrdrv absence remains informational per the plan.

Side observation (non-tooling): the container's `/tmp` exposes host `/tmp`
(apptainer default bind) — co-tenant cache directories were visible in the
container-side find. Irrelevant to the gates; noted for future staging-path
considerations.

### Next-step options (awaiting user decision — agreed stop-and-report path)

Stage 2 NCCL arm is unblocked either way; the decision concerns the MPI/UCX
`D D` arm:

- **(a) Bind-mount the host CUDA OSU binaries (recommended):** the host
  nvhpc/26.3 HPC-X `osu-micro-benchmarks-cuda` binaries (Phase 1 Step 1
  validated) bind-mounted into the container; host and container stacks are
  the same HPC-X 2.25.1 OMPI 4.1.9a1 / UCX 1.20.0 family, so the dynamic
  libs should resolve against the container's stack — to be verified in-job
  (ldd + H H launch sanity) before any `D D` measurement. Deviation from
  "container-packaged" tooling → needs explicit approval (pre-agreed to stop
  and ask).
- **(b) Build a CUDA OSU flavor inside the container** from
  `/workspace/source_code/osu_mpi/osu_mpi.tar.gz` (nvcc 13.1 available);
  heavier and needs build authorization; the tarball can also just be
  enumerated first to see whether the `cuda-nvidia-alternative` flavor is
  even provided.
- **(c) Stage 2 NCCL arm first:** proceed with container-native
  sendrecv/broadcast/all_reduce A/B now and decide the UCX arm separately.
- **(d) Different/newer SIF** packaging a CUDA OSU — largest change,
  reference-configuration impact; only if (a)/(b) are unacceptable.

### Evidence index

- All attempts: `outputs/phase2-preflight/phase2_preflight_v{1,2,3}*`
  (PBS .o/.e, inventory/tooling-gate/versions/rdma/launch/msgflow logs,
  NCCL version probe, osu_bw help, hostfiles, pre/post co-tenant snapshots,
  pre/post scheduler snapshots; v1/v2 superseded only in their gate logic —
  their version/device/identity/launch evidence is reproduced in v3).
- Script: `debug-scripts/phase2-preflight/run_phase2_preflight.pbs`
  (header documents the v1→v3 defect chain); submission/attempt log:
  `debug-scripts/phase2-preflight/README.md`.
- Jobs: `67791.gaas` (v1), `67793.gaas` (v2), `67795.gaas` (v3, scored),
  all g22+g20, gpu_ded, hpc_ebslee.
