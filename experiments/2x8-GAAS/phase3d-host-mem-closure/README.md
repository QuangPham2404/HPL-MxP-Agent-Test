# 2x8-GAAS phase3d-host-mem-closure

TASK-2X8-012 Phase 3D closure for the 2 GAAS nodes x 8 H200 GPUs HPL-MxP
campaign: two independent, fixed, bracketed sweeps run sequentially inside
one 2x8 allocation at the fixed retained TASK-2X8-011 geometry/runtime
stack, with only the Phase-3D host/memory controls varying, one at a time
per stage (tasks/TASK-2X8-012.md Sections 1.6A-1.6C). There is no
interaction matrix, no adaptive refinement, and no downstream Phase-4 work;
the final Phase-3D conclusion is reserved for the Strategic Analyst via
`ANALYSE_RESULTS`.

**Status: Reviewed local scripts (2026-10-01, pre-submission). Submission
is authorized under the unchanged Section 1.12 authorization of
TASK-2X8-012 (EXECUTING / codex) and remains limited to the exact approved
task scope.**

## Structure

- `scripts/run_phase3d_host_mem_closure.pbs` — single same-allocation
  Phase-3D run script: Stage A (R0a, R1-R4, R0b) then Stage B (D0a,
  D1-D7, D0b) always, in the exact approved order; per-arm evidence files;
  attempt tag comes from the `ATTEMPT_TAG` environment at submission
- `outputs/` — per-arm application `.out`/`.err`/`.status` evidence,
  per-arm `.envprobe` raw env-probe evidence, the attempt-specific
  deduplicated hostfile, the allocation-level rank-map / env-map /
  carry-forward logs, the presubmit contention snapshot, and PBS `.o`/`.e`
  job evidence (tracked, never overwritten; every rerun gets a new attempt
  tag; all runtime artifacts live beneath `outputs/` — nothing is written
  to the experiment root)

## Approved arm set (TASK-2X8-012 Sections 1.6B, 1.6C)

Stage A — `--cuda-host-register-step` sweep, exactly this order, once each,
with `--call-dgemv-with-multiple-threads` fixed at 0:

| arm | `--cuda-host-register-step` |
|---|---:|
| R0a | **2048** — opening default control |
| R1 | 512 |
| R2 | 1024 |
| R3 | 4096 |
| R4 | 8192 |
| R0b | **2048** — closing default control |

The range deliberately spans 4x below to 4x above the default 2048 with
mechanism-distinct granularity; no 1536/2560/3072/3584 or other
intermediate values, no added candidates, no adaptive refinement, no
repeats beyond the R0a/R0b bracket (Sections 1.6B rules 1-5, 1.7).

Stage-A completion rule (Section 1.6B rule 7):
`--cuda-host-register-step` is restored to 2048 before Stage B regardless
of the numerical Stage-A result — encoded by construction, since every
Stage-B arm passes `--cuda-host-register-step 2048` explicitly.

Stage B — `--call-dgemv-with-multiple-threads` sweep, exactly this order,
once each, with `--cuda-host-register-step` fixed at 2048:

| arm | `--call-dgemv-with-multiple-threads` |
|---|---:|
| D0a | **0** — opening default control |
| D1 | 128 |
| D2 | 512 |
| D3 | 2048 |
| D4 | 4096 |
| D5 | 8192 |
| D6 | 15360 |
| D7 | 30720 |
| D0b | **0** — closing default control |

The set covers the default, the historical low-range 128/512 region,
previously untested medium/coarse values 2048/4096/8192 under the current
stack, the historical bundled 15360 value, and a deliberately large 30720
endpoint; no intermediate or larger values, no refinement around a
numerical leader, no register-step x DGEMV Cartesian product (Sections
1.6C rules 1-4, 1.7). At Stage-B completion the task stops: no Phase 4.

## Fixed scientific controls (only the Phase-3D controls vary)

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
--fill-device 1
--fill-device-buffer-size 3048
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
the validated TASK-010/TASK-2X8-011 launch form — with the echoed effective
value verified per arm against the task's fixed values:

```
--u-panel-chunk-nbs                    = 8    (installed default [8])
--preset-gemm-kernel                   = 90   (EFFECTIVE value on H200)
```

`--preset-gemm-kernel` note: the installed v26.02 CLI accepts only
`{0,80}` (`--preset-gemm-kernel INT:{0,80} [0]`; flag-check evidence
`experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`).
The effective SM90 preset `90` comes from the default when the flag is
omitted. The flag is omitted in every arm and the echoed effective value
is verified `= 90` per arm.

