# 3Nodes-4GPUs experiment area

This is the canonical topology area for new HPL-MxP experiments on three GAAS
nodes with four H200 GPUs per node. It is an organizational parent, not one
experiment. Each run family belongs in a kebab-case child directory containing
its own README, PBS script(s), and `outputs/`, as required by the workflow.

## Relationship to other directories

- `multi-node-test/` contains validated launch bridges, probes, and model
  scripts. It is not the home for scored tuning evidence.
- `experiments/3x4-baseline/` and `experiments/3x4-smoketest/` are preserved
  historical records from before this parent-directory contract was adopted.
- `planning/analysis/3Nodes-4GPUs/` contains the analysis for these runs.
- `planning/blueprint/` defines the broad sweep phases and mandatory
  dependency checkpoints; `planning/dependency-graph/` defines the reopen
  implications.

## Required run handoff

Before a new run, create its child README and record the decision question,
hypothesis, original baseline, in-sweep control, fixed and varied parameters,
resource/launcher mapping, correctness gates, repetition plan, and user
authorization. Afterward record the PBS job, attempt, raw `.o`/`.e` evidence,
validation, result metadata, and the dependency-checkpoint decision.
