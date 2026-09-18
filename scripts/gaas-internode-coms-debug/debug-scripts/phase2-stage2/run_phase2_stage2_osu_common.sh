#!/bin/bash
# Shared container MPI/UCX GDR A/B runner for Phase 2 Stage 2 (OSU arm).
#
# Purpose: run the staged host OSU-CUDA binaries through the container HPC-X
# MPI/UCX stack in a same-job GDR A/B — ctrl (container defaults) vs gdroff
# (UCX_IB_GPU_DIRECT_RDMA=n: IB without GPU-direct RDMA) — on a
# parameterized 2x1 or 3x4 topology via the validated container launch path
# (container mpirun + rsh_pbsdsh_container.sh bridge + container orted;
# Stage 1 smoke evidence). Per arm: osu_bw D D, osu_bw H H (negative
# control), osu_latency D D, osu_latency H H — every test at np=2 on the
# first two allocated nodes (inter-node pair; pt2pt hostfile slots=1), OSU
# default size sweeps.
#
# UCX tracing (UCX_LOG_LEVEL=info + UCX_PROTO_INFO=y) runs in BOTH arms and
# is -x forwarded so every rank provably sees it; the gdroff knob is echoed
# per rank at the top of each test log. Transport classification (zero-copy
# rc_mlx5 vs staging for D D; H H unchanged between arms) is analysis-time
# from the per-arm logs — the runner's RESULT marker covers execution and
# output shape only, mirroring the host-campaign caveat.
#
# Expected working directory: debug-scripts/phase2-stage2/ on GAAS.
# Inputs: ATTEMPT and REQ_HOSTS from qsub; TOPOLOGY, EXPECTED_NNODES,
#         RANKS_PER_NODE (and optional ARMS, RESULT_TAG) from the PBS
#         wrapper; staged OSU tree from ../../osu-cuda-host/ (auto-staged
#         from the host nvhpc source on first use) copied per job into
#         node-local /tmp/phase2_osu via ../phase2-preflight/stage_osu_tmp.sh.
# Outputs: PBS .o/.e (attempt-named) + per-arm/per-test logs, hostfiles, ABI
#          log, rank map, per-node fabric evidence, and pre/prectrl/mid/post
#          co-tenant checkpoints under ../../outputs/phase2-stage2/.
# Assumptions: full four-GPU node chunks (ngpus=4:ncpus=48:mem=1000GB)
#          pinned for node isolation on every rung; one rank per GPU for the
#          mapping check; no mpiprocs in PBS select; arms sequential in one
#          job on the same allocation (plan: keep each A/B pair on the same
#          allocated nodes).

set -uo pipefail

cd "${PBS_O_WORKDIR:?PBS_O_WORKDIR is not set}"
: "${PBS_JOBID:?}"
: "${PBS_NODEFILE:?}"
: "${ATTEMPT:?submit with -v ATTEMPT=<unique attempt label>}"
: "${REQ_HOSTS:?submit with -v REQ_HOSTS=<host1+host2[+host3]>}"
: "${EXPECTED_NNODES:?PBS wrapper must set EXPECTED_NNODES}"
: "${RANKS_PER_NODE:?PBS wrapper must set RANKS_PER_NODE}"
TOPOLOGY="${TOPOLOGY:-unknown}"
ARMS="${ARMS:-ctrl gdroff}"
RESULT_TAG="${RESULT_TAG:-PHASE2_STAGE2_OSU}"

case "$RANKS_PER_NODE" in
  1|4) ;;
  *) echo "FATAL: RANKS_PER_NODE must be 1 or 4, got $RANKS_PER_NODE" >&2; exit 1 ;;
esac
case "$EXPECTED_NNODES" in
  2|3) ;;
  *) echo "FATAL: EXPECTED_NNODES must be 2 or 3 for Stage 2, got $EXPECTED_NNODES" >&2; exit 1 ;;
esac
TOTAL_RANKS=$((EXPECTED_NNODES * RANKS_PER_NODE))

