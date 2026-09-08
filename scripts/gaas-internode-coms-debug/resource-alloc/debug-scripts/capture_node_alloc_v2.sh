#!/bin/bash
# Pre/post-run per-node host capture for resource-alloc experiment 2
# (clean_node_test; see resource-alloc/README.md).
#
# Invoked on every allocated node by the run script via:
#     pbsdsh -- /bin/bash <this script> <out_prefix> <lock_base> <phase>
# <out_prefix> carries the attempt label; the capture writes
# <out_prefix>_<phase>_<node>.log (one file per node, no interleaving).
# The lock dir (on the shared home filesystem) guarantees the body runs
# exactly once per node even though pbsdsh fires once per slot.
# Best effort: every section prints even if a tool is unavailable; a failed
# section never aborts the capture.
#
# Adds to the experiment-1 capture: an IB port-counter snapshot, per-port
# link state/rate, numastat, a meminfo/load/PSI snapshot, and an in-job
# pbsnodes co-tenant listing. GPU sections see only the job's
# cgroup-allocated GPUs (4 of 8); co-tenant GPU state is unobservable
# in-job (known limitation, same as experiment 1).

set -u

export PATH=/usr/local/apptainer/1.4.1/bin:/usr/local/squashfuse/0.5.2/bin:/usr/local/gocryptfs/2.5.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH="/usr/local/squashfuse/0.5.2/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

SIF="/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif"

OUT_PREFIX="${1:?usage: capture_node_alloc_v2.sh <out_prefix> <lock_base> <phase>}"
LOCK_BASE="${2:?missing lock_base}"
PHASE="${3:-pre}"

NODE=$(hostname)
mkdir -p "$LOCK_BASE"
LOCK_DIR="${LOCK_BASE}/${PHASE}_${NODE}"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "=== CAPTURE2 SKIP ${NODE} ${PHASE} (already captured) ==="
  exit 0
fi

OUT="${OUT_PREFIX}_${PHASE}_${NODE}.log"

{
  echo "=== CAPTURE2 BEGIN ${NODE} phase=${PHASE} ==="
  date --iso-8601=seconds
  echo "kernel=$(uname -r)"

  echo "--- job cpuset / mems (this node) ---"
  grep -E "Cpus_allowed_list|Mems_allowed_list" /proc/self/status || true

  echo "--- numa node cpulists ---"
  for n in /sys/devices/system/node/node[0-9]*; do
    [ -d "$n" ] && echo "$(basename "$n") cpus=$(cat "$n/cpulist" 2>/dev/null)"
  done

  echo "--- cgroup-visible GPU inventory (the allocated set; UUIDs) ---"
  nvidia-smi -L || true

  echo "--- per-GPU pci bus / uuid / memory used ---"
  nvidia-smi --query-gpu=index,pci.bus_id,uuid,memory.used --format=csv || true

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
    | grep -E "^[[:space:]]+(state|jobs|resources_assigned\.(ncpus|ngpus)) =" \
    || echo "pbsnodes unavailable from this node"

  echo "--- container GPU view (renumbered; what the run uses) ---"
  /usr/local/apptainer/1.4.1/bin/apptainer exec --nv "$SIF" nvidia-smi -L || true

  echo "=== CAPTURE2 END ${NODE} phase=${PHASE} ==="
} > "$OUT" 2>&1

echo "=== CAPTURE2 ${PHASE} ${NODE} wrote ${OUT} ==="
