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
| 1 | Container/launch preflight (tooling inventory + versions + device access + launch-path check + option (a) OSU staging validation) | **COMPLETE 2026-09-18** |
| 2 | Container-native OSU/NCCL GDR A/B (2x1 then 3x4, full test set) | ready (tooling validated; awaiting user go) |
| 3 | HPL-MxP integration A/B at N=480000/NB=1024 vs `3x4-baseline_v1` | not started |

## Phase 2 — Stage 1, part 1: container/launch preflight (2026-09-18) — COMPLETE; tooling gate PARTIAL (resolved by option (a), see next section)

**Scored attempt:** `phase2_preflight_v3` — PBS job `67795.gaas` (2026-09-18,
~4 min), pinned `gpu_ded` nodes hpc-gaas-g22 (pristine) + hpc-gaas-g20 (one
co-tenant, 67357), chunks `ngpus=4:ncpus=48:mem=1000GB`, group `hpc_ebslee`,
script `debug-scripts/phase2-preflight/run_phase2_preflight.pbs`.
**Final gates: `PHASE2_PREFLIGHT_TOOLING_GATE=PARTIAL`,
`PHASE2_PREFLIGHT_LAUNCH_GATE=PASS`,
`PHASE2_PREFLIGHT_RESULT=ACTION_REQUIRED`.** The PARTIAL tooling verdict
(nccl-tests complete; no CUDA-capable OSU in the container) was resolved by
the user's option (a) decision — staging validation in the next section.

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

**RESOLVED 2026-09-18: user chose option (a)** — bind/copy the host
CUDA OSU binaries into container reach and validate with a scaling smoke
(1x2 / 2x1 / 3x1 / 3x4, any available nodes). Executed below; the original
option list is preserved for the record:

- (a) host OSU staged into container reach (CHOSEN — see next section);
- (b) build a CUDA OSU flavor inside the container from
  `/workspace/source_code/osu_mpi/osu_mpi.tar.gz`;
- (c) Stage 2 NCCL arm only;
- (d) different/newer SIF.

## Phase 2 — Stage 1 completion: option (a) OSU staging + scaling smoke (2026-09-18) — ALL RUNGS PASS

**Decision:** user-directed option (a) with a 1x2 → 2x1 → 3x1 → 3x4 scaling
smoke on any available nodes (no pristine hunting), including a tiny
container-native NCCL all-reduce per rung. 1x2 = 1 node × 2 GPUs (intra-node
rung), confirmed by the user.

**Staging mechanism (validated):** the host nvhpc/26.3
`osu-micro-benchmarks-cuda` suite (flat layout, 64 entries, 26 MB,
osu_bw sha256 `a62ddcb636f3ae6f4530a199f2d9ec7d14b05823e622ac225dc4c4796ec76227`)
is copied once into `osu-cuda-host/osu-micro-benchmarks-cuda/` (shared
source of truth, gitignored) and then copied per job into **node-local
`/tmp/phase2_osu/`** on every allocated vnode (lock-guarded
`stage_osu_tmp.sh` via `pbsdsh --`). Rationale: **apptainer on GAAS does NOT
bind `/home` into containers** (1x2 v1 evidence: staged binary invisible)
but **`/tmp` IS default-bound** (phase2_preflight_v3 evidence) — and the
bridge-spawned remote `orted` containers ignore custom `-B` flags, so
`/tmp` is the one path visible to every container instance in the job.

**ABI policy (validated):** the staged binaries' host RPATH
(`$ORIGIN/../../lib`) does not exist at the stage locations, so `libmpi.so.40`
resolves to the container's `/opt/hpcx/ompi/lib` (in-container `ldd`:
`libmpi.so.40 => /opt/hpcx/ompi/lib/libmpi.so.40`, cuda libs present, no
missing libs) — the tests exercise the container MPI/UCX stack, made
deterministic by prepending `/opt/hpcx/ompi/lib:/opt/hpcx/ucx/lib` to
`LD_LIBRARY_PATH` scoped to the osu processes. Container-side sha256 of
osu_bw matches the host-side hash.

**Smoke results (final ladder; nodes g14+g11+g15, `gpu_as`, group
`hpc_ebslee`, chunks `ngpus=4:ncpus=48:mem=1000GB`; jobs
`67831/67836/67838/67840.gaas`; every rung: ABI clean, staged binary visible
on every rank, per-rank mapping verified, 6/6 tests PASS):**