OUTDIR="$(cd "$PBS_O_WORKDIR/../.." && pwd)/outputs/phase2-stage2"
mkdir -p "$OUTDIR"
DEBUG_DIR="$(cd "$PBS_O_WORKDIR/../.." && pwd)"
OSU_HOME="$DEBUG_DIR/osu-cuda-host"
SHARED_STAGE="$OSU_HOME/osu-microbenchmarks-cuda"
TMP_STAGE_ROOT="/tmp/phase2_osu"
STAGE="$TMP_STAGE_ROOT/osu-micro-benchmarks-cuda"
STAGE_HELPER="$PBS_O_WORKDIR/../phase2-preflight/stage_osu_tmp.sh"
FABRIC_HELPER="$PBS_O_WORKDIR/fabric_capture.sh"
REPO_ROOT="$(cd "$PBS_O_WORKDIR/../../../.." && pwd)"
BRIDGE="$REPO_ROOT/multi-node-test/rsh_pbsdsh_container.sh"
SNAPSHOT="$PBS_O_WORKDIR/../phase1-step1/collb2_node_snapshot.sh"
SIF="/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif"
HOST_OSU_SRC="/usr/local/nvhpc/Linux_x86_64/26.3/comm_libs/13.1/hpcx/hpcx-2.25.1/ompi/tests/osu-micro-benchmarks-cuda"
export STAGE

module purge || true
module load apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0 \
  || { echo "FATAL: cannot load the validated module set" >&2; exit 1; }

for tool in apptainer timeout sort paste sed grep awk cat date chmod rsync sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "FATAL: required tool '$tool' not found" >&2; exit 1;
  }
done
[ -x /opt/pbs/bin/pbsdsh ] || { echo "FATAL: /opt/pbs/bin/pbsdsh not executable" >&2; exit 1; }
[ -r "$PBS_NODEFILE" ] || { echo "FATAL: PBS_NODEFILE unreadable" >&2; exit 1; }
[ -f "$BRIDGE" ] || { echo "FATAL: container bridge missing: $BRIDGE" >&2; exit 1; }
chmod +x "$BRIDGE"
[ -f "$SNAPSHOT" ] || { echo "FATAL: snapshot helper missing: $SNAPSHOT" >&2; exit 1; }
[ -f "$FABRIC_HELPER" ] || { echo "FATAL: fabric helper missing: $FABRIC_HELPER" >&2; exit 1; }
chmod +x "$FABRIC_HELPER"
[ -f "$SIF" ] || { echo "FATAL: SIF not found: $SIF" >&2; exit 1; }
if [ ! -x "$SHARED_STAGE/osu_bw" ] && [ ! -x "$HOST_OSU_SRC/osu_bw" ]; then
  echo "FATAL: neither the shared stage ($SHARED_STAGE) nor the host source ($HOST_OSU_SRC) is available" >&2
  exit 1
fi

normalize_list() {
  printf '%s\n' "$1" | tr ',+' '\n\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | grep -v '^$' | sort -u | paste -sd+
}

NNODES="$(awk '{gsub(/\r/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); if ($0 != "" && !seen[$0]++) n++} END {print n+0}' "$PBS_NODEFILE")"
REQ_HOST_COUNT="$(printf '%s\n' "$REQ_HOSTS" | awk -F'[+,]' '{print NF}')"
REQUESTED_HOSTS="$(normalize_list "$REQ_HOSTS")"
GRANTED_HOSTS="$(awk '{gsub(/\r/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); if ($0 != "") print $0}' "$PBS_NODEFILE" | sort -u | paste -sd+)"

echo "=== Phase 2 Stage 2 (OSU GDR A/B) metadata ==="
echo "attempt=$ATTEMPT"
echo "topology=$TOPOLOGY (nodes=$EXPECTED_NNODES ranks_per_node=$RANKS_PER_NODE total_ranks=$TOTAL_RANKS)"
echo "pbs_job_id=$PBS_JOBID"
date --iso-8601=seconds
echo "requested_hosts=$REQUESTED_HOSTS"
echo "granted_hosts=$GRANTED_HOSTS"
echo "arms=$ARMS (ctrl=container UCX defaults; gdroff=UCX_IB_GPU_DIRECT_RDMA=n)"
echo "tests=osu_bw_dd osu_bw_hh osu_latency_dd osu_latency_hh (np=2 inter-node pair, OSU default sweep)"
echo "ucx_tracing=UCX_LOG_LEVEL=info UCX_PROTO_INFO=y (both arms, -x forwarded to every rank)"
echo "result_tag=$RESULT_TAG"
echo "sif=$SIF size=$(stat -c %s "$SIF" 2>/dev/null || echo unknown)"
echo "bridge=$BRIDGE"
echo "binding=none"
echo "gpu_selection=one rank per GPU: CUDA_VISIBLE_DEVICES=local rank (mapping check at full rank count)"
echo "scheduler_chunk=4 GPUs/48 CPUs/1000GB per pinned node for node isolation"
echo "abi_policy=LD_LIBRARY_PATH prepend /opt/hpcx/ompi/lib:/opt/hpcx/ucx/lib scoped to the osu processes"

