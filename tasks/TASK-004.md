---
task_id: TASK-004
title: Phase 2A — 2x8 GAAS Process-Grid Shape Screen
status: APPROVED
current_owner: codex
parent_task: TASK-003
analysis_id: 2x8-gaas-phase2a-grid-shape
created: 2026-09-27
last_updated: 2026-09-27
---

# TASK-004 — Phase 2A: 2×8 GAAS Process-Grid Shape Screen

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.11. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Execute the first **Phase-2A process-grid shape screen** for the established
**2 GAAS nodes × 8 H200 GPUs/node** NVIDIA HPL-MxP campaign.

Phase 1 is closed with the retained representative geometry:

```text
N  = 429056
NB = 3072
fill-device = 1
```

The current `4×4 column` grid is only a provisional control. TASK-004 varies
**only the process-grid shape** while holding rank order and all other scientific
controls fixed.

The purpose is to determine whether a different 16-rank decomposition changes:

- end-to-end HPL-MxP performance;
- LU efficiency;
- iterative-refinement cost;
- memory ownership/headroom;
- rank symmetry; and
- the inter-node structure of logical process rows/columns.

This task does **not** compare row versus column order, tune GPU affinity, tune
communication, change N/NB, or start any downstream host/runtime/scheduling
work.

One valid scored attempt per approved grid shape is sufficient.

### 1.2 Context

TASK-003 closed Phase 1 with:

```text
N = 429056
NB = 3072
4x4 column = provisional grid control
overall = 5.5381e+06 GFLOP/s in TASK-003
overall = 5.6091e+06 GFLOP/s in TASK-002
```

The retained NB region is `2048–3072`, with `NB=3072` carried forward as
the representative control.

The dependency graph marks grid/order as open because:

- E09: N materially changed the useful geometry/residency regime;
- E10: NB and process grid jointly affect block ownership, panel count,
  communication, and local update geometry;
- E12: grid shape changes panel communicator sizes/fan-out;
- E24: grid/NB jointly affect U-panel chunk validity/usefulness;
- E29 and placement-related edges become relevant once a grid candidate is
  retained.

The blueprint requires **shape screening first**, with one fixed explicit order
and mapping, before row/column order comparison.

### 1.3 Strategic Question / Hypotheses

Primary question:

> At fixed N=429056, NB=3072, column order, and identity GPU affinity, which
> non-extreme 16-rank process-grid shapes provide the strongest valid
> end-to-end behavior on the 2×8 GAAS topology?

Working hypotheses:

1. `2×8`, `4×4`, and `8×2` create materially different panel/update
   communicator shapes while keeping rank count constant.
2. With 8 ranks per node and fixed column order, these grids map logical
   process rows/columns differently across the two-node boundary; this may
   materially affect panel traffic and synchronization.
3. A more balanced-looking grid is not assumed to win; the correct result is
   whatever gives the best combined LU+IR path with valid correctness.
4. Grid shape may also change worst-rank local matrix ownership and memory
   headroom even at fixed N/NB.
5. Skinny extremes (`1×16`, `16×1`) are diagnostic rather than mandatory
   and are intentionally excluded from this first bounded screen.
6. Numerical winners from prior single-node or old 2×8 experiments are prior
   hypotheses only and must not be transferred.

TASK-004 produces evidence only. Shape retention and any later row-vs-column
order comparison require explicit `ANALYSE_RESULTS`.

### 1.4 Required Evidence / Deliverables

#### A. Fixed process-grid candidate set

Run exactly these three shapes:

```text
2 × 8
4 × 4
8 × 2
```

with:

```text
--nporder column
```

for all three.

Roles:

- `4×4 column`: same-protocol retained Phase-1 control;
- `2×8 column`: wider process-column count / smaller process-row count;
- `8×2 column`: larger process-row count / narrower process-column count.

Do not add `1×16`, `16×1`, row-order variants, adaptive shapes, or any other
grid candidate inside TASK-004.

Preferred candidate order:

```text
4x4 column
2x8 column
8x2 column
```

so the same-protocol control runs first.

#### B. Fixed scientific controls

Vary only:

```text
--nprow
--npcol
```

Use exactly:

