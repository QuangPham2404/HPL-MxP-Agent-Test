# 2x8-GAAS phase3c-residency-closure

TASK-2X8-011 Phase 3C residency closure for the 2 GAAS nodes x 8 H200 GPUs
HPL-MxP campaign: the approved Stage-A residency curve (full-fill controls
bracketing `--fill-device 0` + NB-aligned `--Anq-device` partial-residency
arms) runs sequentially inside one 2x8 allocation at the fixed retained
TASK-010 geometry/runtime stack, with only the FP64 residency controls
(`--fill-device`, `--Anq-device`, `--fill-device-buffer-size`) varying. The
single authorized conditional paths — the F2 control-stability allowance,
the selected-Anq/full-fill confirmation pair, and the Stage-B full-fill
buffer closure 2048/4096/3048 — are encoded in the run script as
pre-authorized mechanical branches with stopping rules
(tasks/TASK-2X8-011.md Sections 1.6A-1.6C); the final residency conclusion
is reserved for the Strategic Analyst via `ANALYSE_RESULTS`.

**Status: Prepared (2026-10-01) — reviewed local scripts only; nothing
submitted yet. Submission is already authorized under the unchanged
Section 1.12 authorization of TASK-2X8-011; no new approval is needed,
and submission remains limited to the exact approved task scope.**

## Structure

- `scripts/run_phase3c_residency_closure.pbs` — single same-allocation
  Phase-3C run script: Stage A (F0, A0-A4, F1) always; the conditional F2
  control, confirmation pair, or Stage B selected by the encoded mechanical
  rules; per-arm evidence files; attempt tag comes from the `ATTEMPT_TAG`
  environment at submission
- `outputs/` — per-arm application `.out`/`.err`/`.status` evidence,
  per-arm `.envprobe` raw env-probe evidence, the attempt-specific
  deduplicated hostfile, the allocation-level rank-map / env-map /
  carry-forward logs, and PBS `.o`/`.e` job evidence (tracked, never
  overwritten; every rerun gets a new attempt tag; all runtime artifacts
  live beneath `outputs/` — nothing is written to the experiment root)

## Approved arm set (TASK-2X8-011 Sections 1.6B, 1.6C)

Stage A — residency curve, exactly this order, once each:

| arm | residency flags |
|---|---|
| F0 | `--fill-device 1 --fill-device-buffer-size 3048` (Anq-device omitted/overridden; effective echo recorded) |
| A0 | `--fill-device 0 --Anq-device 0` |
| A1 | `--fill-device 0 --Anq-device 24576` (= 8 x NB) |
| A2 | `--fill-device 0 --Anq-device 49152` (= 16 x NB) |
| A3 | `--fill-device 0 --Anq-device 73728` (= 24 x NB) |
| A4 | `--fill-device 0 --Anq-device 98304` (= 32 x NB) |
| F1 | `--fill-device 1 --fill-device-buffer-size 3048` |

For `fill-device 0` arms the fill-device buffer stays at the installed
package default (`3048`; flag omitted, effective echo recorded); it is not a
swept variable in those arms. The Anq candidates span no, low, medium, high,
and near-full partial residency; no intermediate or larger Anq values, no
added candidates, no repeats of valid points (Section 1.7 prohibitions).

Conditional arms (encoded in-script, at most one path):

| arm | trigger | residency flags |
|---|---|---|
| F2 | F0/F1 differ by >2.0% in score (single allowance) | `--fill-device 1 --fill-device-buffer-size 3048` |
| conf-anq<v> + conf-fill3048 | best valid partial arm strictly >2.0% above the stable full-fill reference with valid correctness/memory evidence | repeat the selected `--fill-device 0 --Anq-device <v>` arm once + repeat the full-fill 3048 MB control once, then stop (Stage B skipped) |
| B0 | Stage B path only (full fill within the <=2.0% leading region) | `--fill-device 1 --fill-device-buffer-size 2048` |
| B1 | Stage B path only | `--fill-device 1 --fill-device-buffer-size 4096` |
| B2 | Stage B path only (final control repeat) | `--fill-device 1 --fill-device-buffer-size 3048` |

