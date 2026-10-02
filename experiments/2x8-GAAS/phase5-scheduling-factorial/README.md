# 2x8-GAAS phase5-scheduling-factorial

TASK-2X8-017 (Phase 5 — Final Scheduling 2^3 Factorial) executes the complete
2^3 factorial over exactly three binary NVIDIA HPL-MxP scheduling flags on
2 GAAS nodes x 8 H200 GPUs (16 MPI ranks, one rank per GPU), with the retained
current configuration `F=0,T=0,S=1` bracketed at the beginning and end. Task
file: `tasks/TASK-2X8-017.md`; parent `TASK-2X8-016`; analysis_id
`2x8-gaas-phase5-final-scheduling-factorial`. Tuple order is always
`(F, T, S)` with

```text
F = --prioritize-factorization
T = --prioritize-trsm
S = --use-separate-stream-for-gemm
```

This is a fixed factorial, not an adaptive sweep: exactly 8 unique
configurations and 9 scored arms, one scored attempt per arm, exact fixed
order, no transition logic (the matrix is fully pre-authorized). No 10th arm,
no leader repeat, no profiling, no diagnostics, no strategic winner selection,
no follow-up, and no final full-stack confirmation run are authorized in this
task (Sections 1.1, 1.6D-E). Execution-only record: no baseline promotion.

## Provenance (TASK-2X8-017 Section 1.4A identity gate — PASSED before submission)

Evidence: `outputs/2x8-GAAS-phase5-scheduling-factorial_provenance_v1.md`
(read-only gate executed 2026-10-02 on GAAS via `hpc-gaas-hn2`; verdict PASS;
all four identity items match the TASK-2X8-016 record, and the installed
launcher was verified to support all three scheduling flags).

| item | value |
|---|---|
| SIF path (exact, unchanged) | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` |
| SIF size / mtime | 5,307,924,480 bytes / 2026-05-06 06:07:56.408241441 +0800 |
| SIF SHA-256 | `123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628` (freshly computed at the gate; equals the TASK-2X8-016 gate digest) |
| Package release | NVIDIA HPC Benchmarks **v26.02** (SIF built from `nvcr.io/nvidia/hpc-benchmarks:26.02`) |
| CUDA subdirectory (launcher-selected) | `/usr/local/cuda/lib64` → `/etc/alternatives/cuda` → `/usr/local/cuda-13.1` (CUDA 13.1) |
| Scheduling-flag launcher support | `--prioritize-trsm INT:NUMBER [0]`, `--prioritize-factorization INT:NUMBER [0]`, `--use-separate-stream-for-gemm INT:NUMBER [1]` — all three SUPPORTED by the installed v26.02 binary (flag-check evidence `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` items 10-12; binary strings + TUNING doc verified fresh at the gate) |

The run script re-records the in-job container image identity (size, mtime,
one-shot sha256) and hard-stops before any arm if the computed digest differs
from the gate digest above (image-substitution guard; Section 1.7 rule 9); an
unavailable sha256 is a non-fatal provenance record (workflow/03).

## Structure

- `README.md` — this file (pre-run README; execution record appended after execution)
- `scripts/run_phase5_scheduling_factorial.pbs` — the one same-allocation
  sequential PBS job: observational preflights (topology, rank map,
  incoming-OMP, HCA link gate, in-job image digest check), then the NINE
  scored arms in the fixed order, then the mechanical factual factorial
  summary (no adaptive logic, no retry)
- `scripts/hca_counter_snapshot.sh` — host-side per-node HCA counter/link-state
  snapshot helper invoked on every allocated node via `pbsdsh --` (lock-guarded
  once per node; validated phase4d helper copy, `.p5f` lock prefix)
- `outputs/` — all evidence: the pre-submission provenance gate record, the
  per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`/`.hcadelta` files,
  pre/post `_hca_<node>.log` snapshots on both nodes for every arm, the
  allocation-level rank-map / env-map / carry-forward / factorial-summary
  logs, the attempt hostfile, and PBS `.o`/`.e` job evidence (tracked, never
  overwritten; reruns get a new attempt tag)

## The nine arms (TASK-2X8-017 Sections 1.1, 1.6B — only F/T/S varies)

