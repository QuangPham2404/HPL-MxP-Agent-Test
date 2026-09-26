# Workflow Automation and Authorization

This file defines the reusable authorization boundaries. It does not grant
project-specific permissions. The active project's root `AGENTS.md` must list
any specially authorized commands, prefixes, paths, and restrictions.

An approved `tasks/TASK-XXX.md` defines the maximum execution scope for Codex
for that task. The Strategic Analyst proposes the task, the Human Leader
explicitly approves it, and the Strategic Analyst may materialize the approved
content directly in GitHub when authorized. Otherwise the Human Leader or a
mechanical repository agent writes the exact approved content. Codex executes
only the synchronized repository state and scope; it must not reconstruct or
guess a Strategic Specification from conversation history. Direct write access
never grants the Strategic Analyst authority to approve its own proposal.

Before execution, verify task front matter has `status: APPROVED` and
`current_owner: codex`, and `### 1.11 Authorization` records
`status: APPROVED`, `approved_by: user`, and the exact `approved_scope`.
Git writes remain subject to project policy and explicit human authorization.

## `SETUP` authority

`SETUP` authorizes repository and Git inspection and a setup proposal only.
It does not authorize creating, editing, moving, renaming, or deleting files.
After the user agrees with the proposal, Codex presents the exact final change
set, states important areas that will remain untouched, and asks for final
confirmation. Only clear final confirmation authorizes those local setup
changes; revisions to the plan require another review and confirmation.

`SETUP` does not authorize scientific or task execution, cluster jobs,
strategic analysis, or commit/push. Existing project Git policy still governs
commit and push.

## Actions normally within routine workflow scope

Within the approved task scope, and when permitted by the project `AGENTS.md`,
Codex may autonomously:

- decompose the work;
- select the number of workers;
- identify dependencies and run independent work in parallel;
- issue bounded follow-up worker tasks;
- perform operational validation;
- calculate mechanical derived values;
- inspect and organize evidence;
- perform the routine Git, syntax-check, directory, PBS, scheduler, and output
  retrieval actions already permitted by project policy.

The project instructions must define the actual command forms and approved
prefixes. Do not infer that permission from this reusable pack alone.

## Actions outside autonomous Codex authority

Codex may not autonomously:

- expand the allowed command or action set;
- submit additional jobs not approved by the task;
- change resource, launcher, or transport configuration unless approved;
- change the scientific question;
- begin a new optimization direction;
- perform strategic interpretation.

If any of these is required, stop and report the exact additional authority.

## Actions requiring explicit permission or user direction

Stop and request direction before:

- source-code changes;
- optimization decisions or changed experiment priorities;
- compiler, MPI, module, package, or build-strategy changes;
- changed resource requests or launcher strategy;
- package installation or shared-software changes;
- destructive actions, deletion, overwrite, or job cancellation;
- unrelated external coordination;
- pushing when the project policy requires explicit approval;
- starting a new optimization direction after analysis;
- applying a Track 2 fix without a matching override.

The project `AGENTS.md` may be stricter. It must not weaken universal safety
rules in this pack.

## Authority inheritance

Authority narrows at each layer:

```text
Human-approved task scope
        ↓
Codex authority
        ↓
Worker authority
```

Worker authority may never exceed Codex authority, and Codex authority may never
exceed the approved task scope. Codex communicates with workers through
transient prompts or sessions; per-worker task and report files should not
normally be created.

## Authorization scope

Authorization is limited to the named project, cluster scope, current task,
and explicit files or commands. An authorization for one workflow step does
not authorize another step. `ANALYSE_RESULTS` authorizes analysis and its
`EXECUTED` → `ANALYZED` task handoff only; it does not authorize jobs, source
changes, build/run configuration changes, or the next experiment.
`OVERRID_AUTO_PATCH` authorizes only its named error class,
action, scope, and restrictions.

Never treat a recommendation, progress note, analysis conclusion, or proposed
fix as authorization. If finishing a task requires broader scope, Codex must
stop and report exactly which additional action, command, resource, or
configuration authority is required.