```text
N = 429056
NB = 3072
OMP_NUM_THREADS=8

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

Only `nprow × npcol` changes between scored candidates.

Do not explicitly change or tune:

- N or NB;
- row/column order;
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

All unspecified controls must retain the same installed package/default
behavior used in TASK-003.

#### C. Rank-map evidence

Before the first scored candidate in each allocation, record one lightweight
MPI mapping probe using the same:

- 16 ranks;
- shared de-duplicated `slots=8` hostfile;
- container MPI;
- `pbsdsh` bridge;
- launcher daemon flags.

The probe must emit, for all 16 ranks when available:

```text
global_rank
local_rank
hostname
```

or an equivalent unambiguous mapping.

This probe is diagnostic only and must not alter scientific controls.

Preserve the rank-map output as raw evidence. The later Strategic Analyst must
be able to reconstruct which logical grid rows/columns cross the node boundary
for each candidate under `nporder=column`.

Do not add topology profiling or communication tracing.

#### D. Execution logistics

Create a dedicated experiment area, preferably:

```text
experiments/2x8-GAAS/phase2a-grid-shape/
```

with:

```text
README.md
scripts/
outputs/
```

Reuse/adapt the TASK-003 sequential-sweep pattern and the same validated
multinode launcher contract.

Preferred execution:

- one PBS allocation;
- 2 nodes × 8 H200 GPUs;
- 16 MPI ranks;
- one rank/GPU;
- all three shapes sequentially inside one allocation;
- shared de-duplicated hostfile with `slots=8` per node;
- validated NVIDIA container MPI + `pbsdsh` bridge;
- `place=scatter`;
- no `mpiprocs`;
- same module/container stack as TASK-003;
- one rank-map probe before the scored sweep;
- one pre/post hardware-health snapshot around the whole sweep;
- per-candidate stdout/stderr/status evidence;
- unique `ATTEMPT_TAG` evidence naming;
- never overwrite previous evidence;
- no concurrent multinode submissions.

If one allocation is operationally impractical, Codex may split approved
shapes across equivalent 2×8 allocations without additional approval, but each
allocation must preserve the exact scientific controls and include its own
rank-map evidence.

#### E. Minimal pre-submit validation

Reuse accepted Phase-0 through TASK-003 evidence.

Before submission, perform only lightweight checks sufficient to catch
mistakes:

- syntax-check new/modified PBS/shell script;
- verify fixed `N=429056`, `NB=3072`;
- verify candidate set is exactly `2×8`, `4×4`, `8×2`;
- verify all shapes multiply to 16 ranks;
- verify `nporder=column` for every candidate;
- verify fixed controls from Section 1.4B;
- verify validated TASK-003 container/launcher contract;
- verify 2 nodes × 8 GPUs, 16 ranks, one rank/GPU;
- verify project `hpc_ebslee`;
- verify queue is `gpu_as` or `gpu_ded`;
- perform lightweight live queue/node eligibility check.

Do not redo comprehensive topology/software/GDR/NCCL/UCX characterization
unless execution reveals a concrete contradiction.

#### F. Per-candidate evidence

For every grid shape preserve, when emitted:

- attempt ID;
- PBS job ID;
- queue and nodes;
- N, NB, nprow, npcol, nporder;
- fixed scientific controls;
- exit status;
- correctness verdict;
- finite normalized residual;
- overall HPL-MxP GFLOP/s;
- LU time / LU GFLOP/s;
- iterative-refinement time;
- iterative-refinement iteration count;
- host/device memory consumption and headroom;
- any ordinary per-rank timing/imbalance markers present in benchmark output;
- stdout/stderr.

Also preserve the allocation-level rank-map probe from Section 1.4C.

Normal HPL-MxP output is sufficient scientific evidence. No profiling,
hardware counters, or extra tracing is required.

#### G. Result logging

Append factual rows to:

```text
results/metrics.csv
results/RESULTS.md
```

Update the experiment README with factual provenance, candidate order, rank-map
evidence location, and raw result table.

Codex must not:

- rank/promote a final grid shape;
- decide which shapes proceed to row/column order comparison;
- launch row-order variants;
- change affinity;
- update strategic conclusions in `planning/2x8-GAAS.md`;
- begin Phase 2B;
- perform campaign-level interpretation.

Those actions require explicit `ANALYSE_RESULTS`.

### 1.5 Relevant Inputs and References

Primary repository:

`QuangPham2404/HPL-MxP-Agent-Test`

Primary references:

- `tasks/TASK-003.md`
- `planning/analysis/2x8-gaas-phase1b-nb-screen.md`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `experiments/2x8-GAAS/phase1b-nb-screen/README.md`
- `experiments/2x8-GAAS/phase1b-nb-screen/scripts/run_phase1b_nb_screen.pbs`
- `multi-node-test/GAAS_MULTINODE_SETUP.md`
- `workflow/07-Workflow.md`
- `workflow/08-Workflow-Multinode-Tuning.md`
- active root `AGENTS.md` and `APPLICATION.md`
- `results/metrics.csv`

Historical grid results under `experiments/2Nodes-8GPUs/` and single-node
grid analyses may be read as mechanism/context only. Their numerical winners
must not be transferred.

No OpenMxP access is required or authorized.

### 1.6 Execution Scope

#### Allowed

Codex may:

- create `experiments/2x8-GAAS/phase2a-grid-shape/`;
- reuse/adapt the TASK-003 sweep script and launcher;
- execute exactly the three approved grid shapes at fixed N/NB/order;
- run all three sequentially in one 2×8 allocation when practical;
- split them across equivalent 2×8 allocations only when operationally needed;
- choose `gpu_as` or `gpu_ded` based on live eligibility;
- use scheduler-selected eligible nodes or host-pin an eligible pair;
- run the lightweight allocation-level MPI rank-map probe;
- perform lightweight syntax/configuration checks;
- submit and boundedly monitor approved jobs;
- preserve all attempt-specific evidence;
- automatically handle Track-1 synchronization, scheduler, output-path,
  worktree, transfer, or submission failures;
- retry an interrupted candidate/allocation with a new attempt tag when no
  meaningful scientific result was produced;
- continue remaining shapes after an isolated scientifically meaningful
  candidate failure when safe and under unchanged controls;
- update experiment/results/task/progress bookkeeping;
- commit/push approved execution artifacts.

Reasonable scheduler-only changes such as attempt tags, output paths, eligible
host pinning, or sufficient walltime are allowed if scientific controls and
resource shape remain unchanged.

#### Prohibited

Codex and workers must not:

- use any queue other than `gpu_as` or `gpu_ded`;
- use another accounting project;
- change the 2-node × 8-GPU resource shape;
- change N or NB;
- add/remove/replace the approved grid shapes;
- run `1×16` or `16×1`;
- run any `nporder=row` candidate;
- tune or permute GPU affinity;
- start Phase 2B;
- change fill-device buffer/Anq-device;
- tune OpenMP, CPU/memory affinity, DGEMV, communication, U-panel chunking,
  precision, GEMM kernel, host registration, or scheduling controls;
- perform a grid×order×affinity Cartesian sweep;
- rerun the immutable original baseline;
- perform a targeted N/NB resweep;
- repeat comprehensive accepted characterization without concrete reason;
- require extra statistical repeats;
- access or depend on OpenMxP;
- perform strategic analysis or select retained shapes.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and active Workflow v2.
2. Substantive execution remains delegated through the approved OpenCode worker
   workflow.
3. Use PBS compute-node execution only.
4. Resource shape remains:

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

6. Only:

   ```text
   gpu_as
   gpu_ded
   ```

   are authorized queues.

7. `free` node state alone does not prove queue eligibility; verify live
   queue eligibility before host-pinning.

8. Preserve the validated TASK-003 container-MPI / `pbsdsh` launcher.

9. Preserve fixed N, NB, column order, GPU affinity, and all Section 1.4B
   controls.

10. One valid scored attempt per grid shape is sufficient.

11. Preserve unique evidence names and never overwrite prior outputs.

12. A genuine candidate OOM/correctness/runtime failure must be preserved as
    scientific evidence, not silently converted into a different grid/control.

13. An isolated candidate failure does not automatically stop the remaining
    shapes if they remain safe to run under unchanged controls.

14. Track-1 operational recovery is permitted without human intervention when
    it stays within approved scope.

### 1.8 Success Criteria

TASK-004 is operationally complete when:

- the dedicated Phase-2A grid-shape experiment exists;
- the three approved shapes `2×8`, `4×4`, `8×2` have each been attempted,
  except where a documented systemic blocker prevents further execution;
- N=429056 and NB=3072 remain fixed;
- `nporder=column` remains fixed;
- only nprow/npcol vary;
- the rank-map probe proves the allocation's global/local rank-to-node mapping;
- 2×8 / 16-rank resource mapping is preserved;
- only approved queues/project are used;
- every valid scored point has normal benchmark output, finite residual, and
  `PASSED`;
- overall/LU/IR/memory evidence is preserved;
- raw stdout/stderr/status and rank-map evidence are preserved;
- factual rows are added to project results;
- the Execution Report records factual completion/scope compliance only;
- artifacts are committed/pushed;
- task handoff is:

  ```text
  status: EXECUTED
  current_owner: strategic-analyst
  ```

No row-order comparison, affinity tuning, profiling, baseline rerun, strategic
selection, or Phase-2B work is required.

### 1.9 Stop / Escalation Conditions

Stop and return for Strategic Analyst / Human direction only when:

- validated launcher/container behavior materially changed and accepted
  evidence cannot reasonably be reused;
- rank/GPU mapping is materially wrong and Track-1 recovery cannot restore it;
- the rank-map probe reveals unexpected launcher placement that makes the
  approved shape comparison scientifically ambiguous and cannot be resolved
  without changing launcher semantics;
- execution requires changing N, NB, order, affinity, or another scientific
  control;
- execution requires a grid outside the approved three;
- execution requires another resource shape, queue, or accounting project;
- multiple shapes exhibit a common correctness/runtime failure suggesting a
  systemic platform/scientific issue;
- a necessary diagnostic would exceed Section 1.11 authorization.

Do **not** escalate merely because:

- a preferred node pair is unavailable;
- one approved queue lacks an eligible pair;
- the other approved queue must be used;
- a normal worktree/scheduler/output/transfer issue occurs;
- shapes must be split across equivalent allocations;
- one shape is valid but slower;
- one isolated shape fails scientifically while remaining approved shapes are
  still safe to attempt.

### 1.10 Strategic Analyst Notes

TASK-004 is **Phase 2A shape screening only**.

Later analysis must compare:

```text
grid shape
overall GFLOP/s
LU time / LU GFLOP/s
IR time / IR-LU
IR iterations
correctness / residual
host/device headroom
per-rank timing or imbalance markers if emitted
global/local rank-to-node mapping
logical row/column node-crossing pattern under column order
same-protocol 4x4 column control
```

Expected workflow:

```text
TASK-004 execution
        ↓
