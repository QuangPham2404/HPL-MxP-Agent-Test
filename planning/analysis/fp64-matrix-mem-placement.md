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

| Attempt | Register step | Node | Residual marker | GFLOP/s | Percentage vs original baseline | vs matched buffer-32768 control |
|---|---:|---|---|---:|---:|---:|
| `reg_sweep_512` | `512` | `hpc-gaas-g14` | PASSED (`4.607964E-04`) | `1.9646e+06` | `+36.13%` | `-0.14%` |
| `reg_sweep_1024` | `1024` | `hpc-gaas-g11` | PASSED (`4.226508E-04`) | `1.9822e+06` | `+37.35%` | `+0.76%` |
| `reg_sweep_3072` | `3072` | `hpc-gaas-g11` | PASSED (`4.293472E-04`) | `1.9789e+06` | `+37.12%` | `+0.59%` |
| `reg_sweep_4096` | `4096` | `hpc-gaas-g14` | PASSED (`4.341100E-04`) | `1.9521e+06` | `+35.26%` | `-0.77%` |
| `reg_sweep_5012` | `5012` | `hpc-gaas-g15` | PASSED (`4.514143E-04`) | `1.9468e+06` | `+34.89%` | `-1.04%` |

The register-step sweep uses the buffer-32768 placement result
(`1.9673e+06` GFLOP/s) as its matched control. All five register-step values
passed verification and remain above the original baseline, but the observed
spread is small and each value has one attempt.

### Register step resweep at buffer 3048

| Attempt | Register step | Node | Residual marker | GFLOP/s | Percentage vs original baseline | vs matched buffer-3048 control |
|---|---:|---|---|---:|---:|---:|
| `reg_sweep_512_b3048` | `512` | `hpc-gaas-g11` | PASSED (`3.738744E-04`) | `2.2002e+06` | `+52.45%` | `+1.10%` |
| `reg_sweep_1024_b3048` | `1024` | `hpc-gaas-g14` | PASSED (`4.607039E-04`) | `2.1335e+06` | `+47.83%` | `-1.97%` |
| `reg_sweep_3072_b3048` | `3072` | `hpc-gaas-g15` | PASSED (`3.711735E-04`) | `2.1518e+06` | `+49.10%` | `-1.13%` |
| `reg_sweep_4096_b3048` | `4096` | `hpc-gaas-g16` | PASSED (`4.018509E-04`) | `2.1335e+06` | `+47.83%` | `-1.97%` |
| `reg_sweep_5012_b3048` | `5012` | `hpc-gaas-g11` | PASSED (`4.025842E-04`) | `2.1634e+06` | `+49.90%` | `-0.59%` |

The buffer-3048 resweep uses the default-fill result `2.1763e+06` GFLOP/s
as its matched control. All ten register-step attempts passed verification
and remain above the original baseline.

## Register-step analysis addendum

For buffer 32768, the best recorded step is `1024` at `1.9822e+06` GFLOP/s,
`+0.76%` above its matched control. For buffer 3048, the best is `512` at
`2.2002e+06`, `+1.10%` above its matched control. At the same register steps,
the buffer-3048 resweep is higher than the buffer-32768 sweep by 11.99% at
512, 7.63% at 1024, 8.74% at 3072, 9.29% at 4096, and 11.13% at 5012.

The two buffer settings do not identify one stable register-step optimum:
1024 leads at buffer 32768, while 512 leads at buffer 3048. These are single
measurements across multiple nodes, and retained runtime/PBS exit metadata
are unavailable. No correctness regression is present; every attempt reports
a finite residual and `PASSED` verification.

## 4. Insights gained

- Enabling `--fill-device 1` with the observed default buffer size of 3048 is
  the strongest recorded placement result: `2.1763e+06` GFLOP/s.
- Larger tested buffer sizes regress monotonically relative to the default:
  8192 is -1.58% from default, 16384 is -4.85%, and 32768 is -9.61%.
- All placement results remain above the matched `fill-device=0` control, but
  this is based on one attempt per configuration.
- The placement runs span nodes `hpc-gaas-g11`, `g14`, and `g15`; node
  variation and unavailable runtime metadata limit causal confidence.
- The register-step sweeps are now populated at buffers 32768 and 3048; the
  best step depends on the buffer setting in these single measurements.
- No scientific correctness regressions were observed: all included rows have
  finite residuals and `PASSED` verification.

## 5. Suggested next section

For user review, repeat `fill_device_default` and the matched
`fill-device=0` control on comparable nodes, retaining runtime and exact
launch metadata. If the fill-device improvement reproduces, test a small
buffer refinement around 3048 and 8192. Separately, repeat both register-step
sweeps with matched nodes and runtime metadata, including an unchanged-step
control for each buffer setting.

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
