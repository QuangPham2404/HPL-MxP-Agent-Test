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

Populated after retrieval and extraction.