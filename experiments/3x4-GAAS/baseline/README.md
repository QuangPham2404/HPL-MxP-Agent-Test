# 3x4-GAAS baseline

## Purpose

Establish the immutable **original baseline** for the new 3 GAAS nodes × 4 H200
GPUs/node HPL-MxP optimization track (`tasks/TASK-3X4-000.md`, Phase 0). This
is a fixed provisional-configuration scored baseline, not a tuned result: the
first valid `PASSED` attempt produced by this family becomes the `3x4-GAAS`
original baseline and the percentage denominator for the whole 3×4 campaign.
No second scored run is performed by this task.

This task-specific Human-approved path supersedes the older root-`AGENTS.md`
note directing new 3×4 work to `experiments/3Nodes-4GPUs/`; historical
directories (`experiments/3x4-baseline/`, `experiments/3x4-smoketest/`,
`experiments/3Nodes-4GPUs/`) are preserved untouched and are prior evidence
only.

## Fixed configuration (TASK-3X4-000 Section 1.4B)

- Topology: 3 nodes × 4 H200 GPUs, 12 MPI ranks, one rank per GPU
  (`--gpu-affinity 0:1:2:3`, container-renumbered local GPUs), `place=scatter`,
  no `mpiprocs`, per-node chunk `ngpus=4:ncpus=48:mem=1000GB`.
- Grid: `--nprow 4 --npcol 3 --nporder column` (provisional Phase-0 control,
  not a transferred 3×4 optimum).
- Problem: `--n 480000 --nb 3072`.
- Precision/scheduling: `--sloppy-type FP16`, `--use-mpi-panel-broadcast 0`,
  `--use-separate-stream-for-gemm 1`, `--prioritize-trsm 0`,
  `--prioritize-factorization 0`.
- Protocol: `--test-loop 1 --skip-tests 0 --monitor-gpu 0` (internal tests
  enabled, continuous GPU monitoring disabled; root `AGENTS.md` scored-run
  controls). With monitoring disabled, GPU-monitoring output is unavailable by
  design; pre/post-run `nvidia-smi` snapshots are ordinary health evidence.
- Transport: `NCCL_IB_HCA=mlx5_0,mlx5_1,mlx5_2,mlx5_3,mlx5_4,mlx5_5,mlx5_8,mlx5_9`
  (validated 3×4 bond-exclusion correctness setting, job `67974.gaas`),
  exported in the job shell and `-x` forwarded to all 12 ranks.
- Host runtime: no OMP/CPU/memory-affinity tuning choice; the incoming/default
  host-runtime state is preserved and the effective `OMP_NUM_THREADS`,
  `OMP_PLACES`, `OMP_PROC_BIND` values (including `unset`) are recorded per
  rank in the pre-launch rank-map probe log. The v26.02 package wrapper applies
  `OMP_PROC_BIND=TRUE` / `OMP_PLACES=sockets` defaults when unset (captured
  launcher in `todo.md`; flag-check evidence in
  `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`).
- Container: NVIDIA HPC Benchmarks v26.02 (`hpc-benchmarks_26.02.sif`),
  container MPI end-to-end (`/usr/local/mpi/bin/mpirun` + container `orted`)
  through the validated `multi-node-test/rsh_pbsdsh_container.sh` pbsdsh
  bridge with `/opt/pbs` and `/var/spool/pbs` bound in.
- Queue/accounting: `gpu_as` or `gpu_ded` (chosen from the live contention
  snapshot immediately before submission), project `hpc_ebslee`.

## Reused characterization (not re-probed)

Existing 3×4 GAAS evidence is reused per TASK-3X4-000 Section 1.4A: the
validated multinode launch mechanism (`multi-node-test/`), the node-condition
dose-response and clean-node guidance
(`scripts/gaas-internode-coms-debug/resource-alloc/README.md` — node condition
is everything; verify with `pbsnodes -aSj` immediately before submission), the
same-topology correctness/memory envelope through `N=510000`
(resource-alloc experiment 4), and the validated NCCL bond-exclusion setting
(phase 2 stage 2, job `67974.gaas`). Only lightweight checks are performed:
the pre-launch rank-map/transport probe in the run script and the pre-submit
contention snapshot.

## Validation

A valid run requires: PBS normal exit; expected stdout/stderr present; normal
HPL-MxP benchmark output; finite solver residuals; normalized residual with
`PASSED`; emitted `GFLOPS` / `LU GFLOPS` lines. Success is never inferred from
exit status alone.

## Run

Submit one job at a time from this directory (`experiments/3x4-GAAS/baseline/`)
after the pre-submit `pbsnodes -aSj` snapshot and trio selection:

```bash
qsub -q <gpu_as|gpu_ded> -v "ATTEMPT=3x4-GAAS-baseline_v1" \
     -l "select=host=<h1>:ngpus=4:ncpus=48:mem=1000GB+host=<h2>:ngpus=4:ncpus=48:mem=1000GB+host=<h3>:ngpus=4:ncpus=48:mem=1000GB,place=scatter" \
     -o outputs/3x4-GAAS-baseline_v1.o -e outputs/3x4-GAAS-baseline_v1.e \
     scripts/run_3x4_gaas_baseline.pbs
```

`<h1..h3>` are the least-contended eligible trio within one queue from the
live snapshot; the snapshot and selection record are preserved as
`outputs/3x4-GAAS-baseline_v1.presubmit_pbsnodes.log`.

## Logged attempts

| Attempt | PBS job | Queue / nodes | Result | GFLOP/s | Evidence |
|---|---|---|---|---|---|
| *(to be recorded after the single authorized scored attempt)* | | | | | |
