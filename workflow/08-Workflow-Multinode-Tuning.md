# Multinode HPL-MxP Tuning Adapter

This adapter adds GAAS multinode launch and evidence rules to the numbered
workflow. It applies whenever an HPL-MxP run spans more than one node. The
general workflow remains authoritative for Git synchronization, authorization,
validation, error handling, results, analysis, and progress handoff.

## 1. Required references and directory contract

Before preparing a multinode run, read:

- `multi-node-test/GAAS_MULTINODE_SETUP.md` for the tested GAAS launch
  contract;
- `multi-node-test/HPL-MxP/README.md` and its model PBS script for the
  containerized launch pattern;
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md` for the sweep phase and
  checkpoint logic; and
- `planning/dependency-graph/README.md` plus `edges.csv` for reopen rules.

For the 3-node × 4-GPU campaign:

- keep reusable launch bridges, probes, and launch-validation models in
  `multi-node-test/`;
- keep each scored run family in
  `experiments/3Nodes-4GPUs/<run-name>/`, with its README, PBS script(s), and
  `outputs/`;
- keep topology-specific analysis in
  `planning/analysis/3Nodes-4GPUs/<analysis-id>.md`;
- keep campaign-level direction and current-baseline records in
  `planning/PLANS.md`; and
- keep the general sweep method in `planning/blueprint/` and dependency
  evidence in `planning/dependency-graph/`.

The existing `experiments/3x4-baseline/` and `experiments/3x4-smoketest/`
directories are preserved historical records. New 3-node × 4-GPU scored runs
use the topology directory contract above.

## 2. GAAS launch gates

Before submission, the run README and PBS script must state and verify:

1. `select=<nodes>:ngpus=<gpus>` with `place=scatter`; do not rely on the
   select resource alone to produce distinct nodes.
2. No `mpiprocs` in the select specification. Derive ranks as
   `nodes × GPUs-per-node`, normally one rank per GPU.
3. A de-duplicated `$PBS_NODEFILE` hostfile with explicit slots per node.
4. The container's own `mpirun`, container `orted`, and HPL-MxP executable
   end-to-end. Do not use the host `mpirun` to drive the container MPI app.
5. `/opt/pbs` and `/var/spool/pbs` bound into the container, with
   `multi-node-test/rsh_pbsdsh_container.sh` used as the tested remote-spawn
   bridge unless a separately authorized replacement is being evaluated.
6. The tested daemon options: `plm_rsh_no_tree_spawn=1`,
   `plm_rsh_num_concurrent=1`, `routed=direct`, and `--bind-to none`.
7. The global rank, local rank, node, GPU, CPU/NUMA, and NIC mapping is printed
   or otherwise captured and verified before interpreting performance.
8. Multinode jobs are submitted one at a time and monitored with bounded
   polling. Do not submit a batch of concurrent jobs through the GAAS path.

The exact container path, module set, launcher, resource request, and any UCX,
MPI, or NIC settings are run metadata. They must not be silently changed while
comparing tuning candidates.

## 3. Multinode sweep and evidence rules

Use the blueprint's Phase 0 before tuning a flag: establish the actual node,
GPU, NIC, CPU/NUMA, cpuset, launcher, transport, and memory envelope, then
identify the immutable new-system original baseline. A launch-validation run
may use a small problem; a scored tuning run must use the campaign workload
and the fixed monitoring controls required by `AGENTS.md`.

Every scored run records, at minimum, node list/order, ranks and ranks/node,
process grid/order, local GPU affinity, launcher/bridge, container and MPI
provenance, modules, relevant environment, resource request, all HPL-MxP
flags, PBS job ID, attempt ID, output paths, phase timings, memory/headroom,
GPU-monitoring warnings, finite residual, tolerance, verification result, and
overall/LU performance.

Multinode candidates are ranked only after scheduler/output validation and
`PASSED` finite-residual verification. Every analysis table includes both:

- percentage change versus the exact in-sweep control; and
- percentage increase versus the immutable new-system original baseline for
  the active topology. For this campaign that baseline is the 3-node × 4-GPU
  `3x4-baseline_v1` run.

The historical single-node `baseline-sweep_v1` may be shown as context, but is
not the denominator for a 3-node × 4-GPU campaign.

## 4. Authorization and failure boundaries

The blueprint proposes the next bounded experiment; it does not authorize it.
The user must confirm the experiment scope before submission, and the general
workflow's `ANALYSE_RESULTS` authorization is still required before creating or
updating analysis conclusions or `PLANS.md`.

Treat launcher, MPI/UCX, resource, node-placement, rank-mapping, and
container-environment changes as Track 2 decisions unless the user has given a
specific override. Preserve all output and record a manual-inspection case;
do not automatically retry a hang, failed `MPI_Init`, rank misplacement,
transport fallback, or uncertain correctness result.

Only deterministic defects in workflow machinery—such as a wrong path,
output filename, or missing designated directory—may use Track 1, with a new
attempt label and preserved evidence.

After each blueprint phase or later-created communication/scheduling subgroup,
perform the blueprint dependency checkpoint. Record whether the review was
performed or explicitly skipped, the relevant edge IDs, the resulting
full-resweep/light-revalidation/keep-closed action, and exactly one proposed
next action before waiting for human confirmation.
