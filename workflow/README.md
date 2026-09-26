# Codex HPC Optimization Workflow Pack v2

## What this package is

This directory is the v2 reusable workflow pack for agentic optimization of
applications on HPC clusters. It defines the repository structure, safe remote
execution rules, Git synchronization policy, task-based handoff, Codex
orchestration, build and experiment lifecycle, probing rules, error handling,
result logging, strategic analysis, and session handoff.

The pack is intentionally written as a project-adaptation template. It is
based on the tested LULESH workflow, but application facts, cluster facts,
resource syntax, compiler environments, launcher behavior, correctness
criteria, and project-specific permissions must be adapted for each project.
The v2 architecture keeps the proven HPC execution safeguards while separating
strategic analysis from bounded execution.

The operating model is:

```text
Human Leader ↔ Strategic Analyst
                    │ draft task content
                    ▼
              Human review / approval
                    │ Strategic Analyst writes directly when authorized;
                    │ otherwise approved fallback materializes
                    │ commit, push under Git policy
                    ▼
              tasks/TASK-XXX.md
                    ▼
              Codex Orchestrator
                    ↕
              execution workers
                    ▼
           Codex operational validation
                    ▼
              Codex Execution Report
                    ▼
             human-authorized analysis
                    ▼
              Strategic Analyst → Human decision
```

## Mandatory reading and precedence

When this package is active in a project, Codex must read every numbered file
in this directory in numerical order before taking workflow action. The files
are deliberately related; do not selectively task-route them or assume that
one file is sufficient. For normal execution, the active task must also be
explicitly identified; Codex must not infer it from file modification time.
`SETUP` is the exception before an active task exists.

Read in this order:

1. `00-General-SSH-Rules.md`
2. `01-Git-Sync-Policy.md`
3. `02-Repo-Structure.md`
4. `03-Workflow-General-Notes.md`
5. `04-Workflow-Probing-Scripts-Rules.md`
6. `05-Workflow-Error-Patching-Procedures.md`
7. `06-Workflow-Automation-and-Authorization.md`
8. `07-Workflow.md`
9. `08-Workflow-Multinode-Tuning.md`

Files `00`–`07` are the general reusable workflow. `08-Workflow-Multinode-Tuning.md`
is different: it is the project-specific GAAS HPL-MxP multinode operational
adapter, added as a numbered file for this project. It extends, and does not
replace, the `07-Workflow.md` lifecycle.

For normal execution, also read the project root `AGENTS.md`, `APPLICATION.md`,
the approved `tasks/TASK-XXX.md`, and the latest progress report. During
`SETUP`, inspect whichever project guidance and configuration files exist.
The project `AGENTS.md` identifies the active application, cluster,
project-specific permissions, and any exceptions.

Instruction precedence is:

1. User request and explicit authorization;
2. project root `AGENTS.md`;
3. this workflow pack;
4. application documentation such as `APPLICATION.md`;
5. repository README files;
6. historical progress and analysis notes.

If instructions conflict or an authority boundary is unclear, stop and report
the conflict before taking the affected action.

## User guide

### Setting up a fresh or existing project

Make this package available to Codex. If an existing root `AGENTS.md` predates
v2, follow the bootstrap below first. Then ask Codex from the project
repository:

```text
SETUP
```

Codex inspects the repository and proposes the minimum setup, including adding
`workflow/` if needed. A fresh project may use the canonical skeleton in
`02-Repo-Structure.md`; an existing project reuses compatible structures and
preserves historical work. Review the proposal, then give final confirmation
after Codex summarizes the exact change set. The command alone is read-only.
The authoritative procedure is in `07-Workflow.md` under `SETUP`.

For a fresh project without meaningful root instructions, copy or adapt
`AGENTS_EXAMPLE.md` as root `AGENTS.md` before normal task execution. New task
files come from `TASK-TEMPLATE.md`, not a project-invented format.

For an existing project whose root `AGENTS.md` predates v2, first bootstrap
the active instructions:

1. Install or make this package available as the project's `workflow/`.
2. With human approval, surgically adapt the existing root `AGENTS.md` against
   `workflow/AGENTS_EXAMPLE.md`. Preserve project-specific cluster, SSH,
   scheduler, Git, safety, application, and stricter operational rules; replace
   only obsolete architecture, role, and startup logic. Do not overwrite the
   mature file with the generic example.
3. Restart or reload Codex so the updated `AGENTS.md` is read from session
   start, then invoke `SETUP`.

