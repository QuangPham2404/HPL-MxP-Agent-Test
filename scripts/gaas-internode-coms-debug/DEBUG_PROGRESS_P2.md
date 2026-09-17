# GAAS In-Container GDR Debugging Progress — Phase 2 (Track 2.2)

This file records Phase 2 (in-container GPUDirect RDMA verification) results,
analysis, and next steps. Phase 1 (host GDR verification, CLOSED 2026-09-17)
is recorded in `DEBUG_PROGRESS.md`, which is now a frozen historical record —
new content goes here. Plan: `README.md` → "Phase 2 plan" plus the execution
decisions of 2026-09-18 (full test set at both Stage-2 rungs; stop-and-report
on missing container tooling; bond-abort contingency pre-authorized for the
container NCCL 3x4 allreduce, signature-matched only).

Stage overview (per the plan):

| Stage | Scope | Status |
|---|---|---|
| 1 | Container/launch preflight (tooling inventory + versions + device access + launch-path check) | in progress |
| 2 | Container-native OSU/NCCL GDR A/B (2x1 then 3x4, full test set) | not started |
| 3 | HPL-MxP integration A/B at N=480000/NB=1024 vs `3x4-baseline_v1` | not started |

## Phase 2 — Stage 1: container/launch preflight (2026-09-18) — IN PROGRESS

**Attempt:** `phase2_preflight_v1` — script
`debug-scripts/phase2-preflight/run_phase2_preflight.pbs`, 2 host-pinned
nodes, group `hpc_ebslee`. Inspection only: container tooling inventory
(nccl-tests + osu-cuda-nvidia-alternative), SIF identity, container MPI/UCX/
NCCL versions, container RDMA device/library access, host GDR module state
(informational, gdrdrv explicitly not a gate), and the Approach-1 container
launch-path check (container mpirun + bridge + container orted, per-rank
mapping, cross-node MPI message flow).

**Status:** job submitted; results pending. To be completed from
`outputs/phase2-preflight/phase2_preflight_v1*` when the run finishes.
