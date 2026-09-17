#!/bin/bash
# Read-only hardware-counter availability probe for resource-alloc
# experiment 5 (host-contention mechanism study; see resource-alloc/README.md).
#
# Invoked on an allocated node (directly by run_mech_preflight.pbs). Writes a
# per-item available/unavailable report to the log given as $1 so the
# experiment-5 telemetry list can be finalized before any scored run.
#
# Checks (all read-only, nothing installed, nothing made fatal):
#   - perf binary and perf_event_paranoid level
#   - system-wide core-PMU perf (cycles, instructions, LLC misses)
#   - uncore IMC counters (several kernel naming patterns, cas_count_read/write)
#   - pcm-memory / pcm-memory.x availability
#   - PSI (/proc/pressure)
# Every check prints its raw output or the reason it is unavailable.

set -u

OUT="${1:?usage: probe_hw_counters.sh <out_log>}"
NODE=$(hostname)

{
  echo "=== HW-COUNTER PROBE BEGIN ${NODE} ==="
  date --iso-8601=seconds
  echo "kernel=$(uname -r)"
  echo "cpu=$(grep -m1 'model name' /proc/cpuinfo)"

  echo "--- perf binary ---"
  if command -v perf >/dev/null 2>&1; then
    command -v perf
    perf --version 2>&1 || true
  else
    echo "UNAVAILABLE: perf not in PATH"
    for c in /usr/bin/perf /usr/local/bin/perf /opt/*/bin/perf; do
      [ -x "$c" ] && echo "found candidate: $c"
    done
  fi

  echo "--- perf_event_paranoid ---"
  cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo "UNAVAILABLE: cannot read"

  echo "--- PSI ---"
  if [ -d /proc/pressure ]; then
    for r in cpu memory io; do
      echo "[psi $r] $(cat "/proc/pressure/$r" 2>/dev/null | tr '\n' ' ')"
    done
  else
    echo "UNAVAILABLE: /proc/pressure absent"
  fi

  if command -v perf >/dev/null 2>&1; then
    echo "--- system-wide core-PMU perf (cycles,instructions) ---"
    timeout 20 perf stat -a -e cycles,instructions -- sleep 1 2>&1 || echo "UNAVAILABLE: system-wide core-PMU perf failed"
    echo "--- system-wide LLC misses ---"
    timeout 20 perf stat -a -e LLC-load-misses,LLC-store-misses -- sleep 1 2>&1 || echo "UNAVAILABLE: LLC events failed"

    echo "--- uncore IMC pattern 1: uncore_imc_0/cas_count_* ---"
    timeout 20 perf stat -a -e uncore_imc_0/cas_count_read/,uncore_imc_0/cas_count_write/ -- sleep 1 2>&1 || echo "UNAVAILABLE: uncore_imc_0 pattern failed"
    echo "--- uncore IMC pattern 2: imc0/cas_count_* ---"
    timeout 20 perf stat -a -e imc0/cas_count_read/ -- sleep 1 2>&1 || echo "UNAVAILABLE: imc0 pattern failed"
    echo "--- perf list: IMC/uncore PMU inventory (first 20 matches) ---"
    perf list 2>/dev/null | grep -i "imc" | head -20 || echo "no imc events in perf list"
    echo "--- perf list: PMU names containing uncore (first 20) ---"
    perf list pmu 2>/dev/null | head -40 || true
  fi

  echo "--- pcm-memory availability ---"
  found_pcm=0
  for c in pcm-memory pcm-memory.x /opt/intel/pcm/bin/pcm-memory /usr/local/bin/pcm-memory; do
    if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then
      echo "found: $c"
      found_pcm=1
    fi
  done
  [ "$found_pcm" -eq 0 ] && echo "UNAVAILABLE: no pcm-memory binary found"

  echo "=== HW-COUNTER PROBE END ${NODE} ==="
} > "$OUT" 2>&1

echo "=== PROBE wrote ${OUT} ==="
