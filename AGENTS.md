# Project Workflow Instructions

This project uses the reusable Codex HPC Optimization Workflow Pack v2 in
`workflow/`. The project-root `tasks/` directory is the persistent handoff
between the Strategic Analyst and Codex. `workflow_old/` preserves the previous
workflow; Workflow v2 governs new work.

## Additional notes

These two rules are active overrides: wherever they contradict any rule stated
below them (including queue/group references in older instructions), these
rules take precedence.

1. **Job submission group:** from now on, all scripts use `hpc_ebslee`
   instead of `hpc_admin` (PBS accounting group).
2. **Queue scope for node selection:** when selecting clean nodes based on
   user requirement, only the `gpu_as`, `gpu_ded`, and `gpu_free` queues are
   available to choose from. Every queue not in this list is off-limits.
   (Probe note, 2026-09-15: `gpu_free` is currently disabled; its successors
   `gpu_free_normal`/`gpu_free_high` serve the same single node `g25`.)

## Required startup reading

Before taking action, Codex must:

1. Read every numbered file in `workflow/` in numerical order.
2. Read `APPLICATION.md`.
3. Identify the active `tasks/TASK-XXX.md` explicitly; do not infer it from
   file modification time.
4. Read the approved task and the latest progress report under `progress/`.
   Verify front matter has `status: APPROVED` and `current_owner: codex`, and
   `### 1.11 Authorization` records `status: APPROVED`, `approved_by: user`,
   and the exact `approved_scope` before execution.
5. Check the project Git state according to `workflow/01-Git-Sync-Policy.md`.

For the `SETUP` command only, read `APPLICATION.md` if present; no active task
or progress report is required. Read the workflow pack, check Git state, and
inspect existing project guidance and configuration before following the
`SETUP` procedure in `workflow/07-Workflow.md`. No file changes are authorized
until the user confirms the final setup change set. After setup, the normal
approved-task startup requirement applies again.

## Roles and authority

### Human Leader

The Human Leader owns:

- strategic direction;
- approval;
- resource and risk decisions;
- final decisions;
- changes in optimization direction.

### Strategic Analyst

The Strategic Analyst is normally ChatGPT Web / Sol. The Strategic Analyst
owns:

- raw-evidence interpretation;
- quantitative and trend analysis;
- hypothesis generation and evaluation;
- causal reasoning;
- experiment design;
- Strategic Specification creation;
- strategic analysis under `planning/analysis/`;
- sweep design from `planning/blueprint/` and interpretation of
  `planning/dependency-graph/`, including dependency-checkpoint reopen
  decisions (full re-sweep, light revalidation, or keep closed) and the
  single next-action recommendation.

The Strategic Analyst drafts new tasks from `workflow/TASK-TEMPLATE.md` for
Human Leader review. With authorized direct GitHub access, it may write the
task after explicit human approval and write analysis after `ANALYSE_RESULTS`.
A conversation draft is only a proposal, not executable repository state.

The Strategic Analyst proposes actions but does not authorize its own proposal.
The Human Leader reviews, modifies, and explicitly approves the task. With
authorized GitHub access, the Strategic Analyst materializes the approved
`tasks/TASK-XXX.md` directly. Otherwise the Human Leader writes it manually
or authorizes a repository agent to copy the exact approved content. Human
approval and synchronized repository materialization are required before
Codex executes the approved scope.

### Codex Orchestrator

Codex is the operational orchestrator, not the strategic analyst. Codex:

- reads an approved task from the synchronized repository;
- decomposes execution work;
- manages subagents and workers;
- identifies parallel and dependent work;
- performs bounded follow-up orchestration;
- validates evidence operationally;
- verifies scope compliance;
- completes the `CODEX EXECUTION REPORT`.

For substantive task execution, Codex must delegate work to one or more
OpenCode workers through the project-approved OpenCode runtime. Codex may
directly perform orchestration, repository scaffolding, validation,
bookkeeping, and other trivial non-execution operations.