if [ "$NNODES" -ne "$EXPECTED_NNODES" ] || [ "$REQ_HOST_COUNT" -ne "$EXPECTED_NNODES" ] || [ "$REQUESTED_HOSTS" != "$GRANTED_HOSTS" ]; then
  echo "FATAL: expected exactly the requested hosts; nodes=$NNODES requested=[$REQUESTED_HOSTS] granted=[$GRANTED_HOSTS]" >&2
  exit 1
fi

node_snapshot() {
  local tag="$1"
  local lockbase="$OUTDIR/.locks_${ATTEMPT}_${PBS_JOBID}_${tag}"
  echo "=== clean-node checkpoint: $tag (pbsdsh, once per node) ==="
  /opt/pbs/bin/pbsdsh -- /bin/bash "$SNAPSHOT" "$OUTDIR" "$ATTEMPT" "$tag" "$lockbase" \
    || echo "WARN: clean-node checkpoint $tag failed; preserving test execution"
}

fabric_capture() {
  echo "=== per-node fabric evidence (host-side pbsdsh, once per node) ==="
  /opt/pbs/bin/pbsdsh -- /bin/bash "$FABRIC_HELPER" "$OUTDIR" "$ATTEMPT" "$PBS_JOBID" \
    || echo "WARN: fabric evidence capture failed; preserving test execution"
}

node_snapshot pre

echo
echo "============================================================"
echo "SECTION 0: OSU STAGING (shared copy + per-node /tmp copy)"
echo "============================================================"
if [ ! -x "$SHARED_STAGE/osu_bw" ]; then
  echo "shared staged tree absent — copying from $HOST_OSU_SRC"
  mkdir -p "$OSU_HOME"
  rsync -a "$HOST_OSU_SRC" "$OSU_HOME/" \
    || { echo "FATAL: rsync of host OSU-CUDA tree failed" >&2; exit 1; }
  echo "staging_done=yes"
else
  echo "shared staged tree already present — reusing"
fi
[ -x "$SHARED_STAGE/osu_bw" ] && [ -x "$SHARED_STAGE/osu_latency" ] || {
  echo "FATAL: shared OSU tree incomplete at $SHARED_STAGE" >&2; exit 1;
}
echo "--- staging provenance (shared source of truth) ---"
echo "source=$HOST_OSU_SRC"
echo "file_count=$(find "$SHARED_STAGE" -type f | wc -l)"
du -sh "$SHARED_STAGE"
echo "host_sha256_osu_bw=$(sha256sum "$SHARED_STAGE/osu_bw" | cut -d' ' -f1)"

echo "--- per-node /tmp staging ($TMP_STAGE_ROOT) via pbsdsh ---"
chmod +x "$STAGE_HELPER"
/opt/pbs/bin/pbsdsh -- /bin/bash "$STAGE_HELPER" "$SHARED_STAGE" "$TMP_STAGE_ROOT" "$PBS_JOBID" \
  || { echo "FATAL: pbsdsh /tmp staging launch failed" >&2; exit 1; }
if ! ls "$STAGE/osu_bw" >/dev/null 2>&1; then
  echo "FATAL: mother-node /tmp staging incomplete ($STAGE/osu_bw missing)" >&2
  exit 1
fi
echo "mother_node_tmp_sha256_osu_bw=$(sha256sum "$STAGE/osu_bw" | cut -d' ' -f1)"

