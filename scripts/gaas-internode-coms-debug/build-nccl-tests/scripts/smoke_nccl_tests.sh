#!/bin/bash
# Smoke test for the host nccl-tests build — Phase 1 Step 2 support.
#
# Purpose: prove a built binary runs against the site stack (CUDA 13.1 +
# nvhpc-bundled NCCL 2.29.3) on one GPU, and capture enough NCCL debug
# evidence to localize any startup hang. This is a build validation smoke,
# not a measurement — inter-node transport evidence (NET/IB vs Socket, HCA,
# GDR) comes from the Step 2 sendrecv experiment in
# ../debug-scripts/phase1-step2/.
#
# v1 lesson (job 66850.gaas, see README.md attempt log): the build
# succeeded but the smoke hung with zero output for ~29 min until the PBS
# walltime kill — buffered stdout hid everything, so the hang point was
# invisible. v2 fixes the capture and adds hang discrimination:
#   - NCCL debug -> stderr via NCCL_DEBUG_FILE=/dev/stderr (line-buffered,
#     survives a kill) with NCCL_DEBUG_SUBSYS=ALL;
#   - every phase wrapped in `timeout` so the job never burns walltime;
#   - phase 0 runs a standalone singleton osu_hello (HPC-X singleton
#     MPI_Init health check, no NCCL/CUDA involved);
#   - arms default / NCCL_IB_DISABLE=1 / NCCL_NET=Socket separate the IB
#     verbs path from the rest.
# A completed arm proves the binary+stack run; a hung arm's stderr evidence
# localizes the layer.
#
# Expected working directory: anywhere (paths resolve from this script's
# location); runs in the same PBS job after a successful
# build_nccl_tests_host.sh.
# Inputs: ../nccl-tests/build/all_reduce_perf; exactly 1 visible GPU.
# Outputs: app output to stdout, NCCL debug to stderr (captured in the PBS
#          .o/.e files).
# Assumptions: nvhpc/26.3 module environment loaded; NCCL 2.29.3 lib is
#         reachable only via the explicit LD_LIBRARY_PATH below (the module
#         does not add it).
set -uo pipefail

# --- Smoke configuration and paths ---
BNT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$BNT_ROOT/nccl-tests/build"
NVHPC_ROOT="/usr/local/nvhpc/Linux_x86_64/26.3"
HPCX="$NVHPC_ROOT/comm_libs/13.1/hpcx/hpcx-2.25.1"
OSU_DIR="$HPCX/ompi/tests/osu-micro-benchmarks-cuda"
NCCL_HOME="$NVHPC_ROOT/comm_libs/nccl"
export LD_LIBRARY_PATH="$NCCL_HOME/lib:${LD_LIBRARY_PATH:-}"
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=ALL
export NCCL_DEBUG_FILE=/dev/stderr

# --- Preflight ---
[ -x "$BUILD_DIR/all_reduce_perf" ] || { echo "FATAL: all_reduce_perf missing at $BUILD_DIR" >&2; exit 1; }

HANGS=0

run_arm() {
  # run_arm <label> [VAR=value ...] — one timeout-bounded smoke arm.
  local label="$1"; shift
  local rc
  echo ""
  echo "=== Smoke arm: $label (extra env: $*) ==="
  date --iso-8601=seconds
  timeout 240 stdbuf -oL env "$@" \
    "$BUILD_DIR/all_reduce_perf" -b 8 -e 1048576 -f 16 -w 1 -n 2 -g 1
  rc=$?
  echo "arm_${label}_rc=$rc (124=timeout/hang)"
  [ "$rc" -ne 0 ] && HANGS=$((HANGS+1))
  return 0
}

echo "=== Smoke environment ==="
echo "host=$(hostname)"
echo "gpus=[$(nvidia-smi -L 2>/dev/null | tr '\n' ';')]"
echo "binary=$BUILD_DIR/all_reduce_perf"
echo "nccl_debug=INFO subsys=ALL file=/dev/stderr"
echo "--- libnccl resolution (ldd) ---"
ldd "$BUILD_DIR/all_reduce_perf" | grep -E "nccl|cudart|mpi" || true

echo "=== Phase 0: singleton MPI health (standalone osu_hello, no NCCL/CUDA) ==="
if [ -x "$OSU_DIR/osu_hello" ]; then
  timeout 60 "$OSU_DIR/osu_hello"
  rc=$?
  echo "phase0_osu_hello_rc=$rc (124=timeout/hang)"
  [ "$rc" -ne 0 ] && HANGS=$((HANGS+1))
else
  echo "phase0: osu_hello not found at $OSU_DIR/osu_hello (skip)"
fi

run_arm default
run_arm ib_disable NCCL_IB_DISABLE=1
run_arm net_socket NCCL_NET=Socket

echo ""
echo "=== Smoke summary ==="
echo "hangs_or_failures=$HANGS"
if [ "$HANGS" -eq 0 ]; then
  echo "SMOKE_OK"
  exit 0
else
  echo "SMOKE_HAD_HANGS_OR_FAILURES (see arm rc lines and stderr NCCL trace above)"
  exit 1
fi