Codex must not:

- reconstruct or guess a Strategic Specification from conversation history;
- rewrite the Strategic Specification;
- change the strategic objective;
- infer campaign-level root cause;
- choose a new optimization direction;
- promote new baselines;
- reopen closed tuning conclusions through the dependency graph or
  automatically derive and launch revalidation sweeps from graph edges;
- perform the Strategic Analyst's role.

Codex may calculate mechanical derived values and state directly observed
facts, but strategic interpretation remains with the Strategic Analyst.

### Execution Workers

Execution workers are normally OpenCode / GLM. Workers may:

- probe;
- inspect;
- execute;
- test;
- modify only within explicitly approved scope;
- extract measurements;
- preserve and log raw evidence.

Workers may use local reasoning required to complete their task, but must not:

- perform campaign-level interpretation;
- recommend the next strategic action;
- expand scope;
- exceed Codex's authority.

> Worker authority may never exceed Codex authority, and Codex authority may never exceed the approved task scope.

> Codex communicates with workers through transient prompts/sessions. Per-worker task files and report files should not normally be created.

The workflow files are related and must all be read. Do not selectively route
only one workflow file based on the immediate task.

## Active project configuration

- Application: `HPL-MxP (NVIDIA container implementation: https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html)`
- Active cluster: `GAAS`
- Workflow pack path: `workflow/`
- Active task: identify the approved `tasks/TASK-XXX.md` explicitly before
  execution; no active task is selected by this migration.
- Application overview: `APPLICATION.md`
- Remote project root: also record and verify this in
  `workflow/00-General-SSH-Rules.md`: `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test`

Complete the cluster-specific placeholders in
`workflow/00-General-SSH-Rules.md` before remote work begins. That file is the
main operational source for SSH, authentication, remote scope, scheduler, and
execution rules. This file may repeat critical cluster details or add stricter
project-specific restrictions, but must not weaken the workflow pack.

## Task and project-specific automation permissions

An approved `tasks/TASK-XXX.md` defines the maximum execution scope for Codex
for that task. Project permissions must also define the actual command forms,
paths, and restrictions. Neither the reusable pack nor the task grants
authority beyond the approved scope and project instructions.

This section is intentionally explicit. The reusable workflow pack does not
grant project-specific command authorization; an action not listed here still
requires the user's direction and must satisfy the workflow pack.

List only commands explicitly authorized for this project here. Include
approved local commands, approved remote commands, command prefixes, paths,
and restrictions. Do not assume that routine authorization from another
project applies here.

Examples of information to define, only when approved:

- permitted Git commands and branch scope;
- permitted syntax checks and directory creation;
- permitted scheduler submission and bounded monitoring commands;
- permitted output retrieval commands;
- commands that always require user approval;
- commands that are prohibited.

Currently authorized for documentation/setup work:

- local read-only inspection with `pwd`, `rg`, `rg --files`, `sed`, `find`,
  `wc`, `git status`, `git log`, and `git diff`;
- local validation with `bash -n` for changed shell/PBS scripts and
  `git diff --check` for reviewed changes;
- creating designated project directories and documentation files locally;
- read-only GAAS connection verification with `ssh -O check gaas`; and
- non-interactive remote inspection only after the connection check, using
  `ssh -o BatchMode=yes gaas` and staying inside the approved remote project
  root.

For future execution, the following require explicit user authorization in the
current request: committing or pushing changes, remote `git pull`, module or
package changes, PBS submission, scheduler monitoring beyond a bounded check,
output retrieval, resource/launcher/transport changes, and any new tuning
direction. Remote work must use the exact rules in `workflow/00-General-SSH-Rules.md`
and the multinode gates in `workflow/08-Workflow-Multinode-Tuning.md`.

The workflow pack does not grant permission to install packages, modify shared
software, change source code, change resource policy, delete material, cancel
jobs, or start a new optimization direction. If finishing the active task
requires broader scope, Codex must stop and report the exact additional
authority required.

