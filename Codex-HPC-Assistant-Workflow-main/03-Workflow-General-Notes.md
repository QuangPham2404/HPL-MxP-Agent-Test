# Workflow General Notes

These conventions apply to build, experiment, probe, extraction, and workflow
scripts unless a more specific section states otherwise.

## Naming

- Use one stable build or experiment name throughout the README, script names,
  PBS job names, output names, and build or binary paths.
- Use kebab-case for directories.
- Use lowercase snake_case for shell and PBS filenames.
- Use `<name>_v1`, `<name>_v1.1`, and `<name>_v1-final` for attempts.
- Use `<name>_v1.o` and `<name>_v1.e` for PBS output files.
- Every retry gets new attempt-specific output names; never overwrite evidence.

## Script documentation

Every script begins with a short comment describing its purpose, expected
working directory, inputs, outputs, and important assumptions. Divide scripts
into clear commented sections. Comments explain purpose, reasoning, or
non-obvious behavior; they do not merely restate obvious commands.

## Build shell script order

Build `.sh` scripts use this order:

1. shell safety settings;
2. build configuration and paths;
3. helper functions, if needed;
4. environment and tool checks;
5. source and build-directory checks;
6. configure command;
7. build command;
8. expected executable check.

## Build PBS script order

Build `.pbs` scripts use this order:

1. PBS job name, output/error paths, and resource requests;
2. shell safety settings;
3. change to the submitted script directory;
4. print or load the required environment;
5. call the corresponding build `.sh` script.

## Run PBS script order

Run `.pbs` scripts use this order:

1. PBS job name, output/error paths, and resource requests;
2. shell safety settings;
3. change to the submitted script directory;
4. define and print experiment metadata;
5. define and verify the successful build binary;
6. print environment and tool versions;
7. execute the application through the required launcher.

Keep build and run scripts consistent in shell options, comments, metadata
keys, variable naming, and attempt/output naming.

## Preflight checks

Before configuring or running, fail clearly if required source paths, output
directories, tools, launchers, or expected binaries are missing. A tool check
is fatal when the next command directly depends on that tool.

A preflight requirement is mandatory only when the subsequent build, run, or
validation command directly depends on that tool or its output. Optional
diagnostics and provenance tools must not block an otherwise valid workflow;
record unknown or warn when they are unavailable. Do not introduce a new fatal
preflight requirement by inference. Ask the user when necessity is unclear.

## Evidence and metadata

Record, for each run:

- experiment ID;
- PBS job ID;
- timestamp;
- hostname or node allocation;
- compiler and compiler version;
- MPI implementation and version;
- loaded modules;
- build flags;
- input parameters;
- requested resources;
- runtime;
- correctness or convergence result;
- stdout path;
- stderr path;
- exit status.

Do not classify a job as successful based only on exit status. Validate
expected output and correctness criteria.
