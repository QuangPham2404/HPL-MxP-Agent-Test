---
task_id: TASK-003
title: Phase 1B — 2x8 GAAS Bounded NB Screen at Retained N
status: APPROVED
current_owner: codex
parent_task: TASK-002
analysis_id: 2x8-gaas-phase1b-nb-screen
created: 2026-09-27
last_updated: 2026-09-27
---

# TASK-003 — Phase 1B: 2×8 GAAS Bounded NB Screen at Retained N

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.11. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Execute the first bounded **Phase-1B NB screen** for the **2 GAAS nodes × 8 H200 GPUs/node** NVIDIA HPL-MxP campaign.

Phase 1A is closed at the retained representative problem size:

```text
N = 429056
```

under the current provisional controls and `--fill-device 1` policy.

TASK-003 varies **only NB** at this retained N to determine which block-size region provides the strongest valid end-to-end HPL-MxP behavior while preserving enough evidence to evaluate:

- overall HPL-MxP performance;
- LU efficiency;
- iterative-refinement cost;
- memory/workspace headroom; and
- whether changing NB materially moves the useful N/residency regime.

This task does **not** retune N, grid/order, affinity, host runtime, residency buffer, communication, U-panel chunking, precision, GEMM kernel, or scheduling.

One valid scored attempt per approved NB candidate is sufficient for TASK-003 completion. No additional statistical repeat study is required.

### 1.2 Context

TASK-002 established the retained Phase-1A operating point:

```text
N = 429056
NB = 3072
Overall = 5.6091e+06 GFLOP/s
LU = 6.6130e+06 GFLOP/s
LU time = 7.96 s
IR time = 1.43 s
IR/LU = 0.180
IR iterations = 3
Device headroom after matrix generation = 2.767 GB
Host memory consumption MAX = 0.004 GB
Correctness = PASSED
```

This is currently the strongest valid 2×8 Phase-1A result and is approximately +16.77% above the immutable original campaign baseline:

```text
2x8-GAAS-baseline_n700k_v1
overall = 4.8037e+06 GFLOP/s
```

TASK-002 also bounded the FP64-residency transition between `N=429056` and `N=454656`. At the retained N, the device has only approximately 2.767 GB post-matrix-generation headroom, while reported host consumption remains effectively zero.

Therefore NB tuning is not only a performance question. NB may change:

- panel count and panel/update geometry;
- LU efficiency;
- workspace demand;
- memory headroom;
- the useful N/residency boundary; and
- the LU-versus-IR balance.

Per the dependency graph:

- E07 (`N → NB`) is active now;
- E08 (`NB → N / memory boundary`) requires a mandatory post-NB dependency review;
- E10/E22/E23/E24/E28/E34 may reopen downstream conclusions after a material NB change.

The current `NB=3072` is a same-protocol control, not an assumed optimum.

### 1.3 Strategic Question / Hypotheses

Primary question:

> At fixed `N=429056`, which NB region provides the strongest valid end-to-end HPL-MxP behavior, and does changing NB materially affect LU/IR balance, correctness, or the current FP64-residency/memory boundary?

Working hypotheses:

1. Smaller NB may increase panel frequency and synchronization overhead but reduce per-panel workspace/latency.
2. Larger NB may improve GEMM/update efficiency but increase panel/workspace pressure and alter the LU critical path.
3. Because `N=429056` is close to the practical device-residency ceiling, a larger NB may reduce memory headroom enough to create a new boundary.
4. The best NB must therefore be judged by end-to-end score and correctness, not LU throughput alone.
5. Historical single-node NB values are search hypotheses only. No numerical optimum transfers to this 2×8 topology.
6. `N % NB == 0` is not assumed to be a performance requirement.

TASK-003 produces raw evidence only. Strategic retention of an NB region and any decision to reopen N occur only after explicit `ANALYSE_RESULTS`.

### 1.4 Required Evidence / Deliverables

#### A. Fixed NB candidate set

At fixed `N=429056`, run:

```text
NB = 1024
NB = 2048
NB = 3072
NB = 4096
NB = 5120
NB = 6144
```

Roles:

- `1024`, `2048`: smaller-panel region;
- `3072`: same-protocol Phase-1A control;
- `4096`, `5120`, `6144`: progressively larger-panel region.