Experiment output policy:

- PBS stdout and stderr files produced by experiments, specifically `.o` and
  `.e` files under `experiments/*/outputs/`, are useful run evidence and must
  normally be tracked and pushed to GitHub with the corresponding experiment
  record.
- Preserve attempt-specific filenames; do not overwrite evidence from an
  earlier attempt.
- This policy applies to experiment outputs only. Do not commit unrelated
  temporary files or outputs outside the designated experiment directories.

## Application-specific instructions

Maintain `APPLICATION.md` as the application overview. Record the source URL
and exact revision, purpose, dependencies, build and run commands, important
inputs, expected output markers, correctness criteria, and baseline command.
Keep optimization plans and conclusions under `planning/`.

## Conflict and stop rule

If a rule conflicts, a placeholder is incomplete, the required authority is
missing, the active task is not approved, or an error requires judgment beyond
the documented automatic track, stop the affected workflow and report what
must be resolved. Preserve all available evidence. Strategic analysis begins
only after the human explicitly authorizes `ANALYSE_RESULTS`.

## Notes

For future optimization and scored comparison runs, use `--skip-tests 0` and
`--monitor-gpu 0`: the package's internal test phase stays enabled and the
benchmark's continuous GPU monitoring stays disabled. This supersedes the
earlier `--skip-tests 1` plus GPU-monitoring policy for future runs.
Diagnostic monitoring is permitted only as a separately labelled, justified,
and authorized condition; do not silently rank diagnostic monitor-on runs
against monitor-off scored runs. Phase-0 or pre/post-run hardware-health
evidence remains part of ordinary runs. Historical PBS scripts and recorded
evidence are unchanged.

For analysis step in the workflow, always include: (1) the baseline from the baseline run (the original baseline), and (2) the data tables must have a column to show the percentage increase compared to that baseline run

Update on some new directories that might not be mention in the workflow package and structural changes on the project repo
- `multi-node-test/` contains working model scripts for multinode launch of HPL, HPL-MxP, and HPCG. `multi-node-test/HPL-MxP` contains the script for launching multinode HPL-MxP
- `experiments/3Nodes-4GPUs` and `planning/analysis/3Nodes-4GPUs` are directories dedicated to run and analyse HPL-MxP on 3 Nodes - 4 GPUs topology. Use this 2 directories whenever the experiements are ran on 3 nodes - 4 GPUs.
- `experiments/3Nodes-4GPUs` is the canonical parent for new 3-node × 4-GPU
  run families; each run belongs in a child experiment directory with its own
  README, PBS script(s), and `outputs/`. Historical `experiments/3x4-*`
  directories are preserved. `planning/analysis/3Nodes-4GPUs` is the matching
  analysis area.
- `planning/blueprint` is the directory for the general sweeping methodology for HPL-MxP on any hardware topology.
- `planning/dependency-graph` details the dependency of flags with each other to help structure experiments and determine if resweeps are needed.
- `workflow/08-Workflow-Multinode-Tuning.md` is the project-specific GAAS
  HPL-MxP multinode operational adapter inside Workflow v2; it references the
  `workflow/07-Workflow.md` lifecycle and is not a second workflow.
  `workflow_old/` is entirely historical, including its copy of the previous
  multinode adapter.
- `scripts/gaas-internode-coms-debug/resource-alloc/` also hosts the
  single-node node-contention test (its "experiment 6"). Its planning and
  execution log live in `resource-alloc/SINGLE_NODE_TEST.md` — separate from
  the resource-alloc `README.md` experiment records by design, so sessions
  working on experiment 5 records and sessions working on the single-node
  test do not clash. Runner: `resource-alloc/debug-scripts/run_1n_contention.pbs`;
  evidence: `resource-alloc/outputs/sn200k_*`. Read
  `resource-alloc/SINGLE_NODE_TEST.md` and that directory's `AGENTS.md`
  before touching anything single-node.
