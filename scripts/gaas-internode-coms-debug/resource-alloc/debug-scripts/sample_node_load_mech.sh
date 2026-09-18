#!/bin/bash
# In-run per-node sampler for resource-alloc experiment 5 (host-contention
# mechanism study; see resource-alloc/README.md).
#
# Invoked on every allocated node by the run script (in the background) via:
#     pbsdsh -- /bin/bash <this script> <out_prefix> <lock_base> \
#         <interval_s> <stop_file> <max_ticks>
# Same lock-deduplication contract as sample_node_load.sh (experiment 2-4).
#
# Differences vs the experiment 2-4 sampler, per the experiment-5 design:
#   - ~2 s default cadence (was 10 s);
#   - per-tick job-cgroup counters (cpu.stat incl. throttling, memory.current,
#     memory.events, memory.stat subset) — best effort, resolved once;
#   - every 5th tick: CPU/memory affinity, RSS and fault/switch counters of
#     the local xhpl_mxp ranks;
#   - GPU query adds temperature and current PCIe link gen/width;
#   - optional background `perf stat -a` interval collector: started only when
#     PERF_EVENTS (comma-separated, probe-validated) is non-empty and perf
#     exists; output appends to <out_prefix>_perf_<node>.log; bounded by
#     `timeout` and killed at sampler end. Unavailability is recorded, never
#     fatal.
#
# Node-global metrics intentionally include co-tenant activity — that load is
# what this experiment measures. Per-GPU metrics cover only the job's
# cgroup-allocated GPUs (4 of 8). Best effort: any failing section is skipped;
# the loop never aborts.

set -u

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

OUT_PREFIX="${1:?usage: sample_node_load_mech.sh <out_prefix> <lock_base> <interval_s> <stop_file> <max_ticks>}"
LOCK_BASE="${2:?missing lock_base}"
INTERVAL="${3:-2}"
STOP_FILE="${4:?missing stop_file}"
MAX_TICKS="${5:-850}"
PERF_EVENTS="${PERF_EVENTS:-}"

NODE=$(hostname)
mkdir -p "$LOCK_BASE"
LOCK_DIR="${LOCK_BASE}/${NODE}"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "=== SAMPLER-MECH SKIP ${NODE} (already sampling) ==="
  exit 0
fi

OUT="${OUT_PREFIX}_load_${NODE}.log"
PERF_LOG="${OUT_PREFIX}_perf_${NODE}.log"

IB_COUNTERS="port_xmit_data port_rcv_data port_xmit_packets port_rcv_packets port_xmit_discards port_xmit_wait port_rcv_errors port_rcv_constraint_errors port_xmit_constraint_errors port_rcv_remote_physical_errors port_rcv_switch_relay_errors link_error_recovery link_downed excessive_buffer_overrun_errors symbol_error"

# Best-effort job-cgroup dir resolution (same logic as the mech capture).
CGDIR=""
rel=$(awk -F: '/^0::/{print $3}' /proc/self/cgroup 2>/dev/null)
if [ -n "$rel" ] && [ -r "/sys/fs/cgroup${rel}/cpu.stat" ]; then
  CGDIR="/sys/fs/cgroup${rel}"
elif [ -r "/sys/fs/cgroup/cpu.stat" ]; then
  CGDIR="/sys/fs/cgroup"
fi

# Optional perf collector (child process, bounded by timeout + killed at end).
PERF_PID=""
if [ -n "$PERF_EVENTS" ] && command -v perf >/dev/null 2>&1; then
  PERF_BUDGET=$(( MAX_TICKS * INTERVAL + 120 ))
  {
    echo "=== PERF COLLECTOR BEGIN ${NODE} events=${PERF_EVENTS} interval_ms=$((INTERVAL * 1000)) ==="
    date --iso-8601=seconds
  } >> "$PERF_LOG" 2>&1
  ( timeout "$PERF_BUDGET" perf stat -a -I "$((INTERVAL * 1000))" -x, -e "$PERF_EVENTS" -- sleep "$PERF_BUDGET" >> "$PERF_LOG" 2>&1 ) &
  PERF_PID=$!
