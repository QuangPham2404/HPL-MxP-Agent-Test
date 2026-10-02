#!/bin/bash
# Host-side per-node HCA InfiniBand counter/link-state snapshot for the
# 2x8-GAAS phase4d chunk-4 confirmation run
# (TASK-2X8-016 Section 1.4B: per-HCA TX/RX/xmit-wait plus
# link/error/discard/recovery evidence around the single confirmation arm).
#
# Validated helper copy of the TASK-2X8-015 phase4c
# scripts/hca_counter_snapshot.sh (unchanged capture contract; only the
# lock prefix and these header references are task-scoped to phase4d).
#
# Invoked on every allocated vnode by the phase4d run script via:
#     pbsdsh -- /bin/bash hca_counter_snapshot.sh <outdir> <label> <jobid>
#
# Why host-side: the HCA sysfs counters, link state, and rate are host facts
# shared with the containers (the same read pattern is already validated by
# scripts/gaas-internode-coms-debug/resource-alloc/debug-scripts/
# sample_node_load.sh). The lock dir (node-local /tmp, namespaced by job id,
# label, and hostname) guarantees exactly one snapshot per node even though
# pbsdsh fires once per vnode.
#
# Writes <outdir>/<label>_hca_<node>.log with, for every mlx5 device visible
# on the node (the eight expected physical IB HCAs mlx5_0..mlx5_5,mlx5_8,
# mlx5_9 plus anything else that exists, e.g. the known RoCE bond
# mlx5_bond_0, recorded factually with expected=no): numa node, port state,
# port rate, and the full traffic/wait/error/discard/recovery counter set
# from /sys/class/infiniband/<dev>/ports/<port>/counters (with a
# counters_ext fallback for counters exported only there).
#
# Best effort per section: an unreadable counter is recorded as NA and never
# aborts the snapshot; the run script's gate decides what to do with the
# recorded facts. Prints HCASNAPSHOT_OK/SKIP to job stdout as per-node
# evidence.

set -u

OUTDIR="${1:?usage: hca_counter_snapshot.sh <outdir> <label> <jobid>}"
LABEL="${2:?missing label}"
JOBID="${3:?missing jobid}"

NODE=$(hostname)
LOCK="/tmp/.p4d_hca_${JOBID}_${LABEL}_${NODE}"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "=== HCASNAPSHOT SKIP ${NODE} (already captured ${LABEL} for ${JOBID}) ==="
  exit 0
fi

OUT="${OUTDIR}/${LABEL}_hca_${NODE}.log"

# Traffic and health counters read per device/port (byte/packet counters,
# wait/congestion indicator, discard, error, constraint, and link
# recovery/reset counters; the validated resource-alloc counter set).
IB_COUNTERS="port_xmit_data port_rcv_data port_xmit_packets port_rcv_packets port_xmit_discards port_xmit_wait port_rcv_errors port_rcv_constraint_errors port_xmit_constraint_errors port_rcv_remote_physical_errors port_rcv_switch_relay_errors link_error_recovery link_downed excessive_buffer_overrun_errors symbol_error"

EXPECTED_HCAS="mlx5_0 mlx5_1 mlx5_2 mlx5_3 mlx5_4 mlx5_5 mlx5_8 mlx5_9"

{
  echo "HCA_SNAPSHOT node=${NODE} label=${LABEL} jobid=${JOBID} begin=$(date --iso-8601=seconds)"
  for d in /sys/class/infiniband/mlx5*; do
    [ -d "$d" ] || continue
    dev="$(basename "$d")"
    expected=no
    case " ${EXPECTED_HCAS} " in
      *" ${dev} "*) expected=yes ;;
    esac
    numa="$(cat "$d/numa_node" 2>/dev/null || echo NA)"
    for p in "$d"/ports/[0-9]*; do
      [ -d "$p" ] || continue
      port="$(basename "$p")"
      state="$(cat "$p/state" 2>/dev/null || echo NA)"
      rate="$(cat "$p/rate" 2>/dev/null || echo NA)"
      echo "DEV ${dev}/port${port} node=${NODE} numa_node=${numa} state=${state} rate=${rate} expected=${expected}"
      line="COUNTERS ${dev}/port${port} node=${NODE}"
      for k in $IB_COUNTERS; do
        v=""
        if [ -r "$p/counters/$k" ]; then
          v="$(cat "$p/counters/$k" 2>/dev/null || true)"
        elif [ -r "$p/counters_ext/$k" ]; then
          v="$(cat "$p/counters_ext/$k" 2>/dev/null || true)"
        fi
        [ -n "$v" ] || v=NA
        line="${line} ${k}=${v}"
      done
      echo "$line"
    done
  done
  echo "HCA_SNAPSHOT node=${NODE} label=${LABEL} jobid=${JOBID} end=$(date --iso-8601=seconds)"
} > "$OUT" 2>&1

echo "=== HCASNAPSHOT ${NODE} ${LABEL} wrote ${OUT} ==="
