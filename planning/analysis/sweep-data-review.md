# Sweep Data Review

## Summary

The N, NB, and process-grid sweeps all beat the 1.4432e+06 GFLOPS baseline.
The largest, validated gain so far comes from raising the panel size to
NB=3072 and switching the process grid to a 4x2 column layout: 1.8441e+06
GFLOPS (~28% over baseline). One run, N-sweep_402k, reports roughly half the
performance of its neighbors and should be treated as an anomaly pending a
rerun before it is used in any ranking.

## Scope / evaluation criteria

- Analysis ID: `sweep-data-review`
- Source: `results/metrics.csv`
- Included: all 18 sweep attempts across `N-sweep`, `nb-sweep`, `np-sweep`,
  plus the `baseline-sweep` reference row.
- Grouping: by optimization direction (matrix size N, panel size NB, process
  grid / ordering).
- Correctness gate: only rows with `verification=PASSED` are ranked. All rows
  listed below are PASSED with finite residuals, so no row was excluded on
  correctness grounds.
- Caveat: `completion_time`, `runtime`, and `exit_status` are `unknown` in the
  recorded rows (not present in raw stdout); runs used different nodes
  (`hpc-gaas-g11`..`g16`), so node-to-node variance is possible.

## Data and analysis

### Baseline reference

| Config | n | nb | grid | order | GFLOPS |
|---|---|---|---|---|---|
| `baseline-sweep_v1` | 370000 | 1024 | 2x4 | row | 1.4432e+06 |

### N-sweep (nb=1024, 2x4, row)

| Attempt | n | GFLOPS |
|---|---|---|
| N-sweep_v1 | 400000 | 1.5569e+06 |
| N-sweep_399k | 399360 | 1.4918e+06 |
| N-sweep_400k | 400384 | 1.5751e+06 |
| N-sweep_401k | 401408 | 1.5821e+06 |
| N-sweep_402k | 402423 | 7.6797e+05  <- outlier |
| N-sweep_404k | 404000 | 1.4871e+06 |

Ignoring the outlier, the N window 400000-401408 gives 1.56-1.58e+06 GFLOPS,
about 8-10% over baseline. The spread across valid points (~1.49-1.58e+06) is
small, suggesting N has modest, non-monotonic influence near the memory wall.

### nb-sweep (n=401408, 2x4, row)

| Attempt | nb | GFLOPS |
|---|---|---|
| nb-sweep_1024 | 1024 | 1.5782e+06 |
| nb-sweep_2048 | 2048 | 1.7879e+06 |
| nb-sweep_3072 | 3072 | 1.8209e+06 |
| nb-sweep_4096 | 4096 | 1.8040e+06 |
| nb-sweep_5120 | 5120 | 1.7569e+06 |
| nb-sweep_8192 | 8192 | 1.7445e+06 |

NB is the strongest single lever so far: 1024->2048 gives +13%, 2048->3072
gives another +2%, then performance declines above 3072. Peak at NB=3072
(1.8209e+06), i.e. +26% over baseline.

The `nb-sweep` output directory also contains two N re-sweep attempts at
NB=3072: `n-resweep_399k` (n=399360, 1.8177e+06) and `n-resweep_402k`
(n=402432, 1.6981e+06). The lower value at 402432 suggests N near 401408 is
preferable at NB=3072 as well.

### np-sweep (n=399360, nb=3072)

| Attempt | grid | order | GFLOPS |
|---|---|---|---|
| 2x4_row | 2x4 | row | 1.7302e+06 |
| 2x4_col | 2x4 | column | 1.7625e+06 |
| 4x2_row | 4x2 | row | 1.8126e+06 |
| 4x2_col | 4x2 | column | 1.8441e+06 |

At NB=3072, the 4x2 grid is ~5% faster than 2x4, and column ordering is
consistently faster than row for the same grid (2x4: +1.9%; 4x2: +1.7%).
Best overall config in the recorded data: 4x2, column, n=399360, nb=3072.

## Insights

1. **Panel size (NB) dominates the tunable space so far.** Going from 1024 to
   3072 yields roughly +15% at fixed n and grid; values above 3072 regress.
2. **Process grid shape and ordering matter** and interact with NB: 4x2
   column at NB=3072 gives the best recorded result, and column ordering beats
   row in both grids tested.
3. **N is near-optimal in the 400k window** at nb=1024; the improvements over
   baseline there come largely from N and NB together, not N alone.
4. **Anomaly to resolve: `N-sweep_402k` (n=402423).** At ~7.68e+05 GFLOPS it
   is about half of its neighbors (which cluster at 1.49-1.58e+06). The run
   passed verification, so it is a performance anomaly rather than a
   correctness failure. Likely transient node contention, but it should be
   re-run before the point is used.

## Suggested next section (for user review)

- Re-run the `N-sweep_402k` case (n=402423, nb=1024, 2x4 row) to confirm
  whether the low value is reproducible.
- Explore NB around 3072 (e.g. 2560 and 3584) at the best grid, and confirm
  the best N at NB=3072 with the 4x2 column grid.
- Consider fixing the best grid/ordering (4x2 column) and scanning NB and N
  jointly rather than one parameter at a time.

## Provenance

- Structured source of truth: `results/metrics.csv` (19 rows).
- Raw evidence: `.o`/`.e` files under `experiments/{N-sweep,nb-sweep,np-sweep,baseline-sweep}/outputs/`.
- Extraction: `results/scripts/extract_sweeps.py`.
- Report: `results/RESULTS.md`.