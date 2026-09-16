#!/bin/bash
# Smoke test for the host nccl-tests build — Phase 1 Step 2 support.
#
# Purpose: prove a built binary runs against the site stack (CUDA 13.1 +
# nvhpc-bundled NCCL 2.29.3) on one GPU, and capture the NCCL version line
# as build evidence. This is a build validation smoke, not a measurement —
# inter-node transport evidence (NET/IB vs Socket, HCA, GDR) comes from the
# Step 2 sendrecv experiment in ../debug-scripts/phase1-step2/.
# Expected working directory: anywhere (paths resolve from this script's
# location); runs in the same PBS job immediately after a successful
# build_nccl_tests_host.sh.
# Inputs: ../nccl-tests/build/all_reduce_perf; exactly 1 visible GPU on the
#         job's compute node.
# Outputs: smoke output to stdout (captured in the PBS .o file).
# Assumptions: nvhpc/26.3 module environment loaded; NCCL 2.29.3 lib is
#         reachable only via the explicit LD_LIBRARY_PATH below (the module
#         does not add it).
set -euo pipefail

# --- Smoke configuration and paths ---
BNT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$BNT_ROOT/nccl-tests/build"
NVHPC_ROOT="/usr/local/nvhpc/Linux_x86_64/26.3"
NCCL_HOME="$NVHPC_ROOT/comm_libs/nccl"
export LD_LIBRARY_PATH="$NCCL_HOME/lib:${LD_LIBRARY_PATH:-}"
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,ENV

# --- Preflight ---
[ -x "$BUILD_DIR/all_reduce_perf" ] || { echo "FATAL: all_reduce_perf missing at $BUILD_DIR" >&2; exit 1; }

echo "=== Smoke environment ==="
echo "host=$(hostname)"
echo "gpus=[$(nvidia-smi -L 2>/dev/null | tr '\n' ';')]"
echo "binary=$BUILD_DIR/all_reduce_perf"
echo "--- libnccl resolution (ldd) ---"
ldd "$BUILD_DIR/all_reduce_perf" | grep -E "nccl|cudart|mpi" || true

# --- Smoke run: single process, single GPU, tiny sizes ---
echo "=== Smoke run: all_reduce_perf (1 process, 1 GPU, 8 B..1 MiB) ==="
"$BUILD_DIR/all_reduce_perf" -b 8 -e 1048576 -f 16 -w 2 -n 4 -g 1 2>&1

echo "SMOKE_OK"
