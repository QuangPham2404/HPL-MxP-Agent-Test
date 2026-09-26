# Project Workflow Instructions

This project uses the reusable Codex HPC Optimization Workflow Pack v2 in
`workflow/`. The project-root `tasks/` directory is the persistent handoff
between the Strategic Analyst and Codex.

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
- strategic analysis under `planning/analysis/`.

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

- Application: `<application-name>`
- Active cluster: `<cluster-name>`
- Workflow pack path: `workflow/`
- Active task: `tasks/TASK-XXX.md` (identify explicitly before execution)
- Application overview: `APPLICATION.md`
- Remote project root: also record and verify this in
  `workflow/00-General-SSH-Rules.md`

Complete the cluster-specific placeholders in
`workflow/00-General-SSH-Rules.md` before remote work begins. That file is the
main operational source for SSH, authentication, remote scope, scheduler, and
execution rules. This file may repeat critical cluster details or add stricter
project-specific restrictions, but must not weaken the workflow pack.

## Task and project-specific automation permissions

An approved `tasks/TASK-XXX.md` defines the maximum execution scope for Codex
for that task. Project permissions must also define the actual command forms,
paths, and restrictions. Neither this example nor the reusable pack grants
authority beyond the approved task and project instructions.

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

The workflow pack does not grant permission to install packages, modify shared
software, change source code, change resource policy, delete material, cancel
jobs, or start a new optimization direction. If finishing the active task
requires broader scope, Codex must stop and report the exact additional
authority required.

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
