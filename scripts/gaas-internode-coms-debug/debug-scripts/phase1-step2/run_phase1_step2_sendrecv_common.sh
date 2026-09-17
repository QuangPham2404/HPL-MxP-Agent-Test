#!/bin/bash
# Shared host-native NCCL sendrecv runner for Phase 1 Step 2.
#
# Purpose: execute the same NCCL sendrecv A/B/C test on a parameterized
# 2x1, 3x1, or 3x4 topology using the tested GAAS host MPI + pbsdsh launch.
# Expected working directory: debug-scripts/phase1-step2/ on GAAS.
# Inputs: ATTEMPT and REQ_HOSTS from qsub; topology and ranks/node from the
#         topology-specific PBS wrapper; nccl-tests binaries from
#         ../../build-nccl-tests/nccl-tests/build/.
# Outputs: PBS stdout/stderr and per-arm/per-node evidence under
#          ../../outputs/phase1-step2/.
# Assumptions: full four-GPU node chunks are pinned for clean-node controls;
#         one MPI rank uses one local GPU; no mpiprocs in PBS select.
set -uo pipefail

cd "$PBS_O_WORKDIR"
: "${ATTEMPT:?submit with -v ATTEMPT=<unique attempt label>}"
: "${REQ_HOSTS:?submit with -v REQ_HOSTS=<host1+host2[+host3]>}"
: "${EXPECTED_NNODES:?PBS wrapper must set EXPECTED_NNODES}"
: "${GPUS_PER_NODE:?PBS wrapper must set GPUS_PER_NODE}"

case "$GPUS_PER_NODE" in
  1|4) ;;
  *) echo "FATAL: GPUS_PER_NODE must be 1 or 4, got $GPUS_PER_NODE" >&2; exit 1 ;;
esac

OUTDIR="$(cd "$PBS_O_WORKDIR/../.." && pwd)/outputs/phase1-step2"
mkdir -p "$OUTDIR"

REPO_ROOT="$(cd "$PBS_O_WORKDIR/../../../.." && pwd)"
BRIDGE="$REPO_ROOT/multi-node-test/rsh_pbsdsh.sh"
SNAPSHOT="$PBS_O_WORKDIR/../phase1-step1/collb2_node_snapshot.sh"
BNT="$REPO_ROOT/scripts/gaas-internode-coms-debug/build-nccl-tests"
SRBIN="$BNT/nccl-tests/build/sendrecv_perf"
OSU_DIR="/usr/local/nvhpc/Linux_x86_64/26.3/comm_libs/13.1/hpcx/hpcx-2.25.1/ompi/tests/osu-micro-benchmarks-cuda"

module purge || true
module load nvhpc/26.3 || { echo "FATAL: cannot load nvhpc/26.3" >&2; exit 1; }

NVHPC_ROOT="/usr/local/nvhpc/Linux_x86_64/26.3"
export NCCL_HOME="$NVHPC_ROOT/comm_libs/nccl"
export LD_LIBRARY_PATH="$NCCL_HOME/lib:$(printenv LD_LIBRARY_PATH 2>/dev/null)"
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,BOOTSTRAP,ENV,NET,GRAPH
export SRBIN
export LABEL="$ATTEMPT"

# --- Preflight: fatal only for required launch/test inputs ---
for tool in mpirun timeout sort wc paste awk sed grep cat date printenv; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FATAL: required tool $tool not found" >&2; exit 1; }
done
[ -r "$PBS_NODEFILE" ] || { echo "FATAL: PBS_NODEFILE unreadable" >&2; exit 1; }
[ -x "$SRBIN" ] || { echo "FATAL: sendrecv_perf missing at $SRBIN (build v3 must pass first)" >&2; exit 1; }
[ -x "$BRIDGE" ] || { echo "FATAL: pbsdsh bridge missing or not executable at $BRIDGE" >&2; exit 1; }
[ -f "$SNAPSHOT" ] || { echo "FATAL: clean-node snapshot helper missing at $SNAPSHOT" >&2; exit 1; }
[ -f "$NCCL_HOME/lib/libnccl.so.2" ] || { echo "FATAL: libnccl.so.2 missing at $NCCL_HOME/lib" >&2; exit 1; }

NNODES="$(sort -u "$PBS_NODEFILE" | wc -l)"
NPROCS=$((NNODES * GPUS_PER_NODE))
REQUESTED="$(printf '%s\n' "$REQ_HOSTS" | tr ',+' '\n\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -u | paste -sd,)"
GRANTED="$(sort -u "$PBS_NODEFILE" | paste -sd,)"
REQUESTED_COUNT="$(printf '%s\n' "$REQ_HOSTS" | awk -F'[+,]' '{print NF}')"

[ "$NNODES" -eq "$EXPECTED_NNODES" ] || {
  echo "FATAL: expected $EXPECTED_NNODES nodes, scheduler granted $NNODES" >&2; exit 1;
}
[ "$REQUESTED_COUNT" -eq "$EXPECTED_NNODES" ] || {
  echo "FATAL: REQ_HOSTS must list exactly $EXPECTED_NNODES nodes: $REQ_HOSTS" >&2; exit 1;
}
[ "$REQUESTED" = "$GRANTED" ] || {
  echo "FATAL: granted nodes ($GRANTED) != requested ($REQUESTED)" >&2; exit 1;
}

