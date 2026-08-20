# Analysis: FP64 matrix memory placement

## 1. Concise summary

This analysis evaluates the authorized FP64 matrix-memory-placement results.
The tested workload uses `N=399360`, `NB=3072`, an eight-process `4x2`
column-major grid, GPU affinity `0:1:2:3:4:5:6:7`, `--sloppy-type FP16`, and
`--Anq-device 0`. The placement runs enable `--fill-device 1` and vary
`--fill-device-buffer-size`; all recorded runs use
`--cuda-host-register-step 2048`.

The default fill-device setting (`buffer-size=3048`) is the best recorded
placement result at `2.1763e+06` GFLOP/s, 18.01% above the matched
`fill-device=0` control. Performance declines monotonically across the tested
larger buffers. No register-step sweep was run, so that requested group is
reported as `NOT TESTED / TBD`.

## 2. Scope and evaluation criteria

- Analysis ID: `fp64-matrix-mem-placement`
- Analysis date: 2026-08-20
- Source: [`results/metrics.csv`](../../results/metrics.csv)
- Source revision: repository commit `4f4d854`
- Included placement rows: `matrix-placement-control/fill_device_default`,
  `buffer_sweep_8192`, `buffer_sweep_16384`, and `buffer_sweep_32768`.
- Baseline references: the project baseline `baseline-sweep_v1` and the
  matched `np-sweep/4x2_col` control at the same `N`, `NB`, grid, and order.
- Correctness gate: `verification=PASSED`, finite residual, and finite
  reported GFLOP/s. All four placement rows and both references pass.
- Performance metric: reported HPL-MxP GFLOP/s from `metrics.csv`.
- Runtime, completion time, and PBS exit status were not available for most
  rows and were not used for ranking.
- Register-step group: no CSV row or raw output exists for a changed
  `--cuda-host-register-step`; result is `NOT TESTED / TBD`, with no inferred
  performance value.

## 3. Data and analysis

### Baseline

| Reference | Fill-device setting | N | NB | Grid/order | GFLOP/s | Percentage vs original baseline | Verification |
|---|---|---:|---:|---|---:|---:|---|
| `baseline-sweep_v1` | `fill-device=0`, buffer `3048` | 370000 | 1024 | 2x4 row | `1.4432e+06` | `0.00%` | PASSED |
| `np-sweep/4x2_col` | `fill-device=0`, buffer `3048` | 399360 | 3072 | 4x2 column | `1.8441e+06` | `+27.78%` | PASSED |

The `4x2` column result is the appropriate matched control for isolating the
placement flags. It is 27.78% above the project baseline because it also uses
the improved matrix size, panel size, and process-grid/order configuration.

### Default fill

| Attempt | Fill-device | Buffer size | Register step | Node | Residual marker | GFLOP/s | Percentage vs original baseline | vs matched control |
|---|---:|---:|---:|---|---|---:|---:|---:|
| `fill_device_default` | 1 | 3048 | 2048 | `hpc-gaas-g11` | PASSED (`3.851395E-04`) | `2.1763e+06` | `+50.80%` | `+18.01%` |

The default fill-device run is the highest result in this group and is also
50.80% above the project baseline. It is a single attempt, so the improvement
requires repetition before being treated as a stable effect.

### Buffer sweep

| Attempt | Fill-device | Buffer size | Register step | Node | Residual marker | GFLOP/s | Percentage vs original baseline | vs matched control |
|---|---:|---:|---:|---|---|---:|---:|---:|
| `buffer_sweep_8192` | 1 | 8192 | 2048 | `hpc-gaas-g11` | PASSED (`3.628577E-04`) | `2.1420e+06` | `+48.42%` | `+16.15%` |
| `buffer_sweep_16384` | 1 | 16384 | 2048 | `hpc-gaas-g14` | PASSED (`3.659648E-04`) | `2.0709e+06` | `+43.49%` | `+12.30%` |
| `buffer_sweep_32768` | 1 | 32768 | 2048 | `hpc-gaas-g15` | PASSED (`5.224120E-04`) | `1.9673e+06` | `+36.32%` | `+6.68%` |

The recorded performance decreases as the buffer size increases from 3048 to
32768. The 8192 result remains 16.15% above the matched control, while 32768
retains only a 6.68% advantage. This is a monotonic trend across four single
measurements, not a repeated estimate of the curve.

### Register step

| Configuration | Result | Percentage vs original baseline |
|---|---|---:|
| Changed `--cuda-host-register-step` | `NOT TESTED / TBD`; no CSV row, raw output, or performance value exists | `TBD` |

All four placement outputs show `--cuda-host-register-step = 2048`, so this
parameter is held constant rather than evaluated in the current data.

## 4. Insights gained

- Enabling `--fill-device 1` with the observed default buffer size of 3048 is
  the strongest recorded placement result: `2.1763e+06` GFLOP/s.
- Larger tested buffer sizes regress monotonically relative to the default:
  8192 is -1.58% from default, 16384 is -4.85%, and 32768 is -9.61%.
- All placement results remain above the matched `fill-device=0` control, but
  this is based on one attempt per configuration.
- The placement runs span nodes `hpc-gaas-g11`, `g14`, and `g15`; node
  variation and unavailable runtime metadata limit causal confidence.
- The data does not support a conclusion about `--cuda-host-register-step`
  because no changed-step configuration was executed.
- No scientific correctness regressions were observed: all included rows have
  finite residuals and `PASSED` verification.

## 5. Suggested next section

For user review, repeat `fill_device_default` and the matched
`fill-device=0` control on comparable nodes, retaining runtime and exact
launch metadata. If the fill-device improvement reproduces, test a small
buffer refinement around 3048 and 8192. Separately, prepare a controlled
register-step sweep that keeps fill-device and buffer size fixed, records the
actual step values, and includes an unchanged-step control.

Require `PASSED` verification and a repeatable improvement over the matched
control before adopting a placement or register-step setting. This suggestion
does not authorize a new experiment or configuration change.

## 6. Provenance

- Structured source: [`results/metrics.csv`](../../results/metrics.csv)
- Validated report: [`results/RESULTS.md`](../../results/RESULTS.md)
- Experiment metadata: [`experiments/matrix-placement-control/README.md`](../../experiments/matrix-placement-control/README.md)
- Raw placement evidence:
  - [`fill_device_default.o`](../../experiments/matrix-placement-control/outputs/fill_device_default.o)
  - [`buffer_sweep_8192.o`](../../experiments/matrix-placement-control/outputs/buffer_sweep_8192.o)
  - [`buffer_sweep_16384.o`](../../experiments/matrix-placement-control/outputs/buffer_sweep_16384.o)
  - [`buffer_sweep_32768.o`](../../experiments/matrix-placement-control/outputs/buffer_sweep_32768.o)
- Matched control: [`4x2_col.o`](../../experiments/np-sweep/outputs/4x2_col.o)
- Project baseline: [`baseline-sweep_v1.o`](../../experiments/baseline-sweep/outputs/baseline-sweep_v1.o)
- Analysis source revision: `4f4d854`
