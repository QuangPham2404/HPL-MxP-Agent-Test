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
  `--fill-device-buffer-size` or `--cuda-host-register-step` configuration.
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
- `use_mpi_panel_broadcast`: `--use-mpi-panel-broadcast <int>` value parsed from
  the HPL-MxP settings block (`unknown` for experiments that predate the column
  or do not set the flag). 0 selects NCCL; positive values select an MPI
  percentage policy.
- `u_panel_chunk_nbs`: `--u-panel-chunk-nbs <int>` value parsed from the
  settings block (`unknown` when absent).
- `prioritize_trsm`: `--prioritize-trsm <int>` value parsed from the settings
  block (`unknown` when absent/for experiments that predate the column).
- `prioritize_factorization`: `--prioritize-factorization <int>` value parsed
  from the settings block (`unknown` when absent/for experiments that predate
  the column).
- `use_separate_stream_for_gemm`: `--use-separate-stream-for-gemm <int>` value
  parsed from the settings block (`unknown` when absent/for experiments that
  predate the column).
- `call_dgemv_with_multiple_threads`: `--call-dgemv-with-multiple-threads <int>`
  value parsed from the settings block (`unknown` when absent/for experiments
  that predate the column).
- `gpu_affinity`: GPU affinity string.
- `omp_num_threads`, `omp_places`, `omp_proc_bind`: OpenMP thread-count and
  placement/binding environment values (`OMP_NUM_THREADS`, `OMP_PLACES`,
  `OMP_PROC_BIND`). `unset` means the variable was not exported for that run
  (OpenMP runtime default). These are populated for the `omp-sweep` experiment;
  blank for experiments that predate the columns.
- `verification`: `PASSED` or `FAILED` from the HPL-MxP residual marker;
  `UNKNOWN` when the marker is absent.
- `stdout_path`, `stderr_path`: relative raw-output paths.
- `gflops`: the reported HPL-MxP GFLOPS value (the performance marker), in
  scientific notation.

Extraction is performed by `scripts/extract_sweeps.py`; `RESULTS.md` is
regenerated from the CSV by `scripts/generate_results.py`.

## Extractor notes (updated 2026-09-18)

- The rebuild is append-only and order-preserving: existing rows keep their
  recorded order and reviewed metadata (node lists, gpu-affinity strings,
  submission timestamps, queue/resources, verification verdicts) unless the
  raw `.o` explicitly echoes a more authoritative value (`queue=`,
  `resources=` echoes introduced with the `SingleNode-resweep` scripts).
- `mpi_processes` is derived from the parsed `nprow x npcol` grid.
- `experiments/2Nodes-8GPUs/` outputs are recorded under the historical
  experiment ID `2x8-n-sweep` (directory was renamed after the rows were
  recorded); the alias map lives in the extractor.
- The 2026-09-18 rebuild also appended the previously unextracted
  `3x4-smoketest/smoketest_100k_v1` row (PASSED, `1.4438e+04`); its
  node list, gpu affinity (`0:1:2:3`), and resource string were corrected
  manually from the experiment's PBS script and raw output.
- `SingleNode-resweep_v1` is recorded as `failed` (launch argument-contract
  defect, Track 1; see the experiment README); `SingleNode-resweep_v1.1`
  is the valid scored attempt.
