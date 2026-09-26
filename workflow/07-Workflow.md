# Workflow v2

This is the complete task-based operational sequence. Follow the current
task, the supporting rules in the other numbered workflow files, and the
project instructions. Do not skip evidence, validation, authorization, or
handoff requirements because a job exits zero.

The workflow wraps the proven HPC build, synchronization, execution, result
logging, correctness, provenance, and failure-handling rules in a layered
architecture:

```text
Strategic discussion
        ↓
Strategic Specification
        ↓
Human approval
        ↓
Codex orchestration
        ↓
existing build / sync / run / result logging mechanisms
        ↓
Codex Execution Report
        ↓
human authorizes analysis
        ↓
Strategic Analyst analyzes raw evidence
        ↓
planning/analysis/
        ↓
Human strategic decision
```

Codex is the operational orchestrator. It may decompose approved work,
coordinate bounded workers, and validate facts. It must not perform campaign-
level interpretation, choose a new optimization direction, rewrite the
Strategic Specification, or promote a new baseline.

## `SETUP`: repository initialization or adaptation

`SETUP` is the single onboarding command for a fresh or existing repository.
It is a narrow exception to active-task startup: read the complete workflow
pack, check Git state, and inspect available project guidance and configuration;
no `tasks/TASK-XXX.md` or progress report is required. Normal task-based
startup applies after setup.

1. Inspect the repository structure, documentation, Git changes, existing
   workflow files, and project-specific rules. In an existing project, include
   root `AGENTS.md` and `README.md`, directory READMEs that direct future
   work, `tasks/` guidance or templates, active `workflow/`, and obvious
   duplicate workflow copies such as `workflow_old/` or temporary migration
   backups. Classify the repository as fresh or existing and map its directories
   to Workflow v2 roles.
2. Prepare a concise proposal using `PRESERVE`, `ADAPT`, `ADD`, `REPLACE`, and
   `CONFLICT` where applicable. Explain each proposed change, uncertainties,
   and the important areas left untouched. For an existing project, reuse
   compatible structures, preserve historical evidence and stricter valid
   project rules, and surface conflicts with the Workflow v2 architecture or
   other consequential ambiguity. Use the canonical skeleton as a reference,
   not a reason to rearrange historical state. For a fresh project, propose
   only required elements and leave unknown project values as explicit
   placeholders. Classify historical documentation as `PRESERVE`, active stale
   guidance as `ADAPT`, and competing task formats or unnecessary migration
   residue as `CONFLICT` or candidates for removal. State that no files have
   been modified.
3. Wait for the user's review. If the user changes the proposal, revise it.
   When the user agrees, present one concise final summary of exactly what
   will change, explicitly identify important areas left untouched, and ask
   for final confirmation. Agreement with the proposal alone does not
   authorize edits; a clear final confirmation does, without a magic phrase.
4. Apply only the confirmed local setup changes. First ensure they will not
   overwrite unrelated user changes. Preserve project-specific rules and all
   historical artifacts. Do not create a task for historical work or start a
   first task unless separately requested. Do not execute scientific work,
   submit jobs, access the cluster, or perform strategic analysis. A read-only
   cluster configuration check requires specific user approval.
5. Inspect the complete diff, run `git diff --check`, and verify preserved areas
   remain unchanged. For an existing project, make one final consistency check
   of active guidance and control files: future-work ownership, directory
   descriptions, task format, and the identity of the active workflow must
   agree with Workflow v2. Report unresolved conflicts and do not declare
   setup complete while active guidance contradicts it. Historical progress,
   analysis, experiment READMEs, results, and PBS evidence remain preserved.
   Do not delete residue unless removal was in the final confirmed change set.
   Report the result and `git status`. Do not commit or push automatically;
   follow the existing Git policy and authorization.

## Task files and ownership

Each bounded strategic action uses one project-root task file:

```text
tasks/TASK-XXX.md
```

Create it from `workflow/TASK-TEMPLATE.md`, the sole reusable task template.
Retain its front matter and both numbered sections.

The task file contains only:

