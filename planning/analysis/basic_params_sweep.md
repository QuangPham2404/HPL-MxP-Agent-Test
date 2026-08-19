# Analysis: Basic parameter sweep

## 1. Concise summary

This analysis evaluates the recorded baseline, matrix-size (`N`), panel-size
(`NB`), and process-grid/order sweeps for HPL-MxP on GAAS. The purpose is to
identify performance-sensitive basic parameters relative to the recorded
baseline, while retaining all recorded attempts and checking correctness before
ranking results. The scope is all 19 rows currently present in
`results/metrics.csv`.

The baseline is `baseline-sweep_v1`: `N=370000`, `NB=1024`, grid `2x4`, row
ordering, and `1.4432e+06` GFLOP/s. The best recorded result is `4x2`, column
ordering, `N=399360`, `NB=3072`, at `1.8441e+06` GFLOP/s, 27.78% above the
baseline.

## 2. Scope and evaluation criteria

- Analysis ID: `basic_params_sweep`
- Analysis date: 2026-08-20
- Source: [`results/metrics.csv`](../../results/metrics.csv)
- Source revision: repository commit `3605b29` (`Log results sweep`), the
  current local source revision at analysis time
- Application/runtime: NVIDIA HPL-MxP container release `26.02`, image
  `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`, GAAS
  `gpu_as` queue, Apptainer with `--nv`, and 8 MPI processes
- Compiler/MPI environment: prebuilt container benchmark; no application
  compiler build was performed and compiler/MPI version fields were not
  recorded in `metrics.csv`. Experiment metadata records modules
  `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`, and `gocryptfs/2.5.0`,
  with `mpirun -np 8 --bind-to none`.
- Workload: distributed HPL-MxP, eight GPUs, GPU affinity
  `0:1:2:3:4:5:6:7`; baseline and N sweeps use `2x4` row ordering unless
  otherwise shown.
- Baseline: `baseline-sweep_v1`, `N=370000`, `NB=1024`, `2x4` row,
  `1.4432e+06` GFLOP/s, `PASSED`.
- Correctness gate: rank only rows with a finite reported performance and
  `verification=PASSED`. All 19 included rows pass this gate. A passed
  verification does not make an anomalously slow run representative.
- Performance metric: reported HPL-MxP GFLOP/s (`gflops` in the CSV).
- Included: all baseline, N-sweep, NB-sweep, NB-associated N re-sweep, and
  process-grid/order attempts in the CSV.
- Excluded: none. PBS `completion_time`, `runtime`, and `exit_status` values
  recorded as `unknown` were not used for performance ranking.

## 3. Data and analysis

All values below are copied from `results/metrics.csv`; `grid` is
`nprow x npcol`, and the reported result is GFLOP/s. The baseline is used for
all percentage comparisons.

### Baseline

| Attempt | N | NB | Grid | Order | Reported result (GFLOP/s) |
|---|---:|---:|---|---|---:|
| `baseline-sweep_v1` | 370000 | 1024 | 2x4 | row | 1.4432e+06 |

This is the reference point for the three sweep groups below.

### Sweep N

| Attempt | N | NB | Grid | Order | Reported result (GFLOP/s) |
|---|---:|---:|---|---|---:|
| `N-sweep_399k` | 399360 | 1024 | 2x4 | row | 1.4918e+06 |
| `N-sweep_v1` | 400000 | 1024 | 2x4 | row | 1.5569e+06 |
| `N-sweep_400k` | 400384 | 1024 | 2x4 | row | 1.5751e+06 |
| `N-sweep_401k` | 401408 | 1024 | 2x4 | row | 1.5821e+06 |
| `N-sweep_402k` | 402423 | 1024 | 2x4 | row | 7.6797e+05 |
| `N-sweep_404k` | 404000 | 1024 | 2x4 | row | 1.4871e+06 |

At `NB=1024` and `2x4` row, the highest N-sweep result is `N=401408`,
`1.5821e+06` GFLOP/s, 9.62% above baseline. The valid results from
`N=399360` through `404000` are non-monotonic. `N-sweep_402k` is 46.79% below
baseline and roughly half the neighboring results, so it is treated as a
performance anomaly pending repetition rather than as evidence that this N is
optimal or representative.

### Sweep NB

