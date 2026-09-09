#!/bin/bash
# Per-node clean-node checkpoint capture for Phase B2 (collectives diagnostic
# replication; see scripts/gaas-internode-coms-debug/README.md, Phase B2).
#
# Invoked on every allocated node by the run script via:
#     pbsdsh -- /bin/bash collb2_node_snapshot.sh <outdir> <label> <tag> <lock_base>
# The lock dir (shared filesystem) guarantees the body runs exactly once per
# node even if pbsdsh fires more than once; the capture writes
# <outdir>/<label>_<tag>_<node>.log (one file per node, no interleaving).
#
# Records exactly the Phase B2 clean-node evidence list: /proc/loadavg, PSI
# (/proc/pressure/*), memory status, job cpuset, cgroup-visible GPU state,
# and the in-job pbsnodes co-tenant view (a clean pre-submission snapshot
# alone is insufficient; another job may arrive before or during execution).
# Best effort: every section prints even if a tool is unavailable; a failed
# section never aborts the capture.

set -u

OUTDIR="${1:?usage: collb2_node_snapshot.sh <outdir> <label> <tag> <lock_base>}"
LABEL="${2:?missing label}"
TAG="${3:?missing tag}"
LOCK_BASE="${4:?missing lock_base}"

NODE=$(hostname)
mkdir -p "$LOCK_BASE"
LOCK_DIR="${LOCK_BASE}/${TAG}_${NODE}"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "=== COLLB2_SNAPSHOT SKIP ${NODE} ${TAG} (already captured) ==="
  exit 0
fi

OUT="$OUTDIR/${LABEL}_${TAG}_${NODE}.log"
{
  echo "=== COLLB2_SNAPSHOT BEGIN ${NODE} tag=${TAG} ==="
  date --iso-8601=seconds

  echo "--- /proc/loadavg ---"
  cat /proc/loadavg || true

  echo "--- PSI (cpu/memory/io) ---"
  if [ -d /proc/pressure ]; then
    for r in cpu memory io; do
      echo "[psi $r] $(cat "/proc/pressure/$r" 2>/dev/null | tr '\n' ' ')"
    done
  else
    echo "PSI not available on this node"
  fi

  echo "--- memory status (key lines) ---"
  grep -E "^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|AnonPages):" /proc/meminfo || true

  echo "--- job cpuset / mems (this node) ---"
  grep -E "Cpus_allowed_list|Mems_allowed_list" /proc/self/status || true

  echo "--- cgroup-visible GPU inventory (UUIDs) ---"
  nvidia-smi -L || true
  nvidia-smi --query-gpu=index,pci.bus_id,uuid,memory.used,power.draw --format=csv || true

  echo "--- co-tenant jobs on this node (in-job pbsnodes view, best effort) ---"
  /opt/pbs/bin/pbsnodes "$NODE" 2>/dev/null \
    | grep -E "^[[:space:]]+(state|jobs|resources_assigned\.(ncpus|ngpus|mem)) =" \
    || echo "pbsnodes unavailable from this node"

  echo "=== COLLB2_SNAPSHOT END ${NODE} tag=${TAG} ==="
} > "$OUT" 2>&1

echo "=== COLLB2_SNAPSHOT ${TAG} ${NODE} wrote ${OUT} ==="