| arm | label | F | T | S | role |
|---|---|---:|---:|---:|---|
| A001a | `a001a` | 0 | 0 | 1 | retained opening control (validity gate: must be a valid PASSED arm before the factorial continues) |
| A000 | `a000` | 0 | 0 | 0 | factorial point |
| A010 | `a010` | 0 | 1 | 0 | factorial point |
| A011 | `a011` | 0 | 1 | 1 | factorial point |
| A100 | `a100` | 1 | 0 | 0 | factorial point |
| A101 | `a101` | 1 | 0 | 1 | factorial point |
| A110 | `a110` | 1 | 1 | 0 | factorial point |
| A111 | `a111` | 1 | 1 | 1 | factorial point |
| A001b | `a001b` | 0 | 0 | 1 | retained closing control (the only authorized repeat) |

`--prioritize-factorization F`, `--prioritize-trsm T`, and
`--use-separate-stream-for-gemm S` are passed EXPLICITLY on every arm; their
requested and echoed effective values are verified per arm (Section 1.6B — no
omitted default is relied on for the scientific variables).

### Fixed controls (identical on all nine arms; the formally closed Phase-4 stack)

```
--n 429056
--nb 3072
--nprow 4
--npcol 4
--nporder row
--gpu-affinity 0:1:2:3:4:5:6:7
--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted / automatic
UCX_TLS = unset / AUTO
UCX_NET_DEVICES = unset / automatic
OMP_NUM_THREADS=4   (explicit export + mpirun -x; verified = 4 on all 16 ranks)
OMP_PLACES / OMP_PROC_BIND omitted (effective launcher package defaults sockets / TRUE)
--fill-device 1
--fill-device-buffer-size 3048
--cuda-host-register-step 2048
--call-dgemv-with-multiple-threads 0
--sloppy-type FP16
--use-mpi-panel-broadcast 0
--u-panel-chunk-nbs 4
--preset-gemm-kernel 90 (EFFECTIVE via package default / SM90; v26.02 CLI accepts only
                         {0,80}; flag omitted; echoed value verified = 90)
--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Configuration specified by the Strategic Analyst and approved by the Human
Leader in `tasks/TASK-2X8-017.md` Sections 1.1, 1.6, 1.11; Codex/workers did
not derive, optimize, or modify it. The Section 1.6E prohibited list is
enforced by construction.

## Per-arm command

Identical to the validated TASK-2X8-015/016 launch model (Approach-1 container
launcher) with the arm's explicit F/T/S values:

```bash
apptainer exec --nv \
  -B /opt/pbs:/opt/pbs \
  -B /var/spool/pbs:/var/spool/pbs \
  -B "$REPO_ROOT":"$REPO_ROOT" \
  "$SIF" \
  /usr/local/mpi/bin/mpirun -np 16 \
    --hostfile <dedup hostfile, slots=8> \
    --mca plm_rsh_agent <bridge> \
    --mca plm_rsh_no_tree_spawn 1 \
    --mca plm_rsh_num_concurrent 1 \
    --mca routed direct \
    -x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS \
    --bind-to none \
    /workspace/hpl-mxp.sh <fixed args above> \
      --prioritize-factorization <F> --prioritize-trsm <T> --use-separate-stream-for-gemm <S>
```

No UCX/NCCL diagnostic `-x` variables; UCX_TLS is deliberately NOT forwarded
(AUTO arms, verified UNSET on all 16 ranks).

## Per-arm evidence (TASK-2X8-017 Section 1.4B)

Around every executed arm the script preserves:

- per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`/`.hcadelta` files plus
  `hcapre`/`hcapost` snapshots on both nodes (all eight expected physical IB
  HCAs, Section 1.4C);
- requested + effective F/T/S values (explicit request, echoed verification);
- overall/LU GFLOP/s; LU/IR seconds; IR/LU ratio; refinement iteration count;
- finite residual + PASSED (hard validity gates); host/device memory
  consumption and device headroom; total arm wall-clock;
- all application-emitted `<phase> seconds: AVG/MAX/MIN (rank->host)` timing
  lines (raw, in `.timings`; includes GEMM and NCCL U/L2 component timing);
- `OMP_NUM_THREADS=4` verification on all 16 ranks; the
  rank/node/local-rank/GPU map (rank-map log + fixed identity GPU map, local
  rank r -> GPU r, confirmed by the settings echo);
- requested + effective fixed controls (`settings_echo_check`);
- exact UCX/NCCL diagnostic environment state (all verified UNSET on all 16
  ranks) and the UCX_TLS=UNSET (AUTO) / UCX_NET_DEVICES unset state;
