#!/bin/bash
# Per-node host-resource allocation capture for the resource-alloc experiments
# (see resource-alloc/README.md, experiment 1).
#
# Invoked on every allocated node by the run script via:
#     pbsdsh -- /bin/bash <this script> <shared_lock_dir>
# The lock dir (on the shared home filesystem) guarantees the capture body
# runs exactly once per node even if pbsdsh fires once per vnode/slot.
# Best effort: every section prints even if a tool is unavailable; a failed
# section never aborts the capture.

set -u

export PATH=/usr/local/apptainer/1.4.1/bin:/usr/local/squashfuse/0.5.2/bin:/usr/local/gocryptfs/2.5.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH="/usr/local/squashfuse/0.5.2/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

SIF="/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif"

NODE=$(hostname)
LOCK_BASE="${1:-/tmp/resource-alloc-capture}"
LOCK_DIR="${LOCK_BASE}/captured_${NODE}"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "=== NODE-CAPTURE SKIP ${NODE} (already captured) ==="
  exit 0
fi

echo "=== NODE-CAPTURE BEGIN ${NODE} ==="
date --iso-8601=seconds

echo "--- job cpuset / mems (this node) ---"
grep -E "Cpus_allowed_list|Mems_allowed_list" /proc/self/status || true

echo "--- numa node cpulists ---"
for n in /sys/devices/system/node/node[0-9]*; do
  if [ -d "$n" ]; then echo "$(basename "$n") cpus=$(cat "$n/cpulist" 2>/dev/null)"; fi
done

echo "--- host GPU inventory (all GPUs, PCI bus ids) ---"
nvidia-smi -L || true

echo "--- host per-GPU memory used (co-tenancy hint) ---"
nvidia-smi --query-gpu=index,pci.bus_id,memory.used --format=csv || true

echo "--- GPU/NIC/NUMA topology matrix ---"
nvidia-smi topo -m || true

echo "--- ibdev2netdev ---"
ibdev2netdev || true

echo "--- per-NIC numa node ---"
for d in /sys/class/infiniband/mlx5*; do
  if [ -d "$d" ]; then echo "$(basename "$d") numa_node=$(cat "$d/device/numa_node" 2>/dev/null)"; fi
done

echo "--- container GPU view (renumbered; what the run uses) ---"
/usr/local/apptainer/1.4.1/bin/apptainer exec --nv "$SIF" nvidia-smi -L || true

echo "=== NODE-CAPTURE END ${NODE} ==="