Stage-B rules encoded: never test below 2048 MB; no intermediate or larger
buffer values; an invalid/correctness-failing buffer arm is a hard safety
boundary (preserved; the reserve is never squeezed further); after
B0/B1/B2 the task stops in every case with the factual outcome class
recorded (plateau within 2.0% / a 2048-or-4096 arm >2.0% above the
in-stage 3048 control preserved without refinement / other >2.0% spread
recorded / boundary evidence). Stage B never reopens `Anq-device`, N, NB,
grid/order, or host runtime.

## Fixed scientific controls (only the residency controls vary)

```
OMP_NUM_THREADS=4
--n 429056
--nb 3072
--nprow 4
--npcol 4
--nporder row
--gpu-affinity 0:1:2:3:4:5:6:7
--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted
--sloppy-type FP16
--use-mpi-panel-broadcast 0
--use-separate-stream-for-gemm 1
--prioritize-trsm 0
--prioritize-factorization 0
--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Default-equal controls applied via the installed package defaults — exactly
the validated TASK-010 launch form — with the echoed effective value
verified per arm against the task's fixed values:

```
--u-panel-chunk-nbs                    = 8    (installed default [8])
--cuda-host-register-step              = 2048 (installed default [2048])
--call-dgemv-with-multiple-threads     = 0    (installed default [0])
--preset-gemm-kernel                   = 90   (EFFECTIVE value on H200)
```

`--preset-gemm-kernel` note: the installed v26.02 CLI accepts only
`{0,80}` (`--preset-gemm-kernel INT:{0,80} [0]`; flag-check evidence
`experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`).
Passing `90` on the command line is rejected (`90 not in {0,80}`;
SingleNode-resweep v1 Track 1 record, `progress/2026-09-18-progress_s4.md`).
The effective SM90 preset `90` comes from the default when the flag is
omitted — the exact form TASK-010 ran (its `.out` settings block echoes
`--preset-gemm-kernel = 90`). The flag is therefore omitted in every arm and
the echoed effective value is verified `= 90` per arm.

Retained host-runtime contract (TASK-2X8-011 Section 1.6A, quoted as in the
task):

```
OMP_NUM_THREADS = 4
--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted
OMP_PLACES omitted
OMP_PROC_BIND omitted
effective launcher defaults = sockets / TRUE
```

`OMP_NUM_THREADS=4` is explicitly exported in the job shell after module
setup, forwarded to all MPI ranks via `mpirun -x OMP_NUM_THREADS`, and
verified = 4 on all 16 ranks by a per-arm environment probe run immediately
before every scored launch (the arm is aborted before its scored launch on
any mismatch). `OMP_PLACES`/`OMP_PROC_BIND` are unset in the job shell after
recording the incoming values; the allocation-level rank-map probe verifies
they are UNSET on all 16 ranks (abort before any scored arm otherwise), and
the per-arm env probe verifies `omp_places=UNSET omp_proc_bind=UNSET` on all
16 ranks with the arm's exact `-x` set (`PATH`, `LD_LIBRARY_PATH`,
`OMP_NUM_THREADS`). The effective placement policy is the installed
launcher's package defaults `OMP_PLACES=sockets` / `OMP_PROC_BIND=TRUE`.

Every arm's `.status` file records the application's echoed settings for all
fixed controls plus the residency controls with a PASS/FAIL
`settings_echo_check`; in particular it verifies that `--fill-device 1`
arms echo `fill-device = 1` with the requested buffer (Anq-device overridden)
and that partial arms echo `fill-device = 0` with the requested
`Anq-device` value (TASK-2X8-011 Section 1.8 rule 4). A settings-echo
mismatch is control-application failure evidence: the arm is preserved but
marked not valid for promotion into any branch, and the mismatch is
flagged in the carry-forward log.

Configuration supplied by the Strategic Analyst and approved by the Human
Leader in tasks/TASK-2X8-011.md Sections 1.6A-1.6C; Codex/workers did not
derive, optimize, or modify it. All controls not listed above keep the
installed package/default behavior consistently for all arms. N, NB,
grid/order, placement, host runtime, communication, precision, kernel,
DGEMV, register-step, and scheduling are NOT reopened by this task
(Section 1.7).

## Per-arm command

Identical for every arm except the residency flags, launched inside the PBS
job through the validated Approach-1 container launcher with the retained
TASK-009 host-runtime `-x` forwarding. Full-fill arm example (F0/F1/F2/
conf-fill3048; B arms differ only in the buffer value):

```bash
apptainer exec --nv \
  -B /opt/pbs:/opt/pbs \
  -B /var/spool/pbs:/var/spool/pbs \
  -B "$REPO_ROOT":"$REPO_ROOT" \
  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif \
  /usr/local/mpi/bin/mpirun -np 16 \
    --hostfile "$PWD/outputs/2x8-GAAS-phase3c-residency-closure_hostfile_<ATTEMPT_TAG>" \
    --mca plm_rsh_agent multi-node-test/rsh_pbsdsh_container.sh \
    --mca plm_rsh_no_tree_spawn 1 \
    --mca plm_rsh_num_concurrent 1 \
    --mca routed direct \
    -x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS \
    --bind-to none \
    /workspace/hpl-mxp.sh \
      --n 429056 --nb 3072 --nprow 4 --npcol 4 --nporder row \
      --gpu-affinity 0:1:2:3:4:5:6:7 --sloppy-type FP16 \
      --use-mpi-panel-broadcast 0 --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --fill-device-buffer-size 3048 \
      --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