echo
echo "============================================================"
echo "SECTION 1: IN-CONTAINER ABI VALIDATION (mother node)"
echo "============================================================"
ABI_LOG="$OUTDIR/${ATTEMPT}_osu_abi.log"
apptainer exec --nv "$SIF" bash -c '
  echo "--- staged osu_bw (container view) ---"
  ls -la "$STAGE/osu_bw" || { echo "STAGED_BINARY_NOT_VISIBLE"; exit 0; }
  echo "container_sha256_osu_bw=$(sha256sum "$STAGE/osu_bw" | cut -d" " -f1)"
  echo "--- ldd staged osu_bw (container default resolution) ---"
  ldd "$STAGE/osu_bw" 2>&1 | grep -iE "mpi|cuda|not found" || echo "(no mpi/cuda lines)"
  echo "--- ldd with container hpcx libdir prepended (run configuration) ---"
  LD_LIBRARY_PATH="/opt/hpcx/ompi/lib:/opt/hpcx/ucx/lib:$LD_LIBRARY_PATH" \
    ldd "$STAGE/osu_bw" 2>&1 | grep -iE "libmpi|libopen|cuda|not found" || echo "(no lib lines)"
' 2>&1 | tee "$ABI_LOG"
echo "abi_exec_rc=${PIPESTATUS[0]}"

STAGED_VISIBLE=0
grep -q "STAGED_BINARY_NOT_VISIBLE" "$ABI_LOG" || STAGED_VISIBLE=1
ABI_RUN_BLOCK="$(sed -n '/ldd with container hpcx libdir prepended/,$p' "$ABI_LOG")"
ABI_CLEAN=0
if printf "%s\n" "$ABI_RUN_BLOCK" | grep -q 'libmpi.so.40 => /opt/hpcx' \
   && ! printf "%s\n" "$ABI_RUN_BLOCK" | grep -qi "not found"; then
  ABI_CLEAN=1
fi
echo "staged_binary_visible_in_container=$STAGED_VISIBLE"
echo "abi_clean=$ABI_CLEAN (libmpi resolves to container /opt/hpcx; no missing libs)"
[ "$STAGED_VISIBLE" -eq 1 ] || { echo "FATAL: staged binary not visible in container (/tmp default-bind assumption failed)" >&2; exit 1; }
[ "$ABI_CLEAN" -eq 1 ] || { echo "FATAL: staged osu_bw does not resolve cleanly against the container stack" >&2; exit 1; }

echo
echo "============================================================"
echo "SECTION 2: HOSTFILES + PER-RANK MAPPING/VISIBILITY"
echo "============================================================"
HF_FULL="$PWD/${ATTEMPT}_hf_full_${PBS_JOBID}"
HF_PT2PT="$PWD/${ATTEMPT}_hf_pt2pt_${PBS_JOBID}"
awk -v slots="$RANKS_PER_NODE" '
  { gsub(/\r/,""); sub(/^[ \t]+/,""); sub(/[ \t]+$/,""); if ($0=="") next }
  { if (!seen[$0]++) print $0 " slots=" slots }
' "$PBS_NODEFILE" > "$HF_FULL"
PT2PT_SLOTS=1
[ "$EXPECTED_NNODES" -eq 1 ] && PT2PT_SLOTS="$RANKS_PER_NODE"
awk -v slots="$PT2PT_SLOTS" '
  { gsub(/\r/,""); sub(/^[ \t]+/,""); sub(/[ \t]+$/,""); if ($0=="") next }
  { if (!seen[$0]++) print $0 " slots=" slots }
' "$PBS_NODEFILE" > "$HF_PT2PT"
echo "--- hostfile full (slots=$RANKS_PER_NODE) ---"; cat "$HF_FULL"
echo "--- hostfile pt2pt (slots=$PT2PT_SLOTS) ---"; cat "$HF_PT2PT"
echo "pt2pt_pair=$(awk '{print $1}' "$HF_PT2PT" | head -2 | paste -sd+)"
cp "$HF_FULL" "$OUTDIR/${ATTEMPT}_hf_full_${PBS_JOBID}"
cp "$HF_PT2PT" "$OUTDIR/${ATTEMPT}_hf_pt2pt_${PBS_JOBID}"

