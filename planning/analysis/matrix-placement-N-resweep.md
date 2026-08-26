# Analysis: Matrix-placement N re-sweep (fill-device=1, N down in multiples of 1024)

## 1. Concise summary

Tested the hypothesis that lowering N under `--fill-device 1` would let the full
FP64 matrix become GPU-resident, shrink the iterative-solver stage, and net a
GFLOP/s gain despite the lost N³ work. The **mechanism is confirmed** — the
iterative-solver time falls from 13.07 s (N=491520) to 4.09 s (N=368640), and
its share of runtime falls from 39.2% to 29.1% — but the **net result is null**:
GFLOP/s is flat within node noise across the tested range, because the gain in
the solver is cancelled by declining LU efficiency at smaller N. N=491520 with
`--fill-device 1` remains the recommended configuration.

## 2. Scope and evaluation criteria

- Analysis ID: `matrix-placement-N-resweep`
- Analysis date: 2026-08-26
- Source: [`results/metrics.csv`](../../results/metrics.csv)
- Fixed config (layered on `omp-sweep` + `matrix-placement-control` `491k_fill_on`):
  `--fill-device 1` (buffer 3048 and register-step 2048 left at launcher
  defaults), `--nb 3072`, `--nprow 2 --npcol 4 --nporder row`,
  `--gpu-affinity 0:1:2:3:4:5:6:7`, no CPU/memory affinity,
  `OMP_NUM_THREADS=8` + `OMP_PLACES=sockets` + `OMP_PROC_BIND=TRUE`,
  `--skip-tests 1` + GPU monitoring.
- Swept variable: `N` ∈ {491520, 460800, 430080, 399360, 368640} (multiples of
  1024; 491520 is a re-run control of `491k_fill_on`).
- References:
  - Original project baseline `baseline-sweep_v1` = **1.4432e+06**.
  - Pre-N-resweep fill-device reference `491k_fill_on` = **2.3745e+06**
    (N=491520, fill-device 1).
- Correctness: all five runs `PASSED` with finite residuals.
- Metric: reported HPL-MxP GFLOP/s, plus a phase split (LU seconds vs iterative
  solver seconds) extracted from each `.o` for the bottleneck check.

## 3. Data and analysis

### 3.1 Results

| N | GFLOP/s | vs baseline (1.4432e6) | vs 491k_fill_on (2.3745e6) | LU (s) | Solver (s) | Solver % | Node |
|---:|---:|---:|---:|---:|---:|---:|---|
| 491520 | 2.3731e+06 | +64.43% | −0.06% | 20.29 | 13.07 | 39.2% | g16 |
| 460800 | 2.3373e+06 | +61.95% | −1.57% | 17.24 | 10.67 | 38.2% | g17 |
| 430080 | 2.2828e+06 | +58.18% | −3.86% | 15.00 | 8.24 | 35.5% | g18 |
| 399360 | 2.3023e+06 | +59.53% | −3.04% | 12.36 | 6.08 | 33.0% | g19 |
| 368640 | 2.3792e+06 | +64.86% | +0.20% | 9.95 | 4.09 | 29.1% | g19 |

### 3.2 The solver hypothesis (mechanism confirms, net null)

The iterative-solver time collapses monotonically with N (13.07 → 4.09 s, a 69%
reduction), and its runtime share drops from 39.2% to 29.1%. This is direct
evidence for the proposed mechanism: at smaller N the FP64 matrix is device
resident, so the refinement stage stops paying host-device staging costs.

However, GFLOP/s does not rise. The countervailing effect is LU efficiency:
the LU stage should scale as N³, but the measured LU times exceed the N³
prediction from N=491520 by an increasing margin as N shrinks (+3% at 460800,
+10% at 430080, +13% at 399360, +16% at 368640). Smaller matrices amortise
communication/panel overhead worse, and that penalty cancels the solver gain.

### 3.3 Reading the curve

The GFLOP/s curve is not monotonic: a dip in the middle (460800–399360, ~2.28–
2.34e+06) and near-parity at both ends (491520 = 2.3731e+06 on g16; 368640 =
2.3792e+06 on g19). The 368640 result is only +0.20% above 491520 and falls on
a different node, so it is well inside the ±3–7% node noise observed across
g16/g17/g18/g19 this session. There is **no peak below 491520 to refine into**;
368640 is parity, not an optimum.

## 4. Insights gained

- **Mechanism validated:** the iterative solver is a growing fraction of runtime
  as N grows under `--fill-device 1`, and full residency (approached by N≈368640)
  cuts it from 13.07 s / 39.2% to 4.09 s / 29.1%.
- **Net effect null:** solving faster is offset by worse LU efficiency at small
  N, so GFLOP/s is flat across 368640–491520 within node noise.
- The middle range (400k–460k) is the worst region — large enough to still be
  partially host-resident, small enough to lose LU efficiency.
- N=491520 + `--fill-device 1` remains the recommended config; the hypothesis is
  **rejected as a net gain** (mechanism real, payoff zero).

## 5. Suggested next section

Do not refine this N re-sweep (no peak below 491520; the 368640 point is parity
within noise). Keep N=491520 + NB=3072 + 2x4 row + no affinity + OMP 8/sockets/
TRUE + `--fill-device 1` (+ optional buffer 1024) as the shipping config,
reaching ~2.37–2.39e+06. Remaining orthogonal levers for separate experiments:
compute/precision (`--preset-gemm-kernel`, `--sloppy-type`, `--Anq-device`),
LU scheduling (`--use-separate-stream-for-gemm`, `--prioritize-trsm`,
`--prioritize-factorization`, `--u-panel-chunk-nbs`), and panel-broadcast
(`--use-mpi-panel-broadcast`).

This suggestion does not authorize a new experiment.

## 6. Provenance

- Structured source: [`results/metrics.csv`](../../results/metrics.csv)
- Validated report: [`results/RESULTS.md`](../../results/RESULTS.md)
- Experiment metadata: [`experiments/matrix-placement-N-resweep/README.md`](../../experiments/matrix-placement-N-resweep/README.md)
- Run script: [`experiments/matrix-placement-N-resweep/run_N_resweep.pbs`](../../experiments/matrix-placement-N-resweep/run_N_resweep.pbs)
- Raw evidence: `experiments/matrix-placement-N-resweep/outputs/n_*.{o,e}` (5 attempts).
- PBS jobs: 53190–53194.
- Analysis date: 2026-08-26.