Partial-residency arms (A0-A4, conf-anq<v>) replace the last residency
flags with `--fill-device 0 --Anq-device <v>` (fill-device-buffer-size
omitted -> installed default). `OMP_NUM_THREADS=4` is exported in the job
shell (and verified on all 16 ranks by the per-arm env probe) before the
launch, and application stdout/stderr are redirected to that arm's
`.out`/`.err` evidence file.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ncpus=96:ngpus=8:mem=2000GB` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `02:00:00` for the longest authorized path (10 scored arms + per-arm env probes; TASK-010's five-arm sweep used 00:12:48 of 01:30:00); may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by all arms in the allocation; written beneath `outputs/` with an attempt-specific name (`2x8-GAAS-phase3c-residency-closure_hostfile_<tag>`) so no runtime artifact is left in the experiment root |
| Process grid | fixed 4x4, `nporder=row` (not auto-derived) |
| GPU affinity | `0:1:2:3:4:5:6:7` (node-local rank -> local GPU) |
| OMP host-runtime contract | `OMP_NUM_THREADS=4` explicit job-shell export after module setup + `mpirun -x OMP_NUM_THREADS`, verified = 4 on all 16 ranks by the per-arm env probe; `OMP_PLACES`/`OMP_PROC_BIND` omitted (unset in the job shell, verified UNSET on all 16 ranks); effective launcher package defaults `sockets` / `TRUE`; `--cpu-affinity`/`--mem-affinity`/`--ucx-affinity` omitted |
| Flag support evidence | installed v26.02 binary records `--Anq-device INT:NONNEGATIVE [0]`, `--fill-device INT:{0,1} [0]` (overrides `--Anq-device`), `--fill-device-buffer-size INT:NONNEGATIVE [3048]`: `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mirrors
`experiments/2x8-GAAS/task010-geometry-reclosure/scripts/run_task010_stepa_n_coarse.pbs`
(PBS job 76094.gaas, validated) for container/MPI/orted/pbsdsh launcher,
hostfile, resource request, accounting project, bind mounts, daemon flags,
module set, topology gates, probes, and pre/post health-snapshot pattern,
with the N-sweep candidate list replaced by the TASK-2X8-011 residency arm
set and the TASK-010 Section 1.5D branch rule replaced by the TASK-2X8-011
Sections 1.6B/1.6C stability rule, bounded branch, and Stage-B rules.

