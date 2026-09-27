---
task_id: TASK-002
title: Phase 1A — 2x8 GAAS Local N / FP64-Residency Refinement
status: EXECUTING
current_owner: codex
parent_task: TASK-001
analysis_id: 2x8-gaas-phase1a-n-refine
created: 2026-09-27
last_updated: 2026-09-27
---

# TASK-002 — Phase 1A: 2×8 GAAS Local N / FP64-Residency Refinement

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.11. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Execute the bounded Phase-1A local N refinement for the **2 GAAS nodes × 8 H200 GPUs/node** NVIDIA HPL-MxP campaign.

TASK-001 established a useful coarse N region and exposed an FP64-residency transition between approximately `N=404480` and `N=454656`. TASK-002 refines that region at approximately 5% pivot spacing while repeating the three coarse anchor points that bound it.

The purpose is to:

1. refine the current performance peak;
2. resolve the location and behavior of the FP64-residency transition more closely; and
3. check whether the coarse-sweep shape is reproducible under the same execution protocol.

This task does **not** select the final N, tune NB, change process-grid/order, tune residency-buffer controls, or start any downstream optimization direction.

One valid scored attempt per approved N candidate is sufficient for TASK-002 completion. No additional repeat/noise study is required.

### 1.2 Context

TASK-001 completed the six-point coarse Phase-1A sweep in one 2×8 allocation on `hpc-gaas-g12` + `hpc-gaas-g15`, queue `gpu_as`, PBS job `72624.gaas`.

All candidates passed correctness.

Key coarse results:

| N | Overall GFLOP/s | LU GFLOP/s | LU time | IR time | IR/LU | Device headroom after matrix generation | Host memory consumption MAX |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 404480 | `5.1559e+06` | `6.4538e+06` | 6.84 s | 1.72 s | 0.251 | 17.450 GB | 0.004 GB |
| 454656 | **`5.2433e+06`** | `6.8301e+06` | 9.17 s | 2.78 s | 0.303 | 2.257 GB | 15.024 GB |
| 504832 | `5.0179e+06` | `7.0444e+06` | 12.18 s | 4.92 s | 0.404 | 2.257 GB | 51.561 GB |

The current numerical leader is `N=454656`, but TASK-001 used one scored attempt per candidate and did not establish a unique optimum.

The memory evidence shows a clear operating-regime transition:

- `N=404480`: substantial remaining device headroom and effectively no reported host FP64 consumption;
- `N=454656`: device headroom collapses to approximately 2.257 GB and host consumption becomes non-trivial;
- larger N values retain approximately the same minimal device headroom while host consumption and iterative-refinement cost rise.

The approved Strategic Analyst conclusion in `planning/2x8-GAAS.md` is therefore to perform a bounded local N refinement before moving to Phase 1B NB tuning.

The immutable original campaign baseline remains:

```text
2x8-GAAS-baseline_n700k_v1
N = 700000
overall = 4.8037e+06 GFLOP/s
```

It remains the campaign percentage denominator and is not rerun in TASK-002.

### 1.3 Strategic Question / Hypotheses

Primary question:

> Within the approximately 80–100% pivot region, where is the strongest reproducible end-to-end N / FP64-residency operating regime, and how closely does the performance peak align with the observed device-residency transition?

Working hypotheses:

1. The useful end-to-end region lies between the TASK-001 coarse brackets `N=404480` and `N=504832`.
2. The current numerical leader `N=454656` lies near the transition where fill-device reaches its practical device-residency ceiling.
3. A candidate slightly below or above `N=454656` may improve the LU-versus-IR tradeoff.
4. Repeating the three TASK-001 anchors in the same refinement allocation will show whether the coarse performance shape is stable enough to carry forward into Phase 1B.

TASK-002 produces evidence only. Codex must not promote a final N or decide Phase 1B parameters.

### 1.4 Required Evidence / Deliverables

#### A. Fixed refinement candidate set

Run exactly:

```text
N = 404480
N = 429056
N = 454656
N = 480256
N = 504832
```

Roles:

- `404480`: lower coarse anchor / deliberate repeat;
- `429056`: new ~85% pivot refinement point;
- `454656`: current numerical leader / deliberate repeat;
- `480256`: new ~95% pivot refinement point;
- `504832`: upper coarse anchor / deliberate repeat.

These five values are the complete scientific sweep for TASK-002.

Do not add further N values, boundary points, or adaptive follow-up points inside this task.

#### B. Fixed scientific controls

Vary only `N`.

Use exactly the same scientific controls as TASK-001:

