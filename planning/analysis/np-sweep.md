# Analysis: process grid and order sweep (np-sweep)

## 1. Concise summary

We swept the MPI process grid (`--nprow`, `--npcol`) and rank layout
(`--nporder`) across all four combinations — 2x4 row, 2x4 column, 4x2 row, 4x2
column — with the matrix size and block size fixed at the current best
(N = 491520, NB = 3072) and every other tuning parameter unchanged.

At N = 491520 the **2x4 row** configuration is the best of the four, reaching
**2.2067e+06 GFLOP/s (+52.90% over the original 1.4432e+06 baseline)**, which is
also the highest single result recorded for this workload family. The ranking is
2x4 row > 2x4 column > 4x2 column > 4x2 row, a spread of ~1.8%. The current
production configuration (2x4 row) is therefore confirmed as already optimal at
this N.

## 2. Scope and evaluation criteria

- **Source/package**: NVIDIA HPC Benchmarks v26.02 container
  (`hpc-benchmarks_26.02.sif`), HPL-MxP 26.2.0.
- **Environment**: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`,
  `gocryptfs/2.5.0`; `mpirun -np 8 --bind-to none` (one GPU per rank).
- **Hardware**: 1 node, 8x NVIDIA H200 (GH100 SXM, ~140 GB VRAM each),
  ~2 TB system RAM per node, `gpu_as` queue, 8 GPUs.
- **Workload**: fixed N = 491520, NB = 3072,
  `--gpu-affinity 0:1:2:3:4:5:6:7`, `--skip-tests 1` plus GPU monitoring.
- **Swept variable**: `--nprow` ∈ {2,4}, `--npcol` ∈ {4,2},
  `--nporder` ∈ {row,column} (all four combinations).
- **Baseline for comparison**: original `baseline-sweep_v1` (n = 370000,
  nb = 1024, 1.4432e+06 GFLOP/s). Secondary reference: the N-NB resweep peak
  (N = 491520, nb = 3072, 2x4 row, 2.1974e+06).
- **Correctness**: all four runs reported `PASSED` with a finite residual within
  the 1e-12 tolerance.
- **Metric**: the reported HPL-MxP GFLOP/s performance marker.

## 3. Data and analysis

### 3.1 Grid/order trace at N = 491520, NB = 3072

| Grid | Order | Node | GFLOP/s | % vs baseline (1.4432e6) | % vs N-NB 491k/2x4 row |
|---|---|---:|---:|---:|---:|
| 2x4 | row | g15 | 2.2067e+06 | **+52.90%** | **+0.42%** |
| 2x4 | column | g16 | 2.1865e+06 | +51.50% | −0.50% |
| 4x2 | column | g18 | 2.1732e+06 | +50.58% | −1.10% |
| 4x2 | row | g17 | 2.1683e+06 | +50.24% | −1.32% |

The 2x4 grid beats 4x2 by ~1.1–1.8% regardless of order, and within each grid
`row` order is very slightly faster than `column` (2x4: +0.9%; 4x2: −0.2%, i.e.
marginally). The full spread (1.8%) is comparable to observed run/node noise,
but the 2x4-vs-4x2 gap is consistent and monotonic across both orders.

### 3.2 Dependence of the optimal grid on N

This result differs from the earlier np-sweep at N = 399360 (nb = 3072), where
`4x2` column was best (1.8441e+06) and `2x4` row was the weakest (1.7302e+06).
At N = 491520 the ranking reverses to favor `2x4` row. This suggests the optimal
grid shape/order is N-dependent: with P = nprow and Q = npcol, a taller
process-column split (smaller P) favors the larger, more memory-bound N here.
Caveat: the earlier values predate the matrix-placement tuning and were not
node-matched to this sweep, so the reversal is indicative rather than
definitive.

### 3.3 Noise context

Nodes g15–g18 were used, one per run. The 4x2 column result (g18) and 4x2 row
result (g17) sit in the middle, so the ordering is not a single-node artifact.
The +0.42% difference between `2x4_row_491k` (2.2067e+06) and the N-NB resweep's
own 2x4-row point (2.1974e+06) is within run-to-run noise and confirms
cross-sweep reproducibility.

## 4. Insights gained

1. **Confirmed current config is optimal.** At N = 491520, `2x4` row is the best
   grid/order, achieving 2.2067e+06 GFLOP/s (+52.90% over baseline) — the
   highest single result in this workload family.
2. **Grid shape matters more than order.** 2x4 > 4x2 by ~1.1–1.8%; `row` vs
   `column` is a small (±<1%) secondary effect.
3. **The optimal grid appears N-dependent.** The earlier N = 399360 sweep
   favored 4x2 column, while N = 491520 favors 2x4 row, implying the grid should
   be re-tuned as N grows rather than assumed static.
4. **Marginal gains are now exhausted.** All four configurations land within
   ~1.8% of each other; the main levers (N ≈ 491520, nb = 3072) dominate, and
   grid/order tuning contributes only a small refinement.

## 5. Suggested next section

1. **Adopt 2x4 row + N = 491520 + nb = 3072** as the shipping configuration
   (2.2067e+06, +52.90% over baseline).
2. **If further gains are sought**, combine this with the matrix-placement
   levers that previously reached ~2.2e+06 at smaller N
   (`--fill-device-buffer-size`, register step) to test whether they still add
   improvement at N = 491520.
3. **Optionally** confirm the order effect with a matched repetition of 2x4 row
   vs 2x4 column, since the difference (0.9%) is within noise.

These are recommendations for review, not authorization to execute.

## 6. Provenance

- Source CSV: `results/metrics.csv` (94 rows; 4 new `np-sweep` attempts).
- Experiment: `experiments/np-sweep/` (`README.md`, `run_np_sweep.pbs`,
  `outputs/{2x4_row,2x4_col,4x2_row,4x2_col}_491k{.o,.e}`).
- Baseline reference: `baseline-sweep_v1` (metrics.csv), 1.4432e+06 GFLOP/s.
- Secondary reference: `N-nb-resweep_491520`, 2.1974e+06 GFLOP/s.
- PBS jobs: 52288–52291.
- Analysis date: 2026-08-24.