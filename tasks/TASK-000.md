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

Establish the Phase-0 evidence envelope and immutable original baseline for a new **2 GAAS nodes × 8 H200 GPUs/node** HPL-MxP optimization campaign.

This task has two sequential objectives:

1. Re-probe the 2×8 GAAS execution environment and compare it against the existing `scripts/probing_report.md`. Append only genuinely new or corrected information if the existing report is incomplete.
2. Execute the Strategic Analyst-defined NVIDIA HPL-MxP baseline configuration and use the resulting valid run as the new 2×8 campaign's immutable original baseline.

Codex must execute the approved work through Workflow v2 and hand the completed evidence back to the Strategic Analyst at `status: EXECUTED`.

No optimization analysis or next-direction selection is part of this task.

### 1.2 Context

This is the first production deployment of Workflow v2 in this repository.

The target topology is:

- 2 GAAS compute nodes;
- 8 NVIDIA H200 GPUs per node;
- 16 MPI ranks total;
- one MPI rank per GPU.

An older NVIDIA-container 2×8 experiment family exists under:

`experiments/2Nodes-8GPUs/`

It is historical evidence, not the original baseline for this new campaign.

Relevant historical NVIDIA results include:

- `N=700000`, `NB=3072`, 4×4 row:  
  `4.1061e+06 GFLOP/s`, PASSED.
- `N=800000`:  
  device HBM OOM.
- The previous experiment estimated the device-matrix ceiling near `N≈747000`.

Therefore the selected baseline value `N=737280` is close to the known NVIDIA-container HBM boundary. It must be attempted exactly as specified first. Codex must not silently lower `N` if it is invalid or OOMs.

The current hardware report is:

`scripts/probing_report.md`

It was generated from one 8-GPU node (`hpc-gaas-g11`) on 2026-08-20. Phase 0 now concerns a real **two-node × eight-GPU** allocation, so cross-node consistency and current runtime/provenance must be revalidated.

The active Workflow v2 files, root `AGENTS.md`, `APPLICATION.md`, the Phase-0 blueprint, and `workflow/08-Workflow-Multinode-Tuning.md` govern execution.

The Strategic Analyst has already performed the external configuration study. Codex does **not** need to access, inspect, clone, or verify any external OpenMxP repository.

### 1.3 Strategic Question / Hypotheses

#### Question A — Phase-0 characterization

Does the existing `scripts/probing_report.md` contain all hardware, topology, allocation, fabric, and software/provenance information required to trust a 2×8 GAAS HPL-MxP campaign?

Hypothesis:

The existing report captures the single-node hardware well but is likely incomplete for the new Phase-0 target because it does not establish all of the following for a current two-node allocation:

- cross-node hardware/topology consistency;
- allocation-visible CPU/cpuset differences;
- per-node GPU/NIC/NUMA mapping consistency;
- current IB/link state across both nodes;
- current GPUDirect/peer-memory state;
- exact current application/container/software provenance.

Only actual probe evidence may confirm or reject these gaps.

#### Question B — baseline validity

Can the fixed Strategic Analyst-defined baseline configuration run correctly and reproducibly on the NVIDIA HPL-MxP v26.02 container on 2×8 GAAS?

The configuration was selected from prior external performance evidence, but that external evidence is not part of Codex's execution responsibility.

The baseline configuration is an input to this task, not something Codex must derive or verify strategically.

### 1.4 Required Evidence / Deliverables

#### A. Comprehensive 2×8 probe

Create and submit one read-only comprehensive Phase-0 probe on a real:

`select=2:ngpus=8`

allocation with `place=scatter`.

The probe must collect the Phase-0 evidence required by the blueprint on **both allocated nodes**, including where available:

- hostname and PBS allocation identity;
- CPU model/topology;
- allocation-visible CPU set / affinity;
- NUMA topology and memory;
- host memory availability;
- GPU count/model/UUID/VRAM;
- GPU clocks, power limit, PCIe state and temperatures at probe time;
- `nvidia-smi topo -m`;
- GPU↔CPU/NUMA locality;
- GPU↔NIC locality;
- PCIe/NVLink/NVSwitch topology;
- IB/RDMA devices;
- IB port state/link layer/rate;
- `ibdev2netdev`;
- `nvidia_peermem` / relevant GDR module state;
- available container/runtime/module versions;
- current NVIDIA driver;
- current CUDA/runtime information;
- current Apptainer version;
- current MPI/NCCL/UCX provenance where obtainable read-only;
- current HPL-MxP container identity;
- container path and image digest/hash if obtainable read-only;
- effective installed HPL-MxP release;
- relevant launcher/software versions.