```text
OMP_NUM_THREADS=8

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

--fill-device 1

--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Do not explicitly change or tune:

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
- any other downstream tuning control.

Where not explicitly supplied above, retain the same installed package/default behavior used in TASK-001.

#### C. Execution logistics

Use the same experiment logistics as TASK-001.

Create a dedicated refinement experiment area, preferably:

```text
experiments/2x8-GAAS/phase1a-n-refine/
```

with:

```text
README.md
scripts/
outputs/
```

Reuse the TASK-001 sweep-script pattern and validated launcher contract rather than designing a new execution path.

Preferred execution:

- one PBS allocation;
- 2 nodes × 8 H200 GPUs;
- 16 MPI ranks;
- one rank/GPU;
- all five candidates run sequentially inside the same allocation;
- one shared de-duplicated hostfile with `slots=8` per node;
- container MPI + validated `pbsdsh` bridge;
- `place=scatter`;
- no `mpiprocs`;
- same module/container stack as TASK-001;
- pre/post hardware-health snapshot once around the whole sweep;
- per-candidate application stdout/stderr/status files;
- unique `ATTEMPT_TAG`-based evidence naming;
- do not overwrite prior attempt evidence.

As in TASK-001, if operational constraints make a single allocation impractical, Codex may split the approved candidates across equivalent 2×8 allocations without additional human approval, provided the scientific controls remain unchanged and every attempt remains uniquely identified.

No concurrent multinode submissions.

#### D. Minimal pre-submit validation

Reuse accepted TASK-001 / Phase-0 validation.

Before submission, perform only lightweight checks sufficient to catch obvious mistakes:

- syntax-check any new/modified PBS or shell script;
- verify the five approved N values;
- verify the fixed controls from Section 1.4B;
- verify the TASK-001 validated container and launcher contract is reused;
- verify 2 nodes × 8 GPUs, 16 ranks, one rank/GPU, 4×4 column order;
- verify project `hpc_ebslee`;
- verify the selected queue is `gpu_as` or `gpu_ded`;
- perform a lightweight live queue/node eligibility check before submission.

Do not repeat comprehensive Phase-0 characterization, package/flag audits, topology capture, container hashing, GPUDirect/NCCL characterization, or other already-accepted validation unless execution directly reveals a material contradiction.

#### E. Per-candidate evidence

For each approved N preserve, when emitted:

- attempt identifier;
- PBS job ID;
- queue and allocated nodes;
- N;
- fixed scientific controls;
- candidate exit status;
- correctness verdict;
- finite normalized residual;
- overall HPL-MxP GFLOP/s;
- LU time and LU GFLOP/s;
- iterative-refinement time;
- iterative-refinement iteration count;
- host-memory consumption/headroom;
- device-memory consumption/headroom;
- stdout/stderr.

Normal HPL-MxP output is sufficient scientific evidence.

No Nsight profiling, hardware-counter collection, continuous GPU monitoring, or other heavy telemetry is required.

#### F. Result logging

Append factual rows to:

```text
results/metrics.csv
results/RESULTS.md
```

Update the refinement experiment README with factual execution results and provenance.

Preserve raw outputs.

Codex must not:

- rank or promote a final N;
- decide whether Phase 1A is scientifically closed;
- choose Phase-1B NB candidates;
- update the Strategic Analyst conclusions in `planning/2x8-GAAS.md`;
- perform campaign-level interpretation.

Those actions require a later explicit `ANALYSE_RESULTS` authorization.

### 1.5 Relevant Inputs and References

Primary repository:

`QuangPham2404/HPL-MxP-Agent-Test`

Primary references:

- `tasks/TASK-001.md`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `experiments/2x8-GAAS/phase1a-n-coarse/README.md`
- `experiments/2x8-GAAS/phase1a-n-coarse/scripts/run_phase1a_n_coarse.pbs`
- `experiments/2x8-GAAS/phase1a-n-coarse/outputs/`
- `experiments/2x8-GAAS/baseline/README.md`
- `multi-node-test/GAAS_MULTINODE_SETUP.md`
- `workflow/07-Workflow.md`
- `workflow/08-Workflow-Multinode-Tuning.md`
- active root `AGENTS.md` and `APPLICATION.md`
- `results/metrics.csv`

No OpenMxP repository access is required or authorized.

### 1.6 Execution Scope

#### Allowed

Codex may:

- create `experiments/2x8-GAAS/phase1a-n-refine/` and its README/scripts/output structure;
- reuse/adapt the TASK-001 sweep script for the five approved refinement candidates;
- reuse the validated TASK-001 NVIDIA container and multinode launcher;
- execute the five approved N candidates sequentially in one allocation;
- split the five approved candidates across equivalent 2×8 allocations only when operationally useful;
- choose `gpu_as` or `gpu_ded` based on live eligibility;
- use scheduler-selected eligible nodes or an explicitly host-pinned eligible pair;
- perform lightweight syntax/configuration checks;
- submit and boundedly monitor the approved job(s);
- preserve all attempt-specific output/status evidence;
- automatically handle clearly non-scientific Track-1 synchronization, scheduler, output-path, worktree, or submission failures;
- retry an interrupted candidate/allocation with a new attempt tag when no meaningful scientific result was produced;
- continue with remaining approved candidates after an isolated scientifically meaningful candidate failure when safe and within scope;
- update experiment/results/task/progress bookkeeping;
- commit/push approved execution artifacts under normal project Git policy.

Reasonable scheduler-only changes such as attempt tags, output paths, eligible host pinning, or sufficient walltime are permitted without new authorization as long as the approved scientific configuration and 2×8 resource shape do not change.

#### Prohibited

Codex and workers must not:

- use any queue other than `gpu_as` or `gpu_ded`;
- use another accounting project;
- change the 2-node × 8-GPU resource shape;
- add N values outside the five approved candidates;
- perform an adaptive follow-up N sweep;
- change `NB=3072`;
- begin Phase 1B NB tuning;
- change the 4×4 grid or column order;
- change GPU/rank mapping policy;
- tune fill-device buffer size or Anq-device;
- tune OpenMP, CPU/memory affinity, DGEMV, communication, U-panel chunk, precision, GEMM kernel, host registration, or scheduling controls;
- perform an N×NB Cartesian sweep;
- rerun the immutable original baseline;
- repeat comprehensive Phase-0/TASK-001 validation without a concrete reason;
- require extra statistical repeats beyond the approved five-candidate refinement;
- access or depend on OpenMxP;
- perform strategic analysis or promote a final N.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and active Workflow v2.
2. Substantive execution remains delegated through the project-approved OpenCode worker workflow.
3. Use PBS compute-node execution only.
4. Use:

   ```text
   2 nodes × 8 H200 GPUs
   16 MPI ranks
   one rank/GPU
   place=scatter
   no mpiprocs
   ```

5. Use project:

   ```text
   hpc_ebslee
   ```

6. Only these queues are authorized:

   ```text
   gpu_as
   gpu_ded
   ```

   All other queues are outside TASK-002 authorization.

7. A node being reported as `free` does not prove eligibility for the selected queue. Confirm queue eligibility before host-pinning or relying on a node pair.

8. If one approved queue cannot provide an eligible pair, Codex may use the other approved queue without escalation.

9. Preserve the same validated container-MPI / `pbsdsh` launcher contract used by TASK-001.

10. Run candidates sequentially within one allocation when practical.

11. Preserve unique attempt/output names; never overwrite previous evidence.

12. One valid scored attempt per approved N is sufficient for TASK-002.

13. The three repeated anchor values (`404480`, `454656`, `504832`) are deliberate parts of the five-point refinement. They satisfy the intended reproducibility/bracketing check; no additional identical repeats are required.

14. A scientifically meaningful candidate OOM/correctness failure must be preserved as evidence and not silently converted into a different scientific configuration.

15. An isolated candidate failure does not automatically stop the remaining approved candidates when they can still execute safely under unchanged controls.

16. Track-1 operational recovery is permitted without human intervention when it remains inside this approved scope.

### 1.8 Success Criteria

TASK-002 is operationally complete when:

- the dedicated Phase-1A refinement experiment exists;
- the five approved N candidates have each been attempted, except where a documented systemic blocker legitimately prevents further execution;
- the same scientific controls as TASK-001 are preserved for all candidates other than N;
- `--fill-device 1` is active for every candidate;
- only `gpu_as` and/or `gpu_ded` are used;
- 2×8 / 16-rank mapping is preserved;
- every valid scored point has normal HPL-MxP output, finite correctness data, and `PASSED`;
- overall GFLOP/s, LU metrics, IR metrics, iterations, and memory/headroom evidence are preserved when emitted;
- scientifically meaningful failed/invalid points are preserved and not represented as valid scored results;
- factual rows are appended to the project results structure;
- raw stdout/stderr/status evidence is preserved;
- the Execution Report records factual completion and scope compliance only;
- task/progress/results artifacts are committed/pushed;
- front matter is handed back as:

  ```text
  status: EXECUTED
  current_owner: strategic-analyst
  ```

No additional repeat study, profiling, comprehensive reprobe, baseline rerun, NB tuning, downstream revalidation, or strategic conclusion is required.

### 1.9 Stop / Escalation Conditions

Stop and return for Strategic Analyst / Human direction only when:

- the validated TASK-001 launcher/container environment has materially changed and existing evidence cannot reasonably be reused;
- rank/GPU mapping is materially wrong and normal Track-1 recovery cannot restore it;
- execution requires a scientific-control change;
- execution requires a resource shape other than 2×8;
- execution requires a queue other than `gpu_as` or `gpu_ded`;
- execution requires another accounting project;
- multiple candidates exhibit a common correctness/runtime failure suggesting a systemic scientific/platform issue;
- execution cannot proceed without adding/replacing N candidates;
- another necessary action falls outside Section 1.11 authorization.

Do **not** escalate merely because:

- a `free` node is not eligible for the chosen queue;
- one approved queue currently lacks a suitable pair;
- the other approved queue must be used;
- the preferred TASK-001 node pair is unavailable;
- a normal Track-1 Git/worktree/scheduler/output issue occurs;
- the five candidates must be split across more than one equivalent allocation for operational reasons;
- one candidate produces a genuine isolated OOM/correctness failure while the remaining candidates remain safe to run.

### 1.10 Strategic Analyst Notes

This task is the **closing refinement experiment for Phase 1A**, not a new optimization direction.

The scientific comparison should later examine:

```text
overall GFLOP/s
LU time / LU GFLOP/s
IR time
IR/LU
IR iterations
correctness
device headroom
host memory consumption/headroom
repeat-anchor consistency with TASK-001
```

The expected analysis sequence after TASK-002 is:

```text
TASK-002 execution
        ↓
