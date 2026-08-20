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

## Register-step sweep

These runs keep `--fill-device 1`, buffer size `32768`, and the validated
workload fixed while varying `--cuda-host-register-step`.

| Attempt | Register step | PBS job | Node | Residual check | GFLOP/s | Evidence |
|---|---:|---:|---|---|---:|---|
| `reg_sweep_512` | `512` | `50536.gaas` | `hpc-gaas-g14` | PASSED (`4.607964E-04`) | `1.9646e+06` | `outputs/reg_sweep_512.{o,e}` |
| `reg_sweep_1024` | `1024` | `50535.gaas` | `hpc-gaas-g11` | PASSED (`4.226508E-04`) | `1.9822e+06` | `outputs/reg_sweep_1024.{o,e}` |
| `reg_sweep_3072` | `3072` | `50526.gaas` | `hpc-gaas-g11` | PASSED (`4.293472E-04`) | `1.9789e+06` | `outputs/reg_sweep_3072.{o,e}` |
| `reg_sweep_4096` | `4096` | `50528.gaas` | `hpc-gaas-g14` | PASSED (`4.341100E-04`) | `1.9521e+06` | `outputs/reg_sweep_4096.{o,e}` |
| `reg_sweep_5012` | `5012` | `50529.gaas` | `hpc-gaas-g15` | PASSED (`4.514143E-04`) | `1.9468e+06` | `outputs/reg_sweep_5012.{o,e}` |

## Register-step resweep at buffer 3048

These resweep attempts repeat the register values above with
`--fill-device-buffer-size 3048`. The original buffer-32768 results remain
listed in the preceding table.

| Attempt | Register step | PBS job | Node | Residual check | GFLOP/s | Evidence |
|---|---:|---:|---|---|---:|---|
| `reg_sweep_512_b3048` | `512` | `50546.gaas` | `hpc-gaas-g11` | PASSED (`3.738744E-04`) | `2.2002e+06` | `outputs/reg_sweep_512_b3048.{o,e}` |
| `reg_sweep_1024_b3048` | `1024` | `50547.gaas` | `hpc-gaas-g14` | PASSED (`4.607039E-04`) | `2.1335e+06` | `outputs/reg_sweep_1024_b3048.{o,e}` |
| `reg_sweep_3072_b3048` | `3072` | `50548.gaas` | `hpc-gaas-g15` | PASSED (`3.711735E-04`) | `2.1518e+06` | `outputs/reg_sweep_3072_b3048.{o,e}` |
| `reg_sweep_4096_b3048` | `4096` | `50550.gaas` | `hpc-gaas-g16` | PASSED (`4.018509E-04`) | `2.1335e+06` | `outputs/reg_sweep_4096_b3048.{o,e}` |
| `reg_sweep_5012_b3048` | `5012` | `50551.gaas` | `hpc-gaas-g11` | PASSED (`4.025842E-04`) | `2.1634e+06` | `outputs/reg_sweep_5012_b3048.{o,e}` |
