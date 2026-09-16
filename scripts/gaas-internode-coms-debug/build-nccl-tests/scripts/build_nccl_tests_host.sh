#!/bin/bash
# Build nccl-tests (host) — Phase 1 Step 2 support.
#
# Purpose: compile NVIDIA nccl-tests against the site nvhpc/26.3 stack
# (CUDA 13.1, NCCL 2.29.3 from nvhpc comm_libs, HPC-X 2.25.1 OpenMPI mpicc)
# with sm_90 (H200) codegen. Part of build-nccl-tests/; see its README.md.
# Expected working directory: anywhere (paths resolve from this script's
# location); must run inside the build PBS job on a compute node —
# login-node builds are forbidden on GAAS.
# Inputs: source tree at ../nccl-tests (login-node clone of
#         https://github.com/nvidia/nccl-tests); nvhpc/26.3 module
#         environment (nvcc via the nested cuda/13.1 module, mpicc via
#         HPC-X OMPI).
# Outputs: perf binaries in ../nccl-tests/build/ (in-tree); build log to
#          stdout (captured in the PBS .o file).
# Assumptions: NCCL 2.29.3 is NOT in the module's LD_LIBRARY_PATH — all
#         NCCL paths are passed explicitly (NCCL_HOME) and the lib dir is
#         prepended to LD_LIBRARY_PATH for any link-time/run-time resolution.
set -euo pipefail

# --- Build configuration and paths ---
BNT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$BNT_ROOT/nccl-tests"
NVHPC_ROOT="/usr/local/nvhpc/Linux_x86_64/26.3"
NCCL_HOME="$NVHPC_ROOT/comm_libs/nccl"
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-13.1}"
GENCODE="-gencode=arch=compute_90,code=sm_90"
JOBS=8
export LD_LIBRARY_PATH="$NCCL_HOME/lib:${LD_LIBRARY_PATH:-}"

# --- Environment and tool checks (fatal: the build directly depends on them) ---
for tool in nvcc mpicc make git; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FATAL: $tool not found in PATH" >&2; exit 1; }
done
[ -f "$NCCL_HOME/lib/libnccl.so.2" ] || { echo "FATAL: libnccl.so.2 missing at $NCCL_HOME/lib" >&2; exit 1; }
[ -f "$NCCL_HOME/include/nccl.h" ] || { echo "FATAL: nccl.h missing at $NCCL_HOME/include" >&2; exit 1; }

# --- Source and build-directory checks ---
[ -f "$SRC_DIR/Makefile" ] || { echo "FATAL: nccl-tests source missing at $SRC_DIR (clone on the GAAS login node)" >&2; exit 1; }

# --- Build configuration evidence ---
echo "=== Build environment ==="
echo "host=$(hostname)"
echo "src_dir=$SRC_DIR"
echo "cuda_home=$CUDA_HOME ($("$CUDA_HOME/bin/nvcc" --version | tail -1))"
echo "nccl_home=$NCCL_HOME ($(grep -E '^#define NCCL_(MAJOR|MINOR|PATCH) ' "$NCCL_HOME/include/nccl.h" | tr '\n' ' '))"
echo "mpicc=$(command -v mpicc)"
echo "gencode=$GENCODE jobs=$JOBS"
echo "=== Source provenance ==="
git -C "$SRC_DIR" rev-parse HEAD
git -C "$SRC_DIR" log -1 --format='%h %ad %s' --date=short

# --- Build command ---
echo "=== make ==="
make -C "$SRC_DIR" -j "$JOBS" \
  CUDA_HOME="$CUDA_HOME" \
  NCCL_HOME="$NCCL_HOME" \
  MPI=1 \
  NVCC_GENCODE="$GENCODE"

# --- Expected executable check ---
echo "=== Built binaries ==="
ls -la "$SRC_DIR/build/"
EXPECTED="all_reduce_perf all_gather_perf alltoall_perf broadcast_perf reduce_perf reduce_scatter_perf sendrecv_perf scatter_perf gather_perf"
FAIL=0
for b in $EXPECTED; do
  if [ -x "$SRC_DIR/build/$b" ]; then echo "OK: $b"; else echo "MISSING: $b"; FAIL=1; fi
done
[ "$FAIL" -eq 0 ] || { echo "FATAL: expected binaries missing" >&2; exit 1; }
echo "BUILD_OK"
