---
task_id: TASK-005
title: Phase 2A — 2x8 GAAS Row-Order Complement
status: EXECUTING
current_owner: codex
parent_task: TASK-004
analysis_id: 2x8-gaas-phase2a-grid-order-matrix
created: 2026-09-27
last_updated: 2026-09-27
---

# TASK-005 — Phase 2A: 2×8 GAAS Row-Order Complement

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.11. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Complete the second half of the Phase-2A grid/order experiment for the
established **2 GAAS nodes × 8 H200 GPUs/node** NVIDIA HPL-MxP campaign.

TASK-004 already measured the three approved 16-rank grid shapes under:

```text
--nporder column
```

TASK-005 runs the exact same three shapes under:

```text
--nporder row
```

with all other scientific controls unchanged.

Together TASK-004 and TASK-005 form the intended bounded 3×2 grid/order matrix:

| Process grid | column | row |
|---|---|---|
| 2×8 | TASK-004 | TASK-005 |
| 4×4 | TASK-004 | TASK-005 |
| 8×2 | TASK-004 | TASK-005 |

The purpose of TASK-005 is **not** to select a winner independently. Its role is
to provide the row-order counterparts needed for a joint analysis of:

- process-grid shape effect;
- row-vs-column order effect;
- shape×order interaction;
- LU/IR balance;
- host/device headroom;
- and the physical node-crossing pattern implied by the verified rank map.

No Phase-2A retention decision is made until TASK-004 and TASK-005 are analyzed
together.

### 1.2 Context

Phase 1 is closed with:

```text
N  = 429056
NB = 3072
fill-device = 1
```

TASK-004 then ran the column-order shape screen in one valid allocation:

```text
4×4 column = 5.4505e+06 GFLOP/s
2×8 column = 5.3746e+06 GFLOP/s
8×2 column = 5.5487e+06 GFLOP/s
```

All three passed correctness.

However, these differences are not large enough to justify pruning a shape
before checking order. More importantly, `nporder` changes how global ranks
populate the logical process grid. With the observed allocation mapping:

```text
global ranks 0–7  -> node g12
global ranks 8–15 -> node g15
```

switching `row` versus `column` can materially change which logical process
rows or columns remain node-local versus cross the node boundary.

Therefore TASK-004 is treated as the **column half** of the factorial, not a
completed Phase-2A selection.

### 1.3 Strategic Question / Hypotheses

Primary question:

> For the same three process-grid shapes tested in TASK-004, how does
> `nporder=row` change end-to-end performance, LU/IR balance, memory
> behavior, and logical communicator placement relative to `nporder=column`?

Working hypotheses:

1. The preferred order may depend on the grid shape; no global row/column winner
   is assumed.
2. Some shapes may align one logical communicator more favorably with the
   8-ranks-per-node placement under row order than under column order.
3. A shape that was slightly weaker under column order may become competitive
   or superior under row order.
4. Grid/order changes may alter worst-rank local matrix ownership and therefore
   host/device headroom at fixed N/NB.
5. TASK-004 and TASK-005 must be interpreted jointly; TASK-005 alone is not
   sufficient for a retained-grid decision.

### 1.4 Required Evidence / Deliverables

#### A. Fixed candidate set

Run exactly:

```text
4 × 4 row
2 × 8 row
8 × 2 row
```

with:

```text
--nporder row
```

for every scored candidate.

Preferred execution order:

```text
4x4 row
2x8 row
8x2 row
```

This mirrors TASK-004 and simplifies paired comparison.

Do not add:

- column-order reruns;
- `1×16` or `16×1`;
- additional grid shapes;
- adaptive variants.

#### B. Fixed scientific controls

Vary only:

```text
--nprow
--npcol
```

with `nporder=row` fixed.

Use exactly:

