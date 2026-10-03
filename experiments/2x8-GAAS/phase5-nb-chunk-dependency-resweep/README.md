# 2x8-GAAS phase5-nb-chunk-dependency-resweep

TASK-2X8-018 (Phase 5 — NB × U-Panel Chunk Dependency Revalidation) executes
one bounded dependency revalidation after TASK-2X8-017 selected the strong
Phase-5 scheduling candidate `F=1, T=0, S=1` (scheduler 101). It runs the
fixed valid NB × u-panel-chunk matrix under that retained scheduler on 2 GAAS
nodes × 8 H200 GPUs (16 MPI ranks, one rank per GPU). Task file:
`tasks/TASK-2X8-018.md`; parent `TASK-2X8-017`; analysis_id
`2x8-gaas-phase5-nb-chunk-dependency-revalidation`. Tuple order is always
`(F, T, S)` with

```text
F = --prioritize-factorization
T = --prioritize-trsm
S = --use-separate-stream-for-gemm
```

Only NB and `--u-panel-chunk-nbs` vary; the scheduler is fixed at 101 and is
passed explicitly on every arm with the echoed effective values verified per
arm (TASK-2X8-018 Sections 1.6A–1.6B).

This is a fixed dependency-resweep matrix, not an adaptive search: exactly
21 unique valid configurations plus one closing control repeat = 22 scored
arms, one scored attempt per arm, exact fixed order, no transition logic
(the matrix is fully pre-authorized). No 23rd arm, no fine NB/chunk
refinement, no N resweep, no grid revalidation, no additional scheduling
combinations, no numerical-leader repeat, no second control repeat beyond
C3072K4b, no profiling, no diagnostics, no strategic winner selection, no
follow-up, and no final full-stack confirmation run are authorized in this
task (Sections 1.1, 1.6C–1.6F). Execution-only record: no baseline promotion.

## Provenance (TASK-2X8-018 Section 1.4A identity gate — PASS)

This experiment reuses the TASK-2X8-016/017 provenance identity. The
read-only pre-submit gate (identity check + launcher-support verification)
was executed on 2026-10-03 and is recorded in
`outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_provenance_v1.md`.
Required identity:

| item | value |
|---|---|
| SIF path (exact, unchanged) | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` |
| SIF SHA-256 | `123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628` (TASK-2X8-016/017 gate digest) |
| Package release | NVIDIA HPC Benchmarks **v26.02** |
| CUDA subdirectory (launcher-selected) | `/usr/local/cuda-13.1` (CUDA 13.1) |

The pre-submit gate must also verify from the installed launcher/runtime
that `--u-panel-chunk-nbs` and the three scheduling flags remain supported
and that the requested/effective NB and chunk values can be echoed and
checked (support evidence: flag-check log
`experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`
items 10–12 plus prior CLI acceptance — all six NB values in
TASK-003/TASK-2X8-011 phase1b, chunk 2/4/8/16 in TASK-2X8-015 phase4c and
TASK-2X8-016, scheduling flags in TASK-2X8-017). Stop before submission if
the image/package/CUDA identity differs (Section 1.9); do not repeat a
broad provenance investigation when the identity matches.

The run script re-records the in-job container image identity (size, mtime,
one-shot sha256) and hard-stops before any arm if the computed digest
differs from the gate digest above (image-substitution guard; Section 1.7
rule 9); an unavailable sha256 is a non-fatal provenance record
(workflow/03). In-job support/echo enforcement: the per-arm settings-echo
check verifies the requested/effective NB, u-panel-chunk-nbs, and the three
explicit 101 scheduling values were applied exactly on every arm.

## Structure

- `README.md` — this file (pre-run README; the execution record is appended
  after the run)
- `scripts/run_phase5_nb_chunk_dependency_resweep.pbs` — the one
  same-allocation sequential PBS job: observational preflights (topology,
  rank map, incoming-OMP, HCA link gate, in-job image digest check), then
  the TWENTY-TWO scored arms in the fixed order, then the mechanical
  factual matrix summary (no adaptive logic, no retry)
- `scripts/hca_counter_snapshot.sh` — host-side per-node HCA counter/link-state
  snapshot helper invoked on every allocated node via `pbsdsh --` (lock-guarded
  once per node; validated phase4d/phase5 helper copy, `.p5r` lock prefix)
- `outputs/` — all evidence: the pre-submission provenance gate record, the
  per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`/`.hcadelta` files,
  pre/post `_hca_<node>.log` snapshots on both nodes for every arm, the
  allocation-level rank-map / env-map / carry-forward / matrix-summary
  logs, the attempt hostfile, and PBS `.o`/`.e` job evidence (tracked,
  never overwritten; reruns get a new attempt tag)

