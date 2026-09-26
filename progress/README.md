# Progress and Session Handoffs

Write session handoffs as `YYYY-MM-DD-progress.md`, using an unused `_sN`
suffix for additional sessions on the same date. Preserve earlier records.

Record the explicitly identified task and its status, workflow step,
completed work, user decisions, authorization scope, build/experiment/attempt
IDs, PBS IDs, evidence paths, blockers, and the exact next action. For setup,
record that no active task was selected; an execution task is not required.
Follow `../workflow/07-Workflow.md` and the project Git policy.

Historical progress reports are evidence, not approval for new work. A
recommendation or resume note does not authorize submission, scope expansion,
or a new optimization direction.

## Setup review — 2026-09-26

The user approved documentation setup and GitHub push, with the blueprint and
dependency graph explicitly excluded. No task or cluster work is authorized
by this setup. New task selection remains a separate handoff.

Unresolved guidance conflicts preserved at the user's request:

- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md` references the absent
  `workflow/08-Workflow-Multinode-Tuning.md`; the required adapter remains at
  `workflow_old/08-Workflow-Multinode-Tuning.md`.
- The blueprint and dependency-graph README describe `--skip-tests 0` and
  `--monitor-gpu 0` for scored runs. Root `AGENTS.md` requires
  `--skip-tests 1` and GPU monitoring with interval 10, PCIe width warning 16,
  and PCIe generation warning 5. Root instructions take precedence.

Resolve these documentation conflicts only when the user authorizes edits to
those areas. Setup does not certify the excluded guidance as consistent.

## Resolution — 2026-09-26

The user authorized a bounded documentation reconciliation that resolves both
conflicts recorded above:

- The GAAS/HPL-MxP multinode adapter now lives at
  `workflow/08-Workflow-Multinode-Tuning.md` as a project-specific numbered
  file alongside the general workflow `00`–`07`. `workflow_old/` is entirely
  historical, including its copy of `08`.
- For future optimization and scored comparison runs, the user supersedes the
  earlier root test/monitor policy: use `--skip-tests 0 --monitor-gpu 0`
  (internal tests enabled, continuous GPU monitoring disabled). Diagnostic
  monitoring is permitted only as a separately labelled, justified, and
  authorized condition and is not silently ranked against monitor-off scored
  runs. Phase-0 or pre/post-run hardware-health evidence remains part of
  ordinary runs. Historical PBS scripts and recorded evidence are unchanged.

Ownership was resolved in the same reconciliation: the Strategic Analyst owns
the blueprint and dependency-graph interpretation, the dependency-checkpoint
reopen decisions (full re-sweep, light revalidation, keep closed), and the
single next-action recommendation; Codex orchestrates approved task
execution, validates evidence operationally, and cannot reopen closed tuning
conclusions, promote baselines, or derive revalidation sweeps from graph
edges on its own. The historical prior-policy original baseline
`3x4-baseline_v1` remains immutable; any protocol mismatch against it must be
disclosed and paired with an appropriate same-protocol in-sweep control. No
optimization task was created and no cluster work was authorized by this
reconciliation.