- HCA TX/RX deltas per HCA and per node, rail shares/CV, `port_xmit_wait`
  deltas where usable, and error/discard/recovery counter deltas (any nonzero
  delta is flagged; a material HCA/link error is a Section 1.9
  stop-and-report condition);
- PBS job ID, queue, nodes, timestamps, arm exit status (run count from the
  PBS job records / post-run `qstat -fx`, submission-side).

Failure behavior: a nonzero arm exit or a failed settings-echo check
(including a requested F/T/S value not applied exactly) preserves all
evidence and stops the job nonzero — no retry and no second scored attempt of
any arm under this task (a begun arm counts as its one attempt; Section 1.7
rules 14/20); a rerun needs a new `ATTEMPT_TAG` plus human direction. An
invalid A001a stops before A000 (rule 11). An exit-0 non-control candidate
with an invalid verification is preserved as an invalid candidate record and
the fixed matrix continues while the allocation and fixed controls remain
healthy (rules 12-13; Section 1.9). A001b is the only authorized repeat; if
it differs materially from A001a the drift is recorded and no arm is rerun
(rules 16-17). A numerically slower or surprising combination is valid
experimental evidence and is never repeated.

## Factual factorial summary (TASK-2X8-017 Section 1.4D — mechanical only)

After all nine arms the script writes
`outputs/2x8-GAAS-phase5-scheduling-factorial_factorial_summary_<tag>.log`
containing, without strategic interpretation:

1. the factual per-arm table (arm, F, T, S, overall, LU seconds, LU GFLOP/s,
   IR seconds, iterations, residual, verification, memory);
2. the A001a/A001b control midpoint and LU/overall bracket spread;
3. each arm's percentage delta versus the A001 control midpoint for overall
   and LU GFLOP/s;
4. the arithmetic main-effect level means/differences for F, T, and S, and the
   pairwise (F×T, F×S, T×S) and three-way (F×T×S) interaction contrasts for
   both metrics — computed only when all eight unique factorial points are
   valid (the 001 unique point is the A001a measurement).

These calculations are descriptive evidence, not winner selection.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ncpus=96:ngpus=8:mem=2000GB` (no `mpiprocs`) |
| Placement | `place=scatter` |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; pass `-q gpu_as` or `-q gpu_ded` at qsub; the script verifies the assigned queue. TASK-2X8-017 Section 1.6C combined eligible pool `gpu_as` UNION `gpu_ded`: the two nodes need not share a queue label, but the PBS allocation must be legal |
| Walltime | `03:00:00` default (validated phase4c 11-arm request; may be overridden at qsub) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (digest-gated, see Provenance) |
| Launcher | container `mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (validated Approach 1; `multi-node-test/GAAS_MULTINODE_SETUP.md`) |
| Presubmit | `pbsnodes -aSj` snapshot over the eligible queues immediately before submission selects the cleanest schedulable pair from the combined pool (submission-side evidence, not part of the script) |

## Attempt and output naming

`ATTEMPT_TAG` (e.g. `v1`) is required via `qsub -v`. Attempt ID:
`2x8-GAAS-phase5-scheduling-factorial_<arm>_<ATTEMPT_TAG>` per arm. Every
evidence file is attempt-tagged beneath `outputs/`; the pre-run guard refuses
any pre-existing target (all nine arm labels x the six per-arm file suffixes,
both per-node hcapre/hcapost snapshot globs per arm, and the
rankmap/envmap/carryforward/factorial-summary logs and attempt hostfile);
existing evidence is never overwritten and reruns need a new tag.

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` |
| arm status | `outputs/<attempt>.status` |
| per-arm env-probe evidence | `outputs/<attempt>.envprobe` |
| per-arm timing markers | `outputs/<attempt>.timings` |
| per-arm HCA snapshots | `outputs/<attempt>_hca{pre,post}_hca_<node>.log` (both nodes) |
| per-arm HCA deltas | `outputs/<attempt>.hcadelta` |
| allocation rank-map log | `outputs/2x8-GAAS-phase5-scheduling-factorial_rankmap_<tag>.log` |
| per-arm env-map log | `outputs/2x8-GAAS-phase5-scheduling-factorial_envmap_<tag>.log` |
| carry-forward log | `outputs/2x8-GAAS-phase5-scheduling-factorial_carryforward_<tag>.log` |
| factual factorial summary | `outputs/2x8-GAAS-phase5-scheduling-factorial_factorial_summary_<tag>.log` |
| attempt hostfile | `outputs/2x8-GAAS-phase5-scheduling-factorial_hostfile_<tag>` |
| provenance gate record | `outputs/2x8-GAAS-phase5-scheduling-factorial_provenance_v1.md` (pre-existing) |
| v1 submission-side evidence (job 77060.gaas, never ran, user-canceled; preserved) | `outputs/2x8-GAAS-phase5-scheduling-factorial_v1.submission.log`, `..._v1.presubmit_pbsnodes.log`, `..._v1.qstat_monitor.log`, `..._v1.qdel_record.log` |
| v2 submission-side evidence | `outputs/2x8-GAAS-phase5-scheduling-factorial_v2.submission.log`, `..._v2.presubmit_pbsnodes.log`, `..._v2.qstat_monitor.log` |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase5-scheduling-factorial_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase5-scheduling-factorial_<tag>.e` |

