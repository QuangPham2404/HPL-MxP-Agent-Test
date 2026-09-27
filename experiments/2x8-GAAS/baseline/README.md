# 2x8-GAAS baseline

TASK-000 Phase-0 immutable original baseline for the 2 GAAS nodes x 8 H200
GPUs HPL-MxP campaign. The configuration below is fixed and identical for
every attempt. Under the revised approved scope, the first valid scored
attempt becomes the immutable original baseline for the 2x8-GAAS topology; a
single valid scored attempt is sufficient — repeats are not required.

**Status (2026-09-27):** first exact attempt `2x8-GAAS-baseline_v1`
(job 72595.gaas) FAILED with a host-memory OOM kill (exit 137) during
Matrix Generation; it is preserved as historical boundary evidence (see
"Runtime error-patching history" below). TASK-000 has since been rearmed by
the Strategic Analyst / Human Leader with `N=700000`; all other fixed
controls are unchanged. The active attempt is
`2x8-GAAS-baseline_n700k_v1` — a single scored attempt; no v2/v3 repeats
are required for TASK-000 completion.

## Structure

- `scripts/run_2x8_baseline.pbs` — single reusable PBS run script (attempt
  label comes from the `ATTEMPT` environment at submission)
- `outputs/` — attempt-specific PBS `.o`/`.e` evidence and mechanical-check
  logs (tracked, never overwritten; every retry gets a new attempt label)

## Fixed configuration

```
OMP_NUM_THREADS=8
--n 700000
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
`N=700000` is now the Strategic-Analyst-selected fixed baseline N (rearmed
after the v1 N=737280 host-memory OOM), not a tuning choice. It is supported
by prior external performance evidence (N=700000 PASSED at 4.1061e+06
GFLOP/s, N=800000 device OOM in the historical `experiments/2Nodes-8GPUs/`
family; N=737280 sits just below the implied ~747000 device-matrix ceiling
but hit the host-memory wall) — factual context only.

## Pre-submission mechanical checks

| check | result | evidence |
|---|---|---|
| CLI flag support | all 14 supplied flags SUPPORTED by the installed NVIDIA HPC Benchmarks v26.02 package | `outputs/hplmxp_v2602_flag_check_v1.log` |
| N=737280 feasibility (v1 historical precheck) | per-GPU device matrix `737280^2 * 4 / 16 = 135.895 GB` vs 138.739 GB historical available MIN (139.80 GiB free at probe time); no obvious deterministic impossibility | arithmetic over `scripts/probing_report.md` (2x8 supplement) and historical `experiments/2Nodes-8GPUs/` runs |
| N=700000 feasibility (active attempt `2x8-GAAS-baseline_n700k_v1`) | historical 2Nodes-8GPUs run at N=700000 PASSED with host available MIN 238.426 GB/process; host FP64 matrix per node = `700000^2 * 8 / 2 ≈ 1960 GB` vs the 2000 GB per-node cgroup; per-GPU device matrix `700000^2 * 4 / 16 ≈ 122.5 GB` vs 138.739 GB available MIN | historical `experiments/2Nodes-8GPUs/` evidence |

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
qsub -q <gpu_ded|gpu_as> -v "ATTEMPT=2x8-GAAS-baseline_n700k_v1" \
     -o outputs/2x8-GAAS-baseline_n700k_v1.o -e outputs/2x8-GAAS-baseline_n700k_v1.e \
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
| 2x8-GAAS-baseline_v1 | 72595.gaas | gpu_as | hpc-gaas-g12 hpc-gaas-g15 | FAILED: host-memory OOM kill (exit 137) during Matrix Generation; no residual/verification/GFLOPS produced | none (run died before verification) | - | - |
| 2x8-GAAS-baseline_n700k_v1 | TBD | - | - | pending submission under the revised N=700000 scope | - | - | - |

No valid scored attempt exists yet. Under the revised approved scope, the
first valid N=700000 attempt becomes the immutable 2x8-GAAS original
baseline immediately (no repeats required) and the future percentage
denominator for 2x8-GAAS analysis.

## Runtime error-patching history

- `2x8-GAAS-baseline_v1` (job 72595.gaas, 2026-09-27, hpc-gaas-g12 +
  hpc-gaas-g15, queue gpu_as, walltime used 00:04:55): FAILED —
  `Exit_status = 137`. The launch itself was correct and fully validated:
  2 distinct nodes, 16 ranks, 4x4 column grid, all supplied flags echoed
  correctly by the application, internal test phase completed (GEMM/MPI/NCCL
  broadcasts/pdgemv). The application then reported
  `Per process host memory consumption MAX = 253.133 GB, available MIN = 6.782 GB`
  and `Per process device memory consumption MAX = 136.866 GB, available MIN = 138.739 GB`;
  during Matrix Generation it reported
  `Per process memory available MIN system = 6.157 GB, device = 1.155 GB`
  and was then SIGKILLed (`hpl-mxp.sh: line 261: ... Killed`; first failing
  process rank 15 on hpc-gaas-g15, exit code 137; `resources_used.mem =
  3845454204kb` of the 4000gb request). Output ends before LU/refinement;
  no residual, no verification, no GFLOPS. Mechanical arithmetic consistent
  with a host-memory wall: the FP64 host matrix at N=737280 is
  `737280^2 * 8 / 2 = ~2174 GB per node` against the 2000 GB per-node
  cgroup (the historical 2Nodes-8GPUs N-sweep README predicted the
  host-RAM wall in the 700000-800000 range by the same formula; N=700000
  PASSED with host available MIN 238.426 GB/process). **No patch
  attempted, no retry, no N change**: per TASK-000 constraint 20 and stop
  rule 1.9, an OOM at N=737280 is scientifically meaningful boundary
  evidence, not an automatic-patching defect. Evidence:
  `outputs/2x8-GAAS-baseline_v1.{o,e}`,
  `outputs/2x8-GAAS-baseline_v1_submission.log`,
  `outputs/2x8-GAAS-baseline_v1_job72595_qstat_monitor.log`.

## Evidence paths

- `outputs/` — all attempt `.o`/`.e` files
- `outputs/hplmxp_v2602_flag_check_v1.log` — mechanical flag-support check
- `scripts/probing_report.md` (2x8 Phase-0 supplement) — comprehensive
  read-only 2x8 probe evidence (job 72591.gaas, hpc-gaas-g12+hpc-gaas-g15)