1. `STRATEGIC SPECIFICATION`, drafted by the Strategic Analyst, reviewed and
   approved by the Human Leader, then materialized by the Strategic Analyst
   when authorized or through the approved fallback;
2. `CODEX EXECUTION REPORT`, completed by Codex after execution.

The task file is the execution contract and operational history for that
bounded action. Raw evidence remains in canonical locations such as
`experiments/.../outputs/`, `results/metrics.csv`, `scripts/outputs/`, and
`profiling/`; the task references those paths rather than duplicating them.
Worker communication is transient. Per-worker task or report Markdown files
should not normally be created.

Use the task lifecycle where applicable:

```text
DRAFT → APPROVED → EXECUTING → EXECUTED → ANALYZED → CLOSED
```

The front-matter ownership mapping is:

| Status | `current_owner` |
| --- | --- |
| `DRAFT` | `strategic-analyst` |
| `APPROVED` | `codex` |
| `EXECUTING` | `codex` |
| `EXECUTED` | `strategic-analyst` |
| `ANALYZED` | `user` |
| `CLOSED` | `user` |

The Strategic Analyst drafts the task. Human approval moves `DRAFT` to
`APPROVED`. Codex moves it to `EXECUTING` when work starts, then to `EXECUTED`
only after operational validation and the Execution Report are complete. At
that handoff ownership moves to the Strategic Analyst. After authorized
analysis is complete and persisted, the Strategic Analyst moves `EXECUTED` to
`ANALYZED` and returns ownership to the user. The Human Leader may then close
the task or approve a new child task. Codex must not mark a task `ANALYZED`.
`BLOCKED` and `FAILED` remain valid exceptional states; set `current_owner` to
the actor who must act next.

## Step 1: Strategic Specification and human approval

The Human Leader and Strategic Analyst determine the bounded question or
action. The Strategic Analyst owns raw-evidence interpretation, quantitative
analysis, hypotheses, causal reasoning, experiment design, and creation of the
Strategic Specification. The Strategic Analyst proposes; it does not authorize
its own proposal.

The Strategic Analyst drafts a new task from `workflow/TASK-TEMPLATE.md`. The
`STRATEGIC SPECIFICATION` should identify:

- objective and required context;
- strategic question or hypotheses, where relevant;
- required evidence and deliverables;
- exact inputs and repository references;
- allowed and prohibited actions;
- execution constraints;
- success criteria for execution completeness;
- stop and escalation conditions;
- optional decomposition guidance;
- authorization and approved scope.

The Human Leader reviews, modifies, approves, or rejects the draft. After
explicit approval, the Strategic Analyst should materialize the approved task
directly in GitHub when authorized access exists. Otherwise the Human Leader
may write it manually or instruct Codex or another repository agent to copy
the exact approved content mechanically. A conversation draft is not
executable. The approved task is committed and pushed according to project Git
policy. Front matter records:

```yaml
status: APPROVED
current_owner: codex
```

`### 1.11 Authorization` separately records `status: APPROVED`, the exact
`approved_scope`, and `approved_by: user`. Direct GitHub access does not let
the Strategic Analyst approve its own proposal. A mechanical repository agent
must not reinterpret the content, expand scope, add strategic decisions, or
begin execution without separate authorization. The Authorization section
stays `APPROVED` as front-matter lifecycle status advances.

Codex must not reconstruct or guess a Strategic Specification from conversation
history. Before execution it verifies the identified task exists under
`tasks/` at the intended synchronized revision, front matter is `APPROVED`
with `current_owner: codex`, and the Authorization section records human
approval and the approved scope.

## Step 2: Codex orchestration and prepare build/run directories

Before execution, Codex reads the approved task and decomposes only the work inside its scope.

Codex is the operational orchestrator. It may directly perform the orchestration and repository-scaffolding work needed to coordinate execution, including:

- inspecting the approved task, repository state, existing artifacts, and relevant paths;
- deciding worker count, responsibilities, dependencies, ordering, and parallelism;
- determining the build/run/experiment directory and naming structure;
- creating the required local directory skeletons and output directories;
- establishing the files, evidence paths, and interfaces that workers will use;
- validating worker outputs, evidence, provenance, and scope compliance;
- performing simple bookkeeping or mechanical calculations needed for orchestration.