The two swept Phase-3D controls are passed **explicitly** on every arm
(installed flag contract `--cuda-host-register-step INT:POSITIVE [2048]`,
`--call-dgemv-with-multiple-threads INT:NONNEGATIVE [0]`; flag-check
evidence in the same v26.02 flag-check log; both values have prior CLI
acceptance evidence: register-step 2048 in SingleNode-resweep v1.1, dgemv
0..15360 in dgemv-with-multiple-threads / SingleNode-resweep).

Retained host-runtime contract (TASK-2X8-012 Section 1.6A, quoted as in the
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
fixed controls plus both Phase-3D controls with a PASS/FAIL
`settings_echo_check` (Section 1.8 rule 4 requires the effective echo of
both Phase-3D controls on every arm). A settings-echo mismatch is
control-application failure evidence: the arm is preserved but marked not a
valid performance point, and the mismatch is flagged in the carry-forward
log.

Configuration supplied by the Strategic Analyst and approved by the Human
Leader in tasks/TASK-2X8-012.md Sections 1.6A-1.6C; Codex/workers did not
derive, optimize, or modify it. All controls not listed above keep the
installed package/default behavior consistently for all arms. N, NB,
grid/order, placement, host runtime, residency mode/buffer, communication,
precision, kernel, and scheduling are NOT reopened by this task
(Section 1.7).

## Per-arm command

Identical for every arm except the two Phase-3D flags, launched inside the
PBS job through the validated Approach-1 container launcher with the
retained TASK-009 host-runtime `-x` forwarding. Example (Stage-A arm R1;
Stage-B arms differ only in the Phase-3D pair):

```bash
apptainer exec --nv \
  -B /opt/pbs:/opt/pbs \
  -B /var/spool/pbs:/var/spool/pbs \
  -B "$REPO_ROOT":"$REPO_ROOT" \
  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif \
  /usr/local/mpi/bin/mpirun -np 16 \
    --hostfile "$PWD/outputs/2x8-GAAS-phase3d-host-mem-closure_hostfile_<ATTEMPT_TAG>" \
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
      --cuda-host-register-step 512 --call-dgemv-with-multiple-threads 0 \
      --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

`OMP_NUM_THREADS=4` is exported in the job shell (and verified on all 16
ranks by the per-arm env probe) before the launch, and application
stdout/stderr are redirected to that arm's `.out`/`.err` evidence file.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ncpus=96:ngpus=8:mem=2000GB` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `02:00:00` for the 15 scored full-fill arms + per-arm env probes (TASK-2X8-011's ten-arm sweep used 00:18:04 of 02:00:00; every arm here is a ~1 min full-fill arm); may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by all arms in the allocation; written beneath `outputs/` with an attempt-specific name (`2x8-GAAS-phase3d-host-mem-closure_hostfile_<tag>`) so no runtime artifact is left in the experiment root |
| Process grid | fixed 4x4, `nporder=row` (not auto-derived) |
| GPU affinity | `0:1:2:3:4:5:6:7` (node-local rank -> local GPU) |
| OMP host-runtime contract | `OMP_NUM_THREADS=4` explicit job-shell export after module setup + `mpirun -x OMP_NUM_THREADS`, verified = 4 on all 16 ranks by the per-arm env probe; `OMP_PLACES`/`OMP_PROC_BIND` omitted (unset in the job shell, verified UNSET on all 16 ranks); effective launcher package defaults `sockets` / `TRUE`; `--cpu-affinity`/`--mem-affinity`/`--ucx-affinity` omitted |
| Flag support evidence | installed v26.02 binary records `--cuda-host-register-step INT:POSITIVE [2048]`, `--call-dgemv-with-multiple-threads INT:NONNEGATIVE [0]`, `--fill-device INT:{0,1} [0]` (overrides `--Anq-device`), `--fill-device-buffer-size INT:NONNEGATIVE [3048]`: `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mirrors
`experiments/2x8-GAAS/phase3c-residency-closure/scripts/run_phase3c_residency_closure.pbs`
(PBS job 76167.gaas, validated) for container/MPI/orted/pbsdsh launcher,
hostfile, resource request, accounting project, bind mounts, daemon flags,
module set, topology gates, probes, and pre/post health-snapshot pattern,
with the TASK-2X8-011 residency arm set and branch rules replaced by the
TASK-2X8-012 Sections 1.6B/1.6C fixed 15-arm Phase-3D sweep (no conditional
branches: all 15 arms run unconditionally in the approved order).

## Sequential-sweep behavior and encoded stopping rules

- The arms run one at a time inside the single 2x8 allocation (same nodes
  for all arms; same-allocation comparability, TASK-2X8-012 Section 1.8
  rules 1-2: the entire authorized path — Stage A plus Stage B — runs in
  one clean allocation).
- A per-arm environment probe runs immediately before every scored launch
  and verifies `OMP_NUM_THREADS=4` with `OMP_PLACES`/`OMP_PROC_BIND` unset
  on all 16 ranks; a mismatch aborts before that arm's scored launch
  (control-application failure; TASK-2X8-012 Section 1.10).
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
  failure: preserved invalid/boundary evidence (Sections 1.4, 1.8 rules
  6-7); the sweep continues with the next arm of the already-authorized
  path and the job exits nonzero overall if any arm was invalid.
  Invalid/OOM/correctness-failing points are never promoted or repeated
  for performance.
- Evidence guard: before anything runs, the script aborts if any target
  `.out`/`.err`/`.status`/`.envprobe` file (every arm label of the
  authorized path), rank-map/env-map/carry-forward log, or the
  attempt-specific hostfile of this attempt already exists — reruns must
  use a new `ATTEMPT_TAG`; existing evidence is never overwritten.
  Anti-loop: every arm runs at most once per attempt; no additional
  register-step/DGEMV values, no intermediate points, no refinement pass,
  no interaction matrix, no repeats beyond the R0a/R0b and D0a/D0b
  brackets (Sections 1.7, 1.10).
- If the job is killed mid-arm (e.g. walltime), that arm keeps its
  `.out`/`.err` but has no `.status` file, and later arms were not run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query) are
  taken once around the whole sweep; per-arm host/device memory evidence
  comes from the application's own memory-report lines in each `.out` file;
  per-arm setup/registration evidence comes from the ordinary
  `Constructor seconds:` line plus the per-arm start/end wall-clock
  timestamps (recorded in each `.status`).
- The carry-forward log records factual per-arm facts plus the mechanical
  R0a/R0b and D0a/D0b symmetric bracket spreads (drift references only).
  The script declares no winner, computes no baseline-relative percentages,
  and performs no ranking; the final Phase-3D conclusion is reserved for
  the Strategic Analyst via `ANALYSE_RESULTS` (Sections 1.4, 1.11).
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-arm attempt ID:
`2x8-GAAS-phase3d-host-mem-closure_<label>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase3d-host-mem-closure_stagea-r2_v1`), with `<label>` one
of `stagea-r0a`, `stagea-r1`..`stagea-r4`, `stagea-r0b`, `stageb-d0a`,
`stageb-d1`..`stageb-d7`, `stageb-d0b`.

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| arm status | `outputs/<attempt>.status` (attempt, experiment, task id/step, arm label, requested + echoed Phase-3D controls, all echoed fixed-control settings with PASS/FAIL settings-echo check, PBS job ID, queue, nodes, N, NB/grid/order, verified OMP environment, rank-map reference, fixed-controls line, start/end timestamps + arm wall-clock seconds, exit status, score/LU/IR/constructor/iteration/memory/warning evidence, verification verdict, evidence paths) |
| per-arm env-probe evidence | `outputs/<attempt>.envprobe` (that arm's raw 16-rank effective-OMP probe output; the rank lines are also appended, arm-prefixed, to the env-map log) |
| allocation rank-map log | `outputs/2x8-GAAS-phase3d-host-mem-closure_rankmap_<tag>.log` (16 rank lines with the incoming OMP environment + per-host local-rank-0 topology reports for both allocated nodes) |
| per-arm env-map log | `outputs/2x8-GAAS-phase3d-host-mem-closure_envmap_<tag>.log` (per-arm 16-rank effective-OMP verification lines) |
| carry-forward log | `outputs/2x8-GAAS-phase3d-host-mem-closure_carryforward_<tag>.log` (per-arm facts, R0a/R0b and D0a/D0b bracket spreads, register-step restoration record, sweep-end/anti-loop state) |
| attempt hostfile | `outputs/2x8-GAAS-phase3d-host-mem-closure_hostfile_<tag>` (deduplicated `$PBS_NODEFILE` with `slots=8` per node; shared by the rank-map probe, the per-arm env probes, and all arms in the allocation) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase3d-host-mem-closure_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase3d-host-mem-closure_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names.

## Submission (from this directory; already authorized under Section 1.12)

Submission is already authorized under the unchanged Section 1.12
authorization of TASK-2X8-012; no new approval is needed, and submission
remains limited to the exact approved task scope.

Presubmit node-status check (TASK-2X8-012 Section 1.6A): use the approved
node-status workflow (`pbsnodes -aSj` over the eligible queues) to prefer
the cleanest eligible 2-node allocation and preserve the contention
snapshot as submission-side evidence at
`outputs/2x8-GAAS-phase3d-host-mem-closure_<tag>.presubmit_pbsnodes.log`.
Node-selection rule: same-queue `gpu_as` or `gpu_ded` pair per the task
rule; under the current-session user override a mixed `gpu_as`/`gpu_ded`
pair is allowed if needed and if PBS can allocate it under a single allowed
queue (report the precise scheduler constraint otherwise and fall back to a
same-queue pair if eligible); record which queues/nodes were used. If PBS
cannot allocate a clean pair at submission time, report the blocking
condition rather than switching queues outside the approved scope.

Planned host-pinned submission form (`ATTEMPT_TAG=v1`, walltime
`02:00:00`; nodes filled in from the presubmit snapshot):

```bash
qsub -q <gpu_as|gpu_ded> \
     -l select=host=<node1>:ncpus=96:ngpus=8:mem=2000GB+host=<node2>:ncpus=96:ngpus=8:mem=2000GB,place=scatter,walltime=02:00:00 \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase3d-host-mem-closure_v1.o \
     -e outputs/2x8-GAAS-phase3d-host-mem-closure_v1.e \
     scripts/run_phase3d_host_mem_closure.pbs
```

## Available baseline provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s; same scored-run protocol (`--skip-tests 0 --monitor-gpu 0`); campaign percentage denominator for 2x8-GAAS comparisons |
| Baseline evidence | `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.{o,e}`; `experiments/2x8-GAAS/baseline/README.md` |
| Retained-control precedent | TASK-2X8-011 full-fill control (register-step 2048 default, DGEMV 0 default): F0 `6.5296e+06` / F1 `6.5238e+06` / B2 `6.5373e+06` GFLOP/s, IR 0.29 s, IR/LU 0.037, host 0.004 GB/process, device headroom 2.767 GB/process — PBS job 76167.gaas, `experiments/2x8-GAAS/phase3c-residency-closure/` |
| TASK-2X8-011 analysis | `planning/analysis/2x8-gaas-phase3c-residency-closure.md` (E17/E20/E21 context) |
| Flag support | installed v26.02 binary records `--cuda-host-register-step INT:POSITIVE [2048]`, `--call-dgemv-with-multiple-threads INT:NONNEGATIVE [0]`, `--fill-device INT:{0,1} [0]` (overrides `--Anq-device`), `--fill-device-buffer-size INT:NONNEGATIVE [3048]`, `--preset-gemm-kernel INT:{0,80} [0]` (effective 90 via default on H200), and the launcher OpenMP package defaults (`OMP_PROC_BIND=TRUE`, `OMP_PLACES=sockets`): `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |
| Phase-0 topology evidence | `scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated |

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
- the settings block echoing the arm's exact effective Phase-3D controls
  (`--cuda-host-register-step`, `--call-dgemv-with-multiple-threads`) and
  the fixed controls (verified by the script's `settings_echo_check`);
- the `Constructor seconds: AVG = ...` line (ordinary setup/registration
  timing evidence; recorded in each `.status`).

Job-level: PBS completes, the `.o`/`.e` files exist, and `.status` records
`exit_status=0`, `verification=PASSED`, and `settings_echo_check=PASS`.
With `--monitor-gpu 0`, GPU-monitoring output is unavailable by design. An
arm with an OOM, `FAILED`, non-finite residual, or a settings-echo mismatch
is preserved as evidence and is not ranked as a valid performance point
(TASK-2X8-012 Sections 1.4, 1.8 rules 6-7). Do not classify success from
exit status alone.

## Evidence paths

- `outputs/` — per-arm `.out`/`.err`/`.status`, per-arm `.envprobe` raw
  env-probe evidence, the attempt-specific deduplicated hostfile, the
  allocation-level rank-map log, the per-arm env-map log, the factual
  carry-forward log, the presubmit `pbsnodes -aSj` node-status snapshot,
  and PBS `.o`/`.e` (including the environment provenance records:
  `module list`, Apptainer version, container MPI `mpirun --version`, and
  the execution-worktree Git revision)
- `scripts/run_phase3d_host_mem_closure.pbs` — the Phase-3D run script
  (header documents purpose, working directory, inputs, outputs,
  assumptions, and the encoded stopping rules)