ANALYSE_RESULTS
        ↓
retain useful grid shapes
        ↓
dependency checkpoint
        ↓
row vs column comparison only for retained shapes
        ↓
refine/repeat leading shape-order pairs
        ↓
then Phase 2B GPU-affinity / physical placement
```

Do not automatically launch row-order candidates after TASK-004.

### 1.11 Authorization

status: APPROVED

approved_scope: Execute TASK-004 as the bounded Phase-2A process-grid shape screen on the established 2x8 GAAS NVIDIA HPL-MxP topology. Fix N=429056, NB=3072, nporder=column, OMP_NUM_THREADS=8, identity GPU affinity, FP16, MPI panel broadcast=0, separate GEMM stream=1, TRSM/factorization priorities=0, --fill-device 1, --test-loop 1, --skip-tests 0, and --monitor-gpu 0, with all unspecified controls retaining the same package/default behavior as TASK-003. Vary only nprow/npcol across exactly {2x8,4x4,8x2}, preferably running 4x4 first as the same-protocol control, then 2x8 and 8x2. Use the same validated execution logistics as TASK-003: preferably one 2-node x 8-H200 allocation, 16 ranks/one rank per GPU, place=scatter, no mpiprocs, validated container MPI plus pbsdsh bridge, shared de-duplicated slots=8 hostfile, attempt-tag-specific evidence, pre/post sweep health snapshots, project hpc_ebslee, and only queues gpu_as or gpu_ded. Before scored candidates, run one lightweight MPI rank-map probe using the same allocation/hostfile/launcher to preserve global_rank/local_rank/hostname evidence sufficient to reconstruct node placement. Codex may choose between approved queues, select or host-pin eligible nodes, split approved shapes across equivalent 2x8 allocations when operationally necessary, make scheduler-only adjustments, and perform Track-1 recovery without new approval. Preserve correctness, overall/LU/IR, iteration, memory/headroom, job/node, rank-map, stdout/stderr evidence and update factual experiment/results/task/progress artifacts. One valid scored attempt per grid shape is sufficient. No 1x16/16x1 shapes, row-order variants, N/NB changes, affinity permutations, buffer/residency/host-runtime/DGEMV/communication/chunk/precision/kernel/scheduling tuning, grid×order×affinity Cartesian sweep, comprehensive reprobe, profiling, OpenMxP access, Phase-2B work, or strategic interpretation is authorized.

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