## The 22 arms (TASK-2X8-018 Sections 1.1, 1.6B — only NB and chunk vary)

| arm | label | NB | chunk | role |
|---|---|---:|---:|---|
| C3072K4a | `c3072k4a` | 3072 | 4 | retained opening control + matrix point (validity gate: must be a valid PASSED arm before the matrix continues) |
| N1024K8 | `n1024k8` | 1024 | 8 | valid matrix point |
| N1024K16 | `n1024k16` | 1024 | 16 | valid matrix point |
| N2048K4 | `n2048k4` | 2048 | 4 | valid matrix point |
| N2048K8 | `n2048k8` | 2048 | 8 | valid matrix point |
| N2048K16 | `n2048k16` | 2048 | 16 | valid matrix point |
| N3072K2 | `n3072k2` | 3072 | 2 | valid matrix point |
| N3072K8 | `n3072k8` | 3072 | 8 | valid matrix point |
| N3072K16 | `n3072k16` | 3072 | 16 | valid matrix point |
| N4096K2 | `n4096k2` | 4096 | 2 | valid matrix point |
| N4096K4 | `n4096k4` | 4096 | 4 | valid matrix point |
| N4096K8 | `n4096k8` | 4096 | 8 | valid matrix point |
| N4096K16 | `n4096k16` | 4096 | 16 | valid matrix point |
| N5120K2 | `n5120k2` | 5120 | 2 | valid matrix point |
| N5120K4 | `n5120k4` | 5120 | 4 | valid matrix point |
| N5120K8 | `n5120k8` | 5120 | 8 | valid matrix point |
| N5120K16 | `n5120k16` | 5120 | 16 | valid matrix point |
| N6144K2 | `n6144k2` | 6144 | 2 | valid matrix point |
| N6144K4 | `n6144k4` | 6144 | 4 | valid matrix point |
| N6144K8 | `n6144k8` | 6144 | 8 | valid matrix point |
| N6144K16 | `n6144k16` | 6144 | 16 | valid matrix point |
| C3072K4b | `c3072k4b` | 3072 | 4 | retained closing control (the only authorized repeat) |

`--nb <NB>` and `--u-panel-chunk-nbs <chunk>` are passed EXPLICITLY on every
arm; their requested and echoed effective values are verified per arm
(Section 1.6B — no omitted default is relied on for either scientific
variable). The three scheduling flags are fixed at 1/0/1, passed explicitly
on every arm, and echo-verified per arm. C3072K4a is the unique
NB=3072/chunk=4 matrix sample; C3072K4b is its only authorized repeat.

## Geometry-validity rule (Section 1.4B)

For the retained geometry `N = 429056`, `npcol = 4`, every arm must satisfy
the established Phase-4 validity rule:

```text
((N / NB) / npcol) / chunk < 20
```

The approved matrix already excludes the invalid pairs; the runner
re-verifies the rule (and the authorized value sets NB ∈
{1024,2048,3072,4096,5120,6144}, chunk ∈ {2,4,8,16}) in a per-arm
`geometry_gate` BEFORE every arm, so an invalid or unauthorized pair in the
fixed list can never execute. Expected validity (ratio = ((N/NB)/4)/chunk):

| NB | chunk 2 | chunk 4 | chunk 8 | chunk 16 |
|---:|:---:|:---:|:---:|:---:|
| 1024 | invalid (52.375) | invalid (26.1875) | valid (13.09) | valid (6.55) |
| 2048 | invalid (26.1875) | valid (13.09) | valid (6.55) | valid (3.27) |
| 3072 | valid (17.46) | valid (8.73) | valid (4.36) | valid (2.18) |
| 4096 | valid (13.09) | valid (6.55) | valid (3.27) | valid (1.64) |
| 5120 | valid (10.48) | valid (5.24) | valid (2.62) | valid (1.31) |
| 6144 | valid (8.73) | valid (4.36) | valid (2.18) | valid (1.09) |

Do not run: NB=1024 with chunk 2 or 4; NB=2048 with chunk 2. Do not
substitute another value for an invalid pair (Sections 1.4B, 1.6B, 1.6F).

