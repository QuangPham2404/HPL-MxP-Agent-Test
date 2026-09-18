#!/bin/bash
# Shared container NCCL GDR A/B runner for Phase 2 Stage 2 (NCCL arm).
#
# Purpose: run the container-native nccl-tests *_mpi binaries through the
# container NCCL stack (IBext_v11 plugin) in a same-job GDR A/B — ctrl
# (defaults, transport selection free) vs gdroff (NCCL_NET_GDR_LEVEL=LOC: IB
# without GPUDirect RDMA) — on a parameterized 2x1 or 3x4 topology via the
# validated container launch path (container mpirun +
# rsh_pbsdsh_container.sh bridge + container orted; Stage 1 smoke evidence).
# Per arm: sendrecv_perf_mpi, broadcast_perf_mpi (fixed root 0), and
# all_reduce_perf_mpi at the full rank count, host-campaign sweep
# 8 B -> 64 MiB (-b 8 -e 67108864 -f 2 -g 1 -w 5 -n 20), one rank per GPU.
#
# The *_mpi variants are REQUIRED: the container's plain nccl-tests binaries
# are per-process singletons (nranks 1; Stage 1 smoke evidence). NCCL
# diagnostics (DEBUG=INFO, SUBSYS=INIT,BOOTSTRAP,ENV,NET,GRAPH,P2P,COLL,SHM,
# TUNING, FILE=/dev/stderr) run in BOTH arms and are -x forwarded; the ENV
# subsys plus the per-arm channel counts are the knob-reach and data-path
# evidence. Data-path classification uses per-channel "via NET/IBext_v11/..."
# lines only (the host-campaign lesson: per-HCA capability messages mix and
# are not data-path evidence). The per-test AB_VALID/AB_INCONCLUSIVE gate
# line is recorded alongside the run; the runner's RESULT marker covers
# execution and correctness markers only.
#
# Expected working directory: debug-scripts/phase2-stage2/ on GAAS.
# Inputs: ATTEMPT and REQ_HOSTS from qsub; TOPOLOGY, EXPECTED_NNODES,
#         RANKS_PER_NODE (and optional TESTS, ARMS, RESULT_TAG) from the PBS
#         wrapper; container binaries at
#         /workspace/microbenchmarks/nccl_tests/ and the packaged
#         (non-CUDA) osu_bw at /workspace/microbenchmarks/osu_mpi_tests/
#         for the cross-node MPI health gate.
# Outputs: PBS .o/.e (attempt-named) + per-arm/per-test logs, hostfiles,
#          rank map, per-node fabric evidence, and pre/prectrl/mid/post
#          co-tenant checkpoints under ../../outputs/phase2-stage2/.
# Assumptions: full four-GPU node chunks (ngpus=4:ncpus=48:mem=1000GB)
#          pinned for node isolation on every rung; no mpiprocs in PBS
#          select; arms sequential in one job on the same allocation.
#          3x4 P2P caveat (host campaign): sendrecv is a ring — 6
#          intra-node NVLink + 6 inter-node IB legs.

set -uo pipefail

cd "${PBS_O_WORKDIR:?PBS_O_WORKDIR is not set}"
: "${PBS_JOBID:?}"
: "${PBS_NODEFILE:?}"
: "${ATTEMPT:?submit with -v ATTEMPT=<unique attempt label>}"
: "${REQ_HOSTS:?submit with -v REQ_HOSTS=<host1+host2[+host3]>}"
: "${EXPECTED_NNODES:?PBS wrapper must set EXPECTED_NNODES}"
: "${RANKS_PER_NODE:?PBS wrapper must set RANKS_PER_NODE}"
TOPOLOGY="${TOPOLOGY:-unknown}"
TESTS="${TESTS:-sendrecv broadcast allreduce}"
ARMS="${ARMS:-ctrl gdroff}"
RESULT_TAG="${RESULT_TAG:-PHASE2_STAGE2_NCCL}"

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
REPO_ROOT="$(cd "$PBS_O_WORKDIR/../../../.." && pwd)"
BRIDGE="$REPO_ROOT/multi-node-test/rsh_pbsdsh_container.sh"
SNAPSHOT="$PBS_O_WORKDIR/../phase1-step1/collb2_node_snapshot.sh"
FABRIC_HELPER="$PBS_O_WORKDIR/fabric_capture.sh"
SIF="/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif"
NCCL_TESTS_DIR="/workspace/microbenchmarks/nccl_tests"
OSU_MPI_TESTS_DIR="/workspace/microbenchmarks/osu_mpi_tests"
# Packaged (non-CUDA) OSU v7.5 pt2pt binaries live under mpi/pt2pt/ (preflight
# v3 inventory); used only for the cross-node MPI health gate.
OSU_HEALTH_BIN="$OSU_MPI_TESTS_DIR/mpi/pt2pt/osu_bw"

