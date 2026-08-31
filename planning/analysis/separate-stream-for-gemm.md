# Analysis: Separate stream for GEMM (`--use-separate-stream-for-gemm`)

## 1. Concise summary

This analysis toggles `--use-separate-stream-for-gemm` (whether GEMMs run in
their own CUDA stream) at the current best configuration, which already
includes `--prioritize-factorization 1`.

Keeping the separate GEMM stream enabled (the package default `1`) is clearly
better. Turning it off (`0`) lowers LU GFLOP/s by `-3.73%` and end-to-end
GFLOP/s by `-1.89%` relative to the same-node control. The default `1` therefore
remains the recommended setting, and the current best configuration is
unchanged.

## 2. Scope and evaluation criteria

### Configuration

HPL-MxP v26.02, `N=491520`, `NB=3072`, `2x4` row grid,
`--gpu-affinity 0:1:2:3:4:5:6:7`, no CPU/memory affinity,
`OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`,
`--fill-device 1 --fill-device-buffer-size 2048 --cuda-host-register-step 2048`,
`--prioritize-factorization 1` (`--prioritize-trsm` default 0),
`--use-mpi-panel-broadcast` and `--u-panel-chunk-nbs` at defaults (50/8),
`--skip-tests 1`, GPU monitoring enabled. Eight MPI processes on eight GPUs,
node `hpc-gaas-g16`, one PBS job looping both attempts.

### Baseline

The required original project baseline is `1.4432e+06` GFLOP/s. The current
best configuration is `2.4203e+06` (`factorization-priority-test`/`fp_0_1`,
`--prioritize-factorization 1`). The `ss_1` control in this experiment
re-measures that same configuration at `2.4162e+06` (≈ `-0.17%` from the prior
run, within same-node session noise).

### Correctness

Both attempts report `PASSED` with the same solver residuals and a finite final
residual `1.609604E-04`.

## 3. Data and analysis

| Attempt | separate-stream | GFLOP/s | LU GFLOP/s | % vs original baseline | % vs control (ss_1) |
|---|---:|---:|---:|---:|---:|
| ss_1 (control = current best) | 1 | 2.4162e+06 | 4.1275e+06 | +67.42% | 0.00% |
| ss_0 | 0 | 2.3705e+06 | 3.9734e+06 | +64.25% | -1.89% |

Disabling the separate GEMM stream reduces the LU phase rate from
`4.1275e+06` to `3.9734e+06` (`-3.73%`), which propagates to a `-1.89%`
end-to-end loss after the unchanged iterative-solver phase dilutes it. This is
consistent with the flag's purpose: without a dedicated stream, GEMMs serialize
against factorizations/TRSMs on the shared stream, reducing overlap on the LU
critical path. The result is directionally meaningful (well above the ~1%
same-node control drift) but was measured on a single node with one run per
setting.

## 4. Insights gained

- The separate GEMM stream is a real, though modest, contributor: disabling it
  costs `-1.89%` end-to-end and `-3.73%` in the LU phase.
- The package default (`1`) is correct; there is no reason to change it.
- Combined with the prior factorization-priority result, the effective shipping
  config remains: `--prioritize-factorization 1` and
  `--use-separate-stream-for-gemm 1` (default), with the current best score
  ≈ `2.416–2.420e+06` (`+67.4%` over the original baseline).

## 5. Suggested next section

Keep `--use-separate-stream-for-gemm 1` (no change). This scheduling lever is
now closed together with the dependency-priority and panel-broadcast levers:
the LU-scheduling axis is saturated for this workload.

The remaining untested orthogonal direction is the compute/precision path,
which directly targets the dominant (and so far unchanged) `nvjet` kernel:
`--preset-gemm-kernel` (e.g. SM90 kernel `90` vs default `0`), `--sloppy-type`
(`FP4`/`FP8` vs current `FP16`), and conditional `--Anq-device` residency.
Evaluate these with repeated clean runs, `PASSED` verification, finite
residuals, and end-to-end GFLOP/s improvement over the `2.420e+06` control.

This is a recommendation for review, not authorization to start new runs.

## 6. Provenance

- Source data: [`results/metrics.csv`](../results/metrics.csv), rows
  `separate-stream-for-gemm/ss_0`, `ss_1`.
- Raw outputs:
  [`experiments/separate-stream-for-gemm/outputs/ss_*.{o,e}`](../experiments/separate-stream-for-gemm/outputs/).
- Experiment metadata:
  [`experiments/separate-stream-for-gemm/README.md`](../experiments/separate-stream-for-gemm/README.md).
- Original baseline: `baseline-sweep_v1` (`1.4432e+06`).
- Prior best: `factorization-priority-test/fp_0_1` (`2.4203e+06`).
- PBS job `55620.gaas`, node `hpc-gaas-g16`.
- Analysis date: `2026-08-31`.