### Fixed controls (identical on all 22 arms; the closed Phase-4 stack + scheduler 101)

```
--n 429056
--nb <arm NB>                    (explicit per arm; echo verified)
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
--u-panel-chunk-nbs <arm chunk>  (explicit per arm; echo verified)
--prioritize-factorization 1     (fixed 101 scheduler; explicit per arm; echo verified)
--prioritize-trsm 0              (fixed 101 scheduler; explicit per arm; echo verified)
--use-separate-stream-for-gemm 1 (fixed 101 scheduler; explicit per arm; echo verified)
--preset-gemm-kernel 90 (EFFECTIVE via package default / SM90; v26.02 CLI accepts only
                          {0,80}; flag omitted; echoed value verified = 90)
--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Configuration specified by the Strategic Analyst and approved by the Human
Leader in `tasks/TASK-2X8-018.md` Sections 1.1, 1.6, 1.11; Codex/workers did
not derive, optimize, or modify it. The Section 1.6F prohibited list is
enforced by construction.

## Per-arm command

Identical to the validated TASK-2X8-015/016/017 launch model (Approach-1
container launcher) with the arm's explicit NB/chunk values under the fixed
explicit 101 scheduler:

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
      --nb <NB> --u-panel-chunk-nbs <chunk> \
      --prioritize-factorization 1 --prioritize-trsm 0 --use-separate-stream-for-gemm 1
```

No UCX/NCCL diagnostic `-x` variables; UCX_TLS is deliberately NOT forwarded
(AUTO arms, verified UNSET on all 16 ranks).

## Per-arm evidence (TASK-2X8-018 Sections 1.4C, 1.4D)

Around every executed arm the script preserves:

- per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`/`.hcadelta` files plus
  `hcapre`/`hcapost` snapshots on both nodes (all eight expected physical IB
  HCAs, Section 1.4D);
- requested + effective NB and u-panel-chunk-nbs values (explicit request,
  echoed verification) and the per-arm geometry-validity ratio;
- requested + effective fixed 101 scheduling values (explicit request,
  echoed verification);
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

Failure behavior: a nonzero arm exit or a failed settings-echo check (a
fixed control, the arm's requested NB/chunk, or a requested 101 scheduling
value not applied exactly) preserves all evidence and stops the job nonzero
— no retry and no second scored attempt of any arm under this task (a begun
arm counts as its one attempt; Section 1.7 rules 16/22); a rerun needs a new
`ATTEMPT_TAG` plus human direction. An invalid C3072K4a stops before
N1024K8 (rule 10). An exit-0 non-control matrix point with an invalid
verification is preserved as an invalid candidate record and the fixed
matrix continues while the allocation and fixed controls remain healthy
(rule 15; Section 1.9). C3072K4b is the only authorized repeat; if it
differs materially from C3072K4a the drift is recorded and no arm is rerun
(rules 18/19). A numerically slower or surprising pair — including a ranking
reversal versus the historical NB/chunk evidence — is valid experimental
evidence and is never repeated (Section 1.9: do not stop merely because the
historical ranking reverses).

## Factual matrix summary (TASK-2X8-018 Section 1.4E — mechanical only)

After all 22 arms the script writes
`outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_matrix_summary_<tag>.log`
containing, without strategic interpretation:

1. the factual per-arm table (arm, role, NB, chunk, overall GFLOP/s, LU
   seconds, LU GFLOP/s, IR seconds, iterations, residual, verification,
   settings, validity, memory);
2. the C3072K4a/C3072K4b control midpoint and LU/overall bracket spread;
3. each arm's percentage delta versus the C3072K4 control midpoint for
   overall and LU GFLOP/s;
4. within each NB, the valid chunk points, the chunk ordering by overall
   (and by LU when numeric), the best measured valid chunk, and the spread
   across chunks;
5. within each chunk with at least two valid NB points, the measured NB
   ordering;
6. factual NB × chunk interaction indicators: per-NB chunk deltas versus
   that NB's best valid chunk, and strict order reversals of the chunk
   ordering across NB pairs sharing at least two common valid chunks
   (overall and LU; ties never count);
7. factual IR/memory-regime difference flags versus the opening control
   (exact-value comparisons only; materiality belongs to analysis).

The NB=3072/chunk=4 point of every grouping is C3072K4a (the unique matrix
sample); C3072K4b is the control repeat and is excluded from the groupings.
Scientifically invalid arms are preserved in the table but excluded from the
arithmetic. These calculations are descriptive evidence, not winner
selection.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes × 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ncpus=96:ngpus=8:mem=2000GB` (no `mpiprocs`, NOT host-pinned) |
| Placement | `place=scatter` |
| Accounting project | `hpc_ebslee` |
| Queue | `gpu_as` — user-directed unpinned single `qsub -q gpu_as` for the `v1` attempt (authorized in the current conversation; to be recorded by Codex in the task report). This narrowly supersedes the TASK-2X8-018 Section 1.6D combined-pool pair-selection procedure for this attempt only; the scheduler picks the two gpu_as-eligible nodes. The script verifies the assigned queue is gpu_as and aborts on anything else. The Section 1.11 scientific scope is unchanged |
| Walltime | `03:00:00` default (validated phase4c/phase5 request; 22 arms ≈ 35–45 min expected based on phase1b/phase4c/phase5 arm timings; may be overridden at qsub) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (digest-gated, see Provenance) |
| Launcher | container `mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (validated Approach 1; `multi-node-test/GAAS_MULTINODE_SETUP.md`) |
| Presubmit | fresh `pbsnodes -aSj` snapshot over the eligible queues immediately before submission (submission-side evidence, not part of the script) |

## Attempt and output naming

`ATTEMPT_TAG` (this attempt: `v1`, user-directed fresh
tag) is required via `qsub -v`. Attempt ID:
`2x8-GAAS-phase5-nb-chunk-dependency-resweep_<arm>_<ATTEMPT_TAG>` per arm.
Every evidence file is attempt-tagged beneath `outputs/`; the pre-run guard
refuses any pre-existing target (all 22 arm labels × the six per-arm file
suffixes, both per-node hcapre/hcapost snapshot globs per arm, and the
rankmap/envmap/carryforward/matrix-summary logs and attempt hostfile);
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
| allocation rank-map log | `outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_rankmap_<tag>.log` |
| per-arm env-map log | `outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_envmap_<tag>.log` |
| carry-forward log | `outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_carryforward_<tag>.log` |
| factual matrix summary | `outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_matrix_summary_<tag>.log` |
| attempt hostfile | `outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_hostfile_<tag>` |
| provenance gate record | `outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_provenance_v1.md` (created by Codex at the pre-submit gate) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_<tag>.e` |