module purge || true
module load apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0 \
  || { echo "FATAL: cannot load the validated module set" >&2; exit 1; }

for tool in apptainer timeout sort paste sed grep awk cat date chmod; do
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

normalize_list() {
  printf '%s\n' "$1" | tr ',+' '\n\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | grep -v '^$' | sort -u | paste -sd+
}

NNODES="$(awk '{gsub(/\r/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); if ($0 != "" && !seen[$0]++) n++} END {print n+0}' "$PBS_NODEFILE")"
REQ_HOST_COUNT="$(printf '%s\n' "$REQ_HOSTS" | awk -F'[+,]' '{print NF}')"
REQUESTED_HOSTS="$(normalize_list "$REQ_HOSTS")"
GRANTED_HOSTS="$(awk '{gsub(/\r/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); if ($0 != "") print $0}' "$PBS_NODEFILE" | sort -u | paste -sd+)"

echo "=== Phase 2 Stage 2 (NCCL GDR A/B) metadata ==="
echo "attempt=$ATTEMPT"
echo "topology=$TOPOLOGY (nodes=$EXPECTED_NNODES ranks_per_node=$RANKS_PER_NODE total_ranks=$TOTAL_RANKS)"
echo "pbs_job_id=$PBS_JOBID"
date --iso-8601=seconds
echo "requested_hosts=$REQUESTED_HOSTS"
echo "granted_hosts=$GRANTED_HOSTS"
echo "tests=$TESTS (container-native *_mpi binaries, fixed root 0 for broadcast)"
echo "arms=$ARMS (ctrl=NCCL defaults; gdroff=NCCL_NET_GDR_LEVEL=LOC)"
echo "sweep=8B..64MiB factor 2; warmup=5 iters=20; one rank per GPU"
echo "nccl_debug=INFO subsys=INIT,BOOTSTRAP,ENV,NET,GRAPH,P2P,COLL,SHM,TUNING file=/dev/stderr (both arms, -x forwarded)"
echo "result_tag=$RESULT_TAG"
echo "sif=$SIF size=$(stat -c %s "$SIF" 2>/dev/null || echo unknown)"
echo "bridge=$BRIDGE"
echo "binding=none"
echo "gpu_selection=one rank per GPU: CUDA_VISIBLE_DEVICES=local rank + NCCL_TESTS_DEVICE=0"
echo "scheduler_chunk=4 GPUs/48 CPUs/1000GB per pinned node for node isolation"

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
echo "SECTION 1: CONTAINER TOOLING CHECK (mother node)"
echo "============================================================"
TOOL_LOG="$OUTDIR/${ATTEMPT}_nccl_tools.log"
apptainer exec --nv "$SIF" bash -c '
  for b in sendrecv_perf_mpi broadcast_perf_mpi all_reduce_perf_mpi; do
    p="'"$NCCL_TESTS_DIR"'/$b"
    if [ -x "$p" ]; then echo "nccl_bin_ok $b"; else echo "NCCL_BIN_MISSING $b"; fi
  done
  p="'"$OSU_HEALTH_BIN"'"
  if [ -x "$p" ]; then echo "osu_health_bin_ok"; else echo "OSU_HEALTH_BIN_MISSING"; fi
  echo "--- ldd all_reduce_perf_mpi (nccl/cuda linkage) ---"
  # libverifiable.so.0 => not found is the documented benign container
  # packaging quirk (preflight v3 Finding 1); it does not affect execution.
  ldd "'"$NCCL_TESTS_DIR"'/all_reduce_perf_mpi" 2>&1 | grep -iE "nccl|cuda|not found" | grep -v "libverifiable" || echo "(no nccl/cuda lines)"
' 2>&1 | tee "$TOOL_LOG"
echo "tool_check_rc=${PIPESTATUS[0]}"
TOOLS_OK=0
if grep -q "nccl_bin_ok sendrecv_perf_mpi" "$TOOL_LOG" \
   && grep -q "nccl_bin_ok broadcast_perf_mpi" "$TOOL_LOG" \
   && grep -q "nccl_bin_ok all_reduce_perf_mpi" "$TOOL_LOG" \
   && grep -q "osu_health_bin_ok" "$TOOL_LOG" \
   && ! grep -qi "not found" "$TOOL_LOG"; then
  TOOLS_OK=1
fi
echo "container_tooling_ok=$TOOLS_OK"
[ "$TOOLS_OK" -eq 1 ] || { echo "FATAL: container nccl-tests/osu tooling check failed" >&2; exit 1; }

echo
echo "============================================================"
echo "SECTION 2: HOSTFILES + PER-RANK MAPPING"
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
cp "$HF_FULL" "$OUTDIR/${ATTEMPT}_hf_full_${PBS_JOBID}"
cp "$HF_PT2PT" "$OUTDIR/${ATTEMPT}_hf_pt2pt_${PBS_JOBID}"