Preserve raw probe stdout/stderr under `scripts/outputs/` with a new attempt-specific name.

After the probe:

1. Compare its evidence against `scripts/probing_report.md`.
2. If new, changed, or previously missing Phase-0 information is found, append a clearly dated **2×8 Phase-0 supplement** to `scripts/probing_report.md`.
3. Do not rewrite the historical report body.
4. If the report is already complete and current for all relevant information, leave the report unchanged and state that explicitly in the Codex Execution Report.

The probe is observation only. It must not alter system configuration.

#### B. Fixed NVIDIA baseline configuration

The Strategic Analyst has already selected the baseline configuration.

Codex must **not** reconstruct or re-derive it from another repository.

Use the following fixed NVIDIA HPL-MxP configuration:

```text
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

Before submission, Codex may perform only a **mechanical compatibility check** against the installed NVIDIA HPL-MxP v26.02 `--help` or equivalent local package information to confirm that the supplied NVIDIA flags and accepted values are supported.

That check is not authorization to redesign the configuration.

If a supplied flag is unavailable or uses materially different syntax in the installed release, stop and report the incompatibility rather than substituting another tuning control.

Do not add source-specific OpenMxP environment variables or flags.

In particular, do not add:

- `OPENMXP_NVSHMEM_SPLIT`;
- `OPENMXP_IR_INVCACHE`;
- OpenMxP FP16-accumulation controls;
- OpenMxP `-comm`, `-vcomm`, `-dcomm`, `--nbuf`, `-alt`, or `-gdirect`;
- `UCX_IB_GPU_DIRECT_RDMA=n` solely because it was used in another implementation.

The NVIDIA container must use the project's validated NVIDIA multinode transport and launcher contract.

Do not add extra NVIDIA tuning controls unless required by the active launcher itself.

#### C. New 2×8 baseline experiment

Create exactly this new campaign structure:

```text
experiments/2x8-GAAS/
└── baseline/
    ├── README.md
    ├── scripts/
    │   └── <baseline PBS script>
    └── outputs/
```

Do not modify or reuse `experiments/2Nodes-8GPUs/` as the new campaign baseline area.

The baseline README must record:

- the fixed configuration supplied above;
- why it is being used as the Phase-0 starting configuration;
- that the configuration was supplied by the Strategic Analyst;
- that Codex did not independently optimize or derive it;
- exact execution attempts and evidence paths.

The baseline script must follow the active multinode launch contract:

- 2 nodes;
- 8 GPUs/node;
- 16 MPI ranks;
- one rank/GPU;
- `place=scatter`;
- no `mpiprocs`;
- de-duplicated hostfile with `slots=8`;
- NVIDIA HPC Benchmarks v26.02 container;
- container MPI end-to-end;
- `/opt/pbs` and `/var/spool/pbs` bindings;
- `multi-node-test/rsh_pbsdsh_container.sh`;
- `plm_rsh_no_tree_spawn=1`;
- `plm_rsh_num_concurrent=1`;
- `routed=direct`;
- `--bind-to none`;
- project `hpc_ebslee`;
- queue only `gpu_as` or `gpu_ded`;
- current campaign measurement controls:
  `--skip-tests 0 --monitor-gpu 0`.

No parameter sweep is authorized.

#### D. Baseline repetition / noise evidence

Phase 0 requires repeatability evidence.

If the exact baseline completes successfully and passes correctness:

1. designate the **first valid scored attempt** as the immutable
   2×8-GAAS original baseline;
2. run two additional **identical** scored repetitions, sequentially;
3. preserve all three attempts separately;
4. do not change parameters between repetitions;
5. record exact allocated nodes for every attempt;
6. report range, median and simple run-to-run spread/CV mechanically in the execution evidence, without strategic interpretation.

Prefer the same healthy node pair for all three attempts when practical.

Do not wait indefinitely for a particular pair of nodes.

All multinode jobs must run one at a time.

#### E. Baseline correctness / evidence

Every scored attempt must preserve:

- attempt ID;
- PBS job ID;
- queue;
- allocated nodes;
- resource request;
- exact launcher;
- container path and recorded provenance;
- exact HPL-MxP command;
- all explicit HPL-MxP flags;
- relevant environment;
- hostfile/rank count;
- rank↔node↔GPU mapping evidence;
- Phase-0/pre-post hardware-health evidence;
- host and GPU memory/headroom reported by the application where available;
- LU time/GFLOP/s;
- iterative-refinement time/iterations;
- overall GFLOP/s;
- final finite residual;
- normalized harness residual;
- `PASSED`/`FAILED`;
- PBS stdout/stderr and exit state.

The first valid scored attempt is the immutable percentage denominator for future `2x8-GAAS` analysis.

Do not compare or promote the historical `experiments/2Nodes-8GPUs/` results as this new campaign's original baseline.

### 1.5 Relevant Inputs and References

#### Active project repository

`QuangPham2404/HPL-MxP-Agent-Test`

Task-drafting revision:

`643eae6cf5db2396f3223a1ddcd8e3f7e2d6371e`

Required active references:

- `AGENTS.md`
- `APPLICATION.md`
- `workflow/00-General-SSH-Rules.md`
- `workflow/01-Git-Sync-Policy.md`
- `workflow/02-Repo-Structure.md`
- `workflow/03-Workflow-General-Notes.md`
- `workflow/04-Workflow-Probing-Scripts-Rules.md`
- `workflow/05-Workflow-Error-Patching-Procedures.md`
- `workflow/06-Workflow-Automation-and-Authorization.md`
- `workflow/07-Workflow.md`
- `workflow/08-Workflow-Multinode-Tuning.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `planning/dependency-graph/edges.csv`
- `HPL_MxP_TuningParam_Guide.md`
- `scripts/probing_report.md`
- `scripts/compute_node_hardware_probe_v1.pbs`
- `scripts/comm_transport_probe_report.md`
- `multi-node-test/GAAS_MULTINODE_SETUP.md`
- `multi-node-test/HPL-MxP/run_hplmxp_baseline.pbs`
- `experiments/2Nodes-8GPUs/README.md`
- `experiments/2Nodes-8GPUs/scripts/run_hplmxp_n_sweep.pbs`

