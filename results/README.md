# Results

`metrics.csv` is the structured source of truth. Preserve existing rows,
append compatible attempts, retain raw-output provenance, and generate
`RESULTS.md` from the recorded data. Do not add optimization interpretation
without the applicable analysis authorization.

## Schema (documented 2026-08-19)

Columns and semantics for the HPL-MxP sweeps:

- `experiment_id`: experiment directory name (`baseline-sweep`, `N-sweep`,
  `nb-sweep`, `np-sweep`, `affinity-sweep`, `matrix-placement-control`).
- `attempt`: unique attempt label; matches the raw stdout/stderr file stem so
  provenance is direct. For `affinity-sweep`, the output stem identifies the
  tested configuration (`cpu_aff_free`, `cpu_aff_neutral`, `cpu_aff_strict`,
  `mem_aff`, or `thread_10`); the exact affinity and environment settings are
  documented in the experiment README and run scripts. For
  `matrix-placement-control`, the output stem identifies the tested
  `--fill-device-buffer-size` configuration.
- `status`: `completed` when the run produced the final benchmark output and a
  `PASSED` verification marker, otherwise `failed`.
- `pbs_job_id`: PBS job identifier as echoed in raw stdout.
- `pbs_state`: PBS scheduler state when retained; recorded as `F` when the run
  produced final output. Set to `unknown` when unavailable.
- `exit_status`: PBS exit status. Recorded as `unknown` when PBS accounting did
  not expose it in retained history.
- `submission_time`: ISO-8601 submission timestamp echoed in raw stdout.
- `completion_time`: PBS completion timestamp when retained; `unknown`
  otherwise (not present in raw stdout).
- `allocated_node`: node name echoed in raw stdout (`hpc-gaas-gNN`).
- `runtime`: PBS elapsed time when retained; `unknown` otherwise.
- `queue`: `gpu_as`.
- `resources`: PBS resource request.
- `container_image`: apptainer image path.
- `mpi_processes`: number of MPI processes (8).
- `nprow`, `npcol`: process grid rows/columns.
- `nporder`: grid ordering (`row` or `column`), parsed from the run settings.
- `n`: matrix size.
- `nb`: panel size.
- `gpu_affinity`: GPU affinity string.
- `verification`: `PASSED` or `FAILED` from the HPL-MxP residual marker;
  `UNKNOWN` when the marker is absent.
- `stdout_path`, `stderr_path`: relative raw-output paths.
- `gflops`: the reported HPL-MxP GFLOPS value (the performance marker), in
  scientific notation.

Extraction is performed by `scripts/extract_sweeps.py`; `RESULTS.md` is
regenerated from the CSV by `scripts/generate_results.py`.
