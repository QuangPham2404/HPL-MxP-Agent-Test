#!/bin/bash
# Per-node /tmp staging of the OSU-CUDA tree for the Phase 2 smoke jobs.
#
# Invoked on every allocated vnode by the smoke script via:
#     pbsdsh -- /bin/bash stage_osu_tmp.sh <shared_src> <tmp_dst_root> <jobid>
#
# Why: apptainer on GAAS does NOT bind /home into containers (phase2_osu_smoke
# 1x2 v1 evidence), but /tmp IS default-bound (phase2_preflight_v3 container
# find evidence). The shared copy under the project (osu-cuda-host/) is the
# source of truth; each node gets a private copy in its node-local /tmp so
# that BOTH the mother's mpirun container and the bridge-spawned remote orted
# containers (which ignore custom -B flags) can see the binaries.
#
# The lock dir (node-local /tmp, namespaced by job id and hostname) guarantees
# the copy runs exactly once per node even though pbsdsh fires once per vnode.
# Prints OSU_TMP_STAGE_OK/SKIP to stdout, which pbsdsh routes to the job's
# stdout as per-node evidence.

set -u

SRC="${1:?usage: stage_osu_tmp.sh <shared_src> <tmp_dst_root> <jobid>}"
DST_ROOT="${2:?missing tmp_dst_root}"
JOBID="${3:?missing jobid}"

NODE=$(hostname)
mkdir -p "$DST_ROOT" 2>/dev/null || true
LOCK="${DST_ROOT}/.lock_${JOBID}_${NODE}"

if mkdir "$LOCK" 2>/dev/null; then
  rm -rf "${DST_ROOT}/osu-micro-benchmarks-cuda"
  if cp -a "$SRC" "$DST_ROOT/" && [ -x "${DST_ROOT}/osu-micro-benchmarks-cuda/osu_bw" ]; then
    echo "OSU_TMP_STAGE_OK ${NODE} ${DST_ROOT}/osu-micro-benchmarks-cuda/osu_bw"
  else
    echo "OSU_TMP_STAGE_FAIL ${NODE}"
  fi
else
  # A sibling vnode on this node holds the lock for this job: the copy is
  # (being) done there — same node, same /tmp.
  echo "OSU_TMP_STAGE_SKIP ${NODE} (sibling vnode staged for job ${JOBID})"
fi
