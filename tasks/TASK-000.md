---
task_id: TASK-000
title: Phase 0 — 2x8 GAAS Characterization and Baseline
status: APPROVED
current_owner: codex
parent_task: none
analysis_id: 2x8-gaas-phase0
created: 2026-09-27
last_updated: 2026-09-27
---

# TASK-000 — Phase 0: 2×8 GAAS Characterization and Baseline

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Finish Phase 0 quickly by establishing one valid immutable original baseline for the new **2 GAAS nodes × 8 H200 GPUs/node** HPL-MxP campaign.

The comprehensive 2×8 Phase-0 probe and NVIDIA v26.02 flag-support check are already complete and accepted as current evidence. Do **not** repeat them unless a material environment change or contradiction is directly observed during the resumed run.

The Strategic Analyst / Human Leader now selects **`N=700000`** for the baseline. All other baseline controls remain unchanged.

A single valid scored run is sufficient to establish the immutable Phase-0 baseline. Additional identical repeats and noise statistics are **not required for TASK-000 completion**.

No optimization analysis or next-direction selection is part of this task.

### 1.2 Context

The previous exact attempt at `N=737280` (job `72595.gaas`) reached Matrix Generation and was SIGKILLed with exit 137 because host-memory demand exceeded the validated 2000 GB/node allocation. That failure is preserved as boundary evidence and must not be retried.

Historical NVIDIA-container 2×8 evidence already includes a successful `N=700000`, `NB=3072`, 4×4 run. The purpose of selecting `N=700000` here is **not** to claim it is optimal; it is to choose a proven memory-safe N so Phase 0 can obtain a baseline quickly.

Completed evidence that should be reused rather than regenerated:

- comprehensive 2×8 probe: job `72591.gaas`, with raw evidence under `scripts/outputs/phase0_2x8_probe_v1*`;
- dated 2×8 supplement already appended to `scripts/probing_report.md`;
- NVIDIA v26.02 flag-support evidence:
  `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`;
- validated multinode launcher and execution-worktree mechanism;
- failed `N=737280` attempt and its memory evidence.

The existing baseline script and experiment directory should be reused. Update only what is necessary for the new Strategic Analyst decision.

### 1.3 Strategic Question

Can the fixed NVIDIA HPL-MxP configuration below, with `N=700000`, complete correctly on 2×8 GAAS and provide a valid scored original baseline?

This is an execution question only. Codex must not tune or re-derive the configuration.

### 1.4 Required Evidence / Deliverables

#### A. Reuse completed Phase-0 characterization

Do not submit another comprehensive hardware/software probe.

Treat the existing Phase-0 probe, probing-report supplement, and v26.02 flag-support log as sufficient unless the resumed run directly reveals a material contradiction, such as a different container/release, missing GPUs, incorrect rank mapping, or materially different launcher behavior.

No repeated container hash, package-documentation audit, full topology capture, or comprehensive provenance sweep is required.

#### B. Fixed fast-baseline configuration

Use exactly:

```text
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

Only `N` changes from the failed attempt. Do not alter any other scientific/tuning control.

The previous v26.02 flag-support check is accepted. Do **not** repeat flag-by-flag compatibility verification unless the installed container/release has materially changed.

#### C. Minimal baseline preparation

Reuse:

`experiments/2x8-GAAS/baseline/`

Update the baseline README and PBS script so the active attempt uses `N=700000`.

Before submission, perform only lightweight mechanical validation:

- `bash -n` or equivalent syntax validation for a changed shell/PBS script;
- confirm the active script contains `N=700000` and the unchanged required controls;
- confirm 2 nodes × 8 GPUs, 16 ranks, one rank/GPU, 4×4 grid, column order;
- confirm the validated container/launcher contract is still being used;
- perform a quick live eligibility/health check sufficient to avoid an obviously unavailable/unhealthy node pair.

Do not re-run comprehensive Phase-0 validation merely to reconfirm already-established facts.

#### D. One scored baseline attempt

Submit one scored `N=700000` baseline attempt.

Use:

- 2 nodes × 8 GPUs;
- 16 ranks;
- one rank/GPU;
- `place=scatter`;
- no `mpiprocs`;
- de-duplicated hostfile with `slots=8`;
- NVIDIA HPC Benchmarks v26.02 container;
- container MPI end-to-end;
- validated pbsdsh bridge;
- project `hpc_ebslee`;
- queue only `gpu_as` or `gpu_ded`;
- `--skip-tests 0 --monitor-gpu 0`.

If that attempt completes normally and reports a finite correctness result with `PASSED`, it becomes the immutable `2x8-GAAS` original baseline immediately.

**No repeat is required.** Do not delay TASK-000 completion to collect v2/v3 noise statistics.

A retry is allowed only for a clearly non-scientific Track-1 failure (for example a deterministic workflow/scheduler/output-path issue or an obviously unusable node before a meaningful benchmark result). Use a new attempt label. Do not retry a genuine application OOM/correctness/runtime failure without new strategic direction.

#### E. Minimum evidence required

For the successful baseline preserve:

- attempt ID and PBS job ID;
- queue and allocated nodes;
- resource request;
- exact HPL-MxP command/flags;
- execution-tree revision/path;
- enough rank/node/GPU mapping evidence to confirm 16 ranks and one rank/GPU;
- PBS exit state;
- HPL-MxP final correctness/verification result;
- finite residual/normalized residual when emitted;
- LU time/GFLOP/s when emitted;
- iterative-refinement timing/iterations when emitted;
- overall GFLOP/s;
- stdout/stderr.

Existing Phase-0 probe/provenance evidence may be referenced rather than duplicated.

Heavy duplicate telemetry, repeated topology captures, repeated software-version inventories, repeated image hashing, and repeat-run statistics are not completion requirements.

### 1.5 Relevant Inputs and References

Active project repository:

`QuangPham2404/HPL-MxP-Agent-Test`

Primary references for this resume:

- `tasks/TASK-000.md`;
- `progress/2026-09-27-progress_s6.md`;
- `scripts/probing_report.md`;
- `scripts/outputs/phase0_2x8_probe_v1*`;
- `experiments/2x8-GAAS/baseline/README.md`;
- `experiments/2x8-GAAS/baseline/scripts/run_2x8_baseline.pbs`;
- `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`;
- `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_v1.{o,e}`;
- active `AGENTS.md`, `APPLICATION.md`, and Workflow v2 files.

Historical `experiments/2Nodes-8GPUs/` evidence may be used as safety/context. In particular, the prior successful `N=700000` run supports this fast-baseline choice, but it is not itself the new campaign baseline.

No external OpenMxP repository access is required or authorized.

### 1.6 Execution Scope

#### Allowed

Codex may:

- reuse the completed Phase-0 probe and flag-support evidence without repeating it;
- update the existing `experiments/2x8-GAAS/baseline/README.md` for the new `N=700000` decision;
- minimally edit the existing baseline PBS script so `N=700000` is used and all other fixed controls remain unchanged;
- perform lightweight syntax/configuration/resource sanity checks;
- use the validated NVIDIA multinode launcher;
- select an eligible healthy node pair in `gpu_as` or `gpu_ded`;
- submit one scored `N=700000` baseline attempt;
- perform a Track-1 retry only when the failure is clearly non-scientific and already covered by Workflow v2;
- boundedly monitor the approved job;
- retrieve/preserve its designated output;
- update the experiment README and results files with factual execution data;
- update the task Execution Report/lifecycle and required progress handoff;
- commit/push approved task-execution artifacts;
- use direct SSH and the existing clean-primary / isolated-worktree synchronization policy.

The approved resource shape remains 2 nodes × 8 GPUs.

Approved queues remain `gpu_as` and `gpu_ded`.

Approved accounting group remains `hpc_ebslee`.

#### Prohibited

Codex and workers must not:

- access or depend on the OpenMxP repository;
- change `N` away from `700000`;
- change `NB=3072`;
- change the 4×4 grid or `nporder=column`;
- change the supplied communication, precision, residency, affinity, scheduling, or OMP controls;
- perform an N/NB/grid/order/communication/affinity/runtime sweep;
- perform Phase-1 tuning;
- add source-specific OpenMxP flags/environment;
- change launcher/transport strategy;
- modify source code, rebuild the container, install packages, or modify shared software;
- use unapproved queues/projects;
- repeat the comprehensive Phase-0 probe or flag-validation exercise unless a material contradiction is actually observed;
- require extra scored repeats before promoting the first valid `N=700000` run;
- perform campaign-level strategic interpretation, dependency analysis, or `ANALYSE_RESULTS`.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and active Workflow v2.
2. Substantive execution remains delegated to OpenCode worker(s) as required by the workflow.
3. Use PBS compute-node execution only.
4. Use only `gpu_as` or `gpu_ded`, project `hpc_ebslee`.
5. Use 2 nodes × 8 GPUs, 16 MPI ranks, one rank/GPU, `place=scatter`, no `mpiprocs`.
6. Preserve the validated container MPI / pbsdsh multinode launcher.
7. Use the fixed configuration in Section 1.4B.
8. Use `--skip-tests 0 --monitor-gpu 0`.
9. Preserve every actual submitted attempt with unique attempt/output names.
10. Reuse existing Phase-0 characterization/provenance; do not regenerate evidence without a concrete reason.
11. One valid scored `N=700000` attempt is sufficient for TASK-000 completion.
12. No repeatability/noise study is required in this task.
13. If a clearly non-scientific Track-1 issue prevents a meaningful scored result, Codex may repair/retry within existing authority.
14. A genuine OOM, failed verification, non-finite residual, MPI/NCCL hang/failure, or required configuration change is not an automatic retry.

### 1.8 Success Criteria

TASK-000 is complete when:

- the existing completed Phase-0 probe and flag-support evidence are referenced as the accepted characterization;
- the baseline README/script reflect `N=700000` with all other fixed controls unchanged;
- one scored 2×8 `N=700000` attempt completes;
- PBS/application exit is normal;
- HPL-MxP correctness reports `PASSED`;
- residual/normalized residual is finite when emitted;
- overall GFLOP/s is recorded;
- LU and iterative-refinement metrics are recorded when emitted by the application;
- the first valid `N=700000` attempt is designated the immutable `2x8-GAAS` original baseline;
- minimum evidence from Section 1.4E is preserved;
- result/task/progress bookkeeping is updated and committed/pushed;
- task becomes `EXECUTED / current_owner: strategic-analyst`.

No additional repeats, range/median/CV calculation, new comprehensive probe, repeated flag audit, or strategic conclusion is required.

### 1.9 Stop / Escalation Conditions

Stop and return for Strategic Analyst / Human review only if:

- `N=700000` itself OOMs or is otherwise deterministically infeasible;
- HPL-MxP reports failed/non-finite correctness;
- MPI/NCCL/launcher behavior fails or hangs after normal Track-1 recovery is exhausted;
- rank/GPU mapping is materially wrong;
- the active container/release or validated launcher has materially changed such that existing validation cannot be reused;
- a resource/launcher/transport/scientific-control change is required;
- no eligible 2×8 node pair can be obtained in the approved queues;
- another action would exceed the approved scope.

Do **not** stop merely because comprehensive Phase-0 validation was not repeated. Existing probe/flag/provenance evidence is intentionally reused.

Track 1 may automatically handle deterministic non-scientific workflow/synchronization/scheduler-output defects within the existing approved scope.

### 1.10 Strategic Analyst Notes

This is a **fast baseline completion** decision.

The previous `N=737280` attempt established that the original choice sits beyond the practical host-memory limit for the 2000 GB/node allocation. It is historical evidence and must not be retried.

The new fixed N is:

`N=700000`

because it has already been demonstrated to execute successfully in historical 2×8 NVIDIA-container evidence and provides substantially more memory headroom. Numeric performance from the historical run does not become the new denominator; only the first valid run produced under this resumed TASK-000 configuration does.

Execution order:

1. verify current task/repository state;
2. reuse completed Phase-0 probe + v26.02 flag evidence;
3. change the baseline README/script from `N=737280` to `N=700000` only;
4. perform lightweight syntax/configuration/node sanity checks;
5. synchronize the exact execution revision;
6. submit one scored baseline attempt;
7. if valid/PASSED, designate it immediately as the immutable original baseline;
8. log/persist the minimum required evidence and results;
9. hand TASK-000 back as `EXECUTED / strategic-analyst`.

Do not optimize and do not run extra repeats merely for completeness.

### 1.11 Authorization

status: APPROVED

approved_scope: Resume TASK-000 using the already-completed 2x8 Phase-0 characterization and NVIDIA v26.02 flag-support evidence; update only the baseline N from 737280 to the Strategic-Analyst/Human-selected N=700000 while keeping all other fixed controls and the validated launcher/resource shape unchanged; perform only lightweight mechanical pre-submit checks; submit one scored 2x8 baseline attempt, with Track-1 retry only for clearly non-scientific workflow/scheduler defects; preserve minimum correctness/performance/provenance evidence; establish the first valid PASSED N=700000 attempt as the immutable 2x8-GAAS original baseline; update results/task/progress and commit/push. No comprehensive re-probe, repeated flag audit, mandatory repeat/noise study, OpenMxP access, tuning, re-derivation, parameter sweep, transport/resource redesign, or strategic analysis.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

### 2.0 Current Resume Directive — 2026-09-27

The prior `N=737280` execution and its host-memory OOM remain preserved below as historical execution evidence. They are no longer the current decision gate.

The Human Leader / Strategic Analyst has now rearmed TASK-000 as `APPROVED / codex` with the revised Section 1 above. Resume from the completed Phase-0 evidence, change only the baseline N to `700000`, and follow the fast-baseline success criteria. Do not repeat the comprehensive probe, flag audit, or mandatory v2/v3 repeats.

On resumed execution, Codex should update/append the current Execution Report with the new attempt rather than treating the historical `N=737280` BLOCKED report as an unresolved blocker.


### 2.0 Previous Startup Attempts

The following archived report records the previous 2026-09-27 attempts under
the old operational policy (local revisions `3aad619`, `6ba66f9`, and the
resume check recorded at `fe3939d`; GAAS primary revision `87fb61e`). Missing
ControlPath was followed by successful direct SSH to `hpc-gaas-hn2`; inspection
found 167 pre-existing entries including two tracked modifications. No worker,
probe, scheduler job, or HPL-MxP run occurred. These attempts correctly preserved
existing material. Their manual-blocker/handoff instructions are historical,
superseded by the direct-SSH and automatic clean-worktree policy. They are not
unresolved Human blockers for the rearmed task.

<details>
<summary>Historical blocked-attempt report (preserved verbatim)</summary>


<!-- Codex completes this section after execution; do not rewrite section 1. -->

### 2.1 Execution Status

status: BLOCKED

### 2.2 Orchestration Summary

No OpenCode worker was dispatched. The direct non-interactive GAAS SSH check
now succeeds, but the GAAS clone is not synchronized to the approved task
revision and has pre-existing unexpected working-tree changes. Workflow
execution remains stopped at the synchronization gate.

### 2.3 Work Executed

Read Workflow v2 files `00`–`08`, `APPLICATION.md`, this explicitly selected
task, and `progress/2026-09-27-progress.md`. The Authorization section remains
`APPROVED` with `approved_by: user` and the approved scope recorded above. The
task front matter remains `BLOCKED` / `current_owner: user` pending resolution
of the synchronization blocker. Local Git is at `6ba66f9` (`main`, tracking
`origin/main`); `git pull --ff-only` reported `Already up to date`. The
pre-existing untracked `hpl-mxp-runs-on-gaas/` directory was left untouched.

Following the user's direct-SSH instruction, `ssh -o BatchMode=yes gaas` was
used for read-only verification. It reached `hpc-gaas-hn2`. The GAAS project
clone is at `87fb61e`, does not contain `tasks/TASK-000.md` (the task path is
absent), and has 167 pre-existing working-tree entries, including modified
tracked files `scripts/gaas-internode-coms-debug/debug-scripts/phase2-preflight/stage_osu_tmp.sh`
and `scripts/gaas-internode-coms-debug/debug-scripts/phase2-stage2/fabric_capture.sh`.
No changes were made to the GAAS clone.

### 2.4 Operational Validation

The Authorization section is approved for the stated scope, and direct SSH
connectivity is available. Required synchronization cannot proceed safely:
the GAAS clone lacks the task directory/revision and contains unrelated
pre-existing modifications and untracked artifacts. No probe, scheduler
submission, monitoring, output retrieval, or benchmark was attempted. No
benchmark or correctness evidence was produced.

### 2.5 Evidence and Artifacts

Connectivity result: `ssh -o BatchMode=yes gaas` reached `hpc-gaas-hn2`.
Local revision: `6ba66f9`; GAAS clone revision: `87fb61e`. The GAAS clone has
167 working-tree entries and no `tasks/TASK-000.md`. No probe or experiment
evidence exists for this execution attempt.

### 2.6 Files Changed

`tasks/TASK-000.md`; `progress/2026-09-27-progress_s2.md`.

### 2.7 Missing / Unavailable Evidence

All Phase-0 probe and baseline evidence is unavailable because the GAAS clone
is stale relative to the approved task and its dirty working tree prevents a
safe synchronization.

### 2.8 Execution Errors / Exceptions

Execution is blocked at the remote synchronization gate, not by SSH access.
The GAAS clone is at `87fb61e`, lacks `tasks/TASK-000.md`, and has 167
pre-existing working-tree entries (including two tracked modifications).
Do not pull over or clean this state automatically. The Human Leader must
resolve/preserve the remote working-tree material and synchronize the approved
repository revision. No additional task scope has been assumed.

### 2.9 Scope Compliance

Stayed within the approved scope. No external OpenMxP access, probe, PBS job,
tuning, or analysis was performed. Remote commands were limited to read-only
SSH/Git inspection inside the approved project root. The pre-existing local
untracked `hpl-mxp-runs-on-gaas/` directory and all GAAS working-tree material
were left untouched.

### 2.10 Handoff to Strategic Analyst

TASK-000 remains blocked before Phase 0. After the Human Leader resolves the
existing GAAS clone changes and synchronizes the approved repository revision
so `tasks/TASK-000.md` is present, resume at task verification and continue the
approved probe-first order. No benchmark conclusion is available.

#### 2026-09-27 resume check

The Human Leader authorized direct GAAS access and synchronization. The
documented control-socket check `ssh -O check gaas` still fails with
`No ControlPath specified for "-O" command`; the user-authorized non-interactive
check `ssh -o BatchMode=yes gaas` reaches `hpc-gaas-hn2`. Read-only inspection
inside the approved project root confirms the remote clone remains at
`87fb61e`, does not contain `tasks/TASK-000.md`, and still has two modified
tracked scripts plus numerous untracked evidence/runtime artifacts. No pull or
other remote mutation was performed because the dirty clone cannot be safely
fast-forwarded without affecting or disregarding that material. Task execution
remains blocked pending preservation/resolution of the remote changes and
restoration of the approved task revision there.

</details>

### 2.1 Execution Status

status: BLOCKED

The Phase-0 probe objective is COMPLETE. The baseline objective is BLOCKED
at the task 1.9 stop gate: the first exact baseline attempt
(`2x8-GAAS-baseline_v1`, job 72595.gaas) OOMed (host-memory kill, exit 137)
during Matrix Generation at the unchanged fixed `N=737280`. Per Section 1.9
and constraint 20, no retry, no `N` change, and no repeats were performed;
the two identical repeats are conditional on a valid first attempt. The next
action requires Strategic Analyst / Human Leader review and is outside the
approved scope.

### 2.2 Orchestration Summary

Substantive execution was delegated to five sequential/parallel OpenCode
execution workers, each bounded by this task's scope; Codex validated every
worker claim against repository state and raw evidence before relying on it:

1. Worker A — mechanical comparison of the completed 2x8 probe evidence
   against `scripts/probing_report.md` and append-only supplement writing.
2. Worker B — remote mechanical flag-support verification of all 14 supplied
   NVIDIA flags against the installed v26.02 package, plus the N=737280
   feasibility arithmetic (run in parallel with Worker A).
3. Worker C — creation of `experiments/2x8-GAAS/baseline/` (README + PBS
   script) with the unchanged exact configuration.
4. Worker D — live clean-node selection, single host-pinned submission of
   attempt v1, bounded monitoring (6 checks of max 30), evidence retrieval,
   and mechanical validation (stopped on the OOM stop condition as
   instructed).

Codex directly performed Git commit/push, remote worktree synchronization,
and results/task bookkeeping.

### 2.3 Work Executed

1. Startup: read Workflow v2 files 00-08, `APPLICATION.md`, this task
   (EXECUTING/codex, Section 1.11 unchanged APPROVED), and the latest
   progress report; verified Git state (only pre-existing untracked
   `hpl-mxp-runs-on-gaas/`, preserved untouched throughout).
2. Reviewed the completed probe evidence locally: job 72591.gaas outputs
   `scripts/outputs/phase0_2x8_probe_v1.{o,e}`, per-node captures for
   hpc-gaas-g12 and hpc-gaas-g15, node body, submission/monitor logs
   (including preserved never-ran attempts 72556/72590).
3. Worker A appended the dated "2x8 Phase-0 supplement (2026-09-27)" to
   `scripts/probing_report.md` (append-only: 185 added, 0 deleted;
   historical body byte-identical). g12 vs g15 match on all hardware and
   topology dimensions; differences are per-device identity or point-in-time
   runtime state only.
4. Worker B verified all 14 supplied CLI flags as SUPPORTED by the installed
   v26.02 package (wrapper/binary `--help` unavailable on the login node;
   evidence from installed-binary strings plus package README/RUNNING/TUNING
   docs; in-package TUNING doc is stale vs the installed binary but the
   binary is authoritative). N=737280 feasibility: per-GPU device matrix
   `737280^2*4/16 = 135.895 GB` vs 138.739 GB historical available MIN and
   139.80 GiB free at probe time — no obvious deterministic impossibility
   from device memory. Evidence:
   `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`.
5. Worker C created `experiments/2x8-GAAS/baseline/README.md` and
   `scripts/run_2x8_baseline.pbs` with the unchanged exact configuration
   (launch block verified character-for-character against the flag-check
   log); `bash -n` passes.
6. Committed and pushed revision `73b06f4` ("Record TASK-000 2x8 probe
   evidence and baseline preparation"); synchronized the GAAS primary by
   non-destructive `git fetch origin` (dirty primary preserved untouched)
   and created/verified the clean detached execution worktree
   `.codex-worktrees/TASK-000-73b06f4` at exactly
   `73b06f4f56e7c60f937cd1af8fc0eab70cb7c4b4` (script sha256 identical
   local/remote).
7. Worker D selected the clean eligible pair live (`pbsnodes -aSj` + live
   Qlist: hpc-gaas-g12 + hpc-gaas-g15 fully free, Qlist `gpu_as,gpu_ppu`;
   no fully-free gpu_ded pair; g04/g05/g16/g17 fully free but gpu_aisg —
   off-limits) and submitted exactly once:
   `qsub -q gpu_as -l select=host=hpc-gaas-g12:ngpus=8:ncpus=96:mem=2000GB+host=hpc-gaas-g15:ngpus=8:ncpus=96:mem=2000GB -v ATTEMPT=2x8-GAAS-baseline_v1 -o outputs/2x8-GAAS-baseline_v1.o -e outputs/2x8-GAAS-baseline_v1.e scripts/run_2x8_baseline.pbs`
   → job 72595.gaas.
8. Bounded monitoring (6 checks, 60 s apart, max 30): R/substate 42 for
   checks 1-5; F/substate 93 at check 6. Final: `Exit_status = 137`,
   `resources_used.walltime = 00:04:55`, `resources_used.mem = 3845454204kb`,
   exec_vnode exactly hpc-gaas-g12 + hpc-gaas-g15.
9. Retrieved and preserved `2x8-GAAS-baseline_v1.{o,e}` (sha256-verified
   remote→local) plus submission and monitor logs.
10. Logged the failed attempt in `results/metrics.csv` (row
    `2x8-GAAS-baseline,2x8-GAAS-baseline_v1,...`) and regenerated
    `results/RESULTS.md` from the CSV; updated the experiment README with
    the failed-attempt record and no-patch decision.

### 2.4 Operational Validation

Launch validation of the failed attempt (all correct): exactly 2 distinct
nodes; 16 ranks; de-duplicated hostfile `slots=8`; grid `nprow=4 npcol=4
nporder=column`; `gpu_affinity=0:1:2:3:4:5:6:7`; HPL-MxP-NVIDIA 26.2.0
banner; echoed settings match every supplied flag exactly (order=column,
sloppy-type=FP16, use-mpi-panel-broadcast=0, use-separate-stream-for-gemm=1,
prioritize-trsm=0, prioritize-factorization=0, test-loop=1, skip-tests=0,
monitor-gpu=0); internal test phase ran and completed (GEMM 597971 GFLOPS
avg, MPI/NCCL U and L2 broadcasts, pdgemv); rank→node mapping lines show
only hpc-gaas-g12 and hpc-gaas-g15. Pre-run health snapshot normal (30-32 C,
~77 W, 0 MiB used, driver 580.126.20).

Failure facts: the application reported
`Per process host memory consumption MAX = 253.133 GB, available MIN = 6.782 GB`
and `Per process device memory consumption MAX = 136.866 GB, available MIN = 138.739 GB`;
at Matrix Generation `Per process memory available MIN system = 6.157 GB,
device = 1.155 GB`; then SIGKILL (`hpl-mxp.sh: line 261: ... Killed`, first
failing process rank 15 on hpc-gaas-g15, exit code 137). Output ends before
LU/refinement: no residual, no verification verdict, no GFLOPS. Mechanical
arithmetic consistent with a deterministic host-memory wall at this
allocation shape: FP64 host matrix per node `737280^2 * 8 / 2 ≈ 2174 GB`
vs the 2000 GB per-node cgroup (the historical 2Nodes-8GPUs N-sweep
predicted the host-RAM wall in the 700000-800000 range by the same formula;
N=700000 PASSED with host available MIN 238.426 GB/process). The
pre-submission feasibility check (deliverable B) examined device memory only
and found no device-side impossibility; the binding constraint proved to be
host RAM under the validated 2000 GB per-node allocation.

### 2.5 Evidence and Artifacts

- Probe (COMPLETE): job 72591.gaas on exactly hpc-gaas-g12 + hpc-gaas-g15;
  raw evidence `scripts/outputs/phase0_2x8_probe_v1*` (committed at
  `73b06f4`); supplement appended to `scripts/probing_report.md`.
- Flag check: `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`
  (all 14 supplied flags SUPPORTED; OMP_NUM_THREADS=8 recorded as an
  environment setting, not a CLI flag).
- Baseline attempt v1 (FAILED): job 72595.gaas, queue gpu_as, project
  hpc_ebslee, nodes hpc-gaas-g12 + hpc-gaas-g15, walltime used 00:04:55,
  Exit_status 137. Evidence:
  `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_v1.{o,e}`,
  `..._v1_submission.log`, `..._v1_job72595_qstat_monitor.log`.
- Results: `results/metrics.csv` (failed row appended),
  `results/RESULTS.md` (regenerated, 193 rows).
- Commits: `73b06f4` (probe evidence + supplement + baseline preparation);
  this report and the failure bookkeeping are committed in the final
  execution commit of this session.
- Remote execution tree: `.codex-worktrees/TASK-000-73b06f4` at
  `73b06f4f56e7c60f937cd1af8fc0eab70cb7c4b4` (clean; dirty primary and all
  pre-existing remote material untouched).

### 2.6 Files Changed

- `scripts/probing_report.md` (append-only 2x8 supplement)
- `scripts/outputs/phase0_2x8_probe_v1*` (13 evidence files, added)
- `experiments/2x8-GAAS/baseline/README.md` (created, then updated with the
  v1 failure record)
- `experiments/2x8-GAAS/baseline/scripts/run_2x8_baseline.pbs` (created)
- `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`
  (created)
- `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_v1.{o,e}`,
  `..._v1_submission.log`, `..._v1_job72595_qstat_monitor.log` (retrieved
  evidence)
- `results/metrics.csv`, `results/RESULTS.md` (failed-attempt row)
- `tasks/TASK-000.md` (this report; front matter to BLOCKED/user)
- `progress/2026-09-27-progress_s6.md` (session handoff)

### 2.7 Missing / Unavailable Evidence

- No valid scored baseline attempt exists; the immutable 2x8-GAAS original
  baseline has NOT been established.
- The two identical repeats (v2/v3) were not run (conditional on a valid
  first attempt); no repeat range/median/spread/CV exists.
- No LU time/GFLOPS, iterative-refinement data, residual, verification
  verdict, or overall GFLOPS for N=737280 (the run died before those
  phases). GPU-monitoring output is unavailable by design (`--monitor-gpu 0`).

### 2.8 Execution Errors / Exceptions

The exact baseline OOMed (task 1.9 stop gate; constraint 20 anticipated
this as scientifically meaningful boundary evidence): host-memory SIGKILL
(exit 137) during Matrix Generation at N=737280 on the validated
2 x (ngpus=8, ncpus=96, mem=2000GB) allocation, after device memory had
also narrowed to 1.155 GB available MIN. Host FP64 matrix demand
(~2174 GB/node) exceeds the 2000 GB per-node cgroup; N=700000 PASSED
historically with ~238 GB/process host headroom, so the wall sits between
700000 and 737280 on the host side (and between 737280 and 800000 on the
device side). No automatic patch, retry, cancellation, or parameter
substitution was performed; no other errors occurred. Resolving this
requires a human/Strategic-Analyst decision (for example: a new approved
task with a revised configuration such as lower N and/or a different
host-memory strategy, accepting the boundary evidence, or closing Phase 0
differently) — all outside this task's approved scope, which fixed
N=737280 exactly.

### 2.9 Scope Compliance

Stayed within the approved scope throughout: one comprehensive read-only
probe (previous session, 72591.gaas); append-only probing-report
supplement; no external OpenMxP access; configuration never re-derived or
modified (all 14 flags verified unchanged and echoed identically by the
application); exactly one baseline submission with bounded monitoring and
full evidence retrieval; no repeats after the invalid first attempt; queues
restricted to gpu_as (approved) with project hpc_ebslee; no source edits,
package changes, or shared-software changes; dirty remote primary and all
pre-existing material preserved; no ANALYSE_RESULTS or strategic
interpretation performed.

### 2.10 Handoff to Strategic Analyst

TASK-000 is returned as `BLOCKED / user` at the OOM stop gate for Strategic
Analyst / Human Leader review. The Phase-0 characterization evidence (2x8
probe + supplement, flag-support check, feasibility arithmetic) is complete
and committed. The fixed baseline configuration N=737280 is not executable
within the validated 2000 GB per-node host-memory allocation on 2x8 GAAS.
Exact next action (human decision required): review the boundary evidence
in `experiments/2x8-GAAS/baseline/` and decide the path forward — e.g.,
authorize a new task with a revised Strategic-Analyst-supplied
configuration (such as a lower N and/or revised memory strategy), or
redirect Phase 0. No benchmark conclusion is available; no baseline was
promoted.