## Attempt history

### v1 — submitted (first attempt; intentionally unmonitored in the submitting session)

- Attempt tag `v1`; no prior v1 run evidence existed before submission. The
  provenance identity/support gate passed, the target-absence check passed,
  and the required pre-submit `pbsnodes -aSj` snapshot was captured at
  `outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_v1.presubmit_pbsnodes.log`.
- Submitted exactly one unpinned `qsub -q gpu_as` on 2026-10-03 at
  approximately `04:55:51 +08:00`; PBS returned job `77344.gaas`.
- User-directed stop point: immediately after qsub returned. The scheduler
  state, assigned nodes, PBS stdout/stderr, and benchmark outputs were not
  queried or retrieved in this session.
- User direction for this attempt (authorized in the current conversation;
  Codex records it in the task report): submit unpinned to queue `gpu_as`;
  do NOT host-pin a node pair in the runner or the planned qsub; pause
  immediately after the qsub returns — no qstat, no monitoring, no cancel,
  and no retrieval in the submitting session. The script itself still runs
  its exact preauthorized 22 arms after PBS starts.
- The execution record (nodes, per-arm facts, matrix summary facts, and
  retrieval state) will be completed after the run is monitored and evidence
  is retrieved in a later session.

## Submission (completed; under the approved TASK-2X8-018 Section 1.11 authorization plus the current-conversation queue/pause direction)

The exact approved Section 1.11 scope was retained, with the user's separate
queue/pause instruction recorded in the task file. The Section 1.4A gate and
the fresh pre-submit `pbsnodes -aSj` snapshot passed and are recorded above.
PBS accepted one same-allocation sequential job, `77344.gaas`, on queue
`gpu_as`; the select was unpinned.