```text
N = 429056
NB = 3072
OMP_NUM_THREADS=8

--nporder row
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

Do not explicitly tune or change:

- N or NB;
- GPU affinity;
- `--fill-device-buffer-size`;
- `--Anq-device`;
- U-panel chunking;
- DGEMV partitioning;
- CPU/memory affinity;
- OpenMP placement/binding beyond `OMP_NUM_THREADS=8`;
- MPI/NCCL broadcast policy;
- communication/NIC controls;
- precision;
- GEMM kernel/preset;
- host-register step;
- scheduling priorities;
- any other downstream control.

All unspecified controls must retain the same package/default behavior used in
TASK-004.

#### C. Rank-map evidence

Before the first scored candidate in each allocation, record one lightweight
MPI mapping probe using the same:

- 16 ranks;
- shared de-duplicated `slots=8` hostfile;
- container MPI;
- `pbsdsh` bridge;
- launcher daemon flags.

Preserve, for all 16 ranks when available:

```text
global_rank
local_rank
hostname
```

or equivalent unambiguous evidence.

This is required so the later joint TASK-004/TASK-005 analysis can reconstruct
the logical row/column node-crossing pattern under both `column` and `row`
order.

No topology profiling or communication tracing is required.

#### D. Execution logistics

Create a dedicated experiment area, preferably:

```text
experiments/2x8-GAAS/phase2a-grid-row/
```

with:

```text
README.md
scripts/
outputs/
```

Reuse/adapt the TASK-004 sweep script and validated multinode launcher.

Preferred execution:

- one PBS allocation;
- 2 nodes × 8 H200 GPUs;
- 16 MPI ranks;
- one rank/GPU;
- all three row-order candidates sequentially;
- one shared de-duplicated hostfile with `slots=8` per node;
- validated NVIDIA container MPI + `pbsdsh` bridge;
- `place=scatter`;
- no `mpiprocs`;
- same module/container stack as TASK-004;
- one rank-map probe before the sweep;
- one pre/post hardware-health snapshot around the whole sweep;
- per-candidate stdout/stderr/status evidence;
- unique `ATTEMPT_TAG` naming;
- no evidence overwrite;
- no concurrent multinode submissions.

If one allocation is operationally impractical, Codex may split the approved
three candidates across equivalent 2×8 allocations while keeping all
scientific controls unchanged. Each allocation must preserve its own rank-map
evidence.

#### E. Minimal pre-submit validation

Reuse accepted Phase-0 through TASK-004 evidence.

Before submission, perform only lightweight checks needed to catch mistakes:

- syntax-check new/modified PBS/shell script;
- verify fixed `N=429056`, `NB=3072`;
- verify candidate set is exactly `4×4`, `2×8`, `8×2`;
- verify each grid multiplies to 16 ranks;
- verify `nporder=row` for all candidates;
- verify fixed controls from Section 1.4B;
- verify TASK-004 launcher/container contract is reused;
- verify 2 nodes × 8 GPUs, 16 ranks, one rank/GPU;
- verify project `hpc_ebslee`;
- verify queue is `gpu_as` or `gpu_ded`;
- perform a lightweight live queue/node eligibility check.

Do not repeat comprehensive topology/software/GDR/NCCL/UCX characterization
unless a concrete execution contradiction appears.

#### F. Per-candidate evidence

For each row-order candidate preserve, when emitted:

- attempt ID;
- PBS job ID;
- queue and allocated nodes;
- N, NB, nprow, npcol, nporder;
- fixed scientific controls;
- exit status;
- correctness verdict;
- finite normalized residual;
- overall HPL-MxP GFLOP/s;
- LU time and LU GFLOP/s;
- iterative-refinement time;
- iterative-refinement iteration count;
- host/device memory consumption and headroom;
- ordinary per-rank timing/imbalance markers if emitted;
- stdout/stderr.

Also preserve the rank-map evidence from Section 1.4C.

Normal HPL-MxP output is sufficient. No Nsight profiling, hardware counters,
or extra tracing is required.

#### G. Result logging

Append factual rows to:

```text
results/metrics.csv
results/RESULTS.md
```

Update the experiment README with:

- factual execution provenance;
- candidate order;
- rank-map evidence location;
- raw per-grid result table.

Codex must not:

- select a winning grid/order pair;
- compare/rank TASK-004 and TASK-005 strategically;
- prune shapes;
- update strategic conclusions in `planning/2x8-GAAS.md`;
- start a repeat/refinement experiment;
- start Phase 2B;
- perform campaign-level interpretation.

The Strategic Analyst will analyze TASK-004 and TASK-005 **together** after
TASK-005 execution is verified.

### 1.5 Relevant Inputs and References

Primary repository:

`QuangPham2404/HPL-MxP-Agent-Test`

Primary references:

- `tasks/TASK-004.md`
- `experiments/2x8-GAAS/phase2a-grid-shape/README.md`
- `experiments/2x8-GAAS/phase2a-grid-shape/scripts/run_phase2a_grid_shape.pbs`
- `experiments/2x8-GAAS/phase2a-grid-shape/outputs/`
- `planning/analysis/2x8-gaas-phase1b-nb-screen.md`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `multi-node-test/GAAS_MULTINODE_SETUP.md`
- `workflow/07-Workflow.md`
- `workflow/08-Workflow-Multinode-Tuning.md`
- active root `AGENTS.md` and `APPLICATION.md`
- `results/metrics.csv`

Historical grid/order results may be read as qualitative context only. Their
numerical winners must not be transferred.

No OpenMxP access is required or authorized.

### 1.6 Execution Scope

#### Allowed

Codex may:

- create `experiments/2x8-GAAS/phase2a-grid-row/`;
- reuse/adapt the TASK-004 sweep script and validated launcher;
- execute exactly the three approved grid shapes with `nporder=row`;
- run all three sequentially in one equivalent 2×8 allocation when practical;
- split them across equivalent 2×8 allocations when operationally necessary;
- choose `gpu_as` or `gpu_ded` based on live eligibility;
- use scheduler-selected eligible nodes or host-pin an eligible pair;
- run the lightweight rank-map probe;
- perform lightweight syntax/configuration checks;
- submit and boundedly monitor approved jobs;
- preserve all attempt-specific evidence;
- recover from clearly non-scientific Track-1 worktree/scheduler/output/
  transfer/submission failures;
- retry an interrupted candidate/allocation with a new attempt tag when no
  meaningful scientific result was produced;
- continue after an isolated candidate scientific failure when the other
  approved candidates remain safe under unchanged controls;
- update experiment/results/task/progress bookkeeping;
- commit/push execution artifacts.

Scheduler-only changes such as attempt tags, output paths, eligible host
pinning, or sufficient walltime are permitted without new approval as long as
scientific controls and the 2×8 resource shape do not change.

#### Prohibited

Codex and workers must not:

- use any queue other than `gpu_as` or `gpu_ded`;
- use another accounting project;
- change the 2-node × 8-GPU resource shape;
- change N or NB;
- add/remove/replace the three approved shapes;
- run any `nporder=column` scored candidate;
- run `1×16` or `16×1`;
- tune or permute GPU affinity;
- begin Phase 2B;
- tune fill-device buffer/Anq-device;
- tune OpenMP, CPU/memory affinity, DGEMV, communication, U-panel chunking,
  precision, GEMM kernel, host registration, or scheduling controls;
- perform a grid×order×affinity expansion beyond the six total TASK-004/005
  combinations;
- rerun the immutable original baseline;
- perform N/NB resweeps;
- require extra statistical repeats;
- perform profiling or comprehensive reprobes without a concrete reason;
- access or depend on OpenMxP;
- perform strategic joint analysis or select retained grid/order pairs.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and active Workflow v2.
2. Substantive execution remains delegated through the approved OpenCode worker
   workflow.
3. Use PBS compute-node execution only.
4. Preserve:

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

6. Only queues:

   ```text
   gpu_as
   gpu_ded
   ```

   are authorized.

7. `free` alone does not establish queue eligibility; verify live Qlist/queue
   eligibility before host-pinning.

8. Preserve the validated TASK-004 container-MPI / `pbsdsh` launcher.

9. Preserve fixed N, NB, row order, affinity, and all Section 1.4B controls.

10. One valid scored attempt per approved shape is sufficient.

11. Preserve unique evidence names; do not overwrite prior evidence.

12. A genuine OOM/correctness/runtime failure must be preserved as evidence
    rather than silently converted into a different scientific configuration.

13. An isolated candidate failure does not automatically stop the remaining
    approved shapes when they remain safe.

14. Track-1 operational recovery is permitted without human intervention when
    it remains inside this approved scope.

### 1.8 Success Criteria

TASK-005 is operationally complete when:

- the dedicated row-order experiment exists;
- `4×4 row`, `2×8 row`, and `8×2 row` have each been attempted, except
  where a documented systemic blocker prevents further execution;
- N=429056 and NB=3072 remain fixed;
- `nporder=row` is fixed for all scored attempts;
- only nprow/npcol vary;
- rank-map evidence proves global/local rank-to-node mapping for the allocation;
- the 2×8 / 16-rank resource mapping is preserved;
- only approved queues/project are used;
- every valid scored point has normal benchmark output, finite residual, and
  `PASSED`;
- overall/LU/IR/memory evidence is preserved;
- raw stdout/stderr/status and rank-map evidence are preserved;
- factual rows are appended to project results;
- the Execution Report remains factual and contains no grid/order selection;
- task/progress/results artifacts are committed/pushed;
- task handoff is:

  ```text
  status: EXECUTED
  current_owner: strategic-analyst
  ```

No strategic interpretation, TASK-004/TASK-005 combined ranking, repeat study,
affinity tuning, or Phase-2B execution is required.

### 1.9 Stop / Escalation Conditions

Stop and return for Strategic Analyst / Human direction only when:

- launcher/container behavior materially changes and accepted evidence cannot
  reasonably be reused;
- rank/GPU mapping is materially wrong and Track-1 recovery cannot restore it;
- the rank-map probe reveals unexpected placement that makes the comparison
  scientifically ambiguous and cannot be resolved without scientific-control
  changes;
- execution requires changing N, NB, order, affinity, or another scientific
  control;
- execution requires a grid outside the approved three;
- execution requires another resource shape, queue, or accounting project;
- multiple shapes exhibit a common correctness/runtime failure suggesting a
  systemic platform/scientific issue;
- a necessary diagnostic exceeds Section 1.11 authorization.

Do **not** escalate merely because:

- a preferred node pair is unavailable;
- one approved queue lacks an eligible pair;
- the other approved queue must be used;
- a normal Track-1 worktree/scheduler/output/transfer problem occurs;
- shapes must be split across equivalent allocations;
- one shape is valid but slower;
- one isolated shape fails while the remaining approved shapes remain safe.

### 1.10 Strategic Analyst Notes

TASK-005 is the **row-order complement** to TASK-004.

No Phase-2A conclusion should be drawn from TASK-005 in isolation.

After TASK-005 is verified, the Strategic Analyst should analyze the complete:

```text
              column        row
