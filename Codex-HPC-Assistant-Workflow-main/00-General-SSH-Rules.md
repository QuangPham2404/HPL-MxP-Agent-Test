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

## Persistent connection rules

- Use the cluster's documented persistent-connection check before remote work.
- If the connection is unavailable, stop and tell the user exactly how to
  restore it.
- Do not initiate a normal interactive SSH login.
- Every Codex-controlled remote command must use the documented non-interactive
  SSH form.
- Every Codex-controlled file transfer must use the documented non-interactive
  SCP or rsync form.

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

## Cluster configuration — complete before use

Replace every placeholder below. This section is the active cluster adapter.

- Cluster name: `<cluster-name>`
- SSH alias: `<ssh-alias>`
- Persistent connection check: `<connection-check-command>`
- If unavailable, user recovery command: `<recovery-command>`
- Required SSH form: `<ssh-command-form>`
- Required SCP form: `<scp-command-form>`
- Required rsync form, if used: `<rsync-command-form>`
- Remote project root: `<remote-project-root>`
- Scheduler: `<PBS|Slurm|other>`
- Scheduler submission command: `<submission-command>`
- Scheduler monitoring command and polling limit: `<monitoring-policy>`
- MPI or application launcher: `<launcher>`
- Module policy: `<module-policy>`
- Login-node restrictions: `<login-node-policy>`
- Compute-node execution restrictions: `<compute-node-policy>`
- Approved remote paths: `<approved-paths>`

## Cluster adaptation checks

Before the first remote action, verify that:

1. all placeholders have been replaced;
2. the connection check is read-only and correct;
3. SSH and file-transfer commands are non-interactive;
4. the remote root is exact and sufficiently narrow;
5. scheduler commands use batch execution;
6. launcher, modules, and resource syntax match the cluster;
7. no rule asks Codex to handle or expose authentication secrets.

If any check fails, stop before remote work.