## Attempt history

### v1 — submitted 2026-10-02 16:49:41 +0800, user-canceled before start; ZERO scored arms

- Exactly one qsub: PBS job `77060.gaas`, queue `gpu_ded`, unpinned
  `select=2:ncpus=96:ngpus=8:mem=2000GB,place=scatter,walltime=03:00:00`,
  `-v ATTEMPT_TAG=v1`, submitted from the clean execution worktree
  `.codex-worktrees/TASK-2X8-017-b89376b-phase5-v1`
  (HEAD `b89376b1475b2a712a89ebc6e012b6fc2a709e26`; scripts hash-verified
  against local). See
  `outputs/2x8-GAAS-phase5-scheduling-factorial_v1.submission.log`.
- The job NEVER RAN: from the first post-submit `qstat -f` (16:49:53) PBS
  reported `Not Running: Insufficient amount of resource: Qlist` — the
  unpinned gpu_ded request needed two fully-free `Qlist=gpu_ded` nodes but
  only `g22` was fully free (the other fully-free eligible node, `g15`,
  carries `Qlist=gpu_as,gpu_ppu`; v1 presubmit snapshot
  `outputs/2x8-GAAS-phase5-scheduling-factorial_v1.presubmit_pbsnodes.log`).
- The user explicitly canceled the queued job before it started (user
  statement: qdel returned 0; qstat says finished). Final PBS record:
  `job_state=F`, `substate=91`, comment
  `Not Running: Insufficient amount of resource: Qlist and terminated`,
  no start time / exec_host / resources_used, mtime = history_timestamp
  2026-10-02 16:56:40 +0800. Full evidence:
  `outputs/2x8-GAAS-phase5-scheduling-factorial_v1.qdel_record.log`
  (also records that `tracejob` is not available to this account).
- Consequence: ZERO of the nine scored arms were attempted; the v1 PBS
  `.o`/`.e` paths were never created (the job never executed). The fixed
  nine-arm matrix is entirely unattempted after v1. All v1 evidence is
  preserved under `outputs/` with v1 names and will never be reused or
  overwritten; later attempts use new tags.

### v2 — user-directed cross-queue attempt (planned)

User direction (2026-10-02, recorded before the v2 submission): cross-queue
allocation is now allowed; try the fully free pair `hpc-gaas-g15` (gpu_as) +
`hpc-gaas-g22` (gpu_ded) via ONE qsub using a host-pinned two-chunk select
with per-chunk `Qlist` values under one eligible queue, if PBS accepts it:

```text
select=host=hpc-gaas-g15:ngpus=8:ncpus=96:mem=2000GB:Qlist=gpu_as+host=hpc-gaas-g22:ngpus=8:ncpus=96:mem=2000GB:Qlist=gpu_ded
place=scatter, group hpc_ebslee (#PBS -P), no mpiprocs, walltime=03:00:00
```

Scheduler facts recorded by the user (read-only): `Qlist` resource is
type=string_array flag=h; `gpu_as` default_chunk.Qlist=gpu_as;
`gpu_ded` default_chunk.Qlist=gpu_ded; g15 Qlist=gpu_as,gpu_ppu; g22
Qlist=gpu_ded. Boundary conditions directed by the user: if PBS rejects the
per-chunk Qlist syntax or keeps the job held for Qlist incompatibility, do
not alter scheduler configuration, do not submit additional jobs, preserve
the outcome, and report the exact additional cluster-side action needed; do
not attempt a same-queue fallback without reporting back. The already-reviewed
runner, exact nine-arm matrix, bounded monitoring, and retrieval proceed only
if the exact g15+g22 request is accepted and runnable. No further job
cancellation unless required to remove this user-authorized mixed-pair
request that provably cannot run (gather state/evidence first, then cancel
and record).