2x8           TASK-004      TASK-005
4x4           TASK-004      TASK-005
8x2           TASK-004      TASK-005
```

using:

```text
overall GFLOP/s
LU time / LU GFLOP/s
IR time / IR-LU
IR iterations
correctness / residual
host/device headroom
rank-map evidence
logical row/column node-crossing pattern
within-shape row-vs-column delta
within-order shape delta
shape×order interaction
cross-allocation control drift where relevant
```

The joint analysis should then decide:

1. which grid/order pair(s) remain credible;
2. whether a repeat/refinement is required before closing Phase 2A;
3. the dependency checkpoint triggered by the retained grid/order;
4. whether to proceed to Phase 2B GPU affinity / physical placement.

### 1.11 Authorization

status: APPROVED

approved_scope: Execute TASK-005 as the row-order complement to TASK-004 for the established 2x8 GAAS NVIDIA HPL-MxP topology. Fix N=429056, NB=3072, nporder=row, OMP_NUM_THREADS=8, identity GPU affinity, FP16, MPI panel broadcast=0, separate GEMM stream=1, TRSM/factorization priorities=0, --fill-device 1, --test-loop 1, --skip-tests 0, and --monitor-gpu 0, with all unspecified controls retaining the same package/default behavior as TASK-004. Vary only nprow/npcol across exactly {4x4,2x8,8x2}, preferably in that order to mirror TASK-004. Use the same validated execution logistics as TASK-004: preferably one 2-node x 8-H200 allocation, 16 ranks/one rank per GPU, place=scatter, no mpiprocs, validated container MPI plus pbsdsh bridge, shared de-duplicated slots=8 hostfile, attempt-tag-specific evidence, pre/post sweep health snapshots, project hpc_ebslee, and only queues gpu_as or gpu_ded. Before scored candidates, run one lightweight MPI rank-map probe using the same allocation/hostfile/launcher and preserve global_rank/local_rank/hostname evidence. Codex may choose between approved queues, select or host-pin eligible nodes, split approved shapes across equivalent 2x8 allocations when operationally necessary, make scheduler-only adjustments, and perform Track-1 recovery without new approval. Preserve correctness, overall/LU/IR, iteration, memory/headroom, job/node, rank-map, stdout/stderr evidence and update factual experiment/results/task/progress artifacts. One valid scored attempt per shape is sufficient. No column-order reruns, extra shapes, 1x16/16x1, N/NB changes, affinity permutations, buffer/residency/host-runtime/DGEMV/communication/chunk/precision/kernel/scheduling tuning, comprehensive reprobe, profiling, OpenMxP access, Phase-2B work, or strategic TASK-004/TASK-005 comparison is authorized. After TASK-005 is executed and verified, strategic analysis is to combine TASK-004 and TASK-005 as the complete 3x2 grid/order matrix.

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

*List failures and exceptions or state None. Record authorized Track-1 recovery and exact resume action if incomplete.*

### 2.9 Scope Compliance

*State whether work stayed within approved scope.*

### 2.10 Handoff to Strategic Analyst

*Give factual reading guidance only. Explicitly direct the Strategic Analyst to combine TASK-004 and TASK-005; do not perform the comparison here.*