Submission form (user-directed unpinned gpu_as; no `-l` override —
the script's `#PBS` select/place/walltime apply):

```bash
qsub -q gpu_as \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_v1.o \
     -e outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_v1.e \
     scripts/run_phase5_nb_chunk_dependency_resweep.pbs
```

After qsub returned, Codex paused as directed. No qstat, monitoring, cancel,
or retrieval occurred in the submitting session. Bounded monitoring and
retrieval happen only in a later session under the same approved scope.

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
  arm's exact `--nb`, `--u-panel-chunk-nbs`, and the fixed
  `--prioritize-factorization 1`, `--prioritize-trsm 0`,
  `--use-separate-stream-for-gemm 1` values, verified by the script's
  `settings_echo_check`;
- a measured performance result (normal benchmark output, not a stop during
  initialization or internal tests).

Job-level: the job is operationally complete only when all 22 arms were
attempted exactly once in the fixed order, C3072K4a was valid, and no hard
stop fired; a run is correct per-arm only when PBS completed, the expected
files exist, the harness reported successful verification, the residuals
were finite within tolerance, and the output was normal benchmark output
with a measured performance. The `.status` records `exit_status`,
`verification=PASSED`, and `settings_echo_check=PASS`; do not classify
success from exit status alone. An arm killed mid-run (e.g. by walltime)
keeps its `.out`/`.err` but has no `.status` file, and later arms were not
run.

## Available reference provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s; same scored-run protocol (`--skip-tests 0 --monitor-gpu 0`); campaign percentage denominator for 2x8-GAAS comparisons (baseline-relative percentages belong to the post-task analysis under `ANALYSE_RESULTS`, not to this execution record). |
| TASK-2X8-017 scheduler-101 reference (the retained scheduling state this resweep runs under) | arm `a101` (PBS job 77076.gaas, `experiments/2x8-GAAS/phase5-scheduling-factorial/`): overall `7.2398e+06` GFLOP/s; LU `6.99` s / `7.5380e+06` GFLOP/s; IR `0.29` s; 3 iterations; residual `1.416310E-05`; PASSED. The opening control C3072K4a re-runs this configuration (NB=3072/chunk=4 under 101). |

This task does not rerun, select, or promote any baseline, and computes no
baseline-relative percentage deltas; the C3072K4-control-midpoint deltas and
the Section 1.4E group/interaction facts are the only mechanical derived
values. No exact score reproduction is required — the Strategic Analyst
determines the dependency interpretation after `ANALYSE_RESULTS`.

## v1 execution record (completed 2026-10-03; factual only)

Job `77344.gaas` (queue `gpu_as`, unpinned select
`select=2:ncpus=96:ngpus=8:mem=2000GB,place=scatter`, group `hpc_ebslee`)
finished `F` with exit `0` on nodes `hpc-gaas-g14` + `hpc-gaas-g15`. Job-shell
start echo `2026-10-03T16:07:25+08:00`; first scored arm (C3072K4a) started
`16:08:26`, last scored arm (C3072K4b) ended `16:45:45`; the factual matrix
summary was derived at `16:46:00` (all `+08:00`). All evidence (229 files)
was retrieved into `outputs/` with matching transfer checksums; no rerun and
no second attempt of any arm occurred (one scored attempt per arm; a begun
arm counts as its one attempt).

Gate counts (all evidenced under `outputs/`):

- 22/22 arms attempted exactly once in the Section 1.6B fixed order; 0
  invalid arms; 0 invalid candidate records; no early cutoff and no adaptive
  branch fired.
- 22/22 `.status` files record `exit_status=0`, `verification=PASSED`,
  `settings_echo_check=PASS`, `valid_performance_point=yes`; every arm's
  echoed settings block matches the requested/effective NB, chunk, and the
  fixed 101 scheduler (`--prioritize-factorization 1`,
  `--prioritize-trsm 0`, `--use-separate-stream-for-gemm 1`), plus all fixed
  controls (N=429056, 4x4 row, identity GPU affinity, fill 1 / buffer 3048 /
  register 2048, dgemv 0, FP16, panel broadcast 0, effective
  preset-gemm-kernel 90, test-loop 1, skip-tests 0, monitor-gpu 0).
- Per-arm geometry gate PASS for all 22 arms (ratio
  ((429056/NB)/4)/chunk < 20; e.g. C3072K4a ratio 8.729167); the three
  excluded invalid pairs were never run.
- 352/352 rank env probes (22 arms × 16 ranks) show `OMP_NUM_THREADS=4`;
  `OMP_PLACES`/`OMP_PROC_BIND` UNSET; `UCX_TLS` UNSET (AUTO) and every
  UCX/NCCL diagnostic variable UNSET on all ranks (env-map log).
- In-job SIF digest matched the TASK-2X8-016/017 gate digest on every arm
  (`container_image_sha256_injob` = gate value
  `123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628`).
- All 22 `.hcadelta` files report `NEW_ERRORS new_counters=none` on both
  nodes (no new error/discard/recovery state; no HCA/link/platform fault);
  pre/post HCA snapshots exist for both nodes on every arm.
- Every arm's normalized residual is finite and `PASSED` (10 distinct
  residual values; smallest `1.330473E-05` n1024k8, largest `9.833928E-05`
  the four NB=6144 chunk>=4 arms); all arms 3 refinement iterations.
