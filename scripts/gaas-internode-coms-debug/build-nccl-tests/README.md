# Build: nccl-tests (host) — Phase 1 Step 2 support

Self-contained home for building NVIDIA `nccl-tests`
(https://github.com/nvidia/nccl-tests) on GAAS for Phase 1 — Step 2
(host-only NCCL GPUDirect RDMA verification) of the internode comms debug.
Everything related to building and smoke-testing the nccl-tests toolchain —
build/smoke scripts, the source tree, smoke runs, and all of their evidence —
stays in this directory. This includes the 3x4 functional smoke below: smoke
runs are build-toolchain artifacts and must not contaminate the outer
experiment/evidence trees. The transport-control experiment matrix that uses
the built binaries lives in `../debug-scripts/phase1-step2/` with evidence in
`../outputs/phase1-step2/`, planned and recorded in `../README.md` and
`../DEBUG_PROGRESS.md` like every other step. No outer directory (`builds/`,
repo root) is touched by this build.

## Layout

- `scripts/` — build + smoke scripts, including the 3x4 functional smoke
  `run_nccl_tests_smoke_3x4.pbs` (tracked)
- `nccl-tests/` — upstream source clone; builds in-tree into
  `nccl-tests/build/` (not tracked; ignored via the root `.gitignore`)
- `outputs/` — build + smoke PBS `.o`/`.e` evidence, including the 3x4 smoke
  outputs (tracked)

## Toolchain (verified 2026-09-17, GAAS read-only probe)

- Cluster: GAAS (PBS), queue `gpu_as`, submission group `hpc_ebslee`
- Module: `nvhpc/26.3` (also loads `gnu/gcc-12.3` + `cuda/13.1`)
- CUDA: 13.1 (13.1.115); `CUDA_HOME=/usr/local/cuda-13.1` (module-set; the
  nvhpc tree also carries a copy at
  `/usr/local/nvhpc/Linux_x86_64/26.3/cuda`)
- NCCL: 2.29.3 (nvhpc-bundled) at
  `/usr/local/nvhpc/Linux_x86_64/26.3/comm_libs/nccl`
  (`lib/libnccl.so.2` → `libnccl.so.2.29.3`; headers `include/nccl.h`,
  `NCCL_MAJOR 2 / NCCL_MINOR 29 / NCCL_PATCH 3`). NOTE: the nvhpc module
  does NOT add this to `LD_LIBRARY_PATH`; every build/smoke/run script must
  add `$NCCL_HOME/lib` explicitly.
- MPI: HPC-X 2.25.1 OpenMPI v4.1.9a1 (`mpicc` in PATH after
  `module load nvhpc/26.3`)
- Target arch: sm_90 (NVIDIA H200)
- NCCL GDR prerequisite: `nvidia_peermem` kernel module loaded host-wide
  (driver 580.126.20; see `scripts/comm_transport_probe_report.md`,
  2026-09-03). The 2-node experiment re-verifies this in-job via `lsmod`.

## NCCL 2.29.3 control knobs (verified from the shipped library)

- `NCCL_NET_GDR_LEVEL=LOC` — never use GPUDirect RDMA. This is the Step 2
  GDR-off A/B knob (values LOC/PIX/PXB/PHB/SYS; LOC = always disabled, per
  NCCL documentation of the parameter that exists since 2.3.4).
- `NCCL_IB_DISABLE=1` — force the socket NET fallback (transport-floor
  control arm).
- `NCCL_IB_GDR` does NOT exist in 2.29.3 (verified via `strings` on
  `libnccl.so.2.29.3`: the `NCCL_IB_*` parameter list has no GDR entry;
  `NCCL_NET_GDR_LEVEL` is the present knob). `NCCL_IB_DATA_DIRECT` is the
  separate mlx5 "Data Direct DMA Interface" feature, not the classic
  GPUDirect RDMA enable/disable switch.
- `NCCL_DEBUG=INFO` + `NCCL_DEBUG_SUBSYS=INIT,BOOTSTRAP,ENV,NET,GRAPH`
  prints the NCCL version, NET/IB HCA selection, per-channel transport
  graph, and ENV lines proving each `NCCL_*` knob reached the rank
  (`... set by environment to ...`).

## Build command

```bash
make -C nccl-tests -j 8 \
  CUDA_HOME=/usr/local/cuda-13.1 \
  NCCL_HOME=/usr/local/nvhpc/Linux_x86_64/26.3/comm_libs/nccl \
  MPI=1 \
  NVCC_GENCODE="-gencode=arch=compute_90,code=sm_90"
```

Builds run inside a PBS job (login-node builds are forbidden on GAAS).
`scripts/build_nccl_tests_host.pbs` runs the build and then the in-job
smoke (single-GPU tiny `all_reduce_perf` with `NCCL_DEBUG=INFO`) in one
submission, so the smoke is a separate script but executes in the same job.

## Submission

From this directory on GAAS (after `git pull --ff-only` and the login-node
clone of nvidia/nccl-tests into `nccl-tests/`):

```bash
mkdir -p outputs
qsub -o outputs/build_nccl_tests_host_v1.o \
     -e outputs/build_nccl_tests_host_v1.e \
     scripts/build_nccl_tests_host.pbs
```

Retries use a new attempt suffix (`_v2`, …) with new `.o`/`.e` filenames;
never overwrite earlier evidence.

## 3x4 functional smoke (`scripts/run_nccl_tests_smoke_3x4.pbs`)

One functional smoke of the host-native build on the 3-node × 4-GPU topology
(12 MPI/NCCL ranks), separate from the single-node build smoke above and from
the Phase 1 Step 2 transport-control matrix in `../debug-scripts/phase1-step2/`.
It answers: (1) does one NCCL collective complete correctly on this topology,
and (2) which NCCL network backend does the default configuration select for
the collective data path — the IB plugin or Socket? No A/B arms, no forced
Socket/GDR settings, no message-size sweep, no performance comparison;
socket/bootstrap messages alone are not evidence of a Socket data path.

- Binary: `nccl-tests/build/all_reduce_perf`; stack `nvhpc/26.3` (host HPC-X
  OpenMPI, CUDA 13.1, NCCL 2.29.3); one rank per GPU via
  `CUDA_VISIBLE_DEVICES=$OMPI_COMM_WORLD_LOCAL_RANK`; host `mpirun` +
  `multi-node-test/rsh_pbsdsh.sh` bridge (Phase 1 Step 1 recipe).
- Test: one `all_reduce_perf` invocation at a fixed 1 MiB payload, one
  warmup, two iterations — functional correctness only.
- NCCL settings: `NCCL_DEBUG=INFO` +
  `NCCL_DEBUG_SUBSYS=INIT,BOOTSTRAP,ENV,NET,GRAPH`; `NCCL_IB_DISABLE`,
  `NCCL_NET`, `NCCL_NET_GDR_LEVEL`, `NCCL_IB_HCA`, and `NCCL_SOCKET_IFNAME`
  are unset so default network selection is observed.

Submission (from this directory). Before each submission inspect
`pbsnodes -aSj` and choose the cleanest three eligible distinct nodes from
`gpu_as` or `gpu_ded` (`gpu_free` is currently disabled), in the queue
matching those nodes. Reserve four GPUs, 48 CPUs, and 1000 GB per node
(established clean-node shape); do not specify `mpiprocs` — the script
derives 12 ranks from the topology. Group `hpc_ebslee`:

```bash
pbsnodes -aSj
mkdir -p outputs
qsub -q <gpu_as-or-gpu_ded> \
  -l "select=host=<node1>:ngpus=4:ncpus=48:mem=1000GB+host=<node2>:ngpus=4:ncpus=48:mem=1000GB+host=<node3>:ngpus=4:ncpus=48:mem=1000GB" \
  -v "ATTEMPT=nccl_tests_3x4_smoke_v1,REQ_HOSTS=<node1>+<node2>+<node3>" \
  scripts/run_nccl_tests_smoke_3x4.pbs
```

Submit one job only. For any retry, choose a new `ATTEMPT` and new PBS `.o`
/ `.e` names with `qsub -o` and `-e`; preserve all earlier output.

Pass criteria: PBS exit status 0, exactly the three requested/granted nodes,
four local ranks per node, and `all_reduce_perf` reporting `Out of bounds
values : 0 OK`. Classify the selected data backend from NCCL `NET` lines in
the combined log under `outputs/`: `NET/IBext_v11` (or another `NET/IB`
backend) with HCA details means IB; `NET/Socket` with its interface means
Socket; bootstrap/socket lines alone are control traffic and do not classify
the collective. A Socket result is a valid observation, not a script failure;
if the log does not clearly identify the data backend, report transport as
inconclusive even if the collective passes.

### Smoke attempt log

- `nccl_tests_3x4_smoke_v1` — PBS job `67415.gaas`, submitted 2026-09-17
  16:19 +08 on the cleanest feasible allowed-queue trio (pinned gpu_ded:
  g22 pristine 8/8; g01 7/8 with 4 single-GPU co-tenants arriving minutes
  before; g20 6/8 after a 6h job ended; the pristine g16-g18 nodes are
  `gpu_aisg`, which is outside the allowed gpu_as/gpu_ded scope). **FAILED in
  2 s** (exit 1, empty `.o`): `FATAL: required tool 'mpirun' was not found` —
  deterministic Track 1 defect: the tool preflight ran before
  `module load nvhpc/26.3`, which is what supplies `mpirun` on compute nodes.
  Evidence: `outputs/nccl_tests_3x4_smoke_v1.{o,e}` (preserved) and
  `outputs/nccl_tests_3x4_smoke_v1_{presched_t0,startrun_snapshot}.txt`
  (pre-submission/run-start scheduler snapshots). No co-tenant entered the
  nodes during the 2 s run. Patch (v2): the module load + `NCCL_HOME`/
  `LD_LIBRARY_PATH` exports moved before the tool preflight; retry submitted
  as `nccl_tests_3x4_smoke_v2` with new `.o`/`.e` names.
- `nccl_tests_3x4_smoke_v2` — PBS job `67417.gaas`, same pinned trio
  (g01+g22+g20, same co-tenants; no new co-tenant entered during the 13 s
  run). **FAILED at 13 s** (exit 5 from all_reduce_perf): all 12 ranks
  launched and mapped correctly (3 nodes × 4 local ranks, per-rank
  `CUDA_VISIBLE_DEVICES=local_rank`), but every rank with local_rank ≥ 1
  aborted with `Invalid number of GPUs: {2,3,4} requested but only 1 were
  found` + `Test failure common.cu:1545`. Root cause (read from the b4d5bee
  source, `src/util.cu:770-782` / `src/common.cu:1658-1661`): nccl-tests
  defaults to `cudaDev = localRank` when `NCCL_TESTS_DEVICE` is unset,
  assuming each process sees all node GPUs; with one GPU visible per rank the
  local-rank index is out of range. The 2x1/3x1 sendrecv runs never hit this
  because they only ever had local_rank 0. Patch (v3): export
  `NCCL_TESTS_DEVICE=0` per rank (the tool's own override) so each rank uses
  its CVD-mapped device 0; per-rank GPU mapping and all other settings
  unchanged. Evidence: `outputs/nccl_tests_3x4_smoke_v2.{o,e}` (preserved).
- `nccl_tests_3x4_smoke_v3` — PBS job `67419.gaas`, submitted 2026-09-17
  16:27 +08 on the same pinned gpu_ded trio (g01 4/8 with the same 4
  single-GPU co-tenants, g20 6/8 with 2 co-tenants, g22 pristine 8/8;
  re-probed after the user's own 25-min `E03P15C` job released the nodes).
  **PASS** — PBS exit 0 in 19 s; all 12 ranks placed 4-per-node with distinct
  physical H200s (per-rank `CUDA_VISIBLE_DEVICES` + `NCCL_TESTS_DEVICE=0`,
  distinct PCI bus IDs in the device report); `Out of bounds values : 0 OK`.
  **Transport readout: the default NCCL configuration selects the
  InfiniBand plugin (`NET/IBext_v11`) for the collective data path with
  GPUDirect RDMA enabled** — all 8 node HCAs (`mlx5_0`…`mlx5_9`) populated
  with `keep=1 coll=1`, "GPU Direct RDMA Enabled" per HCA, and inter-node
  channels `via NET/IBext_v11/N/GDRDMA`; `bond0.321` served bootstrap/control
  traffic only (not a Socket data path); NCCL 2.29.3+cuda13.1. No new
  co-tenant entered any node during the 19 s run. This is a functional smoke
  only — no performance comparison. Evidence (byte-verified against GAAS):
  `outputs/nccl_tests_3x4_smoke_v3.{o,e}`, 
  `outputs/nccl_tests_3x4_smoke_v3_67419.gaas_{hostfile,nccl.log}`.

## Source provenance

Cloned on the GAAS login node from `https://github.com/nvidia/nccl-tests`
(login-node clone only; the compile itself runs in the PBS build job). The
exact commit is echoed by the build script (`git -C nccl-tests rev-parse
HEAD`) into the PBS output and recorded per attempt below.

## Attempt log

- `build_nccl_tests_host_v1` — PBS job `66850.gaas` (hpc-gaas-g10, 1× H200,
  started 2026-09-17 00:16). **BUILD_OK**: all 9 perf binaries produced
  (source commit `b4d5bee`, 2026-08-27); `ldd` resolves `libnccl.so.2` →
  nvhpc 2.29.3, `libcudart.so.13`, `libmpi.so.40` (HPC-X). **Smoke HUNG**:
  single-GPU `all_reduce_perf` produced no output for ~29 min until the PBS
  walltime kill (`job killed: walltime 1888 exceeded limit 1800`). Evidence:
  `outputs/build_nccl_tests_host_v1.{o,e}` (local copies byte-verified).
  Suspected cause: unknown — buffered stdout hid all NCCL/app progress, so
  the hang point (singleton `MPI_Init` vs CUDA init vs NCCL init/net) is
  not localizable from v1 evidence. Track 1 instrumentation patch (the
  build itself is healthy; the smoke's evidence capture was the defect):
  v2 adds `NCCL_DEBUG_FILE=/dev/stderr` (line-buffered, kill-surviving)
  with `NCCL_DEBUG_SUBSYS=ALL`, `timeout`-bounded phases, a standalone
  singleton `osu_hello` MPI health phase, and default / `NCCL_IB_DISABLE=1`
  / `NCCL_NET=Socket` arms to localize the hang. Rerun as
  `build_nccl_tests_host_v2`.
- `build_nccl_tests_host_v2` — PBS job `66895.gaas` (hpc-gaas-g10,
  2026-09-17 01:04, 13:41 walltime, exit marker `BUILD_OR_SMOKE_FAILED`).
  **Build OK** (incremental no-op; binaries intact, source commit `b4d5bee`).
  **Smoke: hang localized to the standalone/singleton MPI launch path — NOT
  NCCL, NOT CUDA, NOT the build:**
  - Phase 0 `osu_hello` (pure MPI, no NCCL/CUDA), executed directly without
    `mpirun`, hung (`rc=124`, no hello output).
  - All three `all_reduce_perf` arms (default / `NCCL_IB_DISABLE=1` /
    `NCCL_NET=Socket`), executed directly without `mpirun`, hung (`rc=124`)
    with **zero NCCL debug lines in stderr** (`NCCL_DEBUG_FILE=/dev/stderr`,
    `NCCL_DEBUG_SUBSYS=ALL` active) — NCCL never started; the hang precedes
    `ncclCommInit`, i.e. in `mpi_init` (nccl-tests' first call when built
    with `MPI=1`).
  - Both v1 and v2 ran on g10; direct ssh from the login node to compute
    nodes is blocked on GAAS (verified: nested ssh returns rc=255), which
    is consistent with the OpenMPI singleton `MPI_Init` path failing to
    bootstrap a daemon on the compute node. Every successful host MPI job
    in this debug ran through `mpirun` (+ pbsdsh bridge for multi-node).
  Evidence: `outputs/build_nccl_tests_host_v2.{o,e}`. Track 1 fix (smoke
  launch-pattern defect): v3 launches every phase through `mpirun -np 1`
  (local fork; no singleton bootstrap path), keeping the timeout bounds,
  stderr NCCL capture, and the three transport arms. Rerun as
  `build_nccl_tests_host_v3`.

- `build_nccl_tests_host_v3` — PBS job `67034.gaas` (hpc-gaas-g06,
  2026-09-17 07:37 +08, one H200; PBS Exit_status=0).
  PBS recorded the effective allocation as one GPU, 12 CPUs, and 250 GB.
  **BUILD_AND_SMOKE_OK**: incremental build verified all nine perf binaries;
  source commit `b4d5bee`; `ldd` resolved HPC-X `libmpi.so.40`, CUDA 13,
  and NCCL 2.29.3. The MPI health phase launched `osu_hello` with
  `mpirun -np 1` and returned 0. Default, `NCCL_IB_DISABLE=1`, and
  `NCCL_NET=Socket` `all_reduce_perf` arms all returned 0, each reporting
  `Out of bounds values : 0 OK`; summary markers were `SMOKE_OK` and
  `BUILD_AND_SMOKE_OK`. Default-arm NCCL logs selected `IBext_v11` and
  reported GPUDirect RDMA enabled. This is a single-rank startup/build smoke:
  NCCL enumerated the IB/GDR stack but did not exchange data with another
  rank, so it is not evidence of inter-node NCCL communication.
  Raw PBS evidence remains on GAAS at
  `scripts/gaas-internode-coms-debug/build-nccl-tests/outputs/build_nccl_tests_host_v3.{o,e}`.
