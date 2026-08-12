# Project Workflow Instructions

This project uses the reusable Codex HPC Optimization Workflow Pack in
`workflow/`.

## Required startup reading

Before taking action, Codex must:

1. Read every numbered file in `workflow/` in numerical order.
2. Read `APPLICATION.md`.
3. Read the latest progress report under `progress/`.
4. Check the project Git state according to `workflow/01-Git-Sync-Policy.md`.

The workflow files are related and must all be read. Do not selectively route
only one workflow file based on the immediate task.

## Active project configuration

- Application: `<application-name>`
- Active cluster: `<cluster-name>`
- Workflow pack path: `workflow/`
- Application overview: `APPLICATION.md`
- Remote project root: also record and verify this in
  `workflow/00-General-SSH-Rules.md`

Complete the cluster-specific placeholders in
`workflow/00-General-SSH-Rules.md` before remote work begins. That file is the
main operational source for SSH, authentication, remote scope, scheduler, and
execution rules. This file may repeat critical cluster details or add stricter
project-specific restrictions, but must not weaken the workflow pack.

## Project-specific automation permissions

List only commands explicitly authorized for this project here. Include
approved local commands, approved remote commands, command prefixes, paths,
and restrictions. Do not assume that routine authorization from another
project applies here.

Examples of information to define, only when approved:

- permitted Git commands and branch scope;
- permitted syntax checks and directory creation;
- permitted scheduler submission and bounded monitoring commands;
- permitted output retrieval commands;
- commands that always require user approval;
- commands that are prohibited.

The workflow pack does not grant permission to install packages, modify shared
software, change source code, change resource policy, delete material, cancel
jobs, or start a new optimization direction.

## Application-specific instructions

Maintain `APPLICATION.md` as the application overview. Record the source URL
and exact revision, purpose, dependencies, build and run commands, important
inputs, expected output markers, correctness criteria, and baseline command.
Keep optimization plans and conclusions under `planning/`.

## Conflict and stop rule

If a rule conflicts, a placeholder is incomplete, the required authority is
missing, or an error requires judgment beyond the documented automatic track,
stop the affected workflow and report what must be resolved. Preserve all
available evidence.
