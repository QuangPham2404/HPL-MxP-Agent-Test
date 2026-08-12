# Workflow Automation and Authorization

This file defines the reusable authorization boundaries. It does not grant
project-specific permissions. The active project's root `AGENTS.md` must list
any specially authorized commands, prefixes, paths, and restrictions.

## Actions normally within routine workflow scope

When explicitly required by the current user-requested workflow and permitted
by the project `AGENTS.md`, routine actions may include:

- read-only Git inspection;
- adding reviewed current-workflow files;
- committing reviewed scripts, plans, progress, metadata, logs, and extracted
  results;
- fast-forward synchronization;
- syntax checks;
- creating designated build, experiment, script, and output directories;
- submitting reviewed PBS build, run, and read-only probe scripts;
- bounded scheduler inspection;
- retrieving generated outputs into matching local directories.

The project instructions must define the actual command forms and approved
prefixes. Do not infer that permission from this reusable pack alone.

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

## Authorization scope

Authorization is limited to the named project, cluster scope, current task,
and explicit files or commands. An authorization for one workflow step does
not authorize another step. `ANALYSE_RESULTS` authorizes analysis only; it does
not authorize jobs, source changes, build/run configuration changes, or the
next experiment. `OVERRID_AUTO_PATCH` authorizes only its named error class,
action, scope, and restrictions.

Never treat a recommendation, progress note, analysis conclusion, or proposed
fix as authorization.
