#!/bin/bash
# First-pass telemetry aggregation for resource-alloc experiment 5
# (host-contention mechanism study; see resource-alloc/README.md).
#
# Usage: analyze_mech_telemetry.sh <load_log>...
# Prints one CSV row per input log:
#   run,node,ticks,span_s,avg_busy_cpus,gpu_util_med%,gpu_util_p90%,
#   gpu_power_med_W,gpu_active_pct(>50%),cg_throttled_s,cg_nr_throttled,
#   cg_oom_events,cg_max_events,ib_bytes_MiB,numa_remote_pct,
#   memavail_min_GB,ranks_seen,rank_rss_sum_GB,rank_majflt_max
#
# NOTE: the cgroup cpu.stat/memory counters resolved by the sampler measure
# the SAMPLER's own cgroup scope (pbsdsh spawns land outside the app session
# cgroup on GAAS), not the application cgroup — treat them as sampler-scope
# diagnostics only. /proc, numastat, IB, and GPU sections are node-global or
# cgroup-visible-allocated-GPU scoped and do cover the app window.
#
# Whole-run aggregates (no phase segmentation): in the heavy-busy runs LU
# dominates the app window, so whole-run medians approximate the LU window;
# within-run node contrasts are phase-synchronized by construction (same
# run, same wall clock). Best effort: missing sections print n/a.

set -u