For **substantive task execution**, Codex must delegate work to one or more OpenCode workers through the project-approved OpenCode runtime. Codex decides how workers are used, but does not choose whether substantive execution uses workers.

Substantive execution includes, where applicable:

- writing or modifying build, run, PBS, probe, extraction, or task-specific execution scripts;
- inspecting systems or runtime behavior to obtain task evidence;
- executing approved local or remote commands;
- submitting and monitoring scheduler jobs;
- retrieving generated outputs;
- extracting measurements from raw evidence;
- performing task-specific tests or probes;
- making other substantive implementation changes explicitly permitted by the approved task.

Codex may perform a trivial operation directly when it is purely orchestration, validation, or bookkeeping. It must not use this exception to collapse a substantive task back into a single-agent workflow.

Independent worker tasks should run in parallel when safe. Dependent work remains sequential. Shared-file writes must be serialized; workers must not edit the same file concurrently.

Codex communicates with OpenCode workers through transient prompts or sessions. Worker instructions should state:

- the parent task;
- the bounded worker objective;
- relevant inputs and paths;
- allowed actions;
- prohibited actions;
- required factual return values;
- required evidence paths;
- applicable stop conditions.

Workers may probe, inspect, execute, test, write or modify explicitly approved task artifacts, extract measurements, and preserve raw evidence. They may use local reasoning necessary to complete their bounded assignment, but they must not perform campaign-level interpretation, recommend the next strategic action, promote a baseline, or expand task scope.

After each worker returns, Codex validates the relevant claims against repository state and raw evidence before relying on them. Codex may issue bounded follow-up worker assignments when additional operational evidence or correction is needed within the approved scope.

OpenCode worker invocation is part of the project execution workflow and is distinct from platform-native agent spawning or delegation features. A restriction on platform-native agent spawning does not by itself authorize Codex to replace the OpenCode execution layer with direct substantive execution.

### 2.1 Prepare builds

Use `builds/source/`, `builds/build-scripts/`, and
`builds/extra-packages/`. For a new application, inspect the cluster and
clone source there on the login node using the documented direct command before
writing build scripts, unless the application guide says an existing source
tree only needs a build directory. Do not clone application source into the
local workflow repository when project policy forbids that.

Locally create `builds/build-scripts/<build_name>/` with its README, build PBS
script, build shell script when needed, and `outputs/`. Use one stable
descriptive name. The README includes summary, compiler environment, compiler,
MPI compiler, optimization notes, metadata, and build error-patching records.
PBS stdout/stderr go directly to `outputs/`; keep every attempt.

Before remote use, review and validate locally, commit and push when required,
pull remotely, and ensure the remote output directory exists.

### 2.2 Prepare experiments

Create `experiments/<run_name>/` with README, run PBS script(s), and `outputs/`.
The README includes purpose, successful binary path, compiler environment,
compiler, MPI compiler, optimization notes, input/resource metadata, and
runtime error-patching records. Raw PBS outputs remain in `outputs/`; extracted
results go to `results/`.

Preparation must remain within the approved task scope. If a needed build,
experiment, source edit, resource change, launcher change, or package action
is not approved, stop and report the exact additional authority required.

## Step 3: Synchronize the two repositories and verify the active task

Check both clones according to `01-Git-Sync-Policy.md`. Before Codex executes:

1. synchronize the local repository according to normal policy;
2. verify the explicitly identified `tasks/TASK-XXX.md` revision is present
   locally and remotely as applicable;
3. verify front matter has `status: APPROVED` and `current_owner: codex`, and
   `### 1.11 Authorization` records `status: APPROVED`, `approved_by: user`,
   and the exact approved scope matching the user's instruction;
4. ensure Codex is not acting on a stale Strategic Specification;
5. verify reviewed scripts, application revision, and required metadata are
   the versions intended for execution.

Do not infer the active task from whichever file is newest. If fast-forward
synchronization fails, clones diverge, the task revision is stale, or the
approval state is unclear, stop and inspect or report the conflict rather than
merging, overwriting, or changing the task.