ANALYSE_RESULTS
        ↓
determine retained N / residency regime(s)
and whether Phase 1A can close
        ↓
Phase 1B NB tuning
        ↓
mandatory dependency review
        ↓
targeted/local N reopening only if NB materially changes
ranking, headroom, feasibility, or LU/IR balance
```

The following dependency conclusions from the TASK-001 checkpoint remain active:

- E07 (`N → NB`): NB is open, but execution waits until Phase 1A closes;
- E08 (`NB → N/memory boundary`): mandatory after a material NB change;
- E09 (`N → grid/order`): grid/order is open downstream but deferred to Phase 2;
- E14/E15 (`N ↔ FP64 residency`): this is the dependency being resolved by TASK-002;
- E16/E18 and other downstream controls remain provisional and are not tuned here.

The immutable original baseline remains `4.8037e+06` GFLOP/s. Do not replace it.

### 1.11 Authorization

status: APPROVED

approved_scope: Execute TASK-002 as the bounded Phase-1A local N / FP64-residency refinement on the established 2x8 GAAS NVIDIA HPL-MxP topology. Use exactly N={404480,429056,454656,480256,504832}; vary only N while preserving the TASK-001 scientific controls, including NB=3072, 4x4 column grid, OMP_NUM_THREADS=8, identity GPU affinity, FP16, MPI panel broadcast=0, separate GEMM stream=1, TRSM/factorization priorities=0, --fill-device 1, --test-loop 1, --skip-tests 0, and --monitor-gpu 0, with all unspecified controls retaining the same package/default behavior as TASK-001. Use the same TASK-001 execution logistics: preferably one 2-node x 8-H200 allocation with all five candidates sequentially, 16 ranks/one rank per GPU, place=scatter, no mpiprocs, validated container MPI plus pbsdsh bridge, shared deduplicated slots=8 hostfile, attempt-tag-specific evidence, pre/post sweep health snapshots, project hpc_ebslee, and only queues gpu_as or gpu_ded. Codex may choose between approved queues, select or host-pin eligible nodes, split the approved candidates across equivalent 2x8 allocations when operationally useful, make scheduler-only adjustments, and perform Track-1 operational recovery without new approval. Preserve correctness, overall/LU/IR, iteration, memory/headroom, job/node, and stdout/stderr evidence and update factual experiment/results/task/progress artifacts. One valid scored attempt per approved N is sufficient; the three repeated coarse anchors are the intended reproducibility check and no extra repeats are required. No additional N values, baseline rerun, NB tuning, N×NB sweep, grid/order change, buffer/residency tuning, host-runtime/affinity/DGEMV/communication/chunk/precision/kernel/scheduling tuning, comprehensive reprobe, profiling, OpenMxP access, or strategic interpretation is authorized.

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
