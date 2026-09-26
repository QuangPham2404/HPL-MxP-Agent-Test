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
3. inspect unexpected changes;
4. stop if fast-forward synchronization fails or the clones diverge.

Before remote execution after local script changes:

1. prepare files locally;
2. inspect the relevant diff;
3. run appropriate validation;
4. commit reviewed changes when authorized;
5. push from the local PC when authorized;
6. pull with `git pull --ff-only` in the cluster clone;
7. verify the intended commit and scripts are present remotely;
8. confirm that neither tree has unexpected changes, except documented
   generated output or explicitly preserved runtime artifacts.

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
