# 2x8-GAAS baseline

TASK-000 Phase-0 immutable original baseline for the 2 GAAS nodes x 8 H200
GPUs HPL-MxP campaign. The configuration below is fixed and identical for
every attempt. The first valid scored attempt becomes the immutable original
baseline for the 2x8-GAAS topology; two additional identical repeats provide
run-to-run noise evidence (range/median/spread/CV computed mechanically
later).

**Status (2026-09-27):** scripts and README created; no submission yet
(v1-v3 planned).

## Structure

- `scripts/run_2x8_baseline.pbs` — single reusable PBS run script (attempt
  label comes from the `ATTEMPT` environment at submission)
- `outputs/` — attempt-specific PBS `.o`/`.e` evidence and mechanical-check
  logs (tracked, never overwritten; every retry gets a new attempt label)

## Fixed configuration

```
OMP_NUM_THREADS=8
--n 737280
--nb 3072
--nprow 4
--npcol 4
--nporder column
--gpu-affinity 0:1:2:3:4:5:6:7
--sloppy-type FP16
--use-mpi-panel-broadcast 0
--use-separate-stream-for-gemm 1
--prioritize-trsm 0
--prioritize-factorization 0
--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Configuration supplied by the Strategic Analyst and approved by the Human
Leader in `tasks/TASK-000.md`; Codex did not derive, optimize, or modify it.
It was selected from prior external performance evidence (N=700000 PASSED at
4.1061e+06 GFLOP/s, N=800000 device OOM in the historical
`experiments/2Nodes-8GPUs/` family; N=737280 sits just below the implied
~747000 device-matrix ceiling) — factual context only.

## Pre-submission mechanical checks

| check | result | evidence |
|---|---|---|
| CLI flag support | all 14 supplied flags SUPPORTED by the installed NVIDIA HPC Benchmarks v26.02 package | `outputs/hplmxp_v2602_flag_check_v1.log` |
| N=737280 feasibility | per-GPU device matrix `737280^2 * 4 / 16 = 135.895 GB` vs 138.739 GB historical available MIN (139.80 GiB free at probe time); no obvious deterministic impossibility | arithmetic over `scripts/probing_report.md` (2x8 supplement) and historical `experiments/2Nodes-8GPUs/` runs |

## Launch contract

Validated Approach-1 NVIDIA multinode launch (see
`multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`): container `mpirun` +
`multi-node-test/rsh_pbsdsh_container.sh` bridge, `/opt/pbs` and
`/var/spool/pbs` bound into the container, de-duplicated hostfile with
`slots=8`, fixed daemon flags (`plm_rsh_no_tree_spawn=1`,
`plm_rsh_num_concurrent=1`, `routed=direct`, `--bind-to none`), and
`-x PATH -x LD_LIBRARY_PATH` so remote ranks resolve NVML.

Resources: `select=2:ngpus=8` (no `mpiprocs`), `place=scatter`, 16 ranks with
one rank per GPU, `walltime=00:45:00`. Queue `gpu_ded` or `gpu_as` only;
project `hpc_ebslee`; one multinode job at a time (no concurrent
submissions).

## Submission (from this directory)

```bash
qsub -q <gpu_ded|gpu_as> -v "ATTEMPT=2x8-GAAS-baseline_v1" \
     -o outputs/2x8-GAAS-baseline_v1.o -e outputs/2x8-GAAS-baseline_v1.e \
     scripts/run_2x8_baseline.pbs
```

A documented host-pinned select may be passed at `qsub` when live
`pbsnodes`/`Qlist` checks identify a specific clean eligible node pair, as
validated for the Phase-0 probe (job 72591.gaas):

```bash
qsub -l select=host=<n1>:ngpus=8:ncpus=96:mem=2000GB+host=<n2>:ngpus=8:ncpus=96:mem=2000GB ...
```

## Validation criteria

A run is valid only when:

- PBS completes and the expected output files exist;
- normal HPL-MxP output is produced;
- the normalized residual is finite and verification reports `PASSED`;
- overall and LU GFLOPS are recorded;
- rank/node/GPU mapping and memory/headroom lines are preserved;
- GPU-monitoring output is recorded as unavailable by design (`--monitor-gpu 0`).

## Run summary

| attempt | PBS job | queue | nodes | result | residual | overall GFLOP/s | per-GPU GFLOP/s |
|---|---|---|---|---|---|---|---|
| 2x8-GAAS-baseline_v1 | - | - | - | planned | - | - | - |
| 2x8-GAAS-baseline_v2 | - | - | - | planned | - | - | - |
| 2x8-GAAS-baseline_v3 | - | - | - | planned | - | - | - |

`v1` (the first valid scored attempt) is designated the immutable original
baseline for 2x8-GAAS and the future percentage denominator for 2x8-GAAS
analysis.

## Runtime error-patching history

None yet.

## Evidence paths

- `outputs/` — all attempt `.o`/`.e` files
- `outputs/hplmxp_v2602_flag_check_v1.log` — mechanical flag-support check
- `scripts/probing_report.md` (2x8 Phase-0 supplement) — comprehensive
  read-only 2x8 probe evidence (job 72591.gaas, hpc-gaas-g12+hpc-gaas-g15)