After these checks, Codex sets front matter to `status: EXECUTING` with
`current_owner: codex` immediately before the first approved execution action,
whether local, delegated, or on the cluster.

## Step 4: Execute approved work on the cluster

Submit only reviewed and approved build, run, or probe scripts through the
scheduler. Ensure output directories exist. Use new attempt labels and
filenames for retries. Within scope, Codex may issue bounded follow-up worker
tasks, perform mechanical checks, and coordinate independent work.

For every job record experiment/build ID, PBS job ID, submission and completion
timestamps, final state, exit status, allocated node, stdout/stderr paths,
compiler/MPI/module metadata, flags, inputs, resources, runtime, and output
validation.

Build success requires scheduler success, expected output files, and expected
executable presence. Run success requires scheduler success, expected output
files, normal application output, and application-specific correctness or
convergence criteria. Never classify success from exit status alone.

After a failure, classify it using
`05-Workflow-Error-Patching-Procedures.md`. Record the failed attempt before
any permitted patch or retry. Track 1 retries follow the build/experiment
README procedure. Track 2 stops the affected workflow and records
`MANUAL_INSPECTION_ERROR.md`; if it blocks the active task, Codex records the
blocked state in the task's Execution Report. Strategic interpretation of the
failure remains outside Codex's role.

If execution requires an action outside the approved task, Codex must stop.
It must not silently submit a job, change resources or launcher settings,
modify the scientific question, or start a new optimization direction.

## Step 5: Log results and complete the Codex Execution Report

At the end of build/run work, record results only. Do not perform optimization
analysis or update strategic planning conclusions in this step.

Use:

```text
results/
├── README.md
├── metrics.csv
├── RESULTS.md
└── scripts/
```

Before extraction, confirm expected experiment output and required fields are
present. `metrics.csv` is the structured source of truth. Preserve rows,
append attempts, reject duplicate `(experiment_id, attempt)` records, and
support failed/incomplete attempts when metadata permits. Keep raw `.o` and
`.e` provenance. Generate or update `RESULTS.md` from the CSV. Do not add
strategic interpretation to `planning/` during results logging.

After execution work or a blocking failure, Codex completes section 2 of the
same active task file using `workflow/TASK-TEMPLATE.md`.

The report records facts, completeness, provenance, operational validation,
and scope compliance. It must reference raw evidence rather than duplicate
large outputs. It must not rewrite the Strategic Specification or perform
strategic interpretation. If execution is partial, blocked, or failed, record
that state and the exact missing authority or evidence.

Codex should normally record:

- execution status: `COMPLETE`, `PARTIAL`, `BLOCKED`, or `FAILED`;
- worker count, responsibilities, parallel/sequential work, and follow-ups;
- factual work performed;
- requested evidence and run IDs verified;
- expected files, correctness criteria, and provenance checks;
- worker consistency and unresolved factual conflicts;
- evidence paths and commit identifiers;
- files changed, missing evidence, errors, and exceptions;
- whether the approved scope was respected;
- the information the Strategic Analyst needs before reading raw evidence.

After completing the report and operational validation, Codex sets front matter
to `status: EXECUTED` and `current_owner: strategic-analyst`. It validates the
task file and references, commits and pushes when required and authorized by
normal Git policy, and ensures the Strategic Analyst can read the latest
repository revision. The report is operational context, not the analytical
source of truth. Incomplete or failed work retains its accurate exceptional
status and next owner.

## Step 6: Analyze only with `ANALYSE_RESULTS`

Strategic analysis begins only with explicit human authorization:

```text
ANALYSE_RESULTS
analysis_id: <stable analysis name>
source: results/metrics.csv
include: <experiments, variants, or attempts to include>
grouping: <optimization direction or grouped tests>
scope: <current analysis | current session>
restrictions: <additional limits>
```

