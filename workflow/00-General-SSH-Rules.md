# General SSH and Cluster Execution Rules

This document defines the safe remote-execution policy for the workflow pack.
It contains universal rules followed by values that must be adapted for each
new cluster. Preserve the universal rules when adapting this file.

## Universal authentication rules

- Never request, read, store, transmit, echo, or log any SSH password.
- Never use `sshpass`, Expect, password files, clipboard extraction,
  environment variables, or command-line password arguments for authentication.
- Never attempt to modify SSH authentication settings.
- Never automate password entry.
- Never install tools merely to bypass interactive authentication.
- Never store cluster credentials or GitHub credentials on the cluster.

## Direct SSH and optional connection reuse

- Ordinary direct SSH is sufficient. Prefer
  `ssh -o BatchMode=yes gaas '<remote-command>'` for automated commands;
  `ssh gaas '<remote-command>'` is also valid when appropriate.
- A persistent ControlMaster or ControlPath is not a prerequisite.
  `ssh -O check gaas` is only an optional check when a ControlMaster is
  already configured. `ssh -MNf gaas` is never required before remote work.
- `No ControlPath specified for "-O" command` does not block work when
  direct SSH succeeds. Continue with direct SSH under the approved scope.
- If direct SSH cannot authenticate and human interaction is required,
  stop the affected work and ask the user to authenticate personally.
  Never automate password entry or modify authentication configuration.
- Use the documented non-interactive SCP or rsync form for authorized transfers.

## Remote scope and execution rules

- Keep remote work inside the approved project root unless the user explicitly
  approves another path.
- Do not use `sudo`.
- Do not install Codex, package managers, background services, daemons, proxies,
  or remote agents on the cluster.
- Do not install new software or packages without user approval.
- Do not modify shared software. Prefer available modules and site-supported
  tools.
- During workflow execution, create or edit only approved project files and
  designated output directories. Do not delete folders without user approval.
- Run computation through the cluster scheduler via batch jobs.
- Do not perform computational workloads on login nodes.
- Do not poll the scheduler excessively; use bounded monitoring.

## Cluster configuration — GAAS

This section is the active cluster adapter. Command forms do not grant
authorization; follow the project-specific permissions in `AGENTS.md`.

- Cluster name: `GAAS`
- SSH alias: `gaas`
- Direct SSH is sufficient; use `ssh gaas '<remote-command>'` when appropriate.
- Preferred automated SSH form: `ssh -o BatchMode=yes gaas '<remote-command>'`
- Required SCP form: `scp -o BatchMode=yes gaas:<remote-file> <local-file>`
  (reverse source and destination for an authorized upload).
- Required rsync form, if used: not currently authorized; use SCP for
  explicitly authorized transfers.
- Remote project root:
  `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test`
- Scheduler: `PBS`
- Scheduler submission command: `qsub <reviewed-script.pbs>`, only with
  explicit authorization in the human-approved active task or current request.
- PBS accounting group: `hpc_ebslee` (not `hpc_admin`).
- Queue scope for clean-node selection: only `gpu_as`, `gpu_ded`, and
  `gpu_free`; all other queues are off-limits. The 2026-09-15 probe recorded
  `gpu_free` as disabled and `gpu_free_normal`/`gpu_free_high` as successors
  serving `g25`; this observation does not authorize additional queues.
- Scheduler monitoring command and polling limit: `qstat -u $USER` for a
  bounded check; repeated monitoring requires explicit authorization and a
  bounded polling plan. Do not poll excessively.
- MPI or application launcher: HPL-MxP's container launcher inside PBS.
  For multinode runs, follow `multi-node-test/GAAS_MULTINODE_SETUP.md` and
  `multi-node-test/HPL-MxP/`: use the container's own `mpirun` and `orted`,
  one rank per GPU, and the tested PBS remote-spawn bridge
  `multi-node-test/rsh_pbsdsh_container.sh`. Submit multinode jobs one at a
  time. Resource, launcher, and transport changes require explicit approval.
- Module policy: use `module avail` to inspect available modules; module or
  package changes require explicit authorization. Do not modify shared software.
- Login-node restrictions: do not run builds, experiments, or computational
  workloads on login nodes.
- Compute-node execution restrictions: run approved workloads through PBS
  batch jobs, using reviewed scripts and the approved allocation.
- Approved remote paths: only the remote project root above and its
  designated project subdirectories; another path requires explicit approval.

## Cluster adaptation checks

Before the first remote action, verify that:

1. all placeholders have been replaced;
2. direct SSH can authenticate without Codex handling credentials; an optional
   ControlMaster check is not a gate;
3. automated SSH commands prefer BatchMode and file transfers are non-interactive;
4. the remote root is exact and sufficiently narrow;
5. scheduler commands use batch execution;
6. launcher, modules, and resource syntax match the cluster;
7. no rule asks Codex to handle or expose authentication secrets.

If any check fails, stop before remote work.
