# Analysis: Dependency priorities (prioritize-trsm / prioritize-factorization)

## 1. Concise summary

This analysis tests the two LU-scheduling dependency-priority flags —
`--prioritize-trsm` (whether GEMMs wait for U TRSMs) and
`--prioritize-factorization` (whether GEMMs wait for factorizations) — at the
fixed best configuration, following the MPI/NCCL communication study's
recommendation to target the panel-readiness stalls visible in the Nsight trace
rather than the transport mix.

`--prioritize-factorization 1` is a clear winner: it raises LU GFLOP/s by
~6.6% and end-to-end GFLOP/s by ~+3.5% over the same-node control, producing a
new best result of `2.4203e+06` (≈ `+67.70%` over the original baseline and
`+0.96%` over the previous master best of `2.3974e+06`). `--prioritize-trsm`
is neutral (LU and end-to-end scores are within noise of control), and
combining both flags does not add over factorization-only. All four attempts
ran on the same node, `hpc-gaas-g16`, so the comparison is not subject to
cross-node drift, but each point is a single un-repeated run.

## 2. Scope and evaluation criteria

### Configuration

HPL-MxP v26.02, `N=491520`, `NB=3072`, `2x4` row grid,
`--gpu-affinity 0:1:2:3:4:5:6:7`, no CPU/memory affinity,
`OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`,
`--fill-device 1 --fill-device-buffer-size 2048 --cuda-host-register-step 2048`,
`--use-mpi-panel-broadcast` and `--u-panel-chunk-nbs` at package defaults
(observed `50` and `8`), `--skip-tests 1`, GPU monitoring enabled. Eight MPI
processes on eight GPUs, node `hpc-gaas-g16`, one PBS job looping all four
combinations.

### Baseline

The required original project baseline is `1.4432e+06` GFLOP/s
(`baseline-sweep_v1`, N=370000, NB=1024, 2x4). The previous master best prior
to this experiment is `2.3974e+06` (`matrix-placement-control`/`491k_reg_1536`).
The in-experiment control is `fp_0_0` (both flags 0), which measures `2.3375e+06`
on `hpc-gaas-g16`.

### Correctness

Every attempt reports `PASSED` with the same three solver residuals
(`3.20790056e-05`, `7.14561163e-11`, `4.76949480e-14`) and a finite final
residual `1.609604E-04`.

## 3. Data and analysis

### 3.1 End-to-end results

| Attempt | `--prioritize-trsm` | `--prioritize-factorization` | GFLOP/s | LU GFLOP/s | Iterative solver (s) | % vs original baseline | % vs control (fp_0_0) |
|---|---:|---:|---:|---:|---:|---:|---:|
| fp_0_0 (control) | 0 | 0 | 2.3375e+06 | 3.8849e+06 | 13.49 | +61.97% | 0.00% |
| fp_0_1 | 0 | 1 | 2.4203e+06 | 4.1396e+06 | 13.58 | +67.70% | +3.54% |
| fp_1_0 | 1 | 0 | 2.3352e+06 | 3.8964e+06 | 13.58 | +61.81% | -0.10% |
| fp_1_1 | 1 | 1 | 2.4121e+06 | 4.1316e+06 | 13.66 | +67.14% | +3.19% |

The factorization flag is the deciding factor. `fp_0_1`
(`--prioritize-factorization 1`) is the best configuration at `2.4203e+06`,
beating the previous master best (`2.3974e+06`) by `+0.96%` and the control by
`+3.54%`. Setting `--prioritize-trsm 1` alone leaves the score essentially
unchanged (`-0.10%`), and adding it on top of factorization
(`fp_1_1` = `2.4121e+06`) is slightly below factorization-only.

### 3.2 Mechanism

The gain comes from the LU phase, which is the panel factorizations and the
U-side triangular solves. The LU GFLOP/s values isolate the effect:

- factorization 0 (fp_0_0, fp_1_0): LU ≈ `3.88–3.90e+06`.
- factorization 1 (fp_0_1, fp_1_1): LU ≈ `4.13–4.14e+06`, about `+6.4–6.6%`.

The end-to-end gain is smaller (`+3.5%`) because the iterative-solver phase is
unchanged (`13.5–13.7 s` across all four) and dilutes the LU-phase speedup in
the reported total score. This is consistent with the flag's meaning: making
the factorization available earlier lets the GEMMs overlap more of the panel
dependency, shortening the LU critical path without touching the solver.

The TRSM flag has no measurable effect in either LU rate or end-to-end score,
suggesting that the U-TRSM wait is not a limiting dependency at this problem
size and grid shape, or that its benefit is negligible relative to the
factorization path.

## 4. Insights gained

- `--prioritize-factorization 1` is a confirmed, repeatable-in-kind lever:
  LU `+6.6%`, end-to-end `+3.5%`, and a **new best result** `2.4203e+06`
  (`+67.70%` over the original baseline).
- `--prioritize-trsm 1` provides no measurable benefit, alone or combined.
- The factorization gain is entirely in the LU phase; the iterative solver is
  untouched, which caps the end-to-end improvement.
- All four runs share one node and match the historical residual, so the
  comparison is clean, but each configuration is a single run. The `+3.5%`
  factorization win is well above the ~1% same-node control drift seen in prior
  sweeps, yet should be confirmed with one repeated same-node run before
  adoption.

## 5. Suggested next section

Adopt `--prioritize-factorization 1` and keep `--prioritize-trsm` at its
default `0` as the new shipping configuration (raise the current baseline to
`fp_0_1` = `2.4203e+06` after confirmation).

Next-steps hypothesis and controls:

1. Repeat `fp_0_1` once more on a different/comparable node (and re-run the
   `fp_0_0` control alongside) to confirm the `+3.5%` margin is not node
   noise.
2. If confirmed, the remaining untested orthogonal levers are the compute
   path: `--preset-gemm-kernel` (e.g. SM90 kernel 90 vs default 0),
   `--sloppy-type` (`FP4`/`FP8` vs current `FP16`), `--use-separate-stream-for-gemm`,
   and conditional `--Anq-device` residency. These directly target the dominant
   `nvjet` compute kernel, which was unchanged by every scheduling lever so far.

This is a recommendation for review, not authorization to start new runs.

## 6. Provenance

- Source data: [`results/metrics.csv`](../results/metrics.csv), rows
  `factorization-priority-test/fp_0_0`, `fp_0_1`, `fp_1_0`, `fp_1_1`.
- Raw outputs:
  [`experiments/factorization-priority-test/outputs/fp_*.{o,e}`](../experiments/factorization-priority-test/outputs/).
- Experiment metadata:
  [`experiments/factorization-priority-test/README.md`](../experiments/factorization-priority-test/README.md).
- Original baseline: `baseline-sweep_v1` (`1.4432e+06`).
- Previous master best: `matrix-placement-control/491k_reg_1536` (`2.3974e+06`).
- PBS job `55591.gaas`, node `hpc-gaas-g16`.
- Analysis date: `2026-08-31`.