## Submission (planned; under the approved TASK-2X8-017 Section 1.11 authorization)

Submission is authorized under the unchanged approved Section 1.11 authorization
of TASK-2X8-017 and the exact approved task scope. The provenance identity gate
PASSED before the v1 submission (see above); a fresh light identity re-check of
the same four items is recorded in the v2 submission log before the v2 qsub, and
the run script re-records and hard-gates the in-job image digest. A fresh
`pbsnodes -aSj` snapshot over the eligible queues is taken immediately before
the v2 submission as submission-side evidence (see Attempt history — v2). One
same-allocation sequential PBS job (Section 1.6C); one multinode job at a time;
monitoring is bounded.

v2 submission form (user-directed cross-queue host-pinned select; see Attempt
history — v2; `-q` takes one eligible queue):

```bash
qsub -q <gpu_as|gpu_ded> \
     -l select=host=hpc-gaas-g15:ncpus=96:ngpus=8:mem=2000GB:Qlist=gpu_as+host=hpc-gaas-g22:ncpus=96:ngpus=8:mem=2000GB:Qlist=gpu_ded,place=scatter,walltime=03:00:00 \
     -v "ATTEMPT_TAG=v2" \
     -o outputs/2x8-GAAS-phase5-scheduling-factorial_v2.o \
     -e outputs/2x8-GAAS-phase5-scheduling-factorial_v2.e \
     scripts/run_phase5_scheduling_factorial.pbs
```

The v1 form (unpinned select) and its outcome are preserved in Attempt
history — v1; v1 output names are never reused.

## Expected output markers and validation criteria

Every arm is valid only when its `outputs/<attempt>.out` contains:

- `****** Matrix Generation ******`;
- `Solver iteration ... L-infinite residual = ...` lines;
- the normalized-residual line
  `||Ax-b||_oo / (EPS * (||A||_oo * ||x||_oo + ||b||_oo) * N) = <finite residual> ...... PASSED`
  (`FAILED`/non-finite is invalid — the finite residual is a hard validity
  gate even with exit 0);
- `GFLOPS = ... , per GPU = ...` (the overall score to report) and `LU GFLOPS = ...`;
- the settings block echoing the arm's exact effective controls INCLUDING the
  arm's exact `--prioritize-factorization`, `--prioritize-trsm`, and
  `--use-separate-stream-for-gemm` values, verified by the script's
  `settings_echo_check`;
- a measured performance result (normal benchmark output, not a stop during
  initialization or internal tests).

Job-level: the job is operationally complete only when all nine arms were
attempted exactly once in the fixed order, A001a was valid, and no hard stop
fired; a run is correct per-arm only when PBS completed, the expected files
exist, the harness reported successful verification, the residuals were
finite within tolerance, and the output was normal benchmark output with a
measured performance. The `.status` records `exit_status`,
`verification=PASSED`, and `settings_echo_check=PASS`; do not classify
success from exit status alone. An arm killed mid-run (e.g. by walltime)
keeps its `.out`/`.err` but has no `.status` file, and later arms were not
run.

## Available reference provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s; same scored-run protocol (`--skip-tests 0 --monitor-gpu 0`); campaign percentage denominator for 2x8-GAAS comparisons (baseline-relative percentages belong to the post-task analysis under `ANALYSE_RESULTS`, not to this execution record). |
| TASK-2X8-016 confirmation of the retained stack entering Phase 5 | overall `6.8196e+06` GFLOP/s; LU `7.43` s / `7.0833e+06` GFLOP/s; IR `0.29` s; residual `1.416310E-05`; PASSED (PBS job 76998.gaas; `experiments/2x8-GAAS/phase4d-chunk4-confirmation/`) |

This task does not rerun, select, or promote any baseline, and computes no
baseline-relative percentage deltas; the A001-control-midpoint deltas and
factorial contrasts of Section 1.4D are the only mechanical derived values.
No exact score reproduction is required — the Strategic Analyst determines
the scheduling interpretation after `ANALYSE_RESULTS`.
