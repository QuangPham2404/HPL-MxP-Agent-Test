# Workflow Error-Patching Procedures

Classify build and run errors after inspecting evidence, not from process exit
status alone. Review PBS state and exit status, stdout, stderr, expected output,
normal application output, and correctness or convergence markers.

## Track 1: automatic workflow patching

Use Track 1 only for deterministic, low-risk defects in workflow machinery,
when the cause is sufficiently clear and corrected behavior is unambiguous.
Typical cases are incorrect paths, missing output-directory preparation,
incorrect PBS output names, stale expected-binary paths, shell quoting or
control-flow defects, unnecessarily strict preflight checks, inconsistent
metadata, and extraction parsing or duplicate-handling defects.

Track 1 is limited to reversible changes to workflow scripts, documentation,
metadata, and output handling. It must not patch source code, choose compiler
or MPI strategies, change optimization flags or resources, modify shared
software, or interpret uncertain application behavior.

For a Track 1 failure:

1. identify and confirm the deterministic workflow defect;
2. preserve the failed attempt evidence;
3. immediately record the failed attempt in the corresponding build or
   experiment README, including attempt label, PBS job ID, stdout/stderr paths,
   observed error, suspected cause, and planned patch;
4. apply the local patch and run appropriate syntax, path, or configuration
   checks;
5. use a new attempt label and new PBS output filenames;
6. review, commit, push, and synchronize the changed scripts as required;
7. submit the retry through PBS and update the README with its result;
8. continue validation only after PBS, output-presence, application-output,
   and correctness criteria are satisfied.

Build failures belong in `builds/build-scripts/<build_name>/README.md`.
Run failures belong in `experiments/<run_name>/README.md`.

## Track 2: manual inspection

Use Track 2 when an error requires interpretation, user judgment, external
authorization, or a change beyond routine workflow repair. Examples include
compiler/source compatibility errors, unavailable dependencies or modules,
MPI initialization failures or hangs, scheduler/resource/hardware/filesystem
problems, possible compiler or MPI correctness issues, source or input changes,
resource or launcher changes, and uncertain causes.

For Track 2:

1. identify and classify the error;
2. preserve experiment/build ID, attempt, PBS job ID, timestamp, PBS state and
   exit status, node, paths, compiler/MPI metadata, modules, flags, inputs,
   resources, and relevant output;
3. stop the affected workflow; do not patch, retry, change configuration, or
   submit another job automatically;
4. inspect evidence without modifying the affected workflow;
5. record observed error, suspected causes, confirmed facts, unresolved
   questions, affected workflow, and evidence;
6. suggest possible fixes for user review, without applying them;
7. append a unique case to root `MANUAL_INSPECTION_ERROR.md`;
8. wait for the user's decision or an explicitly scoped override;
9. after resolution, update the same case with authorization, action, retry,
   outcome, remaining concerns, and final status.

Maintain the case log as append-only. Use statuses such as `OPEN`,
`USER_ACTION_REQUIRED`, `AUTHORIZED_FOR_PATCH`, `RESOLVED`, or `CLOSED`.
Recording a proposed fix never authorizes it.

## Scientific-correctness exception

A completed build or run with failed, non-finite, or otherwise invalid
scientific correctness is non-blocking by default. Examples include
`MaxRelDiff = -nan`, failed convergence, failed verification markers, or
unexpected numerical output despite successful process exit.

Do not self-patch this condition. Preserve the attempt, record correctness
accurately, and add a clear note to `results/RESULTS.md` describing the run,
marker, no-patch decision, and need for further investigation. If the user
later requests investigation or authorizes a patch, create or link a manual
inspection case and follow the explicit scope.

## `OVERRID_AUTO_PATCH`

This user-supplied command-like authorization may permit automatic handling of
a named Track 2 error only when all fields are explicit:

```text
OVERRID_AUTO_PATCH
error_class: <specific error class>
allowed_action: <specific permitted action>
scope: <current attempt | current build | current experiment | current session>
restrictions: <limitations>
```

The override expires at the stated scope and authorizes only the named class
and action. It does not authorize unrelated source changes, optimization
decisions, resource changes, authentication changes, destructive actions, or
shared-software changes. Package/module actions must preserve provenance.
Record the override, matched error, action, environment changes, retry, and
result in the README and manual-inspection case when applicable.

The detailed response to a failure must also follow the build-, experiment-,
results-, or session-specific instructions in `07-Workflow.md`.
