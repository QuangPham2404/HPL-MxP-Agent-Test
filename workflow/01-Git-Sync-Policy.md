# Git and Execution-Tree Synchronization Policy

This policy keeps reviewed local repository state and the cluster execution
tree synchronized. It applies to workflow files, scripts, planning, progress,
metadata, logs, and extracted results.

## Clone roles

- Prepare, review, commit, and push in the local PC clone when authorized.
- The cluster has a real Git clone at the approved remote project root.
  Use that primary clone or an isolated Git worktree beneath it for execution.
- Do not store GitHub credentials on the cluster or substitute an untracked
  copy for a verified Git execution tree.

## Startup and synchronization

1. Inspect local `git status` and the relevant diff; preserve unrelated changes.
2. Synchronize locally with `git pull --ff-only` only when safe and required.
3. Identify the active task explicitly. Accept `APPROVED / codex` for a fresh
   start or `EXECUTING / codex` for resume. Both require Section 1.11 to retain
   `status: APPROVED`, `approved_by: user`, and the unchanged approved scope.
4. Review and validate execution files locally, then commit and push when
   authorized before remote use. A conversation draft is not executable.
5. Connect with direct SSH under `00-General-SSH-Rules.md`; inspect the primary
   cluster clone revision (`git rev-parse HEAD`) and `git status` before choosing
   one of the modes below.
6. Identify the exact intended commit from fetched `origin/main`, matching the
   approved local/origin task and reviewed scripts. Record its full SHA; do not
   execute a stale specification or blindly select an unrelated newer revision.
7. Verify that exact commit, task, scripts, and required metadata in the
   **execution tree actually being used**. Record its absolute path and SHA.

Human approval and authorized repository materialization precede execution.
The Strategic Analyst may materialize approved content with authorized GitHub
access; otherwise the Human Leader or an authorized mechanical agent does so.
Never run stale local-only scripts on the cluster.

## Mode A — clean primary cluster clone

If status and history show the primary clone is sufficiently clean for safe
fast-forward synchronization, use `git fetch origin` and `git pull --ff-only`
as appropriate. Verify the intended commit and approved task before executing
from the normal project root. Never merge automatically.

## Mode B — dirty primary cluster clone

Tracked modifications, untracked artifacts, or other pre-existing state making
pull unsafe are normally informational conditions, not execution blockers.
The normal automated fallback is a clean isolated Git worktree:

1. Record the primary clone's full revision and `git status`, including existing
   tracked changes and untracked artifacts.
2. Leave all primary working-tree content completely untouched. Do not pull
   over it, reset, clean, stash/pop, delete, overwrite, or merge automatically.
3. Run non-destructive `git fetch origin` from the primary clone. Fetch updates
   repository refs/objects, not the primary checkout or its existing content.
4. Resolve the exact intended approved `origin/main` commit as above.
5. Inspect `git worktree list` and create a detached clean worktree beneath the
   approved project root, for example:

   ```bash
   git worktree add --detach .codex-worktrees/TASK-XXX-<shortsha> <exact-approved-origin-commit>
   ```

6. Verify its HEAD, clean status, exact approved task content, required scripts,
   and unchanged Authorization. Execute the already-approved work there.
7. Keep the dirty primary checkout and all its existing content untouched.

`.codex-worktrees/` is ignored runtime infrastructure. Use its absolute path
consistently for PBS working directories, scripts, launch bridges, outputs,
and retrieval; preserve evidence and its provenance in the matching canonical
local directories. Do not silently use stale files from the primary checkout.
Remote execution need not create Git history in the detached worktree.

### Existing worktrees

Reuse a suitable clean task worktree only at the exact intended revision, after
verification. If it contains uncommitted evidence or changes, preserve it and
create a new uniquely named clean worktree (for example with an attempt suffix).
Never reset, clean, remove, or overwrite an existing task worktree to retry.
A pre-existing destination is not permission to replace its contents.

## Recovery and actual conflicts

Missing optional SSH reuse, stale checkouts recoverable by fetch, and dirty
primary checkouts recoverable by isolation are Track 1 operational recovery.
Keep an already-started task `EXECUTING / codex`, record evidence, and continue
within existing authority. No reset, clean, or stash is required.

Stop the affected action when the intended revision cannot be fetched or
identified, history has genuinely diverged in a way affecting the task,
required task content differs between approved local/origin state, safe
worktree creation fails without documented recovery, or resolution would
require overwriting/deleting user data. Inspect non-destructively first;
`BLOCKED / user` is reserved for missing authority, human judgment,
authentication, or other required external action. Divergence confined to the
unused primary branch does not alone prevent an exact approved origin worktree.
Never create a merge commit or resolve content conflicts automatically.

## Before committing and after execution

- Inspect `git status`, the complete relevant diff, and file list.
- Validate scripts/documentation and referenced evidence as appropriate.
- Commit only reviewed useful project files and required attempt evidence;
  exclude unrelated changes and temporary artifacts.
- Preserve useful failure evidence and attempt-specific output names.
- After the Execution Report, validate its references, commit/push when
  authorized, and make the latest revision available for authorized analysis.

## Remote synchronization rule

Reviewed execution changes must be committed and pushed before remote use
when project policy requires it. Synchronize using Mode A or Mode B and verify
the actual execution tree before submission. Retrieve results only under task
and project permission, into matching local directories with provenance.
