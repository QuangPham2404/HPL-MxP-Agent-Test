#!/bin/bash
# In-run per-node host-load sampler for resource-alloc experiment 2
# (clean_node_test; see resource-alloc/README.md).
#
# Invoked on every allocated node by the run script (in the background) via:
#     pbsdsh -- /bin/bash <this script> <out_prefix> <lock_base> \
#         <interval_s> <stop_file> <max_ticks>
# The lock dir (shared home filesystem) deduplicates pbsdsh invocations so
# exactly one sampler runs per node. Appends a timestamped block every
# <interval_s> to <out_prefix>_load_<node>.log until <stop_file> appears or
# <max_ticks> samples have been taken (failsafe below the job walltime).
#
# Node-global metrics (/proc/loadavg, /proc/stat, meminfo subset, vmstat
# subset, PSI if present, numastat, mlx5 IB port counters) intentionally
# include co-tenant activity: that load is what this experiment measures.
# Per-GPU metrics cover only the job's cgroup-allocated GPUs (4 of 8).
# Best effort: any failing section is skipped; the loop never aborts.
# Sampling cadence drifts slightly (sleep happens after each block); the
# per-sample epoch timestamp makes the series self-describing.

set -u

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

OUT_PREFIX="${1:?usage: sample_node_load.sh <out_prefix> <lock_base> <interval_s> <stop_file> <max_ticks>}"
LOCK_BASE="${2:?missing lock_base}"
INTERVAL="${3:-10}"
STOP_FILE="${4:?missing stop_file}"
MAX_TICKS="${5:-170}"

NODE=$(hostname)
mkdir -p "$LOCK_BASE"
LOCK_DIR="${LOCK_BASE}/${NODE}"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "=== SAMPLER SKIP ${NODE} (already sampling) ==="
  exit 0
fi

OUT="${OUT_PREFIX}_load_${NODE}.log"

# Traffic and health counters read each tick from sysfs (port_xmit_data and
# port_rcv_data are the byte counters; port_xmit_wait, errors, discards and
# recovery counters cover fabric wait/congestion/error conditions).
IB_COUNTERS="port_xmit_data port_rcv_data port_xmit_packets port_rcv_packets port_xmit_discards port_xmit_wait port_rcv_errors port_rcv_constraint_errors port_xmit_constraint_errors port_rcv_remote_physical_errors port_rcv_switch_relay_errors link_error_recovery link_downed excessive_buffer_overrun_errors symbol_error"

{
  echo "=== SAMPLER BEGIN ${NODE} interval=${INTERVAL}s max_ticks=${MAX_TICKS} ==="
  date --iso-8601=seconds
  echo "kernel=$(uname -r)"
  echo "--- NIC port provenance ---"
  for d in /sys/class/infiniband/mlx5*; do
    [ -d "$d" ] || continue
    for p in "$d"/ports/[0-9]*; do
      [ -d "$p" ] || continue
      echo "$(basename "$d") port $(basename "$p") state=$(cat "$p/state" 2>/dev/null) rate=$(cat "$p/rate" 2>/dev/null)"
    done
  done
} >> "$OUT" 2>&1

tick=0
while [ "$tick" -lt "$MAX_TICKS" ]; do
  if [ -e "$STOP_FILE" ]; then
    break
  fi
  tick=$((tick + 1))
  {
    echo "SAMPLE tick=${tick} epoch=$(date +%s) iso=$(date --iso-8601=seconds)"

    echo "-- loadavg --"
    cat /proc/loadavg 2>/dev/null

    echo "-- proc/stat --"
    cat /proc/stat 2>/dev/null

    echo "-- meminfo --"
    grep -E "^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|AnonPages|Active|Inactive|Dirty|Writeback):" /proc/meminfo 2>/dev/null

    echo "-- vmstat --"
    grep -E "^(pgfault|pgmajfault|pswpin|pswpout|pgpgin|pgpgout)" /proc/vmstat 2>/dev/null

    if [ -d /proc/pressure ]; then
      for r in cpu memory io; do
        echo "-- psi ${r} --"
        cat "/proc/pressure/$r" 2>/dev/null
      done
    fi

    echo "-- numastat --"
    for n in /sys/devices/system/node/node[0-9]*; do
      [ -d "$n" ] || continue
      echo "[$(basename "$n")] $(cat "$n/numastat" 2>/dev/null | tr '\n' ' ')"
    done

    echo "-- ib counters --"
    for c in /sys/class/infiniband/mlx5*/ports/[0-9]*/counters; do
      [ -d "$c" ] || continue
      port_dir=${c%/counters}
      tag="$(basename "${port_dir%/ports/*}")/$(basename "$port_dir")"
      line=""
      for k in $IB_COUNTERS; do
        v=$(cat "$c/$k" 2>/dev/null) || v=NA
        line="${line} ${k}=${v}"
      done
      echo "${tag}${line}"
    done

    echo "-- gpu (cgroup-visible allocated set) --"
    nvidia-smi --query-gpu=timestamp,index,pci.bus_id,utilization.gpu,utilization.memory,power.draw,clocks.sm,memory.used --format=csv,noheader 2>/dev/null \
      || echo "nvidia-smi query failed"

    echo "END_SAMPLE tick=${tick}"
  } >> "$OUT" 2>&1
  sleep "$INTERVAL"
done

{
  echo "=== SAMPLER END ${NODE} ticks=${tick} ==="
  date --iso-8601=seconds
} >> "$OUT" 2>&1
echo "=== SAMPLER DONE ${NODE} ticks=${tick} ==="