Historical 2×8 evidence may be used for safety/context, especially the known `N=700000` pass and `N=800000` HBM OOM, but it is not the new campaign baseline.

No external OpenMxP repository access is required or authorized by this task.

### 1.6 Execution Scope

#### Allowed

Within this approved task, Codex may orchestrate and delegate to OpenCode workers the following:

- read required files in the active HPL-MxP-Agent-Test repository;
- perform read-only local/repository inspection;
- create a new Phase-0 probe script under `scripts/`;
- create new attempt-specific probe outputs under `scripts/outputs/`;
- submit one comprehensive read-only 2×8 PBS probe;
- boundedly monitor the approved PBS jobs;
- retrieve/preserve the approved probe outputs;
- append new Phase-0 information to `scripts/probing_report.md` if and only if supported by new evidence;
- create:
  `experiments/2x8-GAAS/baseline/README.md`;
- create:
  `experiments/2x8-GAAS/baseline/scripts/`;
- create:
  `experiments/2x8-GAAS/baseline/outputs/`;
- create and validate the NVIDIA-container baseline PBS script;
- mechanically confirm that the supplied NVIDIA flags are accepted by the installed release;
- use the validated NVIDIA container multinode launcher;
- submit the exact fixed 2×8 baseline and, after a valid first result, up to two identical repeat attempts;
- boundedly monitor those jobs;
- retrieve and preserve `.o`/`.e` evidence and other designated experiment evidence;
- update the experiment README with factual execution records;
- update `results/metrics.csv` / `results/RESULTS.md` only as required by Workflow v2 result logging;
- update the task's Codex Execution Report and lifecycle state;
- create/update the required progress handoff;
- perform required local syntax/path/diff validation;
- commit and push approved task-execution artifacts to the current project repository;
- perform non-destructive synchronization inside the configured GAAS project root using direct SSH (`ssh -o BatchMode=yes gaas '<remote-command>'`, or direct SSH when appropriate), `git status`, `git fetch origin`, `git rev-parse`, `git worktree list`, and `git worktree add --detach`;
- use clean-primary `git pull --ff-only` or, when the primary is dirty, create/use `.codex-worktrees/TASK-000-*` at the exact approved origin commit and execute from that isolated tree; preserve all pre-existing primary content and worktree evidence untouched. This is operational recovery only and does not expand scientific scope.

The approved resource shape for this task is 2 nodes × 8 GPUs.

The approved queues are `gpu_as` and `gpu_ded`.

The approved accounting group is `hpc_ebslee`.

#### Prohibited

Codex and workers must not:

