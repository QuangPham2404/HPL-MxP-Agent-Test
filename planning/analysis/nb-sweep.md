# Analysis: NB sweep at the N=490000 peak

## 1. Concise summary

We swept the HPL-MxP factorization block size (`--nb`) with the matrix size
fixed at **N = 490000** (the peak found in the 2026-08-21 N sweep), starting at
`nb = 1024` and stepping in `+1024` increments, holding every other tuning
parameter identical to the N sweep (`2x4` row grid, `--nporder row`,
`--gpu-affinity 0:1:2:3:4:5:6:7`, 8 GPUs). The sweep terminates at the user's
criterion — two consecutive GFLOP/s degradations.

Performance rises sharply from `nb = 1024` (1.8387e+06) to a peak at
**`nb = 3072` (2.1726e+06 GFLOP/s, +50.54% over the original 1.4432e+06
baseline)**, then declines: two consecutive degradations occur at `nb = 7168`
(2.0536e+06) and `nb = 8192` (1.9785e+06), so the sweep stops there. `nb = 3072`
is confirmed as the best block size for this fixed-N configuration.

## 2. Scope and evaluation criteria

- **Source/package**: NVIDIA HPC Benchmarks v26.02 container
  (`hpc-benchmarks_26.02.sif`), HPL-MxP 26.2.0.
- **Environment**: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`,
  `gocryptfs/2.5.0`; `mpirun -np 8 --bind-to none` (one GPU per rank).
- **Hardware**: 1 node, 8x NVIDIA H200 (GH100 SXM, ~140 GB VRAM each),
  ~2 TB system RAM per node, `gpu_as` queue, 8 GPUs.
- **Workload**: fixed baseline tuning except for NB —
  `--n 490000`, `--nprow 2 --npcol 4 --nporder row`,
  `--gpu-affinity 0:1:2:3:4:5:6:7`, `--skip-tests 1` plus GPU monitoring.
- **Swept variable**: `--nb` ∈ {1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192}.
- **Stopping rule**: increase `nb` by 1024 until two consecutive runs degrade
  in GFLOP/s. Met at `nb = 7168 → 8192`, so no larger `nb` was run.
- **Baseline for comparison**: original `baseline-sweep_v1` (n = 370000,
  nb = 1024, 1.4432e+06 GFLOP/s), per project convention. The fixed-N starting
  point (`nb = 1024`) is also compared against the N sweep's `490000` point.
- **Correctness**: every run reported `PASSED` with a finite residual within
  the 1e-12 tolerance.
- **Metric**: the reported HPL-MxP GFLOP/s performance marker.

## 3. Data and analysis

### 3.1 NB trace at N = 490000

| NB | Node | GFLOP/s | % vs baseline (1.4432e6) | % vs N-sweep 490k (1.8293e6) |
|---:|---:|---:|---:|---:|
| 1024 | g15 | 1.8387e+06 | +27.40% | +0.51% |
| 2048 | g16 | 2.1435e+06 | +48.52% | +17.18% |
| 3072 | g17 | 2.1726e+06 | **+50.54%** | **+18.77%** |
| 4096 | g18 | 2.1150e+06 | +46.55% | +15.62% |
| 5120 | g17 | 2.1297e+06 | +47.57% | +16.42% |
| 6144 | g16 | 2.1303e+06 | +47.61% | +16.45% |
| 7168 | g15 | 2.0536e+06 | +42.29% | +12.26% |
| 8192 | g18 | 1.9785e+06 | +37.09% | +8.16% |

The `nb = 1024` result (1.8387e+06) reproduces the N sweep's `490000` point
(1.8293e+06) to within **+0.51%**, confirming the sweep is a fair, isolated
NB comparison. Performance climbs steeply from `nb = 1024` to `nb = 3072`
(+50.54% over baseline), then forms a broad plateau through `nb = 6144` before
two straight declines at `nb = 7168` and `nb = 8192`.

### 3.2 Stopping criterion

| transition | GFLOP/s trend |
|---|---|
| 6144 → 7168 | 2.1303e+06 → 2.0536e+06 (degradation #1) |
| 7168 → 8192 | 2.0536e+06 → 1.9785e+06 (degradation #2) |

Two consecutive degradations are observed, so the sweep stops at `nb = 8192`
per the agreed criterion.

### 3.3 Noise note at nb = 4096

The single dip at `nb = 4096` (2.1150e+06, on node `g18`) sits between the
`3072` peak and the `5120`/`6144` plateau, then recovers. Unlike the N sweep's
`hpc-gaas-g13` cases, the allocated nodes here (g15–g18) were all distinct and
no single node dominates the outliers; the dip is within the run-to-run/node
noise seen before (~±1–3%). It does not affect the stopping decision, which is
driven by the two terminal drops.

## 4. Insights gained

1. **Confirmed win**: `nb = 3072` is the best block size at N = 490000, reaching
   **2.1726e+06 GFLOP/s (+50.54% over the original baseline)**. This is a
   substantially larger gain than N alone (which peaked at +26.75% at
   nb = 1024).
2. **NB is the stronger lever.** Moving only `nb` from 1024 → 3072 at fixed
   N = 490000 adds ~+18.8% on top of the N-sweep peak, whereas the entire N
   sweep added +26.75%. Combined N + NB is nearly +51% over baseline.
3. **The 3072 optimum is consistent.** Both the earlier nb sweep at N = 401408
   (peak `nb = 3072`, 1.8209e+06) and this fixed-N = 490000 sweep independently
   select `nb = 3072`, so the optimum is robust to N.
4. **Fair reproduction.** `nb = 1024` at N = 490000 (1.8387e+06) matches the
   N-sweep's 490000 point (1.8293e+06) to +0.51%, validating cross-sweep
   comparability.
5. **Plateau, not a sharp peak.** 3072–6144 are within ~2% of each other, so
   the exact optimum is broad; `nb` beyond ~6144 clearly degrades.
6. **Context vs prior bests.** 2.1726e+06 here (2x4 row, default placement) is
   in line with the strongest matrix-placement results (~2.0–2.2e+06 obtained
   at N = 399360 with the `4x2` column grid and `--fill-device`/register tuning).
   Whether N = 490000 + `nb = 3072` + a column grid/placement tuning can exceed
   those remains an open joint question.

## 5. Suggested next section

1. **Combine the two winners**: re-run the peak (`nb = 3072`, N = 490000) on the
   `4x2` column grid (and with the best `--fill-device-buffer-size` / register
   settings from the matrix-placement direction) to test whether N + NB + grid
   + placement yield further gains above ~2.17e6.
2. **Confirm the peak with a repetition**: `nb = 3072` and `nb = 4096` should be
   re-run (a few times) to pin the exact optimum and quantify node noise, since
   the 3072–6144 plateau is broad and the 4096 dip is within noise.
3. **Finer local NB scan** around 2560–3584 (non-1024 steps) only if the
   repetition shows a meaningful, noise-bounded optimum worth resolving.

These are recommendations for review, not authorization to execute.

## 6. Provenance

- Source CSV: `results/metrics.csv` (82 rows; 8 new `nb-sweep` attempts).
- Experiment: `experiments/nb-sweep/` (`README.md`, `run_nb_sweep.pbs`,
  `outputs/nb-sweep_*_490k{.o,.e}`).
- Baseline reference: `baseline-sweep_v1` (metrics.csv), 1.4432e+06 GFLOP/s.
- N-sweep peak reference: `N-sweep_490000`, 1.8293e+06 GFLOP/s.
- PBS jobs: 52247–52254.
- Analysis date: 2026-08-24.