# Build: nccl-tests (host) — Phase 1 Step 2 support

Self-contained home for building NVIDIA `nccl-tests`
(https://github.com/nvidia/nccl-tests) on GAAS for Phase 1 — Step 2
(host-only NCCL GPUDirect RDMA verification) of the internode comms debug.
Everything related to building, smoke-testing, and debugging the nccl-tests
build — scripts, the source tree, and build evidence — stays in this
directory. The experiments that use the built binaries live in
`../debug-scripts/phase1-step2/` with evidence in `../outputs/phase1-step2/`,
planned and recorded in `../README.md` and `../DEBUG_PROGRESS.md` like every
other step. No outer directory (`builds/`, repo root) is touched by this
build.

## Layout

- `scripts/` — build + smoke scripts (tracked)
- `nccl-tests/` — upstream source clone; builds in-tree into
  `nccl-tests/build/` (not tracked; ignored via the root `.gitignore`)
- `outputs/` — build + smoke PBS `.o`/`.e` evidence (tracked)

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
