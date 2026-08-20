# Optimization Plans

## Current baseline

- Baseline run: `baseline-sweep_v1` — n=370000, nb=1024, 2x4 row,
  1.4432e+06 GFLOPS, PASSED.

## Optimization directions

| Direction | Analysis ID/file | Analysis date | Scope | Status | Main finding | Suggested follow-up |
|---|---|---|---|---|---|---|
| N / NB / grid sweep review | `planning/analysis/sweep-data-review.md` | 2026-08-19 | all recorded sweeps | Analyzed | NB=3072 (4x2 column) is the best recorded config: 1.8441e+06 GFLOPS (~28% over baseline); NB is the strongest lever; N-sweep_402k is a ~half-performance anomaly | Re-run N-sweep_402k; finer NB scan around 3072; joint NB+N scan at 4x2 column |
| Basic parameter sweep | `planning/analysis/basic_params_sweep.md` | 2026-08-20 | all 19 rows in `results/metrics.csv` | Analyzed | Best recorded result is N=399360, NB=3072, 4x2 column at 1.8441e+06 GFLOP/s (27.78% over baseline); NB and grid shape/order are confirmed levers; N-sweep_402k remains anomalous | Repeat N-sweep_402k and the best candidate; refine NB and N at 4x2 column with repetitions |
| Basic parameter sweep 2 | `planning/analysis/basic_param_sweep2.md` | 2026-08-20 | all 19 rows in `results/metrics.csv` | Analyzed | NB=3072 is the sampled local peak; 4x2 column gives the best tested grid; best result is 1.8441e+06 GFLOP/s (27.78% over baseline); N-sweep_402k remains a performance anomaly | Repeat the best candidate and the N-sweep_402k anomaly; locally refine NB and N at 4x2 column with repeated controls |

## Next direction

Repeat the `N-sweep_402k` anomaly and the current best candidate, then run a
joint local NB/N scan at the 4x2 column grid to confirm the NB=3072 region and
the best N. Awaiting user confirmation before preparing the next experiment.
