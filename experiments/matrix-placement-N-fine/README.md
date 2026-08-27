# Matrix Placement N Fine Sweep

## Purpose

Follow-up to `matrix-placement-N-resweep`. That sweep lowered N under
`--fill-device 1` in coarse 30720 steps (491520, 460800, 430080, 399360,
368640) and found a null net effect: solver time collapsed but LU-efficiency
loss cancelled it, leaving GFLOP/s flat within node noise. The hypothesis here
is that the coarse step may have jumped over a narrow peak in the immediate
vicinity below N=491520. This experiment maps the 1024-step neighborhood below
491520 with a node-matched control to test whether any fine N beats 491520.

## Fixed config

Identical to `matrix-placement-N-resweep` (for continuity):

- `--fill-device 1`, buffer and register-step left at launcher defaults
  (3048 / 2048).
- `--nb 3072`, `--nprow 2 --npcol 4 --nporder row`.
- `--gpu-affinity 0:1:2:3:4:5:6:7`, no `--cpu-affinity` / `--mem-affinity`.
- `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`.
- `--skip-tests 1` + GPU monitoring flags.

Container: `hpc-benchmarks_26.02.sif`; `apptainer exec --nv`; `mpirun -np 8
--bind-to none`.

## Swept variable and node-matching

Eight fine N values in 1024 steps below 491520, each bracketed by a same-node
491520 control (`ctrl_491520_a` at the start, `ctrl_491520_b` at the end). A
single PBS job loops over the whole sequence on one allocated node, so every
fine point is measured against an interleaved control on the same node.

| role | N |
|---|---:|
| control (start) | 491520 |
| fine point | 490496 |
| fine point | 489472 |
| fine point | 488448 |
| fine point | 487424 |
| fine point | 486400 |
| fine point | 485376 |
| fine point | 484352 |
| fine point | 483328 |
| control (end) | 491520 |

## Run script

`run_N_fine.pbs` executes the sequence above in one node-matched job:

```text
cd experiments/matrix-placement-N-fine
qsub run_N_fine.pbs
```

Each attempt writes attempt-specific evidence to `outputs/`:

- `outputs/ctrl_491520_{a,b}.{o,e}` — node-matched controls.
- `outputs/n_<N>.{o,e}` — one pair per fine N.

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
HPL-MxP reports `PASSED`; the residual is finite and within tolerance; and a
finite HPL-MxP `GFLOPS` value is present.

## Logged attempts

| Attempt | N | PBS job | Node | Residual check | GFLOP/s | Evidence |
|---|---:|---|---:|---|---|---:|---|
| `ctrl_491520_a` | 491520 | 53334 | g18 | PASSED | 2.3792e+06 | `outputs/ctrl_491520_a.{o,e}` |
| `n_490496` | 490496 | 53334 | g18 | PASSED | 2.3737e+06 | `outputs/n_490496.{o,e}` |
| `n_489472` | 489472 | 53334 | g18 | PASSED | 2.3763e+06 | `outputs/n_489472.{o,e}` |
| `n_488448` | 488448 | 53334 | g18 | PASSED | 2.3645e+06 | `outputs/n_488448.{o,e}` |
| `n_487424` | 487424 | 53334 | g18 | PASSED | 2.3711e+06 | `outputs/n_487424.{o,e}` |
| `n_486400` | 486400 | 53334 | g18 | PASSED | 2.3573e+06 | `outputs/n_486400.{o,e}` |
| `n_485376` | 485376 | 53334 | g18 | PASSED | 2.3721e+06 | `outputs/n_485376.{o,e}` |
| `n_484352` | 484352 | 53334 | g18 | PASSED | 2.3820e+06 | `outputs/n_484352.{o,e}` |
| `n_483328` | 483328 | 53334 | g18 | PASSED | 2.3604e+06 | `outputs/n_483328.{o,e}` |
| `ctrl_491520_b` | 491520 | 53334 | g18 | PASSED | 2.3706e+06 | `outputs/ctrl_491520_b.{o,e}` |

## Result

No fine peak below 491520. The eight fine points are a ~1% noise band
(2.3573e+06 … 2.3820e+06) with no trend; none beats the same-node 491520 control
beyond intra-node drift (start control 2.3792e+06 → end control 2.3706e+06,
−0.36% over the job). N=491520 + `--fill-device 1` remains the recommended
config; the N dimension is closed.