| Attempt | N | NB | Grid | Order | Reported result (GFLOP/s) |
|---|---:|---:|---|---|---:|
| `nb-sweep_1024` | 401408 | 1024 | 2x4 | row | 1.5782e+06 |
| `nb-sweep_2048` | 401408 | 2048 | 2x4 | row | 1.7879e+06 |
| `nb-sweep_3072` | 401408 | 3072 | 2x4 | row | 1.8209e+06 |
| `nb-sweep_4096` | 401408 | 4096 | 2x4 | row | 1.8040e+06 |
| `nb-sweep_5120` | 401408 | 5120 | 2x4 | row | 1.7569e+06 |
| `nb-sweep_8192` | 401408 | 8192 | 2x4 | row | 1.7445e+06 |
| `n-resweep_399k` | 399360 | 3072 | 2x4 | row | 1.8177e+06 |
| `n-resweep_402k` | 402432 | 3072 | 2x4 | row | 1.6981e+06 |

With `N=401408` and `2x4` row, performance rises from `1.5782e+06` at
`NB=1024` to a local maximum of `1.8209e+06` at `NB=3072`, then declines at
larger NB values. The peak is 26.18% above baseline. The associated N re-sweep
at `NB=3072` also favors `N=399360` over `N=402432` in the two recorded points,
but does not establish an N optimum by itself.

### Sweep grid (`--nprow`, `--npcol`, `--nporder`)

| Attempt | N | NB | Grid | Order | Reported result (GFLOP/s) |
|---|---:|---:|---|---|---:|
| `2x4_row` | 399360 | 3072 | 2x4 | row | 1.7302e+06 |
| `2x4_col` | 399360 | 3072 | 2x4 | column | 1.7625e+06 |
| `4x2_row` | 399360 | 3072 | 4x2 | row | 1.8126e+06 |
| `4x2_col` | 399360 | 3072 | 4x2 | column | 1.8441e+06 |

At fixed `N=399360` and `NB=3072`, the `4x2` grid outperforms `2x4` for both
orderings. Column ordering outperforms row ordering for both tested grids. The
best grid result, `4x2` column, is 27.78% above baseline and is the best
recorded result overall.

## 4. Insights gained

- Confirmed win: `N=399360`, `NB=3072`, `4x2` column reports
  `1.8441e+06` GFLOP/s, the best result in the included data.
- Confirmed trend: NB is the strongest isolated lever in the recorded
  `2x4` row tests; performance improves through `NB=3072` and regresses for
  `NB=4096` and above.
- Confirmed grid effect: at `N=399360`, `NB=3072`, `4x2` is faster than `2x4`,
  and column ordering is faster than row ordering for both grids.
- N effect: around 400k with `NB=1024`, the valid results favor the
  `399360`--`401408` region, but the response is non-monotonic and the sample
  count is one per point.
- Anomaly: `N-sweep_402k` passed verification but reported only
  `7.6797e+05` GFLOP/s. It is retained as evidence and not discarded, but it
  should not drive configuration selection until repeated.
- Reproducibility limits: most rows have different GAAS nodes; the CSV lacks
  retained runtime and PBS exit status for most attempts; and there are no
  repeated measurements at each configuration. Node and transient-system
  variation therefore cannot be separated from parameter effects.
- No correctness regressions were observed in the included rows: every row is
  marked `PASSED` with a reported performance result.

## 5. Suggested next section

The next optimization direction should be confirmation and local refinement
of the current candidate: first repeat `N-sweep_402k` (`N=402423`, `NB=1024`,
`2x4` row) to determine whether the low result is transient. Then, at the
`4x2` column grid, repeat the current best configuration and scan NB locally
around 3072 (for example 2560 and 3584) together with a small N scan around
399360--401408.

Use the same container, eight-GPU allocation, MPI launcher, affinity,
correctness settings, and monitoring/skip-test controls for all repetitions.
Record at least two comparable attempts per shortlisted configuration, retain
node and runtime metadata, and require `PASSED` verification plus a stable
performance improvement over the baseline. The unresolved questions are
whether `N=399360` remains best at `4x2` column, whether a nearby NB exceeds
3072, and whether the `402423` anomaly reproduces.

This section is a recommendation for review; it does not authorize preparing
or submitting the next experiment.

## 6. Provenance

- Source CSV: [`results/metrics.csv`](../../results/metrics.csv)
- Experiment IDs: `baseline-sweep`, `N-sweep`, `nb-sweep`, and `np-sweep`
- Attempts: all 19 `(experiment_id, attempt)` rows in the source CSV
- Raw output directories:
  - [`experiments/baseline-sweep/outputs/`](../../experiments/baseline-sweep/outputs/)
  - [`experiments/N-sweep/outputs/`](../../experiments/N-sweep/outputs/)
  - [`experiments/nb-sweep/outputs/`](../../experiments/nb-sweep/outputs/)
  - [`experiments/np-sweep/outputs/`](../../experiments/np-sweep/outputs/)
- Extraction script: [`results/scripts/extract_sweeps.py`](../../results/scripts/extract_sweeps.py)
- Analysis date: 2026-08-20