- C3072K4a validity gate PASS before the matrix continued (carry-forward
  log `GATE C3072K4a: PASS`); C3072K4b is the only repeat.

### v1 Section 1.4E factual matrix table (all 22 arms, one table)

The required TASK-2X8-018 Section 1.4E factual matrix table: all 22 scored
arms in the fixed Section 1.6B arm order, with every required field in one
table. All values are original raw values — overall/LU GFLOP/s, LU/IR
seconds, IR/LU, iterations, residual, verification, and host/device memory
consumption are the raw matrix-summary values
(`outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_matrix_summary_v1.log`
DATA lines, identical to the per-arm `.status` records); the two delta
columns are the raw matrix-summary control-midpoint percentage deltas
(section 3 of that log); device headroom is extracted from each arm's raw
`.status`/`.out` evidence. No required value is missing or unavailable for
any arm. Mechanical verification performed: exactly 22 rows in the exact
fixed order; the control midpoint is the arithmetic mean of C3072K4a/C3072K4b
(overall `7.23545e+06`, LU `7.5324e+06` GFLOP/s); both delta columns and
every IR/LU ratio were recomputed from the raw overall/LU/IR values and
match the matrix summary; the device headroom in each row matches both
matrix-generation availability lines of that arm's `.out`. Factual only —
no strategic interpretation, no winner selection, and no baseline-relative
percentages (Section 1.4E).

