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

## Re-run at N=491520 (2026-08-26)

The original experiment above ran at N=399360 (4x2 column), before the
N/NB/grid/OpenMP sweeps moved the shipping workload to N=491520 (2x4 row,
`OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`, peak
2.3204e+06). This section re-opens the matrix-placement levers — `--fill-device`,
`--fill-device-buffer-size`, and `--cuda-host-register-step` — on that final
workload, keeping all other settings fixed. The old N=399360 rows remain in
`results/metrics.csv`; accounts in this section use the `491k_*` attempt prefix
so they do not collide.

Workload (fixed): `--n 491520 --nb 3072 --nprow 2 --npcol 4 --nporder row`,
`--gpu-affinity 0:1:2:3:4:5:6:7`, no CPU/memory affinity,
`OMP_NUM_THREADS=8 OMP_PLACES=sockets OMP_PROC_BIND=TRUE`, `--skip-tests 1` and
GPU monitoring flags.

Run script: `run_matrix_placement.pbs`, parametrized via `qsub -v`:

```text
qsub -v "ATTEMPT=491k_fill_off" \
     -o outputs/491k_fill_off.o -e outputs/491k_fill_off.e \
     run_matrix_placement.pbs

qsub -v "ATTEMPT=491k_fill_on,FILL=1,BUF=3048" \
     -o outputs/491k_fill_on.o -e outputs/491k_fill_on.e \
     run_matrix_placement.pbs

qsub -v "ATTEMPT=491k_buf_512,FILL=1,BUF=512" \
     -o outputs/491k_buf_512.o -e outputs/491k_buf_512.e \
     run_matrix_placement.pbs

qsub -v "ATTEMPT=491k_reg_1024,FILL=1,BUF=<best>,REG=1024" \
     -o outputs/491k_reg_1024.o -e outputs/491k_reg_1024.e \
     run_matrix_placement.pbs
```

### Method

1. **Task 1 — `--fill-device 1` go/no-go.** Run a node-matched control
   (`491k_fill_off`, fill-device=0) and `491k_fill_on` (`--fill-device 1`,
   default buffer 3048). Proceed only if fill-on improves or differs within
   ~1-2% of fill-off.
2. **Task 2 — `--fill-device-buffer-size`** (default 3048, lower = more VRAM
   filled). Sweep downward `2048,1024,512,256` and upward `4096,6144,8192`,
   stopping a direction after two consecutive GFLOP/s declines.
3. **Task 3 — `--cuda-host-register-step`** (default 2048, multiples of 512),
   at the best buffer from Task 2. Sweep downward `1536,1024,512` and upward
   `2560,3072,3584,4096,4608,5120`, stopping each direction after two
   consecutive declines.

### OOM fallback

If `--fill-device 1` OOMs at N=491520 (491520 is already 480x1024), step the
matrix down in multiples of 1024 (`490496`, `489472`, ...) until the run
completes, and record the changed N explicitly in this README and the analysis.

### Results (N=491520)

**Task 1 — fill-device go/no-go**

| Attempt | fill-device | GFLOP/s | Node | Verification |
|---|---|---:|---|---|
| `491k_fill_off` | 0 | 2.1512e+06 | g10 | PASSED |
| `491k_fill_on`  | 1 (buf 3048) | 2.3745e+06 | g16 | PASSED |

**Task 2 — buffer sweep (fill-device=1)**

| Buffer (MB) | GFLOP/s | Node | Verification |
|---:|---:|---|---|
| 256  | 1.2268e+06 | g18 | FAILED |
| 512  | 1.0488e+06 | g17 | FAILED |
| 1024 | 2.3902e+06 | g16 | PASSED |
| 2048 | 2.3920e+06 | g10 | PASSED |
| 3048 | 2.3745e+06 | g16 | PASSED |
| 4096 | 2.3663e+06 | g10 | PASSED |
| 6144 | 2.3722e+06 | g16 | PASSED |
| 8192 | 2.3420e+06 | g17 | PASSED |

**Task 3 — register-step sweep (buffer 1024)**

| Register step | GFLOP/s | Node | Verification |
|---:|---:|---|---|
| 512  | 2.3656e+06 | g17 | PASSED |
| 1024 | 2.3912e+06 | g16 | PASSED |
| 1536 | 2.3974e+06 | g10 | PASSED |
| 2048 | 2.3902e+06 | g16 | PASSED |
| 2560 | 2.3886e+06 | g18 | PASSED |
| 3072 | 2.3722e+06 | g17 | PASSED |
| 3584 | 2.3691e+06 | g16 | PASSED |
| 4096 | 2.3742e+06 | g10 | PASSED |
| 4608 | 2.3549e+06 | g18 | PASSED |
| 5120 | 2.3536e+06 | g17 | PASSED |

No OOM fallback was needed: `--fill-device 1` completed at N=491520 (only the
`buffer <= 512` cells failed verification, a VRAM-overflow effect, not an
allocation failure).