These six values are the complete scientific candidate set for TASK-003.

Do not add NB values above 6144 or insert adaptive intermediate NB values inside this task.

All six candidates should normally be attempted.

A larger remaining NB candidate may be skipped only when an already-attempted candidate provides a **clear safety boundary**, such as device/host OOM, allocation failure caused by benchmark workspace, or correctness invalidity accompanied by memory-exhaustion evidence, such that proceeding upward under the unchanged configuration is not reasonably safe. Record the skipped values and boundary evidence explicitly.

A valid but slower candidate is **not** by itself grounds to truncate the approved six-point sweep.

#### B. Fixed scientific controls

Vary only `NB`.

Use:

```text
N = 429056
OMP_NUM_THREADS=8

--nprow 4
--npcol 4
--nporder column
--gpu-affinity 0:1:2:3:4:5:6:7

--sloppy-type FP16
--use-mpi-panel-broadcast 0
--use-separate-stream-for-gemm 1
--prioritize-trsm 0
--prioritize-factorization 0

--fill-device 1

--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Only `--nb <candidate>` changes between scored runs.

Do not explicitly tune:

- `--fill-device-buffer-size`;
- `--Anq-device`;
- DGEMV partitioning;
- U-panel chunking;
- CPU/memory affinity;
- OpenMP placement/binding;
- MPI/NCCL broadcast policy;
- precision;
- GEMM kernel/preset;
- host-register step;
- communication/NIC controls;
- grid/order;
- N;
- any other downstream control.

Where controls are not explicitly supplied above, retain the same installed package/default behavior used in TASK-002.

#### C. Execution logistics

Use the same validated execution logistics as TASK-001/TASK-002.

Create a dedicated experiment area, preferably:

```text
experiments/2x8-GAAS/phase1b-nb-screen/
```

with:

```text
README.md
scripts/
outputs/
```

Reuse/adapt the TASK-002 sweep-script pattern rather than creating a new launcher design.

Preferred execution:

- one PBS allocation;
- 2 nodes × 8 H200 GPUs;
- 16 MPI ranks;
- one rank/GPU;
- all six NB candidates sequentially within the same allocation;
- one shared de-duplicated hostfile with `slots=8` per node;
- validated NVIDIA container MPI + `pbsdsh` bridge;
- `place=scatter`;
- no `mpiprocs`;
- same module/container stack as TASK-002;
- one pre/post hardware-health snapshot around the entire sweep;
- per-candidate stdout/stderr/status evidence;
- unique `ATTEMPT_TAG`-based naming;
- no overwrite of existing evidence;
- no concurrent multinode submissions.

If one allocation is operationally impractical, Codex may split the approved NB values across equivalent 2×8 allocations without additional human approval, provided all scientific controls remain identical and each attempt is uniquely identified.

Prefer running `NB=3072` early enough to provide a same-allocation control before interpreting any operational anomaly. Exact sequential order is operationally flexible as long as the six approved values are the only scientific candidates and the order is recorded.

#### D. Minimal pre-submit validation

Reuse accepted Phase-0, TASK-001, and TASK-002 evidence.

Before submission, perform only checks needed to catch execution mistakes:

- syntax-check new/modified PBS or shell scripts;
- verify fixed `N=429056`;
- verify the six approved NB values;
- verify all fixed controls from Section 1.4B;
- verify the validated container/launcher contract is reused;
- verify 2 nodes × 8 GPUs, 16 ranks, one rank/GPU;
- verify 4×4 column grid;
- verify project `hpc_ebslee`;
- verify selected queue is `gpu_as` or `gpu_ded`;
- perform a lightweight live queue/node eligibility check before submission.

Do not repeat comprehensive topology probing, software inventory, flag audits, container hashing, GPUDirect/NCCL/UCX characterization, or other accepted evidence unless execution reveals a material contradiction.

#### E. Per-candidate evidence

For every attempted NB preserve, when emitted:

- experiment / attempt identifier;
- PBS job ID;
- queue;
- allocated nodes;
- N and NB;
- fixed scientific controls;
- application/PBS completion state;
- correctness verdict;
- finite normalized residual;
- overall HPL-MxP GFLOP/s;
- LU time;
- LU GFLOP/s;
- iterative-refinement time;
- iterative-refinement iteration count;
- `T_IR / T_LU` derivable from recorded timings;
- host-memory consumption/headroom;
- GPU-memory consumption/headroom;
- stdout/stderr.

Normal HPL-MxP output is the primary scientific evidence.

No profiling, Nsight, hardware counters, continuous GPU monitoring, or extra diagnostic instrumentation is required.

If a candidate fails because of memory/workspace pressure, preserve the raw evidence and identify the phase of failure when possible. Do not rank an invalid/OOM result as a slow valid candidate.

#### F. Result logging

Append factual attempt data to:

```text
results/metrics.csv
results/RESULTS.md
```

Update the experiment README with factual run/provenance information.

Preserve raw stdout/stderr/status evidence.

Codex must not:

- choose a winning NB;
- declare a plateau;
- decide whether N remains closed;
- start a targeted N resweep;
- update strategic conclusions in `planning/2x8-GAAS.md`;
- begin Phase 2;
- perform campaign-level interpretation.

Those actions require explicit `ANALYSE_RESULTS` authorization.

### 1.5 Relevant Inputs and References

Primary repository:

`QuangPham2404/HPL-MxP-Agent-Test`

Relevant references:

- `tasks/TASK-002.md`
- `planning/analysis/2x8-gaas-phase1a-n-refine.md`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `experiments/2x8-GAAS/phase1a-n-refine/README.md`
- `experiments/2x8-GAAS/phase1a-n-refine/scripts/run_phase1a_n_refine.pbs`
- `experiments/2x8-GAAS/phase1a-n-refine/outputs/`
- `experiments/2x8-GAAS/baseline/README.md`
- `multi-node-test/GAAS_MULTINODE_SETUP.md`
- `workflow/07-Workflow.md`
- `workflow/08-Workflow-Multinode-Tuning.md`
- active root `AGENTS.md` and `APPLICATION.md`
- `results/metrics.csv`

Historical single-node NB studies may be read only as qualitative prior knowledge; their numerical winners must not be treated as transferable targets.

No OpenMxP repository access is required or authorized.

### 1.6 Execution Scope

#### Allowed

Codex may:

- create `experiments/2x8-GAAS/phase1b-nb-screen/` and supporting README/scripts/output structure;
- reuse/adapt the TASK-002 sweep script and validated launcher;
- execute exactly the six approved NB candidates at fixed `N=429056`;
- run them sequentially within one 2×8 allocation when practical;
- split them across equivalent 2×8 allocations if operationally necessary;
- choose between `gpu_as` and `gpu_ded` based on live eligibility;
- use scheduler-selected eligible nodes or an explicitly host-pinned eligible pair;
- choose a practical candidate order, including placing `NB=3072` early as a same-allocation control;
- stop larger remaining NB candidates only after a clear memory/correctness safety boundary as defined in Section 1.4A;
- perform lightweight syntax/configuration checks;
- submit and boundedly monitor approved jobs;
- preserve all attempt-specific evidence;
- automatically recover/retry clearly non-scientific Track-1 scheduler, synchronization, output-path, worktree, or submission failures;
- retry an interrupted candidate/allocation with a new attempt tag when no meaningful scientific result was produced;
- continue after an isolated scientifically meaningful failure when the remaining approved candidates can still execute safely under unchanged controls;
- update experiment/results/task/progress bookkeeping;
- commit and push approved execution artifacts under normal project Git policy.

Reasonable scheduler-only changes such as attempt tags, output paths, eligible host pinning, or sufficient walltime are allowed without new approval as long as the scientific configuration and 2×8 resource shape remain unchanged.

#### Prohibited

Codex and workers must not:

- use any queue other than `gpu_as` or `gpu_ded`;
- use another accounting project;
- change the 2-node × 8-GPU resource shape;
- change `N=429056`;
- add NB values outside `{1024,2048,3072,4096,5120,6144}`;
- extend NB beyond 6144;
- start a local N resweep;
- perform an N×NB Cartesian sweep;
- change the 4×4 grid or column order;
- change rank/GPU mapping policy;
- tune fill-device buffer size or Anq-device;
- tune OpenMP, CPU/memory affinity, DGEMV, MPI/NCCL broadcast, U-panel chunking, communication/NIC controls, precision, GEMM kernel, host registration, or scheduling priorities;
- rerun the immutable original baseline;
- repeat comprehensive Phase-0/TASK-001/TASK-002 characterization without concrete contradiction;
- require extra statistical repeats;
- access or depend on OpenMxP;
- perform strategic analysis;
- promote an NB candidate or decide whether N must reopen;
- begin Phase 2.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and active Workflow v2.
2. Substantive execution remains delegated through the project-approved OpenCode worker workflow.
3. Use PBS compute-node execution only.
4. Resource shape remains:

   ```text
   2 nodes × 8 H200 GPUs
   16 MPI ranks
   one rank/GPU
   place=scatter
   no mpiprocs
   ```

5. Accounting project:

   ```text
   hpc_ebslee
   ```

6. Only these queues are authorized:

   ```text
   gpu_as
   gpu_ded
   ```

   All other queues are outside TASK-003 authorization.

7. Scheduler state `free` does not by itself prove queue eligibility. Confirm queue eligibility before host-pinning or relying on a node pair.

8. If one approved queue cannot provide an eligible pair, Codex may use the other approved queue without escalation.

9. Preserve the validated TASK-002 container-MPI / `pbsdsh` launcher contract.

10. Preserve fixed `N=429056` and all Section 1.4B controls.

11. Use:

   ```text
   --skip-tests 0
   --monitor-gpu 0
   ```

12. Preserve unique attempt/output names; never overwrite evidence.

13. One valid scored attempt per approved NB is sufficient.

14. A scientifically meaningful OOM, allocation failure, or correctness invalidity must be preserved as evidence.

15. If such a failure clearly establishes an unsafe memory/workspace boundary for larger NB under unchanged controls, Codex may stop the larger remaining NB values and document the reason. Otherwise continue the approved set.

16. Valid performance degradation alone does not authorize early truncation.

17. Track-1 operational recovery is permitted without human intervention when it stays inside approved scope.

### 1.8 Success Criteria

TASK-003 is operationally complete when:

- the dedicated Phase-1B NB experiment area exists;
- the approved NB candidates have been attempted, except larger values legitimately skipped after a documented safety boundary;
- `N=429056` is fixed for every scored attempt;
- only NB changes across scored candidates;
- the same TASK-002 scientific controls and package/default behavior are otherwise preserved;
- only `gpu_as` and/or `gpu_ded` are used;
- the 2×8 / 16-rank mapping is preserved;
- every valid scored candidate has normal HPL-MxP output, finite residual data, and `PASSED`;
- overall, LU, IR, iteration, and memory/headroom evidence is captured when emitted;
- invalid/OOM candidates are preserved as boundary evidence rather than ranked as valid points;
- any skipped larger NB values are explicitly linked to the safety-boundary evidence;
- factual rows are added to the project results structure;
- raw stdout/stderr/status evidence is preserved;
- Codex completes the Execution Report without selecting a winning NB or deciding N reopening;
- task/progress/results artifacts are committed/pushed;
- task ownership is handed back as:

  ```text
  status: EXECUTED
  current_owner: strategic-analyst
  ```

No profiling, comprehensive reprobe, baseline rerun, mandatory extra repeatability study, strategic interpretation, or targeted N resweep is required for completion.

### 1.9 Stop / Escalation Conditions

Stop the affected work and return for Strategic Analyst / Human direction only when:

- the validated launcher/container environment has materially changed and accepted evidence cannot reasonably be reused;
- rank/GPU mapping is materially incorrect and normal Track-1 recovery cannot restore it;
- execution requires changing `N=429056`;
- execution requires an NB outside the approved set;
- execution requires another scientific-control change;
- execution requires a resource shape other than 2×8;
- execution requires a queue other than `gpu_as` or `gpu_ded`;
- execution requires another accounting project;
- multiple candidates exhibit a common correctness/runtime failure suggesting a systemic platform/scientific issue rather than an NB-specific boundary;
- interpreting an ambiguous failure would require a new diagnostic experiment outside this task;
- another required action exceeds Section 1.11 authorization.

Do **not** escalate merely because:

- a `free` node is ineligible for the chosen queue;
- one approved queue lacks an eligible pair;
- the other approved queue must be used;
- the TASK-002 node pair is unavailable;
- a normal Track-1 synchronization/worktree/scheduler/output issue occurs;
- the candidates must be split across equivalent allocations;
- one candidate is valid but slower;
- one candidate establishes a clear memory/workspace boundary and larger approved values are therefore safely skipped under Section 1.4A.

### 1.10 Strategic Analyst Notes

TASK-003 is the initial Phase-1B NB screen.

The later analysis must compare at minimum:

```text
NB
overall GFLOP/s
LU time / LU GFLOP/s
IR time
IR/LU
IR iterations
correctness / residual
device headroom
host memory consumption/headroom
same-protocol NB=3072 control
immutable original baseline comparison
```

The intended workflow after TASK-003 is:

```text
TASK-003 execution
        ↓
