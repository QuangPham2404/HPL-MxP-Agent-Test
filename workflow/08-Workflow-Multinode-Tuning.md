# Multinode HPL-MxP Tuning Adapter (GAAS)

This is the project-specific GAAS multinode operational adapter for HPL-MxP
inside Workflow v2. It is not a second workflow: the general numbered files
remain authoritative, especially the task lifecycle, synchronization,
authorization, validation, error handling, results, analysis, and progress
handoff in `07-Workflow.md`. This file adds the multinode launch, evidence,
ownership, and dependency-checkpoint gates that apply whenever an HPL-MxP run
spans more than one GAAS node.

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
and the fixed scored-run controls required by root `AGENTS.md`:
`--skip-tests 0 --monitor-gpu 0` (internal tests enabled, continuous GPU
monitoring disabled). Phase-0 or pre/post-run hardware-health evidence is
part of ordinary runs. Diagnostic monitoring is permitted only as a
separately labelled, justified, and authorized condition; never silently rank
a diagnostic monitor-on run against monitor-off scored runs. Historical PBS
scripts and recorded evidence are unchanged by this policy.

Every scored run records, at minimum, node list/order, ranks and ranks/node,
process grid/order, local GPU affinity, launcher/bridge, container and MPI
provenance, modules, relevant environment, resource request, all HPL-MxP
flags, PBS job ID, attempt ID, output paths, phase timings, memory/headroom,
Phase-0 or pre/post-run hardware-health evidence, finite residual, tolerance,
verification result, and overall/LU performance. GPU-monitoring warnings are
recorded only when separately authorized diagnostics emit them; with
monitoring disabled, record that GPU-monitoring output is unavailable rather
than making new probes or tools mandatory beyond the existing gates.

Multinode candidates are ranked only after scheduler/output validation and
`PASSED` finite-residual verification. Every analysis table includes both:

- percentage change versus the exact in-sweep control; and
- percentage increase versus the immutable new-system original baseline for
  the active topology. For this campaign that baseline is the 3-node × 4-GPU
  `3x4-baseline_v1` run.

The historical single-node `baseline-sweep_v1` may be shown as context, but is
not the denominator for a 3-node × 4-GPU campaign. No agent selects or
promotes a new baseline; baseline promotion requires an explicit human
decision.

### Historical baseline comparability

`3x4-baseline_v1` was recorded under the earlier project policy
(`--skip-tests 1` with continuous GPU monitoring enabled) and predates the
current scored-run protocol. It remains the immutable original baseline for
the 3-node × 4-GPU topology: do not recreate, replace, or promote any run in
its place. Disclose this protocol mismatch whenever it is used as a
comparison denominator, and pair it with the appropriate same-protocol
in-sweep control. Never silently treat monitor-on and monitor-off runs as
interchangeable, and never autonomously replace the historical baseline.

## 4. Ownership of the sweep method and dependency checkpoint

The Strategic Analyst owns the blueprint's sweep design, candidate ranges,
and hypotheses; the interpretation of `planning/dependency-graph/`; and the
dependency-checkpoint outcome—whether an earlier conclusion is fully
re-swept, lightly revalidated, or kept closed. Codex orchestrates and
validates approved execution only. Codex must not reopen a closed tuning
conclusion, select or promote a baseline, or automatically derive and launch a
revalidation from graph edges; it may execute only an explicitly prespecified
revalidation inside an approved task scope.

The multinode handoff follows `07-Workflow.md`: the Strategic Analyst drafts
the specification from `TASK-TEMPLATE.md`; the Human Leader reviews, modifies,
and approves the exact scope; and the approved content is materialized as a
synchronized `tasks/TASK-XXX.md` whose front matter records
`status: APPROVED` and `current_owner: codex` and whose
`### 1.11 Authorization` records `status: APPROVED`, `approved_by: user`,
and the exact approved scope. Codex decomposes the approved scope, delegates
substantive execution to OpenCode workers bounded by Codex and by the task,
validates evidence, and completes the Execution Report; successful completion
sets the task `EXECUTED` with `current_owner: strategic-analyst`. Only then
may the Human explicitly authorize `ANALYSE_RESULTS`, after which the
Strategic Analyst analyzes the raw evidence and performs the applicable
checkpoint. Exceptional incomplete tasks retain their accurate status and
next owner under `07-Workflow.md`.

After each blueprint phase or later-created communication/scheduling subgroup,
the dependency checkpoint is mandatory: the Strategic Analyst must ask whether
the human wants to perform the review or explicitly skip it. If performed,
record the earlier decision, the relevant edge IDs (`E##`), whether the
upstream change was material, the resulting
full-re-sweep/light-revalidation/keep-closed action, and the supporting
evidence. If skipped, record the skip and its scope. In both cases the
Strategic Analyst presents exactly one next-action recommendation and waits
for the human decision; a new bounded experiment requires a newly approved
task under `07-Workflow.md`, and an explicitly prespecified revalidation may
run only within an already approved task scope.

## 5. Authorization and failure boundaries

The blueprint proposes the next bounded experiment; it does not authorize it.
The Human Leader must approve the exact experiment scope, and that approval
must be materialized in the synchronized approved `tasks/TASK-XXX.md` before
submission. The general workflow's `ANALYSE_RESULTS` authorization is still
required before creating or updating analysis conclusions or `PLANS.md`.

Treat launcher, MPI/UCX, resource, node-placement, rank-mapping, and
container-environment changes as Track 2 decisions unless the user has given a
specific override. Preserve all output and record a manual-inspection case;
do not automatically retry a hang, failed `MPI_Init`, rank misplacement,
transport fallback, or uncertain correctness result.

Only deterministic defects in workflow machinery—such as a wrong path,
output filename, or missing designated directory—may use Track 1, with a new
attempt label and preserved evidence.

Respect the scientific-correctness exception in
`05-Workflow-Error-Patching-Procedures.md`: a completed run with failed,
non-finite, or otherwise invalid scientific correctness is preserved with no
self-patching, recorded accurately, and reported for investigation. It does
not by itself stop other approved work unless the active task requires it.
