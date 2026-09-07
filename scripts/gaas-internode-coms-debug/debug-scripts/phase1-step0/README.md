# Phase 1 — Step 0: host-native launch sanity check

Part of `scripts/gaas-internode-coms-debug/` (see the directory `README.md`
debug plan, Phase 1, Step 0).

## Purpose

Validate the measurement infrastructure before any GPUDirect RDMA test, so a
later failure can be attributed to the GDR path rather than the launch
machinery or a non-CUDA-aware MPI build (test the tool before using the tool).

Checks:

- **A** — host OpenMPI (HPC-X 2.25.1, `nvhpc/26.3`) is CUDA-aware, via
  `ompi_info --all | grep -i cuda`.
- **B** — (informational) per-rank host placement + GPU visibility.
- **C** — `osu_hello` completes across 2 nodes through the exact launch path
  used later (host `mpirun` + `rsh_pbsdsh.sh` pbsdsh bridge).
- **D** — `osu_allreduce` (host buffers, default sizes) completes across
  2 nodes through the same launch path.

Only process spawn was validated previously; C and D confirm real cross-node
message flow.

## Layout / resources

- `select=2:ngpus=1` + `place=scatter` (2 nodes × 1 GPU, matching the Phase 1
  test shape).
- Host-native only: no container, no `apptainer`.

## Script

- `run_phase1_step0_sanity.pbs` — submit with `qsub run_phase1_step0_sanity.pbs`
  from this directory on GAAS.

## Outputs

- `../../outputs/phase1-step0/phase1_step0_sanity_v1.o` / `.e` — PBS evidence
  (attempt `phase1_step0_sanity_v1`; retries use `_v2`, `_v3`, ...).
- `hostfile` — generated in this directory by the job (untracked runtime
  artifact; preserved on GAAS).

## Pass criteria

- Checks A, C, D all exit 0 (`STEP0_RESULT=PASS` in the summary).
- If any fails: debug the launcher/bridge or MPI build first; do not interpret
  later GDR bandwidth results.