ANALYSE_RESULTS
        ↓
retain NB region / identify plateau or boundary
        ↓
mandatory dependency review
        ↓
E08: did NB materially move N/residency/feasibility/LU-IR?
        ↓
if NO: keep N closed
if YES: authorize only a targeted local N resweep
        ↓
verify retained Phase-1 geometry
        ↓
close Phase 1 when justified
```

Do not automatically start the N recheck or Phase 2.

### 1.11 Authorization

status: APPROVED

approved_scope: Execute TASK-003 as the bounded Phase-1B NB screen on the established 2x8 GAAS NVIDIA HPL-MxP topology. Fix N=429056 and vary only NB across exactly {1024,2048,3072,4096,5120,6144}. Preserve the TASK-002 scientific controls: OMP_NUM_THREADS=8, 4x4 column grid, identity GPU affinity, FP16, MPI panel broadcast=0, separate GEMM stream=1, TRSM/factorization priorities=0, --fill-device 1, --test-loop 1, --skip-tests 0, and --monitor-gpu 0, with all unspecified controls retaining the same package/default behavior as TASK-002. Use the same validated execution logistics as TASK-002: preferably one 2-node x 8-H200 allocation with the six candidates sequentially, 16 ranks/one rank per GPU, place=scatter, no mpiprocs, validated container MPI plus pbsdsh bridge, shared de-duplicated slots=8 hostfile, attempt-tag-specific evidence, pre/post sweep health snapshots, project hpc_ebslee, and only queues gpu_as or gpu_ded. Codex may choose between approved queues, select or host-pin eligible nodes, split approved candidates across equivalent 2x8 allocations when operationally useful, choose a practical candidate order with NB=3072 available as the same-protocol control, make scheduler-only adjustments, and perform Track-1 operational recovery without new approval. All six candidates should normally be attempted; valid performance degradation alone does not authorize truncation. If an attempted NB establishes a clear memory/workspace/correctness safety boundary making larger NB values unsafe under unchanged controls, Codex may stop the larger remaining candidates and must preserve/document the boundary evidence and skipped values. Preserve correctness, overall/LU/IR, iterations, memory/headroom, job/node, and stdout/stderr evidence and update factual experiment/results/task/progress artifacts. One valid scored attempt per NB is sufficient. No other NB values, N changes/resweeps, baseline rerun, N×NB sweep, grid/order/affinity/buffer/residency/host-runtime/DGEMV/communication/chunk/precision/kernel/scheduling tuning, comprehensive reprobe, profiling, OpenMxP access, Phase-2 work, or strategic interpretation is authorized.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

<!-- Codex completes this section after execution; do not rewrite section 1. -->

### 2.1 Execution Status

status: <COMPLETE | PARTIAL | BLOCKED | FAILED>

### 2.2 Orchestration Summary

*Workers, responsibilities, dependencies, ordering, and follow-ups.*

### 2.3 Work Executed

*Factual work performed.*

### 2.4 Operational Validation

*Evidence, correctness, provenance, consistency, and scope checks.*

### 2.5 Evidence and Artifacts

*Reference raw evidence paths and revisions; do not duplicate large outputs.*

### 2.6 Files Changed

*List files or state None.*

### 2.7 Missing / Unavailable Evidence

*List gaps or state None.*

### 2.8 Execution Errors / Exceptions

*List failures and exceptions or state None. Record authorized Track-1 recovery and the exact resume action if incomplete.*

### 2.9 Scope Compliance

*State whether work stayed within the approved scope.*

### 2.10 Handoff to Strategic Analyst

*Give factual reading guidance without strategic interpretation.*