# Container launch through the validated bridge path. Extra mpirun -x
# forwards are passed before the "--" separator so each arm can ship its
# own UCX environment to every rank.
launch() {
  local hf="$1" np="$2"; shift 2
  local xf=(-x PATH -x LD_LIBRARY_PATH -x STAGE)
  while [ "${1:-}" != "--" ]; do
    [ "$#" -gt 0 ] || { echo "FATAL: launch called without -- separator" >&2; return 2; }
    xf+=("$1"); shift
  done
  shift
  timeout 300 apptainer exec --nv \
    -B /opt/pbs:/opt/pbs \
    -B /var/spool/pbs:/var/spool/pbs \
    -B "$REPO_ROOT/multi-node-test":"$REPO_ROOT/multi-node-test" \
    -B "$PBS_O_WORKDIR":"$PBS_O_WORKDIR" \
    "$SIF" \
    /usr/local/mpi/bin/mpirun -np "$np" \
      --hostfile "$hf" \
      --mca plm_rsh_agent "$BRIDGE" \
      --mca plm_rsh_no_tree_spawn 1 \
      --mca plm_rsh_num_concurrent 1 \
      --mca routed direct \
      "${xf[@]}" \
      --bind-to none "$@"
}

MAP_LOG="$OUTDIR/${ATTEMPT}_rank_map.log"
launch "$HF_FULL" "$TOTAL_RANKS" -- bash -c '
  echo "rank=$OMPI_COMM_WORLD_RANK/$OMPI_COMM_WORLD_SIZE host=$(hostname) local_rank=$OMPI_COMM_WORLD_LOCAL_RANK/$OMPI_COMM_WORLD_LOCAL_SIZE container_cvd=$(printenv CUDA_VISIBLE_DEVICES || echo unset) cpus_allowed=$(grep Cpus_allowed_list /proc/self/status | cut -f2)"
  if [ -x "$STAGE/osu_bw" ]; then echo "staged_osu_visible=YES"; else echo "staged_osu_visible=NO"; fi
  echo "gpu=$(nvidia-smi -L 2>/dev/null | sed -n "1p")"
  echo "hcas_visible=$(ls /dev/infiniband 2>/dev/null | grep -c "^hca" || true)"
' 2>&1 | tee "$MAP_LOG"
MAP_RC="${PIPESTATUS[0]}"
echo "rank_map_rc=$MAP_RC"
RANK_LINES=$(grep -c "^rank=" "$MAP_LOG" || true)
VIS_NO=$(grep -c "staged_osu_visible=NO" "$MAP_LOG" || true)
echo "rank_lines=$RANK_LINES expected=$TOTAL_RANKS staged_not_visible_ranks=$VIS_NO"
if [ "$MAP_RC" -ne 0 ] || [ "$RANK_LINES" -ne "$TOTAL_RANKS" ] || [ "$VIS_NO" -ne 0 ]; then
  echo "FATAL: rank mapping/visibility check failed (rc=$MAP_RC lines=$RANK_LINES vis_no=$VIS_NO)" >&2
  exit 1
fi

fabric_capture

echo
echo "============================================================"
echo "SECTION 3: GDR A/B ARMS (ctrl vs gdroff, sequential)"
echo "============================================================"
# UCX tracing in both arms; -x forwarded so every rank provably sees it.
export UCX_LOG_LEVEL=info
export UCX_PROTO_INFO=y

FAILS=0
TOTAL=0
TEST_LIST="osu_bw_dd osu_bw_hh osu_latency_dd osu_latency_hh"

