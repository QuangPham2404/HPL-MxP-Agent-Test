# Analysis: Basic parameter sweep 2

## 1. Concise summary

This is a fresh Step 6 analysis of all experiments currently recorded in
`results/metrics.csv`. It compares the baseline, matrix-size (`N`) sweep,
panel-size (`NB`) sweep, and process-grid/order sweep. The baseline is the
explicit `baseline-sweep_v1` run: `N=370000`, `NB=1024`, `2x4` row, and
`1.4432e+06` GFLOP/s.

The best recorded configuration is `N=399360`, `NB=3072`, `4x2` column at
`1.8441e+06` GFLOP/s, which is 27.78% above the baseline. All 19 rows pass the
recorded verification gate, but the single very low `N-sweep_402k` result is
not treated as representative without repetition.

## 2. Scope and evaluation criteria

- Analysis ID: `basic_param_sweep2`
- Analysis date: 2026-08-20
- Source: [`results/metrics.csv`](../../results/metrics.csv)
- Source revision: repository `HEAD` `a3e9393251ef12ac18baa6f6ed638924d9d64afd`
  at analysis time; the working tree also contains a pre-existing modification
  to `workflow/07-Workflow.md`, which is unrelated to this analysis.
- Included: all 19 rows from `baseline-sweep`, `N-sweep`, `nb-sweep`, and
  `np-sweep`; no attempts were excluded.
- Workload/runtime: NVIDIA HPL-MxP container `26.02`, GAAS `gpu_as` queue,
  eight MPI processes/GPUs, GPU affinity `0:1:2:3:4:5:6:7`, and FP16 sloppy
  type as shown in the raw benchmark output.
- Baseline: `baseline-sweep_v1`, `N=370000`, `NB=1024`, grid setup `2x4 row`,
  `1.4432e+06` GFLOP/s, `PASSED`.
- Correctness gate: a row is rankable only when `verification=PASSED` and
  `gflops` is finite. Every included row satisfies this gate. The gate does
  not make a large performance outlier representative.
- Metric: reported HPL-MxP performance (`gflops`, GFLOP/s). Increase is
  `(reported result / 1.4432e+06 - 1) * 100`.
- Limitations: most rows have unknown retained runtime and exit status, and
  runs use different GAAS nodes. There is only one measurement at most
  configurations, so parameter effects and transient/node variation are not
  fully separable.

## 3. Data and analysis

The tables below copy the selected numeric fields from `results/metrics.csv`.
The `grid setup` column combines `nprow`, `npcol`, and `nporder` as
`nprow x npcol order`. Every percentage uses the baseline above.

### Baseline

| Attempt | N | NB | Grid setup | Reported result (GFLOP/s) | Increase vs baseline |
|---|---:|---:|---|---:|---:|
| `baseline-sweep_v1` | 370000 | 1024 | 2x4 row | 1.4432e+06 | 0.00% |

### Sweep N

The N sweep holds `NB=1024` and `2x4 row` fixed.

| Attempt | N | NB | Grid setup | Reported result (GFLOP/s) | Increase vs baseline |
|---|---:|---:|---|---:|---:|
| `N-sweep_399k` | 399360 | 1024 | 2x4 row | 1.4918e+06 | 3.37% |
| `N-sweep_v1` | 400000 | 1024 | 2x4 row | 1.5569e+06 | 7.88% |
| `N-sweep_400k` | 400384 | 1024 | 2x4 row | 1.5751e+06 | 9.14% |
| `N-sweep_401k` | 401408 | 1024 | 2x4 row | 1.5821e+06 | 9.62% |
| `N-sweep_402k` | 402423 | 1024 | 2x4 row | 7.6797e+05 | -46.79% |
| `N-sweep_404k` | 404000 | 1024 | 2x4 row | 1.4871e+06 | 3.04% |

The valid N results are non-monotonic. Excluding the anomalous `402423` row,
the range is `1.4871e+06` to `1.5821e+06` GFLOP/s, or 3.04% to 9.62% above
baseline. The highest single N result is `N=401408`, but one run per point is
insufficient to establish an N optimum.

### Sweep NB

The main NB sweep holds `N=401408` and `2x4 row` fixed. The two N re-sweep
rows retain `NB=3072` and the same grid while changing N.

| Attempt | N | NB | Grid setup | Reported result (GFLOP/s) | Increase vs baseline |
|---|---:|---:|---|---:|---:|
| `nb-sweep_1024` | 401408 | 1024 | 2x4 row | 1.5782e+06 | 9.35% |
| `nb-sweep_2048` | 401408 | 2048 | 2x4 row | 1.7879e+06 | 23.88% |
| `nb-sweep_3072` | 401408 | 3072 | 2x4 row | 1.8209e+06 | 26.17% |
| `nb-sweep_4096` | 401408 | 4096 | 2x4 row | 1.8040e+06 | 25.00% |
| `nb-sweep_5120` | 401408 | 5120 | 2x4 row | 1.7569e+06 | 21.74% |
| `nb-sweep_8192` | 401408 | 8192 | 2x4 row | 1.7445e+06 | 20.88% |
| `n-resweep_399k` | 399360 | 3072 | 2x4 row | 1.8177e+06 | 25.95% |
| `n-resweep_402k` | 402432 | 3072 | 2x4 row | 1.6981e+06 | 17.66% |

