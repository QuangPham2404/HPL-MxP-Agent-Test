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
| `3x4-GAAS-baseline_v1` | `73926.gaas` | `gpu_as` / g14+g10+g09 | PASSED (`3.784553E-04`), exit 0, walltime 00:04:15 | `2.0193e+06` (168271.05/GPU) | `outputs/3x4-GAAS-baseline_v1.{o,e}`, `outputs/3x4-GAAS-baseline_v1.rankmap.log`, `outputs/3x4-GAAS-baseline_v1.presubmit_pbsnodes.log` |

## Run record — `3x4-GAAS-baseline_v1` (job `73926.gaas`, 2026-09-29)

Per TASK-3X4-000 Section 1.4E, this first valid `PASSED` scored attempt is
designated the **immutable `3x4-GAAS` original baseline** and the future
percentage denominator for the 3×4 campaign. No second scored run was
performed or is authorized by TASK-3X4-000.

Scheduler and allocation:

- PBS job `73926.gaas`, queue `gpu_as`, project `hpc_ebslee`, state `F`,
  exit status 0, walltime `00:04:15` (qtime 2026-09-29 09:53:54, mtime
  09:58:15 +08:00).
- Host-pinned select `host=hpc-gaas-g14 + hpc-gaas-g10 + hpc-gaas-g09`, each
  `ngpus=4:ncpus=48:mem=1000GB`, `place=scatter`, no `mpiprocs`; 12 ranks,
  4 per node, one rank per GPU (rank-map gate PASS: 12 rank lines, 4 per
  host on 3 distinct hosts, 4 container-visible GPUs per host).
- Pre-submit contention snapshot (both approved queues inspected): no
  eligible node existed in `gpu_ded` (all of g01/g02/g03/g20/g21/g22 lacked
  ≥4 free GPUs); eligible `gpu_as` nodes were g09/g10/g13/g14 only (the
  pristine-capable g16/g17 and g04/g05 now carry `Qlist=gpu_aisg` and are
  off-limits). No pristine trio existed; the least-contended eligible trio
  g14+g10+g09 was selected and host-pinned. Recorded co-tenant state at
  submission: g14 one light-active job (1 GPU + 12 CPUs, ~300% CPU, ~19 GB
  resident); g10 one light-active job (2 GPUs + 24 CPUs, ~191% CPU);
  g09 two light-active jobs (3 GPUs + 36 CPUs total). g13 was rejected for
  the third slot (single heavy holder: 4 GPUs + 48 CPUs + 1 TB allocated,
  ~275 GB resident). Full snapshot: `outputs/3x4-GAAS-baseline_v1.presubmit_pbsnodes.log`.

Launch and environment:

- Execution tree: clean detached worktree
  `.codex-worktrees/TASK-3X4-000-9230b5a` at
  `9230b5a27d5a0b6365380a1a3b6814670c6ea1e7` (remote primary clone preserved
  untouched; Workflow 01 Mode B).
- Validated Approach-1 launch: container `/usr/local/mpi/bin/mpirun` +
  `multi-node-test/rsh_pbsdsh_container.sh` bridge, `plm_rsh_no_tree_spawn=1`,
  `plm_rsh_num_concurrent=1`, `routed=direct`, `--bind-to none`,
  `-x PATH -x LD_LIBRARY_PATH -x NCCL_IB_HCA`, de-duplicated hostfile with
  `slots=4`; NVIDIA HPC Benchmarks v26.02 container; modules
  `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0`.
- `NCCL_IB_HCA=mlx5_0,mlx5_1,mlx5_2,mlx5_3,mlx5_4,mlx5_5,mlx5_8,mlx5_9`
  verified set on all 12 ranks by the pre-launch probe.
- OMP record (no tuning choice made; incoming/default state preserved):
  incoming `OMP_NUM_THREADS=48` on all 12 ranks (PBS-supplied allocation CPU
  count), `OMP_PLACES`/`OMP_PROC_BIND` unset in the rank environment; the
  v26.02 wrapper's documented defaults (`OMP_PLACES=sockets`,
  `OMP_PROC_BIND=TRUE`) therefore applied at application launch. No
  OMP/CPU/memory-affinity flag was set or forwarded.
- Effective application defaults echoed by the package: `--tolerance 1e-12`,
  `--preset-gemm-kernel 90`, `--u-panel-chunk-nbs 8`,
  `--call-dgemv-with-multiple-threads 0`, `--Anq-device 0`,
  `--cuda-host-register-step 2048`, `--fill-device 0`,
  `--fill-device-buffer-size 3048`, `--mpi-use-host-threads 1`.

Result (factual, from `outputs/3x4-GAAS-baseline_v1.o`):

- Internal test phase ran (`--skip-tests 0`): GEMM test 9.76 s AVG
  (604277.19 GFLOPS AVG); MPI/NCCL broadcast and pdgemv component tests
  present.
- Phases: Constructor 0.09 s; RNG 108.26 s AVG (MAX 113.71 on g09);
  Set Diagonal 0.02 s; Get Anorm 0.12 s; Sp 20.59 s; matgen 134.58 s;
  **LU 16.52 s**; **iterative solver 19.99 s** (3 iterations).
- Solver L-infinite residuals (finite, converging): `4.88488318e-04`,
  `9.94571092e-10`, `1.09573917e-13`.
- Normalized residual `3.784553E-04` — **PASSED** (threshold 16).
- **Overall: `GFLOPS = 2.0193e+06`, per GPU = 168271.05** (the HPL-MxP
  performance to report). LU-only: `4.4619e+06` GFLOPS, 371823.91 per GPU.
- Memory evidence: per-process host consumption MAX 144.203 GB (available
  MIN 17.718 GB; 2.097 GB available at the matgen peak); per-process device
  consumption MAX 79.561 GB (available MIN 138.843 GB; 58.608 GB during the
  solve). Continuous GPU-monitoring output is unavailable by design
  (`--monitor-gpu 0`); pre/post-run `nvidia-smi` snapshots on the mother
  node (g14) show healthy hardware (H200, driver 580.126.20, 30–34 °C,
  1980 MHz SM clocks post-run, 0 MiB residual GPU memory).
- Stderr records the known non-fatal recurring notes (`cuda/13.1` module
  hint, unknown-groupid warnings) and the two remote bridge/orted spawn
  lines (g10, g09) as provenance.

## Runtime error-patching attempts

None. The single authorized scored attempt completed normally; no retry was
needed and none is authorized by TASK-3X4-000.