Column meanings (consumption vs headroom): "host memory" and "device
memory" are per-process consumption MAX in GB; "device headroom" is the
per-process minimum available device memory at matrix generation
(`matgen_headroom` in each arm's `.status`, GB) — a minimum-available
(headroom) measure, not a consumption value. The separate
`available MIN = 138.739 GB` figure printed on every arm's `device_memory`
output line (identical on all 22 arms) is a distinct availability value and
is not the minimum device headroom reported here.

| arm | NB | chunk | overall GFLOP/s | overall delta vs control midpoint (%) | LU seconds | LU GFLOP/s | LU delta vs control midpoint (%) | IR seconds | IR/LU | iterations | residual | verification | host memory (GB) | device memory (GB) | device headroom (GB) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---:|---:|---:|
| C3072K4a | 3072 | 4 | 7.2303e+06 | -0.0712 | 7.00 | 7.5266e+06 | -0.0770 | 0.29 | 0.041 | 3 | 1.416310E-05 | PASSED | 0.004 | 135.254 | 2.767 |
| N1024K8 | 1024 | 8 | 5.5667e+06 | -23.0635 | 9.08 | 5.7961e+06 | -23.0511 | 0.37 | 0.041 | 3 | 1.330473E-05 | PASSED | 0.004 | 132.289 | 5.700 |
| N1024K16 | 1024 | 16 | 5.7008e+06 | -21.2102 | 8.87 | 5.9370e+06 | -21.1805 | 0.37 | 0.042 | 3 | 1.502147E-05 | PASSED | 0.004 | 132.289 | 5.700 |
| N2048K4 | 2048 | 4 | 6.8861e+06 | -4.8283 | 7.28 | 7.2283e+06 | -4.0372 | 0.36 | 0.049 | 3 | 2.349567E-05 | PASSED | 0.517 | 135.763 | 2.237 |
| N2048K8 | 2048 | 8 | 6.9567e+06 | -3.8526 | 7.20 | 7.3086e+06 | -2.9712 | 0.36 | 0.050 | 3 | 2.082078E-05 | PASSED | 0.517 | 135.763 | 2.237 |
| N2048K16 | 2048 | 16 | 6.9401e+06 | -4.0820 | 7.22 | 7.2899e+06 | -3.2194 | 0.36 | 0.050 | 3 | 2.082078E-05 | PASSED | 0.517 | 135.763 | 2.237 |
| N3072K2 | 3072 | 2 | 7.1815e+06 | -0.7456 | 7.04 | 7.4754e+06 | -0.7567 | 0.29 | 0.041 | 3 | 1.416310E-05 | PASSED | 0.004 | 135.254 | 2.767 |
| N3072K8 | 3072 | 8 | 7.2296e+06 | -0.0809 | 7.00 | 7.5274e+06 | -0.0664 | 0.29 | 0.041 | 3 | 1.416310E-05 | PASSED | 0.004 | 135.254 | 2.767 |
| N3072K16 | 3072 | 16 | 7.1564e+06 | -1.0925 | 7.07 | 7.4472e+06 | -1.1311 | 0.29 | 0.041 | 3 | 1.587984E-05 | PASSED | 0.004 | 135.254 | 2.767 |
| N4096K2 | 4096 | 2 | 6.4333e+06 | -11.0864 | 7.42 | 7.0993e+06 | -5.7498 | 0.77 | 0.104 | 3 | 6.423867E-05 | PASSED | 6.123 | 135.762 | 2.284 |
| N4096K4 | 4096 | 4 | 6.4730e+06 | -10.5377 | 7.39 | 7.1208e+06 | -5.4644 | 0.74 | 0.100 | 3 | 6.423867E-05 | PASSED | 6.123 | 135.762 | 2.284 |
| N4096K8 | 4096 | 8 | 6.5382e+06 | -9.6366 | 7.36 | 7.1507e+06 | -5.0674 | 0.69 | 0.094 | 3 | 6.423867E-05 | PASSED | 6.123 | 135.762 | 2.284 |
| N4096K16 | 4096 | 16 | 6.4549e+06 | -10.7879 | 7.40 | 7.1127e+06 | -5.5719 | 0.75 | 0.101 | 3 | 6.423867E-05 | PASSED | 6.123 | 135.762 | 2.284 |
| N5120K2 | 5120 | 2 | 6.2965e+06 | -12.9771 | 7.70 | 6.8425e+06 | -9.1591 | 0.67 | 0.087 | 3 | 4.634291E-05 | PASSED | 2.554 | 135.762 | 2.319 |
| N5120K4 | 5120 | 4 | 6.4324e+06 | -11.0988 | 7.58 | 6.9430e+06 | -7.8249 | 0.60 | 0.079 | 3 | 4.634291E-05 | PASSED | 2.554 | 135.762 | 2.319 |
| N5120K8 | 5120 | 8 | 6.4169e+06 | -11.3130 | 7.61 | 6.9154e+06 | -8.1913 | 0.59 | 0.078 | 3 | 4.634291E-05 | PASSED | 2.554 | 135.762 | 2.319 |
| N5120K16 | 5120 | 16 | 6.3614e+06 | -12.0801 | 7.66 | 6.8750e+06 | -8.7276 | 0.62 | 0.081 | 3 | 4.634291E-05 | PASSED | 2.554 | 135.762 | 2.319 |
| N6144K2 | 6144 | 2 | 5.9657e+06 | -17.5490 | 7.77 | 6.7778e+06 | -10.0181 | 1.06 | 0.136 | 3 | 4.128619E-05 | PASSED | 11.900 | 135.763 | 2.362 |
| N6144K4 | 6144 | 4 | 6.0386e+06 | -16.5415 | 7.73 | 6.8121e+06 | -9.5627 | 0.99 | 0.128 | 3 | 9.833928E-05 | PASSED | 11.900 | 135.763 | 2.362 |
| N6144K8 | 6144 | 8 | 5.7758e+06 | -20.1736 | 8.02 | 6.5653e+06 | -12.8392 | 1.10 | 0.137 | 3 | 9.833928E-05 | PASSED | 11.900 | 135.763 | 2.362 |
| N6144K16 | 6144 | 16 | 5.7160e+06 | -21.0001 | 8.08 | 6.5143e+06 | -13.5163 | 1.13 | 0.140 | 3 | 9.833928E-05 | PASSED | 11.900 | 135.763 | 2.362 |
| C3072K4b | 3072 | 4 | 7.2406e+06 | 0.0712 | 6.99 | 7.5382e+06 | 0.0770 | 0.29 | 0.041 | 3 | 1.416310E-05 | PASSED | 0.004 | 135.254 | 2.767 |

Factual matrix facts (full detail in the raw matrix summary
`outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_matrix_summary_v1.log`;
mechanical Section 1.4E values only, no strategic interpretation):

- Control bracket: C3072K4a overall `7.2303e+06` / LU `7.5266e+06`;
  C3072K4b overall `7.2406e+06` / LU `7.5382e+06`; control midpoint overall
  `7.23545e+06`, LU `7.5324e+06`; symmetric bracket spread 0.1425 %
  (overall) / 0.1541 % (LU) ((hi-lo)/lo*100).
- Per-NB best measured valid chunk (by overall; spread across that NB's
  valid chunks): NB=1024 -> chunk 16 (`5.7008e+06`, spread 2.41 %);
  NB=2048 -> chunk 8 (`6.9567e+06`, 1.03 %); NB=3072 -> chunk 4
  (`7.2303e+06`, 1.03 %); NB=4096 -> chunk 8 (`6.5382e+06`, 1.63 %);
  NB=5120 -> chunk 4 (`6.4324e+06`, 2.16 %); NB=6144 -> chunk 4
  (`6.0386e+06`, 5.64 %).
- Per-chunk measured NB ordering (by overall): chunk 2: 3072 > 4096 > 5120 >
  6144; chunk 4: 3072 > 2048 > 4096 > 5120 > 6144; chunk 8: 3072 > 2048 >
  4096 > 5120 > 6144 > 1024; chunk 16: 3072 > 2048 > 4096 > 5120 > 6144 >
  1024.
- Deltas vs the C3072K4 control midpoint (overall): NB=1024 arms -23.06 %
  (k8) / -21.21 % (k16); NB=2048 arms -4.83 % (k4) / -3.85 % (k8) / -4.08 %
  (k16); NB=3072 arms -0.75 % (k2) / -0.08 % (k8) / -1.09 % (k16); NB=4096
  arms -11.09 % (k2) / -10.54 % (k4) / -9.64 % (k8) / -10.79 % (k16);
  NB=5120 arms -12.98 % (k2) / -11.10 % (k4) / -11.31 % (k8) / -12.08 %
  (k16); NB=6144 arms -17.55 % (k2) / -16.54 % (k4) / -20.17 % (k8) /
  -21.00 % (k16). LU deltas for the same arms are in the matrix summary.
- Interaction indicators: strict chunk-order reversals across NB pairs
  sharing >= 2 common valid chunks total 22 (overall) and 22 (LU) — e.g.
  NB=1024 ranks chunk 16 above chunk 8 while NB=2048/3072/4096/5120/6144
  rank chunk 8 above chunk 16; NB=2048 ranks 8 above 4 while NB=3072 ranks 4
  above 8. Per-NB chunk deltas versus each NB's best chunk and the full
  reversal list are in the matrix summary (Section 1.4E item 6).
- IR/memory regime exact-value differences versus the opening control
  (c3072k4a: IR 0.29 s, host 0.004 GB, device 135.254 GB): 17 arms differ in
  IR seconds and/or host/device memory (all NB=1024/2048/4096/5120/6144
  arms); no arm changed the iteration count (all 3) or the verdict; the
  largest IR is 1.13 s (n6144k16) and the largest host memory 11.900 GB
  (NB=6144 arms). Materiality belongs to analysis.

Results extraction (2026-10-03; job-level timing fields corrected the same
day from the retained PBS accounting record): exactly 22 unique attempt rows
(`2x8-GAAS-phase5-nb-chunk-dependency-resweep_<arm>_v1`) were appended to
`results/metrics.csv` in the fixed arm order (302 -> 324 rows; existing rows
untouched). Per the `results/README.md` schema, the job-level fields on all
22 rows are: `submission_time` = PBS `qtime` `2026-10-03T04:55:27+08:00`;
`completion_time` = PBS `obittime` `2026-10-03T16:46:03+08:00`; `runtime` =
PBS `resources_used.walltime` `00:38:37`; `pbs_state=F`, `exit_status=0`
per the PBS job record. The per-arm wall-clock is not a row field and
remains preserved as `arm_wallclock_seconds` in each arm's `.status` raw
evidence. The exact job-level PBS accounting values (qtime/stime/obittime,
walltime, exit status, nodes, queue, resources, run_count) are durably
recorded in
`outputs/2x8-GAAS-phase5-nb-chunk-dependency-resweep_v1.qstat_fx_final.log`
(captured read-only via `ssh -o BatchMode=yes gaas 'qstat -fx 77344.gaas'`
after completion; concise record, GPU telemetry block omitted).
`results/RESULTS.md` was regenerated from the CSV with the established
`results/scripts/generate_results.py`. Per-arm stdout/stderr provenance is
the `outputs/<attempt>.out` / `.err` pair referenced by each row.
