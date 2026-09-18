#!/bin/bash
# Host-side per-node fabric/GDR-module evidence capture for Phase 2 Stage 2.
#
# Invoked on every allocated vnode by the Stage 2 runners via:
#     pbsdsh -- /bin/bash fabric_capture.sh <outdir> <attempt> <jobid>
#
# Why host-side: GPU topology, kernel modules (nvidia_peermem/gdrdrv), and
# the HCA inventory are host facts shared with the containers; in-container
# per-rank GPU/HCA visibility is proven live by the runners' rank-map echo
# (and was proven in the Phase 2 preflight). The lock dir (node-local /tmp,
# namespaced by job id and hostname) guarantees one capture per node even
# though pbsdsh fires once per vnode. Writes
# <outdir>/<attempt>_fabric_<node>.log; prints FABRIC_CAPTURE_OK/SKIP to the
# job stdout as per-node evidence. Best effort: every section prints even if
# a tool is unavailable; a failed section never aborts the capture.

set -u

OUTDIR="${1:?usage: fabric_capture.sh <outdir> <attempt> <jobid>}"
ATTEMPT="${2:?missing attempt}"
JOBID="${3:?missing jobid}"

NODE=$(hostname)
LOCK="/tmp/.p2s2_fabric_${JOBID}_${NODE}"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "=== FABRIC_CAPTURE SKIP ${NODE} (already captured for ${JOBID}) ==="
  exit 0
fi

OUT="$OUTDIR/${ATTEMPT}_fabric_${NODE}.log"
{
  echo "=== FABRIC_CAPTURE BEGIN ${NODE} ==="
  date --iso-8601=seconds

  echo "--- nvidia-smi topo -m ---"
  nvidia-smi topo -m 2>&1 || true

  echo "--- GPU inventory ---"
  nvidia-smi -L 2>&1 || true

  echo "--- GDR kernel modules ---"
  lsmod 2>&1 | grep -E "nvidia_peermem|peermem|gdrdrv" || echo "no peermem/gdrdrv module matched"

  echo "--- ibv_devices ---"
  ibv_devices 2>&1 || true

  echo "--- /dev/infiniband ---"
  ls /dev/infiniband 2>&1 || true

  echo "=== FABRIC_CAPTURE END ${NODE} ==="
} > "$OUT" 2>&1

echo "=== FABRIC_CAPTURE ${NODE} wrote ${OUT} ==="
