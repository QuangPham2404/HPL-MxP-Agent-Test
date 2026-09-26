# Git and Two-Clone Synchronization Policy

This policy keeps the local PC clone and cluster clone synchronized. It
applies to workflow files, build/run scripts, planning, progress, metadata,
logs, and extracted results.

## Clone roles

- The local PC clone is the preferred place for preparing and reviewing files,
  committing, and pushing.
- The cluster contains a real Git clone at the approved remote project root.
- The cluster clone is used for remote builds and scheduler execution.
- Do not store GitHub credentials on the cluster.
- Do not use an untracked copy as the project clone.

## Startup and synchronization

Before starting work in either environment:

1. run `git status`;
2. run `git pull --ff-only` when synchronization is required;
3. inspect unexpected changes if needed;

Before Codex executes an approved task or remote execution after local script
changes:

1. prepare files locally;
2. inspect the relevant diff;
3. run appropriate validation;
4. commit reviewed changes when authorized;
5. push from the local PC when authorized;
6. pull with `git pull --ff-only` in the cluster clone;
7. verify the intended commit, task revision, and scripts are present
   remotely;
8. verify the explicitly identified task has `status: APPROVED` and
   `current_owner: codex` in front matter, and its Authorization section
   records `status: APPROVED`, `approved_by: user`, and an approved scope
   matching the user's instruction;
9. confirm that neither tree has unexpected changes, except documented
   generated output or explicitly preserved runtime artifacts.

Codex must not act on a stale Strategic Specification. If the intended task
revision is absent, the task is not approved, or the local and remote clones
disagree about the task, stop and synchronize or report the conflict.

For the Strategy → Execution handoff, the Human Leader approves the task and
authorizes its repository materialization. With authorized direct GitHub
access, the Strategic Analyst writes the approved task. Otherwise the Human
Leader writes it or authorizes a repository agent to copy the exact approved
content mechanically. The approved task must then be committed and pushed
under project Git policy before Codex pulls and executes it.

Never run stale local-only build, run, extraction, or planning scripts on the
cluster. They must reach the cluster through the reviewed Git synchronization.

## Before committing

- Run `git status`.
- Inspect the relevant diff and file list.
- Validate scripts and documentation as appropriate.
- Commit only reviewed and useful scripts, plans, progress notes, metadata,
  logs, and extracted results.
- Do not commit unrelated changes or raw temporary files.
- Preserve useful failure evidence when the workflow requires it.

## Divergence and unexpected changes

If `git pull --ff-only` fails because the clones diverged, stop and inspect the
difference. Do not create a merge commit automatically. Do not overwrite or
delete user changes. Report the conflicting state and wait for direction when
resolution requires judgment.

Pre-existing untracked runtime artifacts must be preserved and reported. Do not
delete them merely to make the repository appear clean.

## Remote synchronization rule

When Codex creates or updates build scripts, PBS scripts, run scripts,
extraction scripts, or planning files locally for remote execution, the
reviewed local changes must be committed and pushed before those scripts are
used remotely, when the project permissions require that sequence. The remote
clone must then run `git pull --ff-only` before submission.

Aspire2A-to-local result retrieval may use the project's documented output
retrieval workflow, but retrieved files must land in the matching local
project directories and retain their provenance.

After Codex completes the Execution Report in the active task:

1. validate the task file and referenced evidence;
2. commit and push when required and authorized by normal project policy;
3. ensure the Strategic Analyst can read the latest repository revision before
   analysis is authorized.
