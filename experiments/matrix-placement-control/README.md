# FP64 Matrix Placement Control

## Purpose

Test HPL-MxP matrix-placement controls after the affinity sweep, using the
fixed workload `N=399360`, `NB=3072`, `4x2` column-major grid, eight MPI
processes, and GPU-local CPU/memory affinity.

The retained runs use `--fill-device 1` and
`--cuda-host-register-step 2048`; the sweep varies
`--fill-device-buffer-size`. The default run records the application's
observed default value `3048`.

## Logged attempts

| Attempt | Buffer size | PBS job | Node | Residual check | GFLOP/s | Evidence |
|---|---:|---:|---|---|---:|---|
| `fill_device_default` | `3048` | `50489.gaas` | `hpc-gaas-g11` | PASSED (`3.851395E-04`) | `2.1763e+06` | `outputs/fill_device_default.{o,e}` |
| `buffer_sweep_8192` | `8192` | `50491.gaas` | `hpc-gaas-g11` | PASSED (`3.628577E-04`) | `2.1420e+06` | `outputs/buffer_sweep_8192.{o,e}` |
| `buffer_sweep_16384` | `16384` | `50492.gaas` | `hpc-gaas-g14` | PASSED (`3.659648E-04`) | `2.0709e+06` | `outputs/buffer_sweep_16384.{o,e}` |
| `buffer_sweep_32768` | `32768` | `50493.gaas` | `hpc-gaas-g15` | PASSED (`5.224120E-04`) | `1.9673e+06` | `outputs/buffer_sweep_32768.{o,e}` |

All raw PBS stdout/stderr files under `outputs/` are authoritative evidence.