for f in "$@"; do
  base=$(basename "$f")
  run=${base%_load_*}
  node=${base##*_load_}
  node=${node%.log}

  awk -v RUN="$run" -v NODE="$node" '
    function clean(s) { gsub(/[%W MHz iB]/, "", s); return s }
    function median(arr, n,   i, j, t) {
      if (n == 0) return "n/a"
      for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (arr[j] < arr[i]) { t = arr[i]; arr[i] = arr[j]; arr[j] = t }
      return (n % 2) ? arr[int(n / 2)] : (arr[n / 2 - 1] + arr[n / 2]) / 2
    }
    function p90(arr, n,   i, j, t) {
      if (n == 0) return "n/a"
      for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (arr[j] < arr[i]) { t = arr[i]; arr[i] = arr[j]; arr[j] = t }
      return arr[int((n - 1) * 0.9)]
    }
    /^SAMPLE tick=/ {
      for (i = 1; i <= NF; i++) if ($i ~ /^epoch=/) { split($i, a, "="); cur_epoch = a[2] }
      if (first_epoch == "") first_epoch = cur_epoch
      last_epoch = cur_epoch
      tick++
      section = ""
    }
    section == "procstat" && $1 == "cpu" {
      busy = $2 + $3 + $4 + $7 + $8 + $9; total = busy + $5 + $6
      if (first_total == "") { first_busy = busy; first_total = total }
      last_busy = busy; last_total = total
    }
    section == "numastat" && /^\[node/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "local_node") cur_local += $(i + 1)
        if ($i == "other_node") cur_other += $(i + 1)
      }
      nn++
      if (nn == numnodes) {
        if (n_local_first == "") { n_local_first = cur_local; n_other_first = cur_other }
        n_local_last = cur_local; n_other_last = cur_other
        cur_local = 0; cur_other = 0; nn = 0
      }
    }
    section == "cgcpu" && $1 == "usage_usec" { if (cg_usage_first == "") cg_usage_first = $2; cg_usage_last = $2 }
    section == "cgcpu" && $1 == "nr_throttled" { if (cg_thr_first == "") cg_thr_first = $2; cg_thr_last = $2 }
    section == "cgcpu" && $1 == "throttled_usec" { if (cg_thru_first == "") cg_thru_first = $2; cg_thru_last = $2 }
    section == "cgmem" && $1 == "memory.current" { memcur = $2 }
    section == "cgmem" && $1 == "max" { if (cg_max_first == "") cg_max_first = $2; cg_max_last = $2 }
    section == "cgmem" && $1 == "oom" { if (cg_oom_first == "") cg_oom_first = $2; cg_oom_last = $2 }
    section == "ib" && /^mlx5_/ {
      tag = $1
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^port_xmit_data=/) { split($i, a, "="); if (!(tag in ib_first)) ib_first[tag] = a[2]; ib_last[tag] = a[2] }
        if ($i ~ /^port_rcv_data=/) { split($i, a, "="); if (!(("r" tag) in ib_first)) ib_first["r" tag] = a[2]; ib_last["r" tag] = a[2] }
      }
    }
    section == "gpu" && /%,/ {
      n = split($0, g, ", ")
      if (n >= 8) {
        u = clean(g[4]); p = clean(g[6]); c = clean(g[7])
        tick_u += u; tick_p += p; tick_c += c; tick_g++
      }
    }
    section == "ranks" && /^pid=/ {
      ranks++
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^rss_kb=/) { split($i, a, "="); rss_sum += a[2] }
        if ($i ~ /^minflt=/) { split($i, a, "="); mf = a[2] }
        if ($i ~ /^majflt=/) { split($i, a, "="); if (a[2] > majflt_max) majflt_max = a[2] }
      }
    }
    section == "ranks" && /^no xhpl_mxp/ { ranks = 0; rss_sum = 0; majflt_max = 0 }
    /^-- loadavg --/ { section = "" }
    /^-- proc\/stat --/ { section = "procstat" }
    /^-- meminfo --/ { section = "meminfo" }
    section == "meminfo" && /^MemAvailable:/ { v = $2 / 1048576; if (memavail_min == "" || v < memavail_min) memavail_min = v }
    /^-- vmstat --/ { section = "vmstat" }
    /^-- numastat --/ { section = "numastat"; if (numnodes == 0) { nl = 0; c = 0; while ((getline ln) > 0 && ln ~ /^\[node/) { nl++; } numnodes = nl; c = 1 } }
    /^-- cgroup cpu\.stat --/ { section = "cgcpu" }
    /^-- cgroup memory --/ { section = "cgmem" }
    /^-- ib counters --/ { section = "ib" }
    /^-- gpu / { section = "gpu" }
    /^-- local hpl processes/ { section = "ranks"; ranks = 0; rss_sum = 0; majflt_max = 0 }
    /^END_SAMPLE/ {
      if (tick_g > 0) {
        util[tick - 1] = tick_u / tick_g
        pwr[tick - 1] = tick_p / tick_g
        clk[tick - 1] = tick_c / tick_g
        if (tick_u / tick_g > 50) gpu_active++
      }
      tick_u = 0; tick_p = 0; tick_c = 0; tick_g = 0
      section = ""
    }
    END {
      span = last_epoch - first_epoch
      if (last_total > first_total) avg_busy = (last_busy - first_busy) / (last_total - first_total) * 100; else avg_busy = "n/a"
      ib_bytes = 0
      for (t in ib_last) ib_bytes += ib_last[t] - ib_first[t]
      if (n_local_last > n_local_first + n_other_last - n_other_first) nr = (n_other_last - n_other_first) / (n_local_last - n_local_first + n_other_last - n_other_first) * 100; else nr = "n/a"
      if (tick > 0) act_pct = gpu_active / tick * 100; else act_pct = "n/a"
      printf "%s,%s,%d,%d,%s,%.1f,%.1f,%.1f,%.0f,%.1f,%.3f,%d,%d,%d,%.1f,%s,%.1f,%d,%.2f,%d\n", \
        RUN, NODE, tick, span, avg_busy, median(util, tick), p90(util, tick), median(pwr, tick), median(clk, tick), \
        act_pct, (cg_thru_last - cg_thru_first) / 1e6, cg_thr_last - cg_thr_first, \
        cg_oom_last - cg_oom_first, cg_max_last - cg_max_first, ib_bytes / 1048576, nr, memavail_min, \
        ranks, rss_sum / 1048576, majflt_max
    }
  ' "$f"
done