elif [ -n "$PERF_EVENTS" ]; then
  echo "=== PERF COLLECTOR UNAVAILABLE ${NODE} (perf binary missing) ===" >> "$PERF_LOG" 2>&1
fi

{
  echo "=== SAMPLER-MECH BEGIN ${NODE} interval=${INTERVAL}s max_ticks=${MAX_TICKS} ==="
  date --iso-8601=seconds
  echo "kernel=$(uname -r)"
  echo "cgroup_dir=${CGDIR:-UNAVAILABLE}"
  echo "perf_events=${PERF_EVENTS:-none}"
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
    grep -E "^(pgfault|pgmajfault|pswpin|pswpout|pgpgin|pgpgout|pgmigrate|numa_)" /proc/vmstat 2>/dev/null

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

    if [ -n "$CGDIR" ]; then
      echo "-- cgroup cpu.stat --"
      cat "${CGDIR}/cpu.stat" 2>/dev/null
      echo "-- cgroup memory --"
      echo "memory.current=$(cat "${CGDIR}/memory.current" 2>/dev/null)"
      cat "${CGDIR}/memory.events" 2>/dev/null
      grep -E "^(anon|file|kernel|pgfault|pgmajfault|workingset_refault|pglazyfree)" "${CGDIR}/memory.stat" 2>/dev/null
    else
      echo "-- cgroup counters unavailable --"
    fi

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
    nvidia-smi --query-gpu=timestamp,index,pci.bus_id,utilization.gpu,utilization.memory,power.draw,clocks.sm,memory.used,temperature.gpu,pcie.link.gen.current,pcie.link.width.current --format=csv,noheader 2>/dev/null \
      || echo "nvidia-smi query failed"

    # Every 5th tick: local xhpl_mxp rank placement + per-process counters.
    if [ $((tick % 5)) -eq 1 ]; then
      echo "-- local hpl processes (affinity/rss/faults/switches) --"
      found_rank=0
      for pid in $(pgrep -f xhpl_mxp 2>/dev/null); do
        [ -r "/proc/$pid/status" ] || continue
        found_rank=1
        cl=$(awk '/^Cpus_allowed_list/{print $2}' "/proc/$pid/status" 2>/dev/null)
        ml=$(awk '/^Mems_allowed_list/{print $2}' "/proc/$pid/status" 2>/dev/null)
        rss=$(awk '/^VmRSS/{print $2}' "/proc/$pid/status" 2>/dev/null)
        vcs=$(awk '/^voluntary_ctxt_switches/{print $2}' "/proc/$pid/status" 2>/dev/null)
        ivcs=$(awk '/^nonvoluntary_ctxt_switches/{print $2}' "/proc/$pid/status" 2>/dev/null)
        flt=$(awk '{print "minflt=" $10 " majflt=" $12}' "/proc/$pid/stat" 2>/dev/null)
        echo "pid=${pid} cpus=${cl} mems=${ml} rss_kb=${rss} ${flt} vctx=${vcs} ivctx=${ivcs}"
      done
      [ "$found_rank" -eq 0 ] && echo "no xhpl_mxp processes visible yet"
    fi

    echo "END_SAMPLE tick=${tick}"
  } >> "$OUT" 2>&1
  sleep "$INTERVAL"
done

if [ -n "$PERF_PID" ]; then
  kill "$PERF_PID" 2>/dev/null || true
  wait "$PERF_PID" 2>/dev/null || true
  echo "=== PERF COLLECTOR END ${NODE} $(date --iso-8601=seconds) ===" >> "$PERF_LOG" 2>&1
fi

{
  echo "=== SAMPLER-MECH END ${NODE} ticks=${tick} ==="
  date --iso-8601=seconds
} >> "$OUT" 2>&1
echo "=== SAMPLER-MECH DONE ${NODE} ticks=${tick} ==="
