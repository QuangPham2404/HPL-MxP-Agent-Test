# Matrix Placement N Re-sweep

## Purpose

Test the hypothesis that the iterative-solver stage — measured at ~39% of
runtime at N=491520 with `--fill-device 1` — can be shrunk by lowering N so the
full FP64 matrix fits in GPU VRAM, producing a net GFLOP/s gain despite the
lost N³ work. The FP64 matrix at N=491520 is ~241 GB/GPU, exceeding the H200's
~141 GB HBM, so part of it remains host-resident and the refinement stage pays
staging costs. Full residency is approximately reached near N = 360–385k
(where N² bytes ≈ ~141 GB).

## Fixed config

Derived from `matrix-placement-control` attempt `491k_fill_on` (which itself
layered `--fill-device 1` onto the `omp-sweep` best):

- `--fill-device 1`, buffer and register-step left at launcher defaults
  (3048 / 2048).
- `--nb 3072`, `--nprow 2 --npcol 4 --nporder row`.
- `--gpu-affinity 0:1:2:3:4:5:6:7`, no `--cpu-affinity` / `--mem-affinity`.
- `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`.
- `--skip-tests 1` + GPU monitoring flags.

Container: `hpc-benchmarks_26.02.sif`; `apptainer exec --nv`; `mpirun -np 8
--bind-to none`.

## Swept variable

`N` (multiples of 1024): `491520` (re-run control), `460800`, `430080`,
`399360`, `368640`.

## Run script

`run_N_resweep.pbs`, parametrized via `qsub -v "ATTEMPT=<label>,N=<n>"`:

```text
qsub -v "ATTEMPT=n_491520,N=491520" \
     -o outputs/n_491520.o -e outputs/n_491520.e \
     run_N_resweep.pbs
```

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the residual is finite and within tolerance; and a
finite HPL-MxP `GFLOPS` value is present.

## Logged attempts

| Attempt | N | PBS job | Node | Residual check | GFLOP/s | Evidence |
|---|---|---:|---|---|---:|---|
| `n_491520` | 491520 | 53190 | g16 | PASSED | 2.3731e+06 | `outputs/n_491520.{o,e}` |
| `n_460800` | 460800 | 53191 | g17 | PASSED | 2.3373e+06 | `outputs/n_460800.{o,e}` |
| `n_430080` | 430080 | 53192 | g18 | PASSED | 2.2828e+06 | `outputs/n_430080.{o,e}` |
| `n_399360` | 399360 | 53193 | g19 | PASSED | 2.3023e+06 | `outputs/n_399360.{o,e}` |
| `n_368640` | 368640 | 53194 | g19 | PASSED | 2.3792e+06 | `outputs/n_368640.{o,e}` |

## Result

The solver mechanism is confirmed (iterative-solver time 13.07 s → 4.09 s, its
runtime share 39.2% → 29.1% as N drops 491520 → 368640), but the net GFLOP/s is
flat within node noise because LU efficiency degrades at smaller N. No peak
below 491520; the hypothesis is rejected as a net gain. N=491520 + `--fill-device
1` remains the recommended config.