# Tasks

This directory is the persistent handoff between the Strategic Analyst and
Codex for new Workflow v2 work. No active task is selected by setup.

Create each new `TASK-XXX.md` from `../workflow/TASK-TEMPLATE.md`, retaining
its front matter, Strategic Specification, and Codex Execution Report.
Do not create retrospective tasks for historical experiments.

The Strategic Analyst drafts the specification; the user approves it before
repository materialization. Codex must not reconstruct a specification from
conversation history. Identify the active task explicitly, synchronize its
approved revision under the project Git policy, and verify before execution:

- Front matter: `status: APPROVED` for a fresh start or `status: EXECUTING`
  for resume, with `current_owner: codex` in either case.
- Section 1.11: `status: APPROVED`, `approved_by: user`, and the exact
  `approved_scope` matching the authorized work.

Section 1.11 is durable human permission; front matter describes progress.
`EXECUTING / codex` may span sessions without reapproval of unchanged scope.
Recoverable Track 1 mechanics keep that state; `BLOCKED / user` means genuine
human/external action or new authorization is required.

Follow `../workflow/07-Workflow.md` for lifecycle and ownership transitions.
Codex completes section 2 with operational facts and evidence references;
strategic analysis belongs to the Strategic Analyst under
`../planning/analysis/` after explicit `ANALYSE_RESULTS` authorization.
Raw evidence remains in its canonical directories. Worker communication is
transient; do not normally create per-worker task or report files.
