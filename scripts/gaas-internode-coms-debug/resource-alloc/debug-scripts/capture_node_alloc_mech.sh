#!/bin/bash
# Pre/post-run per-node host capture for resource-alloc experiment 5
# (host-contention mechanism study; see resource-alloc/README.md).
#
# Invoked on every allocated node by the run script via:
#     pbsdsh -- /bin/bash <this script> <out_prefix> <lock_base> <phase>
# Superset of capture_node_alloc_v2.sh (experiment 2-4 capture). Added for
# the mechanism study: job-cgroup path/effective limits and cpu.stat /
# memory.* counters, transparent-huge-page/VM state, and GPU PCIe link
# generation/width. Every section is best effort; a failed section never
# aborts the capture. GPU sections see only the job's cgroup-allocated GPUs;
# co-tenant GPU state is unobservable in-job (known limitation).

set -u

export PATH=/usr/local/apptainer/1.4.1/bin:/usr/local/squashfuse/0.5.2/bin:/usr/local/gocryptfs/2.5.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH="/usr/local/squashfuse/0.5.2/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

SIF="/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif"

OUT_PREFIX="${1:?usage: capture_node_alloc_mech.sh <out_prefix> <lock_base> <phase>}"
LOCK_BASE="${2:?missing lock_base}"
PHASE="${3:-pre}"

NODE=$(hostname)
mkdir -p "$LOCK_BASE"
LOCK_DIR="${LOCK_BASE}/${PHASE}_${NODE}"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "=== CAPTURE-MECH SKIP ${NODE} ${PHASE} (already captured) ==="
  exit 0
fi

OUT="${OUT_PREFIX}_${PHASE}_${NODE}.log"

# Best-effort job-cgroup dir resolution: PBS jobs typically land in their own
# cgroup namespace where /sys/fs/cgroup *is* the job cgroup; fall back to the
# 0::<path> entry from /proc/self/cgroup.
resolve_cgroup_dir() {
  local cg_root=/sys/fs/cgroup
  local rel
  rel=$(awk -F: '/^0::/{print $3}' /proc/self/cgroup 2>/dev/null)
  if [ -n "$rel" ] && [ -r "${cg_root}${rel}/cpu.stat" ]; then
    echo "${cg_root}${rel}"
  elif [ -r "${cg_root}/cpu.stat" ]; then
    echo "${cg_root}"
  else
    echo ""
  fi
}

{
  echo "=== CAPTURE-MECH BEGIN ${NODE} phase=${PHASE} ==="
  date --iso-8601=seconds
  echo "kernel=$(uname -r)"

  echo "--- job cpuset / mems (this node) ---"
  grep -E "Cpus_allowed_list|Mems_allowed_list" /proc/self/status || true

  echo "--- numa node cpulists ---"
  for n in /sys/devices/system/node/node[0-9]*; do
    [ -d "$n" ] && echo "$(basename "$n") cpus=$(cat "$n/cpulist" 2>/dev/null)"
  done

  echo "--- job cgroup (path + effective limits + counters) ---"
  echo "self_cgroup=$(cat /proc/self/cgroup 2>/dev/null | tr ';' ' ')"
  CGDIR=$(resolve_cgroup_dir)
  if [ -n "$CGDIR" ]; then
    echo "resolved_cgroup_dir=${CGDIR}"
    for f in cpu.stat cpu.max cpuset.cpus.effective cpuset.mems.effective \
             memory.current memory.max memory.min memory.events memory.stat; do
      if [ -r "${CGDIR}/${f}" ]; then
        if [ "$f" = "memory.stat" ] || [ "$f" = "memory.events" ]; then
          echo "[${f}]"
          cat "${CGDIR}/${f}"
        else
          echo "${f}=$(cat "${CGDIR}/${f}" | tr '\n' ' ')"
        fi
      else
        echo "${f}=UNAVAILABLE"
      fi
    done
  else
    echo "resolved_cgroup_dir=UNAVAILABLE (cgroup counters not readable)"
  fi

  echo "--- transparent hugepage / VM state ---"
  for f in /sys/kernel/mm/transparent_hugepage/enabled /sys/kernel/mm/transparent_hugepage/defrag; do
    [ -r "$f" ] && echo "$(basename "$(dirname "$f")")/$(basename "$f")=$(cat "$f" 2>/dev/null)"
  done
  echo "swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null)"

  echo "--- cgroup-visible GPU inventory (the allocated set; UUIDs) ---"
  nvidia-smi -L || true

  echo "--- per-GPU pci bus / uuid / memory used ---"
  nvidia-smi --query-gpu=index,pci.bus_id,uuid,memory.used --format=csv || true

  echo "--- GPU PCIe link generation/width (current vs max) ---"
  nvidia-smi --query-gpu=pci.bus_id,pcie.link.gen.current,pcie.link.width.current,pcie.link.gen.max,pcie.link.width.max --format=csv || true

  echo "--- GPU/NIC/NUMA topology matrix ---"
  nvidia-smi topo -m || true

  echo "--- ibdev2netdev ---"
  ibdev2netdev || true

  echo "--- per-NIC numa node + port state/rate ---"
  for d in /sys/class/infiniband/mlx5*; do
    [ -d "$d" ] || continue
    dev=$(basename "$d")
    numa=$(cat "$d/device/numa_node" 2>/dev/null)
    for p in "$d"/ports/[0-9]*; do
      [ -d "$p" ] || continue
      echo "${dev} port $(basename "$p") numa_node=${numa} state=$(cat "$p/state" 2>/dev/null) rate=$(cat "$p/rate" 2>/dev/null)"
    done
  done

  echo "--- IB port counters (one-shot snapshot) ---"
  for c in /sys/class/infiniband/mlx5*/ports/[0-9]*/counters; do
    [ -d "$c" ] || continue
    port_dir=${c%/counters}
    echo "[$(basename "${port_dir%/ports/*}") port $(basename "$port_dir")]"
    for f in "$c"/*; do
      echo "$(basename "$f")=$(cat "$f" 2>/dev/null)"
    done
  done

  echo "--- numastat (per numa node) ---"
  for n in /sys/devices/system/node/node[0-9]*; do
    [ -d "$n" ] || continue
    echo "[$(basename "$n")] $(cat "$n/numastat" 2>/dev/null | tr '\n' ' ')"
  done

  echo "--- host load snapshot ---"
  cat /proc/loadavg || true
  grep -E "^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|AnonPages|Dirty|Writeback):" /proc/meminfo || true
  if [ -d /proc/pressure ]; then
    for r in cpu memory io; do
      echo "[psi $r] $(cat "/proc/pressure/$r" 2>/dev/null | tr '\n' ' ')"
    done
  else
    echo "PSI not available on this node"
  fi

  echo "--- co-tenant jobs on this node (in-job pbsnodes view, best effort) ---"
  /opt/pbs/bin/pbsnodes "$NODE" 2>/dev/null \
    | grep -E "^[[:space:]]+(state|jobs|resources_assigned\.(ncpus|ngpus|mem)) =" \
    || echo "pbsnodes unavailable from this node"

  echo "--- container GPU view (renumbered; what the run uses) ---"
  /usr/local/apptainer/1.4.1/bin/apptainer exec --nv "$SIF" nvidia-smi -L || true

  echo "=== CAPTURE-MECH END ${NODE} phase=${PHASE} ==="
} > "$OUT" 2>&1

echo "=== CAPTURE-MECH ${PHASE} ${NODE} wrote ${OUT} ==="