# De-duplicated hostfile with explicit ranks/node; PBS select intentionally
# contains no mpiprocs so pbsdsh vnode indices remain correct.
HOSTFILE="$OUTDIR/$LABEL"_hostfile_"$PBS_JOBID"
awk -v slots="$GPUS_PER_NODE" '
  { gsub(/\r$/,""); sub(/^[ \t]+/,""); sub(/[ \t]+$/,""); if ($0=="") next }
  { if (!seen[$0]++) print $0 " slots=" slots }
' "$PBS_NODEFILE" > "$HOSTFILE"

echo "=== Phase 1 Step 2 (NCCL sendrecv) metadata ==="
echo "attempt=$LABEL"
echo "topology=$TOPOLOGY"
echo "pbs_job_id=$PBS_JOBID"
date --iso-8601=seconds
echo "expected_nodes=$EXPECTED_NNODES granted_nodes=$NNODES ranks_per_node=$GPUS_PER_NODE total_ranks=$NPROCS"
echo "nodes=$GRANTED"
echo "req_hosts=$REQ_HOSTS"
echo "scheduler_chunk=4 GPUs/node reserved for node isolation; $GPUS_PER_NODE rank(s)/node used"
echo "mpirun=$(command -v mpirun)"
echo "sendrecv_bin=$SRBIN"
echo "source_commit=$(git -C "$BNT/nccl-tests" rev-parse HEAD 2>/dev/null || echo unknown)"
echo "nccl_home=$NCCL_HOME"
echo "nccl_lib=$(readlink -f "$NCCL_HOME/lib/libnccl.so.2" 2>/dev/null || echo unresolved)"
echo "bridge=$BRIDGE"
echo "binding=none"
echo "controls=default NCCL; NCCL_NET_GDR_LEVEL=LOC; NCCL_IB_DISABLE=1"
echo "nccl_debug=$NCCL_DEBUG subsys=$NCCL_DEBUG_SUBSYS"
echo "sweep=8B..64MiB factor 2; one GPU/rank; warmup=5 iters=20"
echo "=== PBS_NODEFILE ==="
cat "$PBS_NODEFILE"
echo "=== hostfile ==="
cat "$HOSTFILE"

launch_mpi() {
  local limit="$1"
  shift
  timeout "$limit" mpirun -np "$NPROCS" --hostfile "$HOSTFILE"     --mca plm_rsh_agent "$BRIDGE"     --mca plm_rsh_no_tree_spawn 1     --mca plm_rsh_num_concurrent 1     --mca routed direct     --bind-to none "$@"
}

# Collect global/local rank and GPU assignment before the NCCL tests.
echo "=== Rank and GPU mapping ==="
launch_mpi 120 -x GPUS_PER_NODE bash -c '
  local_rank="$OMPI_COMM_WORLD_LOCAL_RANK"
  if [ "$local_rank" -ge "$GPUS_PER_NODE" ]; then
    echo "FATAL: local rank $local_rank exceeds GPUS_PER_NODE=$GPUS_PER_NODE on $(hostname)" >&2
    exit 1
  fi
  export CUDA_VISIBLE_DEVICES="$local_rank"
  echo "rank=$OMPI_COMM_WORLD_RANK/$OMPI_COMM_WORLD_SIZE host=$(hostname) local_rank=$local_rank/$OMPI_COMM_WORLD_LOCAL_SIZE cvd=$CUDA_VISIBLE_DEVICES cpus_allowed=$(grep Cpus_allowed_list /proc/self/status | cut -f2) mems_allowed=$(grep Mems_allowed_list /proc/self/status | cut -f2)"
'
MAP_RC=$?
echo "rank_mapping_rc=$MAP_RC"
[ "$MAP_RC" -eq 0 ] || { echo "FATAL: rank mapping/launch check failed" >&2; exit 1; }

# Capture GPU/NIC topology and driver modules once per node. These diagnostics
# are best-effort; NCCL and the rank mapping remain the functional gates.
echo "=== Per-node GPU/NIC evidence ==="
launch_mpi 120 -x OUTDIR -x LABEL bash -c '
  if [ "$OMPI_COMM_WORLD_LOCAL_RANK" = "0" ]; then
    {
      echo "host=$(hostname)"
      echo "--- nvidia-smi topo -m ---"
      nvidia-smi topo -m 2>&1 || true
      echo "--- nvidia-smi inventory ---"
      nvidia-smi -L 2>&1 || true
      echo "--- GDR modules ---"
      lsmod 2>&1 | grep -E "nvidia_peermem|peermem|gdrdrv" || echo "no peermem/gdrdrv module matched"
      echo "--- ibv_devices ---"
      ibv_devices 2>&1 || true
    } > "$OUTDIR/$LABEL"_fabric_"$(hostname)".log 2>&1
    echo "fabric_evidence_written host=$(hostname)"
  fi
  true
