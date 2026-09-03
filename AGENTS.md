# Project Workflow Instructions

This project uses the reusable Codex HPC Optimization Workflow Pack in
`workflow/`.

## Required startup reading

Before taking action, Codex must:

1. Read every numbered file in `workflow/` in numerical order.
2. Read `APPLICATION.md`.
3. Read the latest progress report under `progress/`
4. Check the project Git state according to `workflow/01-Git-Sync-Policy.md`.

The workflow files are related and must all be read. Do not selectively route
only one workflow file based on the immediate task.

## Active project configuration

- Application: `HPL-MxP (NVIDIA container implementation: https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html)`
- Active cluster: `GAAS`
- Workflow pack path: `workflow/`
- Application overview: `APPLICATION.md`
- Remote project root: also record and verify this in
  `workflow/00-General-SSH-Rules.md`: `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test`

Complete the cluster-specific placeholders in
`workflow/00-General-SSH-Rules.md` before remote work begins. That file is the
main operational source for SSH, authentication, remote scope, scheduler, and
execution rules. This file may repeat critical cluster details or add stricter
project-specific restrictions, but must not weaken the workflow pack.

## Project-specific automation permissions

If this section is not filled, agents are to assume they can execute any commands to complete their specified jobs, adhering strictly to the workflow and its following restrictions.

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

Experiment output policy:

- PBS stdout and stderr files produced by experiments, specifically `.o` and
  `.e` files under `experiments/*/outputs/`, are useful run evidence and must
  normally be tracked and pushed to GitHub with the corresponding experiment
  record.
- Preserve attempt-specific filenames; do not overwrite evidence from an
  earlier attempt.
- This policy applies to experiment outputs only. Do not commit unrelated
  temporary files or outputs outside the designated experiment directories.

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

## Notes

For optimization runs, use the flag `--skip-tests 1` to skip test and save time. Also add the following params for monitoriring:

```txt
--monitor-gpu 1 \
--monitor-gpu-interval 10 \
--monitor-gpu-pcie-width-warning 16 \
--monitor-gpu-pcie-gen-warning 5
```

For analysis step in the workflow, always include: (1) the baseline from the baseline run (the original baseline), and (2) the data tables must have a column to show the percentage increase compared to that baseline run

Update on some new directories that might not be mention in the workflow package and structural changes on the project repo
- `multi-node-test/` contains working model scripts for multinode launch of HPL, HPL-MxP, and HPCG. `multi-node-test/HPL-MxP` contains the script for launching multinode HPL-MxP
- `experiments/3Nodes-4GPUs` and `planning/analysis/3Nodes-4GPUs` are directories dedicated to run and analyse HPL-MxP on 3 Nodes - 4 GPUs topology. Use this 2 directories whenever the experiements are ran on 3 nodes - 4 GPUs.
- `planning/blueprint` is the directory for the general sweeping methodology for HPL-MxP on any hardware topology.
- `planning/dependency-graph` details the dependency of flags with each other to help structure experiments and determine if resweeps are needed.