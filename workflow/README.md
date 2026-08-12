# Codex HPC Optimization Workflow Pack

## What this package is

This directory is a reusable workflow pack for Codex-assisted optimization of
applications on HPC clusters. It defines the repository structure, safe remote
execution rules, Git synchronization policy, build and experiment lifecycle,
probing rules, error handling, result logging, analysis, and session handoff.

The pack is intentionally written as a project-adaptation template. It is
based on the tested LULESH workflow, but application facts, cluster facts,
resource syntax, compiler environments, launcher behavior, correctness
criteria, and project-specific permissions must be adapted for each project.

## Mandatory reading and precedence

When this package is active in a project, Codex must read every numbered file
in this directory in numerical order before taking workflow action. The files
are deliberately related; do not selectively task-route them or assume that
one file is sufficient.

Read in this order:

1. `00-General-SSH-Rules.md`
2. `01-Git-Sync-Policy.md`
3. `02-Repo-Structure.md`
4. `03-Workflow-General-Notes.md`
5. `04-Workflow-Probing-Scripts-Rules.md`
6. `05-Workflow-Error-Patching-Procedures.md`
7. `06-Workflow-Automation-and-Authorization.md`
8. `07-Workflow.md`

Also read the project root `AGENTS.md`, `APPLICATION.md`, and the latest
progress report before acting. The project `AGENTS.md` identifies the active
application, cluster, project-specific permissions, and any exceptions.

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

### Starting a new project

1. Clone or copy this package into the new project repository.
2. Copy or adapt `AGENTS_EXAMPLE.md` into the project root as `AGENTS.md`.
3. Read every numbered workflow file in this directory in order.
4. Edit the clearly marked placeholders in
   `00-General-SSH-Rules.md` for the target cluster.
5. Add the application-specific `APPLICATION.md`.
6. Add project-specific automation permissions and approved command prefixes
   to the project root `AGENTS.md`.
7. Ask Codex to initialize or validate the repository skeleton described in
   `02-Repo-Structure.md`.
8. Review the adapted instructions before any remote execution.

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

For every session, Codex should read the complete pack, inspect the latest
progress report, identify the current workflow step, and follow `07-Workflow.md`.
The pack is not permission to submit jobs, change source code, install
packages, modify shared software, change resources, or choose an optimization
direction. Those actions require the permissions described in the project
instructions and the applicable workflow step.

## Package files

- `AGENTS_EXAMPLE.md`: example project-root instructions that activate this
  pack without modifying an existing project `AGENTS.md`.
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
  boundaries and project-specific permission handoff.
- `07-Workflow.md`: the complete Step 1 through Step 7 workflow.
- `clusters/`: optional cluster reference material, not mandatory reading.
