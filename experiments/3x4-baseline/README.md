# 3x4-baseline

## Purpose

Establish the new-system **original baseline** for the 3-node x 4-GPU topology
(12 MPI ranks, one GPU per process). This is the immutable Phase-0 baseline run
that later optimizations are compared against; it is a fixed provisional
configuration, not a tuned result.

## Fixed configuration

- Topology: `select=3:ngpus=4`, `place=scatter` (12 ranks, `nprow=3 x npcol=4`,
  `nporder row`).
- `--gpu-affinity 0:1:2:3` (identity per-node, one GPU per local rank).
- `N=480000`, `NB=1024`.
- `--skip-tests 1` + GPU monitoring flags.
- Container: `hpc-benchmarks_26.02.sif`.

## Validation

A valid run must report a finite normalized residual and `PASSED` from the
HPL-MxP harness, plus a normal `GFLOPS` line.

## Run

```bash
qsub run_3x4_baseline.pbs
```

## Logged attempts

| Attempt | PBS job | Result | GFLOP/s | Evidence |
|---|---|---|---|---|
| _pending_ | | | | |