launch() {
  local hf="$1" np="$2"; shift 2
  local xf=(-x PATH -x LD_LIBRARY_PATH)
  while [ "${1:-}" != "--" ]; do
    [ "$#" -gt 0 ] || { echo "FATAL: launch called without -- separator" >&2; return 2; }
    xf+=("$1"); shift
  done
  shift
  timeout 600 apptainer exec --nv \
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
  echo "gpu=$(nvidia-smi -L 2>/dev/null | sed -n "1p")"
  echo "hcas_visible=$(ls /dev/infiniband 2>/dev/null | grep -c "^hca" || true)"
' 2>&1 | tee "$MAP_LOG"
MAP_RC="${PIPESTATUS[0]}"
echo "rank_map_rc=$MAP_RC"
RANK_LINES=$(grep -c "^rank=" "$MAP_LOG" || true)
echo "rank_lines=$RANK_LINES expected=$TOTAL_RANKS"
if [ "$MAP_RC" -ne 0 ] || [ "$RANK_LINES" -ne "$TOTAL_RANKS" ]; then
  echo "FATAL: rank mapping check failed (rc=$MAP_RC lines=$RANK_LINES)" >&2
  exit 1
fi

fabric_capture

echo
echo "============================================================"
echo "SECTION 3: MPI HEALTH GATE (packaged osu_bw H H, cross-node)"
echo "============================================================"
HEALTH_LOG="$OUTDIR/${ATTEMPT}_mpi_health.log"
launch "$HF_PT2PT" 2 -- "$OSU_HEALTH_BIN" H H > "$HEALTH_LOG" 2>&1
HEALTH_RC=$?
tail -20 "$HEALTH_LOG"
HEALTH_ROWS=$(grep -cE "^[0-9]+[[:space:]]+[0-9]" "$HEALTH_LOG" || true)
echo "mpi_health_rc=$HEALTH_RC table_rows=$HEALTH_ROWS"
if [ "$HEALTH_RC" -ne 0 ] || [ "$HEALTH_ROWS" -lt 5 ]; then
  echo "FATAL: container MPI health gate failed (cross-node message flow unproven)" >&2
  exit 1
fi

echo
echo "============================================================"
echo "SECTION 4: GDR A/B ARMS (ctrl vs gdroff, sequential)"
echo "============================================================"
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,BOOTSTRAP,ENV,NET,GRAPH,P2P,COLL,SHM,TUNING
export NCCL_DEBUG_FILE=/dev/stderr

FAILS=0
TOTAL=0

testbin_for() {
  case "$1" in
    sendrecv)  echo "$NCCL_TESTS_DIR/sendrecv_perf_mpi" ;;
    broadcast) echo "$NCCL_TESTS_DIR/broadcast_perf_mpi" ;;
    allreduce) echo "$NCCL_TESTS_DIR/all_reduce_perf_mpi" ;;
    *) echo "FATAL: unknown test '$1' (expected sendrecv, broadcast, or allreduce)" >&2; return 1 ;;
  esac
}