- access, clone, inspect, or depend on the OpenMxP repository for this task;
- re-derive or redesign the supplied baseline configuration;
- perform Phase-1 tuning;
- sweep `N`, `NB`, grid, order, communication, affinity, runtime, residency, precision, or scheduling controls;
- choose a different baseline configuration after failure;
- silently lower `N=737280`;
- silently change `NB=3072`;
- change the 4×4 process grid;
- change `nporder=column`;
- substitute a different tuning control if one supplied flag is unsupported;
- add source-specific OpenMxP flags or environment variables;
- change launcher/transport policy outside the validated NVIDIA multinode contract;
- use NVSHMEM as a new NVIDIA-container transport experiment;
- modify source code;
- rebuild or replace the NVIDIA container;
- install packages;
- modify shared cluster software;
- change scheduler policy;
- use `gpu_aisg`, `gpu_free`, or other unapproved queues;
- use project `hpc_admin`;
- delete or overwrite historical evidence;
- modify `experiments/2Nodes-8GPUs/`;
- perform campaign-level strategic interpretation;
- promote any result other than the first valid exact baseline attempt as the original baseline;
- create Phase-1 work;
- run the dependency checkpoint;
- perform `ANALYSE_RESULTS`.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and Workflow `00`–`08`.
2. Substantive execution must be delegated to OpenCode worker(s).
3. Probe work is read-only with respect to cluster state.
4. All scheduler work must use PBS.
5. All GPU work must run on compute nodes.
6. Multinode jobs run sequentially, one at a time.
7. Use only `gpu_as` or `gpu_ded`.
8. Use `#PBS -P hpc_ebslee`.
9. Use `place=scatter`.
10. Do not specify `mpiprocs`.
11. Use one MPI rank per GPU.
12. Use the container's MPI runtime end-to-end.
13. Preserve `/opt/pbs` and `/var/spool/pbs` bindings and the validated pbsdsh bridge.
14. Use the exact Strategic Analyst-supplied baseline configuration unless a mechanical syntax incompatibility requires escalation.
15. Baseline scored runs must use:
    - `--skip-tests 0`
    - `--monitor-gpu 0`
16. Hardware health must be established with the Phase-0 probe and/or pre/post-run diagnostics rather than continuous benchmark monitoring.
17. Every retry uses a new attempt label and new output filenames.
18. Preserve failed/OOM attempts as evidence.
19. Before submitting `N=737280`, use existing NVIDIA evidence plus current available-memory/headroom information to confirm there is no obvious deterministic impossibility. Do not perform a new `N` search.
20. Existing evidence places the HBM wall between `N=700000` and `N=800000`; therefore an OOM at `N=737280` is scientifically meaningful boundary evidence and not an automatic-patching defect.

### 1.8 Success Criteria

Task execution is operationally complete when:

#### Probe

- one approved comprehensive 2×8 probe completes;
- raw evidence is preserved;
- both allocated nodes are represented;
- the existing probing report has been explicitly compared against the new Phase-0 evidence;
- any genuinely missing/current information is append-only added to `scripts/probing_report.md`, or Codex explicitly records that no update was necessary.

#### Baseline configuration

- the supplied NVIDIA baseline flags are mechanically confirmed as supported by the installed release;
- the configuration is recorded exactly in `experiments/2x8-GAAS/baseline/README.md`;
- no external-source re-derivation is performed;
- no unsupported tuning substitutions are introduced.

#### Baseline execution

- `experiments/2x8-GAAS/baseline/` exists with README, `scripts/`, and `outputs/`;
- the exact baseline is attempted at:
  - 2 nodes × 8 GPUs;
  - 16 ranks;
  - `N=737280`;
  - `NB=3072`;
  - grid 4×4;
  - `nporder=column`;
  - `OMP_NUM_THREADS=8`;
  - supplied communication/precision/scheduling flags;
- scheduler/output validation is complete;
- first valid attempt reports normal HPL-MxP output;
- residual is finite;
- verification reports `PASSED`;
- overall and LU performance are recorded;
- memory/headroom is recorded where available;
- the first valid attempt is explicitly identified as the immutable `2x8-GAAS` original baseline;
- two additional identical valid repeats are completed, if the first attempt is valid;
- simple mechanical noise/repeat statistics are recorded without strategic interpretation;
- evidence is committed/pushed;
- Codex completes Section 2;
- task status becomes `EXECUTED`;
- `current_owner` becomes `strategic-analyst`.

No optimization conclusion is required for execution completeness.

### 1.9 Stop / Escalation Conditions

Stop the affected branch of execution and report to the Human Leader if any of the following occurs:

- the two-node probe finds material hardware/topology asymmetry that makes the baseline unsafe or ambiguous;
- expected GPUs, cpusets, NICs, IB links, or rank placement are materially different from the documented environment;
- intended GPU-direct/CUDA-aware behavior cannot be established sufficiently for the approved launcher;
- the NVIDIA container/release or launcher provenance differs materially from `APPLICATION.md`;
- one of the supplied NVIDIA baseline flags is unavailable or has materially incompatible syntax/semantics;
- exact `N=737280` is deterministically infeasible;
- the exact baseline OOMs;
- the exact baseline fails verification;
- residual is non-finite;
- launcher/MPI/NCCL/UCX behavior fails or hangs;
- rank/GPU mapping is incorrect;
- a transport or resource change outside the approved launcher is required;
- a node appears unhealthy or contaminated in a way that invalidates performance measurement;
- fewer than two healthy eligible 8-GPU nodes can be obtained within the approved queues;
- any required action exceeds this task's scope.