'
FABRIC_RC=$?
echo "fabric_evidence_launch_rc=$FABRIC_RC"
[ "$FABRIC_RC" -eq 0 ] || echo "WARN: per-node fabric evidence launch returned $FABRIC_RC"

# Run the MPI health test through the same hostfile/bridge path as NCCL.
HELLO_LOG="$OUTDIR/$LABEL"_mpi_hello.log
echo "=== MPI health: osu_hello via GAAS pbsdsh bridge ==="
launch_mpi 120 "$OSU_DIR/osu_hello" > "$HELLO_LOG"
HELLO_RC=$?
cat "$HELLO_LOG"
echo "phase0_osu_hello_rc=$HELLO_RC"
if [ "$HELLO_RC" -ne 0 ] || ! grep -Fq "This is a test with $NPROCS processes" "$HELLO_LOG"; then
  echo "FATAL: MPI health test failed or reported the wrong process count" >&2
  exit 1
fi

node_snapshot() {
  local tag="$1"
  local lockbase="$OUTDIR/.locks_"$LABEL"_"$PBS_JOBID"_"$tag
  echo "=== clean-node checkpoint: $tag (pbsdsh, once per node) ==="
  /opt/pbs/bin/pbsdsh -- /bin/bash "$SNAPSHOT" "$OUTDIR" "$LABEL" "$tag" "$lockbase"     || echo "WARN: clean-node checkpoint $tag failed; preserving test execution"
}

node_snapshot pre
FAILS=0
TOTAL=0

run_suite() {
  local mode="$1"
  local rc arm_log
  case "$mode" in
    gdroff)
      export NCCL_NET_GDR_LEVEL=LOC
      unset NCCL_IB_DISABLE
      ;;
    sockfloor)
      export NCCL_IB_DISABLE=1
      unset NCCL_NET_GDR_LEVEL
      ;;
    ctrl)
      unset NCCL_NET_GDR_LEVEL NCCL_IB_DISABLE
      ;;
    *)
      echo "FATAL: unknown mode $mode" >&2
      return 1
      ;;
  esac

  arm_log="$OUTDIR/$LABEL"_"$mode"_sendrecv.log
  echo ""
  echo "########## RUN: $mode (NCCL_NET_GDR_LEVEL=$(printenv NCCL_NET_GDR_LEVEL 2>/dev/null || echo unset) NCCL_IB_DISABLE=$(printenv NCCL_IB_DISABLE 2>/dev/null || echo unset)) ##########"
  date --iso-8601=seconds
  if [ "$mode" = "gdroff" ]; then
    launch_mpi 600 -x LD_LIBRARY_PATH -x NCCL_HOME -x NCCL_DEBUG -x NCCL_DEBUG_SUBSYS -x SRBIN -x NCCL_NET_GDR_LEVEL       bash -c 'export CUDA_VISIBLE_DEVICES="$OMPI_COMM_WORLD_LOCAL_RANK"; exec "$SRBIN" -b 8 -e 67108864 -f 2 -g 1 -w 5 -n 20' > "$arm_log"
  elif [ "$mode" = "sockfloor" ]; then
    launch_mpi 600 -x LD_LIBRARY_PATH -x NCCL_HOME -x NCCL_DEBUG -x NCCL_DEBUG_SUBSYS -x SRBIN -x NCCL_IB_DISABLE       bash -c 'export CUDA_VISIBLE_DEVICES="$OMPI_COMM_WORLD_LOCAL_RANK"; exec "$SRBIN" -b 8 -e 67108864 -f 2 -g 1 -w 5 -n 20' > "$arm_log"
  else
    launch_mpi 600 -x LD_LIBRARY_PATH -x NCCL_HOME -x NCCL_DEBUG -x NCCL_DEBUG_SUBSYS -x SRBIN       bash -c 'export CUDA_VISIBLE_DEVICES="$OMPI_COMM_WORLD_LOCAL_RANK"; exec "$SRBIN" -b 8 -e 67108864 -f 2 -g 1 -w 5 -n 20' > "$arm_log"
  fi
  rc=$?
  cat "$arm_log"

  if [ "$rc" -eq 0 ] && ! grep -Fq "Out of bounds values : 0 OK" "$arm_log"; then
    echo "WARN: $mode completed with rc=0 but the expected zero-error marker is absent"
    rc=1
  fi
  echo "arm_"$mode"_sendrecv_rc=$rc (124=timeout)"
  TOTAL=$((TOTAL+1))
  [ "$rc" -ne 0 ] && FAILS=$((FAILS+1))
  return 0
}

node_snapshot prectrl
run_suite ctrl
node_snapshot mid1
run_suite gdroff
node_snapshot mid2
run_suite sockfloor
node_snapshot post

echo ""
echo "=== Phase 1 Step 2 ($TOPOLOGY) summary ==="
echo "total_arms=$TOTAL"
echo "failed_arms=$FAILS"
if [ "$TOTAL" -eq 3 ] && [ "$FAILS" -eq 0 ]; then
  echo "STEP2_SENDRECV_RESULT=PASS"
  exit 0
else
  echo "STEP2_SENDRECV_RESULT=FAIL"
  exit 1
fi
