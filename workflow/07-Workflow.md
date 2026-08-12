# Workflow

This is the complete operational sequence. Follow the current step and the
supporting rules in the other numbered workflow files. Do not skip evidence,
validation, authorization, or handoff requirements because a job exits zero.

## Step 1: Initial Planning

At the start of work on a new application, create the root `APPLICATION.md`.
If it exists, review and update it without recreating or overwriting it.

`APPLICATION.md` is strictly an application overview, not an optimization
plan. It must contain the application repository link and exact source
revision/tag, what the application does, correctness metrics, dependencies,
key build commands, key run commands, important input flags, expected output
markers, baseline command, and expected baseline correctness/output markers.

Prepare Step 1 documentation locally, then review, commit, and synchronize it
before remote build or run execution. Optimization decisions and priorities
belong in `planning/`.

## Step 2: Prepare build and run directories

Prepare workflow files locally first. Remote inspection may inform scripts, but
do not edit the repository directly on the cluster when local preparation is
required.

### 2.1 Prepare builds

Use `builds/source/`, `builds/build-scripts/`, and `builds/extra-packages/`.
For a new application, inspect the cluster and clone source there on the login
node using the documented direct command before writing build scripts, unless
the application guide says an existing source tree only needs a build
directory. Do not clone the application source into the local workflow repo
when the project policy forbids that.

Then locally create `builds/build-scripts/<build_name>/` with its README,
build PBS script, build shell script when needed, and `outputs/`. Use one
stable descriptive name. The README includes summary, compiler environment,
compiler, MPI compiler, optimization notes, metadata, and build error-patching
records. PBS stdout/stderr go directly to `outputs/`; keep every attempt.

Before remote use, review and validate locally, commit and push when required,
pull remotely, and ensure the remote output directory exists.

### 2.2 Prepare experiments

Create `experiments/<run_name>/` with README, run PBS script(s), and `outputs/`.
The README includes purpose, successful binary path, compiler environment,
compiler, MPI compiler, optimization notes, input/resource metadata, and
runtime error-patching records. Raw PBS outputs remain in `outputs/`; extracted
results go to `results/`.

## Step 3: Synchronize the two repositories

Check both clones. After local script changes are pushed, run remote
`git pull --ff-only`. Continue only when the intended commit is present in
both clones and there are no unexpected changes, apart from documented output
artifacts. Verify the submitted scripts and source revision are the reviewed
versions. If fast-forward synchronization fails or clones diverge, stop and
inspect rather than merging or overwriting.

## Step 4: Execute builds and runs on the cluster

Submit reviewed build and run scripts through the scheduler. Ensure output
directories exist. Use new attempt labels and filenames for retries.

For every job record experiment/build ID, PBS job ID, submission and completion
timestamps, final state, exit status, allocated node, stdout/stderr paths,
compiler/MPI/module metadata, flags, inputs, resources, runtime, and output
validation.

Build success requires scheduler success, expected output files, and expected
executable presence. Run success requires scheduler success, expected output
files, normal application output, and application-specific correctness or
convergence criteria. Never classify success from exit status alone.

After a failure, classify it using `05-Workflow-Error-Patching-Procedures.md`.
Record the failed attempt before any permitted patch or retry. Track 1 retries
follow the build/experiment README procedure; Track 2 stops the affected
workflow and records `MANUAL_INSPECTION_ERROR.md`.

## Step 5: Log results

At the end of build/run work, record results only. Do not perform optimization
analysis or update planning conclusions in this step.

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
interpretation to `planning/` during results logging.

The result schema is application- and experiment-specific. Before a new sweep,
decide required columns, units, and semantics with the user and document the
decision in `results/README.md`. Compatible runs may proceed automatically;
pause when new columns or semantics are needed.

## Step 6: Analyze only with `ANALYSE_RESULTS`

Analysis begins only with explicit user authorization:

```text
ANALYSE_RESULTS
analysis_id: <stable analysis name>
source: results/metrics.csv
include: <experiments, variants, or attempts to include>
grouping: <optimization direction or grouped tests>
scope: <current analysis | current session>
restrictions: <additional limits>
```

The ID is stable lowercase kebab-case. If only `ANALYSE_RESULTS` is supplied,
inspect available results and ask which direction or group to analyze before
writing a new file. The command authorizes reading selected results, creating
or updating `planning/analysis/<analysis-id>.md`, updating `planning/PLANS.md`,
and presenting analysis. It does not authorize jobs, source changes,
configuration changes, optimization decisions, or the next experiment.

Use:

```text
planning/
├── README.md
├── PLANS.md
└── analysis/
    └── <analysis-id>.md
```

`PLANS.md` has exactly three main sections: `## Current baseline`,
`## Optimization directions`, and `## Next direction`. The optimization table
contains Direction, Analysis ID/file, Analysis date, Scope, Status, Main
finding, and Suggested follow-up. Preserve analysis history and links.

Analysis files must identify summary, scope/evaluation criteria, data and
analysis, insights, suggested next section, and provenance. Use
`results/metrics.csv` as numeric truth, retain experiment/attempt provenance,
include relevant failed or invalid results, do not invent missing values, and
check correctness before ranking performance. The suggested next section is a
recommendation for user review, not execution permission.

## Step 7: End the session and resume

Before ending, write a dated `progress/YYYY-MM-DD-progress[_sN].md` file.
Include current step, completed work, decisions, build/experiment/attempt IDs,
PBS IDs, evidence paths, blockers, and the exact next action.

### Case 1: before Step 5 is complete

Preserve evidence and failed attempts. Record the current step, IDs, PBS job,
stdout/stderr, error or blocker, and manual-inspection case. State whether the
workflow awaits user action, external change, authorization, or a fix. Record
the exact resume action. Do not retry, patch, submit, or change direction
without authorization. Validate, commit, and push the progress record when
the normal Git workflow applies, and synchronize before remote work resumes.
Preserve and report pre-existing untracked artifacts.

### Case 2: Step 6 is complete

Record experiments, analysis IDs, findings, limitations, current baseline, and
next direction. Ensure the detailed analysis and `PLANS.md` contain the required
records. Preserve historical evidence. Treat the suggested next section as a
recommendation and wait for user confirmation or modification before preparing
the next experiment. After confirmation, resume at Step 2; do not repeat Step 1
unless this is a genuinely new application.