At fixed `N=401408`, increasing NB from 1024 to 2048 improves performance by
13.29% relative to the NB=1024 point; NB=3072 adds a further 1.85% over
NB=2048. Performance then falls 0.93% at NB=4096 and 4.20% by NB=8192
relative to NB=3072. Thus `NB=3072` is a clear local peak in this sampled
range, although nearby values were not tested.

The two NB=3072 N re-sweep points are both above baseline, but `N=402432`
is 6.58% below `N=399360` in that pair. This supports sensitivity to N near
400k, but does not prove a global N preference because the points are not
repeated and are not at the same grid used for the best result.

### Sweep grid (nprow, npcol, nporder)

The grid sweep holds `N=399360` and `NB=3072` fixed.

| Attempt | N | NB | Grid setup | Reported result (GFLOP/s) | Increase vs baseline |
|---|---:|---:|---|---:|---:|
| `2x4_row` | 399360 | 3072 | 2x4 row | 1.7302e+06 | 19.89% |
| `2x4_col` | 399360 | 3072 | 2x4 column | 1.7625e+06 | 22.12% |
| `4x2_row` | 399360 | 3072 | 4x2 row | 1.8126e+06 | 25.60% |
| `4x2_col` | 399360 | 3072 | 4x2 column | 1.8441e+06 | 27.78% |

At fixed N and NB, changing `2x4` to `4x2` improves the row result by 4.76%
and the column result by 4.63%. Column ordering improves `2x4` by 1.87% and
`4x2` by 1.74%. The combined change from `2x4 row` to `4x2 column` is 6.58%,
making `4x2 column` the best tested setup.

## 4. Insights gained

- **Best measured result:** `4x2 column`, `N=399360`, `NB=3072`, at
  `1.8441e+06` GFLOP/s, 27.78% above baseline. It passed verification.
- **NB has the clearest isolated effect:** at `N=401408`, `2x4 row`, the
  result rises from `1.5782e+06` at NB=1024 to `1.8209e+06` at NB=3072,
  then declines through NB=8192. The sampled peak is broad enough to justify
  local refinement, but not enough to claim the exact optimum.
- **Grid shape and order both matter:** at fixed `N=399360`, `NB=3072`, the
  4x2 shape is faster than 2x4 for both orders, and column is faster than row
  for both shapes. These effects are smaller than the NB change but are
  consistent across the four grid rows.
- **N is a secondary, noisy lever in the tested range:** the normal N-sweep
  results cluster around 399360--401408, while 404000 returns near baseline.
  The `402423` run is 46.79% below baseline despite passing verification and
  is therefore a performance anomaly, not a correctness failure.
- **Cross-check evidence:** the N=401408, NB=1024, 2x4-row result is
  `1.5821e+06` in the N sweep and `1.5782e+06` in the NB sweep, only 0.25%
  apart. This supports the broad level of the result, while still leaving
  ordinary run-to-run noise unresolved.
- **No invalid rows:** all 19 rows have `PASSED` verification and finite
  reported GFLOP/s. The analysis therefore ranks all rows numerically, while
  flagging the anomalous performance value rather than discarding it.
- **Reproducibility constraint:** node placement differs across attempts and
  most retained runtime/exit-status fields are unknown. The measurements do
  not support attributing every difference solely to the requested parameter.

## 5. Suggested next section

For user review, the next direction should be confirmation and local refinement
at the `4x2 column` grid: repeat the current best (`N=399360`, `NB=3072`),
repeat `N=402423, NB=1024, 2x4 row` to resolve the anomaly, and test nearby NB
values around 3072 with a small N set around 399360--401408. Use the same
container, eight-GPU allocation, launcher, affinity, correctness settings,
and monitoring controls. Prefer at least two comparable attempts per
shortlisted configuration, retaining node and runtime metadata.

Selection should require `PASSED` verification and a repeatable improvement
over the baseline; a single peak should remain provisional. This suggestion
does not authorize a new experiment.

## 6. Provenance

- Structured source: [`results/metrics.csv`](../../results/metrics.csv)
- Validated summary: [`results/RESULTS.md`](../../results/RESULTS.md)
- Experiment IDs: `baseline-sweep`, `N-sweep`, `nb-sweep`, `np-sweep`
- Attempts: all 19 `(experiment_id, attempt)` rows in the CSV
- Raw evidence directories:
  - [`experiments/baseline-sweep/outputs/`](../../experiments/baseline-sweep/outputs/)
  - [`experiments/N-sweep/outputs/`](../../experiments/N-sweep/outputs/)
  - [`experiments/nb-sweep/outputs/`](../../experiments/nb-sweep/outputs/)
  - [`experiments/np-sweep/outputs/`](../../experiments/np-sweep/outputs/)
- Extraction script: [`results/scripts/extract_sweeps.py`](../../results/scripts/extract_sweeps.py)
- Raw marker check: each included stdout contains a `PASSED` residual marker
  and a finite `GFLOPS` report matching the CSV row.
- Analysis date: 2026-08-20