run_osu_arm() {
  local mode="$1" t bin args log rc rows
  case "$mode" in
    ctrl)   unset UCX_IB_GPU_DIRECT_RDMA || true ;;
    gdroff) export UCX_IB_GPU_DIRECT_RDMA=n ;;
    *) echo "FATAL: unknown mode $mode" >&2; return 1 ;;
  esac

  local xf=(-x UCX_LOG_LEVEL -x UCX_PROTO_INFO)
  [ "$mode" = "gdroff" ] && xf+=(-x UCX_IB_GPU_DIRECT_RDMA)

  for t in $TEST_LIST; do
    case "$t" in
      osu_bw_dd)      bin="osu_bw";      args="D D" ;;
      osu_bw_hh)      bin="osu_bw";      args="H H" ;;
      osu_latency_dd) bin="osu_latency"; args="D D" ;;
      osu_latency_hh) bin="osu_latency"; args="H H" ;;
      *) echo "FATAL: unknown test $t" >&2; return 1 ;;
    esac
    log="$OUTDIR/${ATTEMPT}_${mode}_${t}.log"
    TOTAL=$((TOTAL+1))
    echo ""
    echo "########## RUN: arm=$mode test=$t (UCX_IB_GPU_DIRECT_RDMA=$(printenv UCX_IB_GPU_DIRECT_RDMA 2>/dev/null || echo unset)) ##########"
    date --iso-8601=seconds
    launch "$HF_PT2PT" 2 "${xf[@]}" -- bash -c "
      export LD_LIBRARY_PATH=/opt/hpcx/ompi/lib:/opt/hpcx/ucx/lib:\$LD_LIBRARY_PATH
      export CUDA_VISIBLE_DEVICES=\$OMPI_COMM_WORLD_LOCAL_RANK
      echo \"ucx_env_check rank=\$OMPI_COMM_WORLD_RANK host=\$(hostname) ucx_gdr=\${UCX_IB_GPU_DIRECT_RDMA:-unset} proto_info=\${UCX_PROTO_INFO:-unset} log_level=\${UCX_LOG_LEVEL:-unset}\"
      exec \"\$STAGE/$bin\" $args
    " > "$log" 2>&1
    rc=$?
    cat "$log"
    rows=$(grep -cE "^[0-9]+[[:space:]]+[0-9]" "$log" || true)
    echo "arm_${mode}_${t}_rc=$rc (124=timeout) table_rows=$rows"
    echo "ucx_marker_summary arm=$mode test=$t rc_mlx5=$(grep -c "rc_mlx5" "$log" || true) cuda_copy=$(grep -c "cuda_copy" "$log" || true) gdr_copy=$(grep -c "gdr_copy" "$log" || true)"
    if [ "$rc" -ne 0 ] || [ "$rows" -lt 5 ]; then
      echo "arm_${mode}_${t}=FAIL"
      FAILS=$((FAILS+1))
    else
      echo "arm_${mode}_${t}=PASS"
    fi
  done
  return 0
}

node_snapshot prectrl
arm_idx=0
ARM_COUNT=$(echo $ARMS | wc -w)
for mode in $ARMS; do
  run_osu_arm "$mode" || true
  arm_idx=$((arm_idx+1))
  if [ "$arm_idx" -lt "$ARM_COUNT" ]; then
    node_snapshot "mid${arm_idx}"
  fi
done
node_snapshot post

rm -f "$HF_FULL" "$HF_PT2PT"

echo
echo "============================================================"
echo "SECTION 4: SUMMARY"
echo "============================================================"
echo "phase2_stage2_osu_end=$(date --iso-8601=seconds)"
echo "topology=$TOPOLOGY abi_clean=$ABI_CLEAN staged_visible=$STAGED_VISIBLE"
echo "--- cross-arm UCX marker counts (coarse; formal classification is analysis-time from the per-arm logs) ---"
for t in $TEST_LIST; do
  ctrl_log="$OUTDIR/${ATTEMPT}_ctrl_${t}.log"
  gdroff_log="$OUTDIR/${ATTEMPT}_gdroff_${t}.log"
  if [ -f "$ctrl_log" ] && [ -f "$gdroff_log" ]; then
    echo "ucx_ab_markers test=$t ctrl{rc_mlx5=$(grep -c "rc_mlx5" "$ctrl_log" || true),cuda_copy=$(grep -c "cuda_copy" "$ctrl_log" || true),gdr_copy=$(grep -c "gdr_copy" "$ctrl_log" || true)} gdroff{rc_mlx5=$(grep -c "rc_mlx5" "$gdroff_log" || true),cuda_copy=$(grep -c "cuda_copy" "$gdroff_log" || true),gdr_copy=$(grep -c "gdr_copy" "$gdroff_log" || true)}"
  else
    echo "ucx_ab_markers test=$t INCOMPLETE (missing arm log)"
  fi
done
EXPECTED_TOTAL=$((ARM_COUNT * 4))
echo "total_runs=$TOTAL expected=$EXPECTED_TOTAL failed_runs=$FAILS"
echo "NOTE: ${RESULT_TAG}_RESULT=PASS reflects execution and output shape only; GDR A/B validity is classified from UCX_PROTO_INFO evidence at analysis time."
if [ "$TOTAL" -eq "$EXPECTED_TOTAL" ] && [ "$FAILS" -eq 0 ]; then
  echo "${RESULT_TAG}_RESULT=PASS"
  exit 0
else
  echo "${RESULT_TAG}_RESULT=FAIL"
  exit 1
fi