`SETUP` then performs the normal repository-wide proposal and confirmation
procedure, including a final check for conflicting active guidance and
migration residue.

Do not begin cluster work until all placeholders in
`00-General-SSH-Rules.md` have been replaced and the SSH, remote-root,
scheduler, launcher, authentication, and resource rules have been reviewed.

### Adapting the cluster rules

`00-General-SSH-Rules.md` contains universal safety rules plus a clearly
marked cluster-configuration section. The universal rules must be preserved.
The configuration section must be completed for the new cluster, including
the SSH alias or connection method, connection check, required non-interactive
SSH/SCP/rsync forms, remote project root, scheduler, launcher, module policy,
login-node policy, and compute-node policy.

The project `AGENTS.md` may repeat the active cluster name, remote root, or
other especially important details, but the complete SSH and remote-execution
policy belongs in `00-General-SSH-Rules.md`. Keep one authoritative operational
copy instead of allowing duplicated rules to drift.

The optional `clusters/` directory contains reference material only. Codex
does not need to read it as part of the mandatory workflow-pack reading pass.
The active cluster configuration in `00-General-SSH-Rules.md` and any explicit
project `AGENTS.md` instructions are authoritative.

### Adapting the application

The workflow pack is universal in structure, not in application details. Each
project must document its application in `APPLICATION.md`, including its
source repository and revision, purpose, dependencies, build commands, run
commands, input parameters, expected output, correctness criteria, and
baseline command.

Do not put optimization conclusions in `APPLICATION.md`; put them in
`planning/`. Do not silently assume that LULESH fields, flags, executables,
launchers, or acceptance criteria apply to another application.

### Project-specific automation authorization

The reusable pack defines authorization boundaries and required safety
behavior, but it does not define special command permissions for a project.
Those permissions belong in the project root `AGENTS.md`. Include only reviewed
commands within the project and approved cluster scope. Do not copy broad or
unrelated permissions into a new project.

### Normal use

After setup, for every execution session the Human Leader or approved
automation must identify the active task. Codex should read the complete pack,
verify that task's status is permitted for execution, inspect the latest
progress report, and follow `07-Workflow.md`. Codex may orchestrate and
validate work within that approved task, but it is not the Strategic Analyst
and may not choose a new optimization direction. The pack is not permission to
submit jobs, change source code,
install packages, modify shared software, change resources, or expand task
scope. Those actions require the permissions described in the project
instructions and the applicable task.

## Package files

- `AGENTS_EXAMPLE.md`: example project-root instructions that activate this
  pack; adapt an existing project `AGENTS.md` surgically.
- `TASK-TEMPLATE.md`: the sole canonical template for new task files.
- `00-General-SSH-Rules.md`: universal safe SSH/execution policy and cluster
  adaptation placeholders.
- `01-Git-Sync-Policy.md`: local/cluster clone synchronization and Git rules.
- `02-Repo-Structure.md`: repository skeleton, directory roles, and templates.
- `03-Workflow-General-Notes.md`: naming, script, PBS, preflight, and metadata
  conventions.
- `04-Workflow-Probing-Scripts-Rules.md`: read-only probe rules.
- `05-Workflow-Error-Patching-Procedures.md`: Track 1, Track 2, correctness
  exceptions, and override handling.
- `06-Workflow-Automation-and-Authorization.md`: routine authorization
  boundaries, task-scope inheritance, and project-specific permission handoff.
- `07-Workflow.md`: the complete task-based Step 1 through Step 7 workflow.
- `08-Workflow-Multinode-Tuning.md`: project-specific GAAS multinode HPL-MxP
  operational adapter. Unlike the general files `00`–`07`, this is active
  project guidance rather than reusable template content; it references the
  `07-Workflow.md` lifecycle and is not a second workflow.
- `clusters/`: optional cluster reference material, not mandatory reading.

Task files are persistent project-root handoffs between the Strategic Analyst
and Codex. They contain the Strategic Specification and the Codex Execution
Report. Raw evidence remains in the canonical project locations, and strategic
analysis remains under `planning/analysis/`; neither is duplicated in the task
file. After human approval, the Strategic Analyst may write the task directly
in GitHub when authorized; otherwise the Human Leader or a mechanical
repository agent materializes the exact approved content. After
`ANALYSE_RESULTS`, the Strategic Analyst may directly write the analysis and
applicable `planning/PLANS.md` update under project Git policy. Codex executes
only synchronized, approved repository state.
