# 3x4-smoketest

## Purpose

Smoketest to confirm HPL-MxP launches correctly on a 3-node x 4-GPU topology
(12 MPI ranks, one GPU per process). Uses a small `N=200000` for a fast run;
this is a correctness/launch check, not a performance measurement or tuning
sweep.

## Method

Adapted from the validated multinode launch recipe in
`multi-node-test/HPL-MxP/run_hplmxp_baseline.pbs`, which uses the container's
own `mpirun` plus the `rsh_pbsdsh_container.sh` pbsdsh bridge (see
`multi-node-test/GAAS_MULTINODE_SETUP.md`). No parameter changes beyond N.

## Fixed configuration

- Topology: `select=3:ngpus=4`, `place=scatter` (12 ranks, 3x4 `nprow x npcol`,
  `nporder row`).
- `N=200000`, `NB=1024`.
- `--skip-tests 1` + GPU monitoring flags.
- Container: `hpc-benchmarks_26.02.sif`.

## Validation

A successful run must report a finite normalized residual and `PASSED` from the
HPL-MxP harness, plus a normal `GFLOPS` line.

## Run

```bash
qsub run_3x4_smoketest.pbs
```

## Logged attempts

| Attempt | PBS job | Result | Evidence |
|---|---|---|---|
| _pending_ | | | |