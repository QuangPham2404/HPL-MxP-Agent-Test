# Extra instructions for agents for this directory (resource-alloc)

- This directory holds the host resource-allocation investigation for the 3x4
  HPL-MxP degradation. All logistics for this investigation stays inside this
  directory: do not move or copy its scripts, outputs, or records into other
  project directories (for example `experiments/`, `multi-node-test/`, or the
  parent `debug-scripts/`).
- `README.md` records the motivation, the list of experiments (experiment 1
  onward), and the analysis of results once runs are done.
- `SINGLE_NODE_TEST.md` is the dedicated planning + execution log for the
  single-node node-contention test (experiment 6). It is kept separate from
  `README.md`'s experiment records so the experiment-5 workstream is never
  touched; read it before working on anything `sn200k_*`/single-node.
- `debug-scripts/` stores all scripts used by these experiments.
- `outputs/` stores the raw job outputs (PBS `.o`/`.e` and per-attempt
  evidence) with attempt-specific filenames that are never overwritten.
- GAAS execution, Git synchronization, and evidence handling still follow the
  parent `scripts/gaas-internode-coms-debug/` debug process and the project
  workflow pack. Do not submit jobs from this directory without the reviewed
  scripts present in `debug-scripts/`.