| Rung (attempt) | osu_bw D D @4 MiB (MB/s) | osu_bw H H @4 MiB | osu_latency D D @8 B (µs) | NCCL allreduce 1 MiB busbw (GB/s) | NCCL channels (IBext/GDRDMA) |
|---|---|---|---|---|---|
| 1x2 (`phase2_osu_smoke_1x2_v5`) | 288,743 (NVLink) | 87,742 | 16.7 | 52.7 | intra-node (NVLink) |
| 2x1 (`phase2_osu_smoke_2x1_v2`) | 37,839 | 88,166 | 14.9 | 4.84 | 16/8 |
| 3x1 (`phase2_osu_smoke_3x1_v2`) | 37,844 | 88,335 | 14.3 | 4.70 | 24/16 |
| 3x4 (`phase2_osu_smoke_3x4_v2`) | 37,274 | 88,329 | 14.3 | 15.5 | 512/384 |

Smoke numbers are context only (default settings, no A/B, no numeric
gates), but three observations matter for Stage 2:

1. **Inter-node GPU-direct p2p runs at ~43% of the H H fabric ceiling**
   (37.3-37.8 vs ~88.3 GB/s) in the container default arm — echoing the host
   Phase 1 finding (host D D 50.4 vs H H 87.9 = 57%, rail-limited). Stage 2's
   UCX arm must capture `UCX_PROTO_INFO` rail/protocol evidence to explain
   the delta.
2. **Container NCCL GDR is live at default settings**: every inter-node rung
   shows per-channel `via NET/IBext_v11/N/GDRDMA` graph tags (8/16/384
   GDRDMA channels at 2x1/3x1/3x4), and 2x1 allreduce 1 MiB busbw (4.84
   GB/s) closely matches the host campaign's ctrl value (4.98 GB/s algbw
   equivalent) — the container NCCL stack behaves like the host's.
3. **The container's plain nccl-tests binaries are per-process singletons**
   (each forms a `nranks 1` comm); cross-node collectives require the
   `*_mpi` variants (MPI bootstrap). Stage 2's NCCL arm must use
   `sendrecv_perf_mpi` / `broadcast_perf_mpi` / `all_reduce_perf_mpi`.

**Stage 1 conclusion: COMPLETE.** Tooling validated for both Stage 2 arms:
staged host OSU-CUDA (D D + `-d cuda`) through the container MPI/UCX stack,
and container-native nccl-tests `*_mpi` binaries through container NCCL
(IBext_v11 + GDRDMA). The launch path (container mpirun + bridge + container
orted) is verified at 1/2/3 nodes and 12 ranks. Stage 2 awaits user go.

Attempt chain (all Track 1, evidence preserved): 1x2 v1 (job `67817.gaas` —
`/home` staging invisible in containers) → v2/v3 (`67819`/`67820.gaas` —
remote-sync collision left a stale script for v2; v3 hit a path typo
`osu-microbenchmarks-cuda`) → v4 (`67821.gaas`) PASS with `/tmp` staging;
first full ladder v1 (`67822/67823/67827.gaas`) PASS but the NCCL test used
the plain (per-process) `all_reduce_perf` → final ladder v5/v2/v2/v2
(`67831/67836/67838/67840.gaas`) PASS with `all_reduce_perf_mpi`.

### Evidence index (Stage 1)

- Preflight: `outputs/phase2-preflight/phase2_preflight_v{1,2,3}*` (jobs
  `67791/67793/67795.gaas`; v3 scored).
- OSU smoke: `outputs/phase2-preflight/phase2_osu_smoke_*` (attempts listed
  above; final ladder = `1x2_v5`, `2x1_v2`, `3x1_v2`, `3x4_v2`), including
  per-rung ABI logs, rank maps, per-test logs, hostfiles, pre/post
  co-tenant snapshots and scheduler snapshots.
- Scripts: `debug-scripts/phase2-preflight/run_phase2_preflight.pbs`,
  `run_phase2_osu_smoke.pbs`, `stage_osu_tmp.sh`; staging home:
  `osu-cuda-host/` (README + gitignored tree).
- Jobs (all g14/g11/g15-class `gpu_as` nodes, group `hpc_ebslee`):
  preflight `67791/67793/67795.gaas`; smoke `67817/67819/67820/67821/
  67822/67823/67827/67831/67836/67838/67840.gaas`.
