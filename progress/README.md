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