If the exact baseline fails because `N=737280` is too close to the NVIDIA memory wall, do **not** automatically choose a smaller `N`. Preserve the evidence and return the task as `BLOCKED` or `PARTIAL` as appropriate for Strategic Analyst/Human review.

Track 1 may repair only deterministic workflow machinery defects according to `workflow/05-Workflow-Error-Patching-Procedures.md`.

Track 2 conditions must follow the manual-inspection process.

### 1.10 Strategic Analyst Notes

Execution order:

1. Verify synchronized repository/task state.
2. Perform comprehensive 2×8 probe.
3. Compare against `scripts/probing_report.md`.
4. Append only genuinely new/corrected evidence if necessary.
5. Mechanically confirm the supplied NVIDIA flags are accepted by the installed release.
6. Create and validate the baseline script.
7. Synchronize.
8. Submit the exact fixed baseline.
9. If valid, designate the first valid attempt as original baseline.
10. Run two identical repeats sequentially.
11. Preserve/log all evidence.
12. Complete Codex Execution Report and hand ownership back to Strategic Analyst.

Do not perform any external OpenMxP investigation.

Do not optimize during this task.

The baseline configuration is a Human/Strategic-Analyst-approved starting point. Codex's job is to execute and validate it operationally, not to reconsider how it was derived.

Historical `experiments/2Nodes-8GPUs/` evidence should be used only for NVIDIA-container feasibility and safety context, not as the original-baseline denominator for the new `2x8-GAAS` campaign.

After Codex hands the task back as `EXECUTED`, the Human Leader may separately authorize `ANALYSE_RESULTS` for `analysis_id: 2x8-gaas-phase0`. The Phase-0 dependency checkpoint belongs to that later Strategic Analyst step, not to Codex execution.

### 1.11 Authorization

status: APPROVED

approved_scope: Comprehensive 2x8 GAAS Phase-0 probe; append-only probing-report supplementation if evidence requires it; execution of the fixed Strategic-Analyst-supplied NVIDIA HPL-MxP 2x8 baseline configuration; creation of experiments/2x8-GAAS/baseline; exact baseline submission and up to two identical valid repeats; bounded monitoring, evidence retrieval, result logging, synchronization, commit/push, and Workflow-v2 handoff. No external OpenMxP access, tuning, configuration re-derivation, or parameter substitution.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

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

status: PARTIAL

TASK-000 is rearmed as `APPROVED / codex` by explicit human authorization in
the workflow-maintenance request. Approved task execution has not begun.

### 2.2 Orchestration Summary

No worker was dispatched during maintenance. The next execution session must
use the existing OpenCode execution layer within the approved task scope.

### 2.3 Work Executed

Workflow-maintenance documentation only; no TASK-000 execution.

### 2.4 Operational Validation

Section 1.11 approval and exact scope are unchanged. The fixed baseline,
scientific stop conditions, and approved probe-first order are unchanged.

### 2.5 Evidence and Artifacts

Previous startup evidence is preserved above and in the historical progress
records. Maintenance handoff: `progress/2026-09-27-progress_s4.md`.

### 2.6 Files Changed

Workflow-maintenance files are listed in the maintenance progress record.

### 2.7 Missing / Unavailable Evidence

All Phase-0 probe and baseline execution evidence is still pending.

### 2.8 Execution Errors / Exceptions

No current manual blocker is established by the previous dirty-clone or
missing-ControlPath conditions. Use documented Track 1 recovery; escalate
only actual unresolved authority, authentication, content, or external issues.

### 2.9 Scope Compliance

No GAAS connection, worker, probe, scheduler action, HPL-MxP run, OpenMxP
access, tuning, or analysis was performed during this maintenance patch.

### 2.10 Handoff to Strategic Analyst

Next action is a fresh Codex execution session explicitly selecting TASK-000:
verify approved local/origin revision and unchanged Section 1.11, connect by
direct SSH, inspect/preserve primary state, fetch and create/reuse a clean
isolated worktree if needed, verify the actual execution tree, and continue
the approved probe-first sequence. Set `EXECUTING / codex` on initial start;
subsequent sessions may resume that state without new approval. No strategic
or benchmark conclusion is available.
