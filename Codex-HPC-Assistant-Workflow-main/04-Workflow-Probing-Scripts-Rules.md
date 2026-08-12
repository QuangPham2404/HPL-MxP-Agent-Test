# Workflow Probing-Script Rules

A probing script only observes hardware, software, modules, scheduler
allocations, filesystem state, or other settings relevant to an optimization
strategy. It is unrelated to building, running, or result handling.

## Placement and format

- Store probing scripts in `scripts/` with a clear lowercase snake_case name.
- Follow the general documentation, shell-safety, and PBS conventions.
- Raw probe `.o` and `.e` files belong in the relevant output directory,
  normally `scripts/outputs/`.
- Use a new attempt-specific name for every rerun.

## Scope restrictions

Probe scripts may observe relevant state but must not:

- edit source code, build files, experiments, results, or planning files;
- change shared settings;
- install software;
- delete files;
- expose passwords, tokens, or sensitive environment variables;
- perform computational workloads on login nodes;
- contain optimization recommendations;
- modify files outside their designated output directory.

Use bounded PBS resources. A probe may report facts relevant to optimization,
but any script that suggests or applies an optimization, writes outside its
output directory, or changes configuration requires user permission before use.

## Probe workflow

Probe-only scripts may be committed, pushed, and submitted without separate
permission when they satisfy the read-only scope above and pass syntax and
output-path checks. They still follow the normal synchronize, pull, submit,
validate, and output-retrieval workflow. Preserve raw output as evidence and
record the attempt in the applicable progress or script documentation.