run_nccl_arm() {
  local mode="$1" t testbin testargs log rc ib_ch gdr_ch sock_ch
  case "$mode" in
    ctrl)   unset NCCL_NET_GDR_LEVEL || true ;;
    gdroff) export NCCL_NET_GDR_LEVEL=LOC ;;
    *) echo "FATAL: unknown mode $mode" >&2; return 1 ;;
  esac

  local xf=(-x NCCL_DEBUG -x NCCL_DEBUG_SUBSYS -x NCCL_DEBUG_FILE)
  [ "$mode" = "gdroff" ] && xf+=(-x NCCL_NET_GDR_LEVEL)

  for t in $TESTS; do
    testbin="$(testbin_for "$t")" || return 1
    # broadcast_perf defaults to -r -1 (root rotation); the agreed
    # convention is fixed root 0, so pin it explicitly.
    case "$t" in
      broadcast) testargs="-r 0" ;;
      *)         testargs="" ;;
    esac
    log="$OUTDIR/${ATTEMPT}_${mode}_${t}.log"
    TOTAL=$((TOTAL+1))
    echo ""
    echo "########## RUN: arm=$mode test=$t (NCCL_NET_GDR_LEVEL=$(printenv NCCL_NET_GDR_LEVEL 2>/dev/null || echo unset)) ##########"
    date --iso-8601=seconds
    launch "$HF_FULL" "$TOTAL_RANKS" "${xf[@]}" -- bash -c '
      export CUDA_VISIBLE_DEVICES=$OMPI_COMM_WORLD_LOCAL_RANK
      export NCCL_TESTS_DEVICE=0
      exec '"$testbin"' -b 8 -e 67108864 -f 2 -g 1 -w 5 -n 20 '"$testargs"'
    ' > "$log" 2>&1
    rc=$?
    cat "$log"

    # Correctness gate: rc=0, zero out-of-bounds values, and proof the MPI
    # bootstrap engaged (a nranks-1 comm means the plain singleton binary
    # ran — Stage 1 smoke lesson).
    if [ "$rc" -eq 0 ] && ! grep -Fq "Out of bounds values : 0" "$log"; then
      echo "WARN: $mode/$t completed with rc=0 but the expected zero-error marker is absent"
      rc=1
    fi
    if grep -q "nranks 1 " "$log"; then
      echo "WARN: $mode/$t formed a nranks-1 comm (MPI bootstrap did not engage)"
      rc=1
    fi
    echo "arm_${mode}_${t}_rc=$rc (124=timeout)"

    # Data-path evidence from per-channel "via" lines only; the per-HCA
    # "GPU Direct RDMA Enabled/Disabled" capability messages mix within one
    # log and are not data-path evidence (host-campaign lesson).
    ib_ch=$(grep -c "via NET/IBext" "$log" || true)
    gdr_ch=$(grep -c "GDRDMA" "$log" || true)
    sock_ch=$(grep -c "via NET/Socket" "$log" || true)
    echo "transport_summary arm=$mode test=$t via_ibext_channels=$ib_ch gdrdma_channels=$gdr_ch via_socket_channels=$sock_ch nccl_gdr_level_env_lines=$(grep -c "NCCL_NET_GDR_LEVEL" "$log" || true)"

    [ "$rc" -ne 0 ] && FAILS=$((FAILS+1))
  done
  return 0
}

node_snapshot prectrl
arm_idx=0
ARM_COUNT=$(echo $ARMS | wc -w)
TEST_COUNT=$(echo $TESTS | wc -w)
for mode in $ARMS; do
  run_nccl_arm "$mode" || true
  arm_idx=$((arm_idx+1))
  if [ "$arm_idx" -lt "$ARM_COUNT" ]; then
    node_snapshot "mid${arm_idx}"
  fi
done
node_snapshot post

rm -f "$HF_FULL" "$HF_PT2PT"

echo
echo "============================================================"
echo "SECTION 5: SUMMARY"
echo "============================================================"
echo "phase2_stage2_nccl_end=$(date --iso-8601=seconds)"
echo "--- per-test A/B validity gates (both arms via_ibext>0, ctrl gdrdma>=1, gdroff gdrdma=0; else INCONCLUSIVE) ---"
for t in $TESTS; do
  ctrl_log="$OUTDIR/${ATTEMPT}_ctrl_${t}.log"
  gdroff_log="$OUTDIR/${ATTEMPT}_gdroff_${t}.log"
  if [ -f "$ctrl_log" ] && [ -f "$gdroff_log" ]; then
    ctrl_ib=$(grep -c "via NET/IBext" "$ctrl_log" || true)
    ctrl_gdr=$(grep -c "GDRDMA" "$ctrl_log" || true)
    gdroff_ib=$(grep -c "via NET/IBext" "$gdroff_log" || true)
    gdroff_gdr=$(grep -c "GDRDMA" "$gdroff_log" || true)
    if [ "$ctrl_ib" -gt 0 ] && [ "$gdroff_ib" -gt 0 ] && [ "$ctrl_gdr" -ge 1 ] && [ "$gdroff_gdr" -eq 0 ]; then
      echo "ab_gate test=$t CLASSIFICATION=AB_VALID (ctrl:ib=$ctrl_ib,gdr=$ctrl_gdr gdroff:ib=$gdroff_ib,gdr=$gdroff_gdr)"
    else
      echo "ab_gate test=$t CLASSIFICATION=AB_INCONCLUSIVE (ctrl:ib=$ctrl_ib,gdr=$ctrl_gdr gdroff:ib=$gdroff_ib,gdr=$gdroff_gdr)"
    fi
  else
    echo "ab_gate test=$t CLASSIFICATION=AB_INCOMPLETE (missing arm log)"
  fi
done
EXPECTED_TOTAL=$((ARM_COUNT * TEST_COUNT))
echo "total_runs=$TOTAL expected=$EXPECTED_TOTAL failed_runs=$FAILS"
echo "NOTE: ${RESULT_TAG}_RESULT=PASS reflects execution and correctness markers only; transport A/B validity is the ab_gate lines above."
if [ "$TOTAL" -eq "$EXPECTED_TOTAL" ] && [ "$FAILS" -eq 0 ]; then
  echo "${RESULT_TAG}_RESULT=PASS"
  exit 0
else
  echo "${RESULT_TAG}_RESULT=FAIL"
  exit 1
fi