`ANALYSE_RESULTS` authorizes the Strategic Analyst to read the selected
evidence, create or update `planning/analysis/<analysis-id>.md`, update
`planning/PLANS.md` when applicable, update the task front matter after
completed analysis, and present analysis. With authorized direct GitHub access,
the Strategic Analyst writes these files directly. Otherwise the Human Leader
may materialize the Strategic Analyst's exact analysis and task metadata update
manually or authorize a repository agent to copy them mechanically. All writes follow
project Git policy; direct access does not grant self-approval of a new task.
`ANALYSE_RESULTS` does not authorize jobs, source changes, configuration
changes, or the next experiment.

If only `ANALYSE_RESULTS` is supplied, identify the available evidence and ask
which direction or group is in scope before writing a new analysis.

The Strategic Analyst reads, as applicable:

- the Strategic Specification;
- the Codex Execution Report;
- `results/metrics.csv` and `results/RESULTS.md`;
- raw experiment, probe, profiling, PBS, and build evidence;
- relevant prior analysis and repository context.

The Strategic Analyst should read raw evidence directly whenever practical,
rather than treating the Codex report as the analytical source of truth.
Analysis must preserve technical accuracy, provenance, correctness checks,
relevant failed or invalid data, uncertainty, baseline comparisons where
required, and a clear distinction between observation and inference. Do not
invent values or turn noisy evidence into a definitive conclusion.

Every new or substantially updated analysis file uses:

```markdown
---
task_id: TASK-XXX
title: <relevant title>
analysis_id: <stable analysis id>
status: COMPLETE
parent_task: <TASK-XXX | none>
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
---

# Analysis — <Title>

## 1. Summary

...

## 2. Analysis

...
```

The internal structure of `## 2. Analysis` is flexible. It may contain
quantitative comparisons, trends, hypothesis evaluation, causal reasoning,
alternative explanations, failed or inconclusive evidence, uncertainty,
technical implications, recommended next action, and provenance links.
One analysis may synthesize multiple tasks when scientifically appropriate.

Only after authorized analysis is completed and persisted is the Strategic
Analyst responsible for moving each task whose analysis is complete to
`status: ANALYZED` and `current_owner: user`, directly or through the approved
mechanical fallback. Make the latest revision available to the Human Leader.
Strategic conclusions stay in `planning/analysis/`, not the task file.

Use technically precise but human-readable engineering prose. Prefer direct
wording over unnecessarily dense academic or agent-style language. Use jargon
only when it improves precision. Never simplify away uncertainty.

`planning/PLANS.md` may retain its established three main sections:
`## Current baseline`, `## Optimization directions`, and `## Next direction`.
The suggested next action is a recommendation for Human Leader review, not
execution permission. A new strategic action normally creates a new task file
with `parent_task` linking it to the preceding task; do not silently redefine
the purpose of an existing task.

## Step 7: Human decision, session handoff, and resume

The Strategic Analyst presents findings, uncertainty, hypothesis status, and
any proposed next action. The Human Leader decides whether to close the issue,
create a new task, approve a controlled experiment, reopen a direction, or
stop the investigation. No agent autonomously changes the campaign direction,
promotes a baseline, or turns an analysis recommendation into execution
permission. A human decision to close the task sets `status: CLOSED` and
`current_owner: user`; a new strategic action normally gets a child task.

Before ending, write a dated
`progress/YYYY-MM-DD-progress[_sN].md` file. Include the active task and
status, current workflow step, completed work, decisions, build/experiment/
attempt IDs, PBS IDs, evidence paths, blockers, authorization state, and the
exact next action.

### Case 1: execution is incomplete

Preserve evidence and failed attempts. Record the current task, IDs, PBS job,
stdout/stderr, error or blocker, and manual-inspection case. State whether the
workflow awaits user action, external change, authorization, or a fix. Record
the exact resume action. Do not retry, patch, submit, change direction, or
widen scope without authorization. Validate, commit, and push the progress
record when normal Git policy applies, and synchronize before remote work
resumes.

### Case 2: analysis is complete

Record experiments, task and analysis IDs, findings, limitations, current
baseline, and next direction. Preserve historical evidence. Treat the
Strategic Analyst's proposed next action as a recommendation and wait for the
Human Leader's confirmation or modification before preparing the next task.
After approval of a new task, resume at Step 2; do not repeat Step 1 unless
this is a genuinely new application.