## Sequential-sweep behavior and encoded stopping rules

- The arms run one at a time inside the single 2x8 allocation (same nodes
  for all arms; same-allocation comparability, TASK-2X8-011 Section 1.8
  rules 1-2: the entire authorized path — Stage A plus the single selected
  conditional path — runs in one clean allocation).
- A per-arm environment probe runs immediately before every scored launch
  and verifies `OMP_NUM_THREADS=4` with `OMP_PLACES`/`OMP_PROC_BIND` unset
  on all 16 ranks; a mismatch aborts before that arm's scored launch
  (control-application failure; TASK-2X8-011 Section 1.10).
- A scored arm command that exits nonzero is preserved evidence that STOPS
  the sweep: its `.status` file is fully written first (together with its
  `.out`/`.err`), the carry-forward log records the abort, the job returns
  nonzero immediately, and no later arm of the authorized path is launched
  (the post-sweep hardware-health snapshot is skipped on this abort path).
  There is no in-script retry; a rerun needs a new `ATTEMPT_TAG` plus
  human direction (error classification per the workflow from the
  preserved evidence).
- An arm that exits 0 with an invalid verification, an OOM/non-finite
  residual, or a failed settings-echo check is a scientific-correctness
  failure: preserved invalid/boundary evidence (Sections 1.4, 1.6B rule 4,
  1.8 rule 5); the sweep continues with the next arm of the
  already-authorized path and the job exits nonzero overall if any arm was
  invalid. Invalid/OOM/correctness-failing points are never promoted or
  repeated for performance.
- Evidence guard: before anything runs, the script aborts if any target
  `.out`/`.err`/`.status`/`.envprobe` file (every possible arm label of the
  authorized path), rank-map/env-map/carry-forward log, or the
  attempt-specific hostfile of this attempt already exists — reruns must
  use a new `ATTEMPT_TAG`; existing evidence is never overwritten.
  Anti-loop: every arm runs at most once per attempt; no new Anq/buffer
  values, no intermediate points, no second refinement pass, no automatic
  N reopen (Sections 1.7, 1.10).
- If the job is killed mid-arm (e.g. walltime), that arm keeps its
  `.out`/`.err` but has no `.status` file, and later arms were not run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query) are
  taken once around the whole sweep; per-arm host/device memory evidence
  comes from the application's own memory-report lines in each `.out` file.
- The Stage-A control-stability rule, the bounded branch, and the Stage-B
  rules are applied mechanically in-script (see the script header for the
  exact encoded thresholds). The conservative same-regime proxy used for
  the "same qualitative LU/IR/memory regime" clause: both controls valid,
  IR seconds within a factor of 2, and per-process host-memory consumption
  MAX within a factor of 10 (raw values recorded in the carry-forward log;
  the observed TASK-010 residency cliff is ~5.5x IR and ~3756x host
  consumption, far outside both bands). "Differ by <=2.0%" is the symmetric
  spread `max <= min * 1.02`; the full-fill reference is the median of the
  valid full-fill controls (two-control mean, or the middle of three after
  F2).
