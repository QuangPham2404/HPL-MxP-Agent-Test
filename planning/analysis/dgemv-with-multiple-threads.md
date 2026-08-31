# Analysis: dgemv-with-multiple-threads (`--call-dgemv-with-multiple-threads`)

## 1. Concise summary

This analysis sweeps `--call-dgemv-with-multiple-threads` (the number of rows
each host thread works on when dgemv is called with multiple threads) over
`0, 128, 256, 384, 512, 640` at the current best configuration.

The default `0` (single-threaded dgemv) is clearly optimal. Every non-zero
value is slower, ranging from `-3.37%` (`512`) to `-12.72%` (`256`) end-to-end,
with no monotonic or favorable trend. The effect is confined to the iterative
solver phase — where the dgemv calls live — whose time rises from `13.52 s`
(control) to as much as `18.22 s` (`256`), while the LU phase is essentially
unchanged (`~4.12–4.14e+06`). This flag is therefore a strict regression when
departed from its default, and the current best configuration is unchanged.

## 2. Scope and evaluation criteria

### Configuration

HPL-MxP v26.02, `N=491520`, `NB=3072`, `2x4` row grid,
`--gpu-affinity 0:1:2:3:4:5:6:7`, no CPU/memory affinity,
`OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`,
`--fill-device 1 --fill-device-buffer-size 2048 --cuda-host-register-step 2048`,
`--prioritize-factorization 1` (`--prioritize-trsm` default 0),
`--use-separate-stream-for-gemm` default 1, `--use-mpi-panel-broadcast` and
`--u-panel-chunk-nbs` at defaults (50/8), `--skip-tests 1`, GPU monitoring
enabled. Eight MPI processes on eight GPUs, node `hpc-gaas-g16`, one PBS job
looping all six attempts.

### Baseline

The required original project baseline is `1.4432e+06` GFLOP/s. The current
best configuration measures `2.4203e+06` (`fp_0_1`) / `2.4162e+06` (`ss_1`);
the `dgemv_0` control here re-measures the same config at `2.4252e+06` (within
same-node session noise of the prior two, actually slightly higher).

### Correctness

All six attempts report `PASSED` with identical solver residuals and a finite
final residual `1.609604E-04`.

## 3. Data and analysis

| Attempt | dgemv-mt | GFLOP/s | LU GFLOP/s | Iterative solver (s) | % vs original baseline | % vs control (dgemv_0) |
|---|---:|---:|---:|---:|---:|---:|
| dgemv_0 (control) | 0 | 2.4252e+06 | 4.1394e+06 | 13.52 | +68.04% | 0.00% |
| dgemv_128 | 128 | 2.1552e+06 | 4.1350e+06 | 17.59 | +49.33% | -11.13% |
| dgemv_256 | 256 | 2.1166e+06 | 4.1280e+06 | 18.22 | +46.66% | -12.72% |
| dgemv_384 | 384 | 2.1940e+06 | 4.1333e+06 | 16.93 | +52.02% | -9.53% |
| dgemv_512 | 512 | 2.3435e+06 | 4.1210e+06 | 14.57 | +62.38% | -3.37% |
| dgemv_640 | 640 | 2.2940e+06 | 4.1299e+06 | 15.34 | +58.95% | -5.41% |

The LU phase is flat across the whole sweep (`4.12–4.14e+06`), confirming the
flag does not touch the factorization/GEMM critical path. The entire effect is
in the iterative solver: solver time is minimized at `0` (`13.52 s`) and rises
for every non-zero setting, peaking at `256` (`18.22 s`, `+4.7 s`). Since the
reported GFLOP/s is dominated by the solver phase at this problem size, the
solver slowdown maps directly to the end-to-end regression. There is no
non-zero value worth keeping: the sweep is a strict loss versus control, and
the mild drop from `512`/`640` relative to `128`/`256`/`384` is not a usable
minimum — it is still `-3%` to `-5%` below the default.

## 4. Insights gained

- `--call-dgemv-with-multiple-threads 0` (default, single-threaded dgemv) is
  correct; multi-threading the host dgemv only adds synchronization/spawn
  overhead to the solver with no LU benefit.
- The flag's impact is isolated to the iterative-solver phase, providing a
  clear mechanism: solver time rises by up to `+4.7 s` while LU is unchanged.
- This lever is a strict regression and is now closed; the default should be
  retained.
- The control `2.4252e+06` (same config as the current best) remains the
  highest single measurement, consistent with `~2.42e+06` being the true
  shipping score (≈ `+68%` over the original baseline).

## 5. Suggested next section

Keep `--call-dgemv-with-multiple-threads 0` (no change). This is the last of
the LU-scheduling / host-threading levers targeted so far; the full set
(panel-broadcast, U-panel chunk size, dependency priorities, separate GEMM
stream, and dgemv multi-threading) is now closed, with `--prioritize-factorization 1`
being the only retained change over the earlier buffer/register-step best.

The remaining untested orthogonal direction is the compute/precision path,
which directly targets the dominant `nvjet` kernel: `--preset-gemm-kernel`
(e.g. SM90 kernel `90` vs default `0`), `--sloppy-type` (`FP4`/`FP8` vs current
`FP16`), and conditional `--Anq-device` residency. Evaluate these with repeated
clean runs, `PASSED` verification, finite residuals, and end-to-end GFLOP/s
improvement over the `~2.420e+06` control.

This is a recommendation for review, not authorization to start new runs.

## 6. Provenance

- Source data: [`results/metrics.csv`](../results/metrics.csv), rows
  `dgemv-with-multiple-threads/dgemv_0`, `dgemv_128`, `dgemv_256`, `dgemv_384`,
  `dgemv_512`, `dgemv_640`.
- Raw outputs:
  [`experiments/dgemv-with-multiple-threads/outputs/dgemv_*.{o,e}`](../experiments/dgemv-with-multiple-threads/outputs/).
- Experiment metadata:
  [`experiments/dgemv-with-multiple-threads/README.md`](../experiments/dgemv-with-multiple-threads/README.md).
- Original baseline: `baseline-sweep_v1` (`1.4432e+06`).
- Current best: `factorization-priority-test/fp_0_1` (`2.4203e+06`).
- PBS job `55643.gaas`, node `hpc-gaas-g16`.
- Analysis date: `2026-09-01`.