- The branch outcome (`STOP_*`, confirmation pair, or Stage B) does not
  affect the job exit status; all are normal authorized outcomes. The
  script computes no percentage deltas versus the campaign baseline and
  performs no ranking beyond the mechanical branch rules; the final
  residency conclusion is reserved for the Strategic Analyst via
  `ANALYSE_RESULTS` (Sections 1.4, 1.11).
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-arm attempt ID:
`2x8-GAAS-phase3c-residency-closure_<label>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase3c-residency-closure_stagea-a2_v1`), with `<label>` one
of `stagea-f0`, `stagea-a0`..`stagea-a4`, `stagea-f1`, `stagea-f2`,
`conf-anq0`/`conf-anq24576`/`conf-anq49152`/`conf-anq73728`/`conf-anq98304`,
`conf-fill3048`, `stageb-b0`..`stageb-b2`.

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| arm status | `outputs/<attempt>.status` (attempt, experiment, task id/step, arm label/mode, residency controls requested + echoed, all echoed fixed-control settings with PASS/FAIL settings-echo check, PBS job ID, queue, nodes, N, NB/grid/order, verified OMP environment, rank-map reference, fixed-controls line, start/end timestamps, exit status, score/LU/IR/iteration/memory/warning evidence, verification verdict, evidence paths) |
| per-arm env-probe evidence | `outputs/<attempt>.envprobe` (that arm's raw 16-rank effective-OMP probe output; the rank lines are also appended, arm-prefixed, to the env-map log) |
| allocation rank-map log | `outputs/2x8-GAAS-phase3c-residency-closure_rankmap_<tag>.log` (16 rank lines with the incoming OMP environment + per-host local-rank-0 topology reports for both allocated nodes) |
| per-arm env-map log | `outputs/2x8-GAAS-phase3c-residency-closure_envmap_<tag>.log` (per-arm 16-rank effective-OMP verification lines) |
| carry-forward log | `outputs/2x8-GAAS-phase3c-residency-closure_carryforward_<tag>.log` (per-arm facts, F0/F1(/F2) stability evaluation with regime-proxy values, full-fill reference, branch decision and outcome, Stage-B classification, anti-loop state) |
| attempt hostfile | `outputs/2x8-GAAS-phase3c-residency-closure_hostfile_<tag>` (deduplicated `$PBS_NODEFILE` with `slots=8` per node; shared by the rank-map probe, the per-arm env probes, and all arms in the allocation) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase3c-residency-closure_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase3c-residency-closure_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names.

## Submission (from this directory; requires TASK-2X8-011 execution authorization)

Before submission, use the approved node-status workflow (`pbsnodes -aSj`
over the eligible queues) to prefer the cleanest eligible same-queue
2-node allocation and preserve the contention/provenance snapshot as
submission-side evidence (TASK-2X8-011 Section 1.6A).

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase3c-residency-closure_v1.o \
     -e outputs/2x8-GAAS-phase3c-residency-closure_v1.e \
     scripts/run_phase3c_residency_closure.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (only
eligible idle `gpu_as`/`gpu_ded` nodes; same validated pattern as the
phase1a/phase3ab/TASK-010 submissions):

```bash
qsub -q <gpu_as|gpu_ded> \
     -l select=host=hpc-gaas-<n1>:ncpus=96:ngpus=8:mem=2000GB+host=hpc-gaas-<n2>:ncpus=96:ngpus=8:mem=2000GB,place=scatter,walltime=02:00:00 \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase3c-residency-closure_v1.o \
     -e outputs/2x8-GAAS-phase3c-residency-closure_v1.e \
     scripts/run_phase3c_residency_closure.pbs
```

## Mechanical feasibility context (arithmetic only)

Per-GPU FP64 device-matrix footprint under `--fill-device 1` is
`N^2 * 8 / 16` bytes; at the retained N=429056 that is
`429056^2 * 8 / 16 = 92,044,525,568 bytes ~= 92.0 GB` (TASK-010 evidence:
device consumption MAX 135.254 GB and post-matgen device headroom 2.767
GB/process at this N with the 3048 MB buffer). The `--Anq-device` values
are column counts of the FP64 matrix placed on the device (installed flag
semantics); no byte-level residency is inferred from the application memory
counters — host/device memory consumption and headroom are reported as
observed allocation/headroom evidence per arm (TASK-2X8-011 Section 1.8
rules 6-7). Host-side, the full FP64 matrix (`N^2 * 8 / 2` bytes/node
~= 735 GB at N=429056) fits the 2000 GB per-node cgroup even for the
no-residency arm A0. These are mechanical derived values, not predictions
or recommendations.

## Available baseline provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s; same scored-run protocol (`--skip-tests 0 --monitor-gpu 0`); campaign percentage denominator for 2x8-GAAS comparisons |
| Baseline evidence | `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.{o,e}`; `experiments/2x8-GAAS/baseline/README.md` |
| Retained-control precedent | TASK-010 N=429056 control (`--fill-device 1`, buffer 3048 default): overall `6.4431e+06` GFLOP/s, LU 7.85 s / `6.6784e+06` GFLOP/s, IR 0.29 s, IR/LU 0.037, host 0.004 GB/process, device headroom 2.767 GB/process — PBS job 76094.gaas, `experiments/2x8-GAAS/task010-geometry-reclosure/` |
| TASK-010 analysis | `planning/analysis/2x8-gaas-task010-geometry-reclosure.md` (residency/IR cliff between N=429056 and N=454656; E14-E17 context) |
| Flag support | installed v26.02 binary records `--fill-device INT:{0,1} [0]` (overrides `--Anq-device`), `--Anq-device INT:NONNEGATIVE [0]`, `--fill-device-buffer-size INT:NONNEGATIVE [3048]`, `--preset-gemm-kernel INT:{0,80} [0]` (effective 90 via default on H200), and the launcher OpenMP package defaults (`OMP_PROC_BIND=TRUE`, `OMP_PLACES=sockets`): `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |
| Phase-0 topology evidence | `scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated (note: the TASK-010 script header cites this as `experiments/2x8-GAAS/baseline/scripts/probing_report.md`; the file lives at the repo-root `scripts/` path) |

This task does not rerun the baseline. No run here promotes or replaces any
baseline; baseline-relative percentages belong to the post-task analysis
under `ANALYSE_RESULTS`.

## Expected output markers and validation criteria

An arm is valid only when its `outputs/<attempt>.out` contains:

- normal HPL-MxP output: internal tests completed (`--skip-tests 0`: GEMM /
  MPI / NCCL broadcast / pdgemv sections), `****** Matrix Generation ******`,
  `LU seconds: AVG = ...`, `Solver iteration <k>, L-infinite residual = ...`
  lines, and a measured performance result (not a stop during
  initialization or internal tests);
- the normalized-residual line
  `||Ax-b||_oo / (EPS * (||A||_oo * ||x||_oo + ||b||_oo) * N) = <finite value> ...... PASSED`
  (`FAILED` or a non-finite value is invalid);
- `GFLOPS = <value>, per GPU = <value>` (the overall score to report) and
  `LU GFLOPS = <value>` (excluding iterative refinement);
- the memory lines `Per process host memory consumption MAX = ..., available MIN = ...`
  and the device equivalent, plus the post-matrix-generation
  `Per process memory available MIN system = ..., device = ...` line;
- the settings block echoing the arm's exact effective residency controls
  (`--fill-device`, `--Anq-device`, `--fill-device-buffer-size`) and the
  fixed controls (verified by the script's `settings_echo_check`).

Job-level: PBS completes, the `.o`/`.e` files exist, and `.status` records
`exit_status=0`, `verification=PASSED`, and `settings_echo_check=PASS`.
With `--monitor-gpu 0`, GPU-monitoring output is unavailable by design. An
arm with an OOM, `FAILED`, non-finite residual, or a settings-echo mismatch
is preserved as evidence and is not ranked as a valid performance point
(TASK-2X8-011 Sections 1.4, 1.8 rule 5). Do not classify success from exit
status alone.

## Evidence paths

- `outputs/` — per-arm `.out`/`.err`/`.status`, per-arm `.envprobe` raw
  env-probe evidence, the attempt-specific deduplicated hostfile, the
  allocation-level rank-map log, the per-arm env-map log, the
  stability-rule/branch carry-forward log, and PBS `.o`/`.e` (including
  the environment provenance records: `module list`, Apptainer version,
  container MPI `mpirun --version`, and the execution-worktree Git
  revision)
- `scripts/run_phase3c_residency_closure.pbs` — the Phase-3C run script
  (header documents purpose, working directory, inputs, outputs,
  assumptions, and every encoded branch/stopping rule)
