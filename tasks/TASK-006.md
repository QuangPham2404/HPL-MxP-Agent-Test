---
task_id: TASK-006
title: Phase 2A — 2x8 GAAS Grid/Order Confirmation
status: EXECUTED
current_owner: strategic-analyst
parent_task: TASK-005
analysis_id: 2x8-gaas-phase2a-grid-order-confirm
created: 2026-09-27
last_updated: 2026-09-27
---

# TASK-006 — Phase 2A: 2×8 GAAS Grid/Order Confirmation

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.11. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Run one bounded **same-allocation Phase-2A confirmation** for the two surviving
process-grid shapes and their row/column order controls on the established
2 GAAS nodes × 8 H200 GPUs/node NVIDIA HPL-MxP topology.

TASK-004 and TASK-005 established the following leading region:

```text
4x4 row    = 5.6347e+06 GFLOP/s
8x2 column = 5.5487e+06 GFLOP/s
difference = 1.55%
```

That gap is smaller than the observed cross-allocation movement of the repeated
4×4-column control, so Phase 2A cannot close from TASK-004/005 alone.

TASK-006 therefore places the two leaders and their corresponding order
controls **inside one PBS allocation** so the Strategic Analyst can judge the
grid/order region with much stronger comparability.

This task produces evidence only. Codex must not select the final grid/order
pair or begin Phase 2B.

### 1.2 Context

Retained Phase-1 controls:

```text
N  = 429056
NB = 3072
fill-device = 1
```

TASK-004/TASK-005 joint analysis:

- 2×8 is dropped from serious contention;
- 4×4 row is the current numerical leader;
- 8×2 column is a co-leading serious candidate;
- 4×4 column is the established campaign/order control;
- 8×2 row is the corresponding within-shape order control;
- Phase 2A remains open.

The purpose of TASK-006 is **not** to expand the search. It is a confirmation
experiment only.

### 1.3 Strategic Question / Hypotheses

Primary question:

> When all four surviving grid/order arms are run sequentially inside the
> same 2×8 allocation, do 4×4 row and 8×2 column separate clearly enough to
> retain one pair, or do they remain a tied Phase-2A region?

Working hypotheses:

1. Cross-allocation drift was large enough that TASK-004/005 cannot distinguish
   the two leaders confidently.
2. A same-allocation four-arm confirmation will reduce the largest current
   comparability weakness.
3. 4×4 row may retain its apparent advantage by improving both LU and IR.
4. 8×2 column may remain competitive through its lower IR fraction.
5. If the two leaders remain within ordinary within-allocation/control movement,
   both should remain viable into Phase 2B rather than forcing a false winner.

### 1.4 Required Evidence / Deliverables

#### A. Exact candidate set

Run exactly these four scored configurations:

```text
1. 4x4 column
2. 4x4 row
3. 8x2 column
4. 8x2 row
```

Preferred execution order is exactly the order above.

Do not add:

- any 2×8 candidate;
- 1×16 or 16×1;
- additional grid shapes;
- extra repeat loops;
- adaptive candidates.

#### B. Fixed scientific controls

Use exactly:

```text
N = 429056
NB = 3072
OMP_NUM_THREADS=8

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

The only scored-candidate variables are:

```text
--nprow
--npcol
--nporder
```

with the exact four combinations in Section 1.4A.

Do not tune or change:

- N or NB;
- GPU affinity;
- fill-device buffer / Anq-device;
- U-panel chunking;
- DGEMV partitioning;
- CPU/memory affinity;
- OpenMP placement/binding beyond OMP_NUM_THREADS=8;
- MPI/NCCL broadcast policy;
- UCX/NIC controls;
- precision;
- GEMM kernel/preset;
- host-register step;
- factorization/TRSM/GEMM scheduling;
- any other downstream control.

All unspecified controls must retain the same installed package/default
behavior used in TASK-004 and TASK-005.

#### C. Same-allocation requirement

All four scored candidates must run **sequentially inside one PBS allocation**.

This is a scientific requirement of TASK-006, not merely a preferred
operational arrangement.

The allocation must preserve:

```text
2 nodes × 8 H200 GPUs
16 MPI ranks
one rank/GPU
place=scatter
no mpiprocs
shared de-duplicated hostfile with slots=8/node
validated NVIDIA container MPI + pbsdsh bridge
```

Do not split the four scored candidates across different allocations.

If the allocation terminates before all four scored candidates complete and
the missing candidates cannot be resumed within the same still-running
allocation, preserve the partial evidence and return BLOCKED/PARTIAL rather
than silently creating a cross-allocation comparison.

A new full-attempt family may be submitted under Track-1 recovery only when
the prior allocation produced **no scientifically meaningful scored result**.
If any scored result from the attempt is valid, do not combine a second
allocation with it as the TASK-006 confirmation matrix.

#### D. Rank-map evidence

Before the first scored candidate, run one lightweight rank-map probe with the
same launcher/hostfile used for the scored runs.

Preserve:

```text
global_rank
local_rank
hostname
```

for all 16 ranks when available.

Expected mapping is the already-validated contiguous pattern, but it must be
measured rather than assumed.

The later Strategic Analyst must be able to reconstruct which logical process
rows/columns cross the node boundary for each of the four configurations.

#### E. Experiment area and execution logistics

Create a dedicated experiment area, preferably:

```text
experiments/2x8-GAAS/phase2a-grid-order-confirm/
```

with:

```text
README.md
scripts/
outputs/
```

Reuse/adapt the validated TASK-004/TASK-005 launcher and sweep structure.

Execution logistics:

- exactly one 2×8 allocation for the four scored points;
- candidate order from Section 1.4A;
- one rank-map probe before the scored sweep;
- one pre/post hardware-health snapshot around the whole sweep;
- unique attempt-tag evidence naming;
- per-candidate stdout/stderr/status;
- no overwrite of previous evidence;
- no concurrent multinode submissions.

Codex may choose `gpu_as` or `gpu_ded` based on live eligibility and may
host-pin any eligible pair that satisfies the approved topology.

#### F. Minimal pre-submit validation

Perform only lightweight checks necessary to protect the experiment:

- syntax-check new/modified PBS/shell script;
- verify fixed N=429056 and NB=3072;
- verify the candidate set is exactly:
  `4x4-column, 4x4-row, 8x2-column, 8x2-row`;
- verify each P×Q product is 16;
- verify all Section 1.4B controls are fixed;
- verify the four candidates are configured to run in one allocation;
- verify 2 nodes × 8 GPUs, 16 ranks, one rank/GPU;
- verify project `hpc_ebslee`;
- verify queue is `gpu_as` or `gpu_ded`;
- perform a lightweight live queue/node eligibility check;
- verify the TASK-004/TASK-005 launcher contract is reused.

Do not repeat accepted Phase-0/GDR/NCCL/UCX/topology characterization unless a
concrete contradiction appears.

#### G. Per-candidate evidence

For each of the four configurations preserve, when emitted:

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
- IR time;
- IR iteration count;
- IR/LU;
- host/device memory consumption and headroom;
- ordinary per-rank timing/imbalance markers if emitted;
- stdout/stderr.

Preserve allocation-level rank-map and scheduler evidence.

Normal HPL-MxP output is sufficient. No profiling or tracing is required.

#### H. Result logging

Append factual rows to:

```text
results/metrics.csv
results/RESULTS.md
```

Update the experiment README with:

- execution provenance;
- single-allocation proof;
- candidate order;
- rank-map evidence path;
- factual four-arm result table;
- raw evidence paths.

Codex must not:

- declare the final retained grid/order pair;
- classify the top two as tied or separated;
- update strategic conclusions in `planning/2x8-GAAS.md`;
- reopen N;
- start Phase 2B;
- tune affinity/communication/chunk/scheduling;
- perform campaign-level interpretation.

Those decisions require explicit `ANALYSE_RESULTS` after TASK-006 is verified.

### 1.5 Relevant Inputs and References

Primary repository:

`QuangPham2404/HPL-MxP-Agent-Test`

Primary references:

- `planning/analysis/2x8-gaas-phase2a-grid-order-matrix.md`
- `planning/2x8-GAAS.md`
- `tasks/TASK-004.md`
- `tasks/TASK-005.md`
- `experiments/2x8-GAAS/phase2a-grid-shape/`
- `experiments/2x8-GAAS/phase2a-grid-row/`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `multi-node-test/GAAS_MULTINODE_SETUP.md`
- `workflow/07-Workflow.md`
- `workflow/08-Workflow-Multinode-Tuning.md`
- root `AGENTS.md` and `APPLICATION.md`
- `results/metrics.csv`

Historical single-node and old 2×8 grid/order results remain qualitative prior
knowledge only and must not determine the TASK-006 outcome.

No OpenMxP access is required or authorized.

### 1.6 Execution Scope

#### Allowed

Codex may:

- create `experiments/2x8-GAAS/phase2a-grid-order-confirm/`;
- reuse/adapt TASK-004/TASK-005 scripts and launcher;
- execute exactly the four approved grid/order combinations;
- run all four sequentially in one approved 2×8 allocation;
- choose `gpu_as` or `gpu_ded` based on live eligibility;
- use scheduler-selected eligible nodes or host-pin an eligible pair;
- run the lightweight rank-map probe;
- perform lightweight validation;
- submit and boundedly monitor the approved allocation;
- preserve all attempt-specific evidence;
- perform Track-1 recovery for worktree/scheduler/output/transfer/submission
  mechanics when scientific controls remain unchanged;
- retry a whole attempt family only when the failed attempt produced no
  meaningful scored result;
- continue remaining candidates after an isolated scientifically meaningful
  candidate failure if the same allocation is still healthy and the remaining
  approved candidates are safe to run;
- update experiment/results/task/progress bookkeeping;
- commit/push execution artifacts.

Scheduler-only changes such as attempt tags, output paths, eligible host pinning,
or sufficient walltime are allowed if the one-allocation requirement and all
scientific controls remain unchanged.

#### Prohibited

Codex and workers must not:

- use any queue other than `gpu_as` or `gpu_ded`;
- use another accounting project;
- change the 2-node × 8-GPU resource shape;
- split the four scored candidates across allocations;
- change N or NB;
- add or remove any scored candidate;
- reintroduce 2×8;
- run 1×16 or 16×1;
- tune or permute GPU affinity;
- change fill-device/buffer/Anq-device;
- tune OpenMP, CPU/memory affinity, DGEMV, communication, U-panel chunking,
  precision, GEMM kernel, host registration, or scheduling controls;
- rerun the immutable original baseline;
- perform N/NB resweeps;
- add extra statistical repeats inside TASK-006;
- perform profiling/tracing without a concrete execution contradiction;
- access OpenMxP;
- start Phase 2B;
- perform strategic retention/tie/noise analysis.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and active Workflow v2.
2. Substantive execution remains delegated through the approved OpenCode worker
   workflow.
3. Use PBS compute-node execution only.
4. Resource shape:

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

7. `free` does not prove queue eligibility; verify live Qlist/queue
   eligibility before host-pinning.

8. Preserve the validated container-MPI / `pbsdsh` launcher contract.

9. Preserve all fixed controls from Section 1.4B.

10. All four scored candidates must share one allocation/job ID.

11. One valid scored attempt per configuration is sufficient.

12. Preserve unique evidence names; never overwrite prior evidence.

13. A genuine candidate OOM/correctness/runtime failure is scientific evidence
    and must be preserved.

14. Do not rerun a valid candidate simply because its score is slower or
    unexpected.

15. Track-1 recovery remains permitted only when it does not compromise the
    same-allocation scientific purpose.

### 1.8 Success Criteria

TASK-006 is operationally complete when:

- the dedicated confirmation experiment exists;
- all four approved configurations have been attempted inside one PBS
  allocation, except where a documented systemic blocker prevents completion;
- all four share the same job ID and node pair;
- N=429056 and NB=3072 remain fixed;
- only P×Q/order vary according to the exact candidate set;
- rank-map evidence proves the 16-rank / 8-ranks-per-node placement;
- only approved queue/project/resource shape are used;
- every valid scored point has normal HPL-MxP output, finite residual, and
  `PASSED`;
- overall/LU/IR/memory evidence is preserved;
- raw stdout/stderr/status, PBS, and rank-map evidence are preserved;
- factual rows are appended to project results;
- the execution report remains factual and does not choose the retained pair;
- artifacts are committed/pushed;
- task handoff becomes:

  ```text
  status: EXECUTED
  current_owner: strategic-analyst
  ```

No Phase-2A closure, N reopening, Phase-2B execution, or downstream tuning is
part of TASK-006.

### 1.9 Stop / Escalation Conditions

Stop and return for Strategic Analyst / Human direction when:

- all four candidates cannot be kept in one scientifically comparable
  allocation;
- launcher/container behavior materially changes and accepted evidence cannot
  be reused;
- rank/GPU mapping is wrong and Track-1 recovery cannot restore it;
- execution requires changing N, NB, candidate set, affinity, or another
  scientific control;
- another resource shape, queue, or accounting project is required;
- multiple candidates exhibit a common correctness/runtime failure suggesting a
  systemic scientific/platform issue;
- a necessary diagnostic exceeds Section 1.11 authorization.

Do not escalate merely because:

- the preferred node pair is unavailable;
- `gpu_as` versus `gpu_ded` changes within the approved set before
  submission;
- an eligible alternative node pair must be used;
- ordinary worktree/output/transfer/submission mechanics require Track-1
  recovery;
- one candidate is slower;
- one isolated candidate fails scientifically while the same allocation
  remains healthy for the remaining candidates.

### 1.10 Strategic Analyst Notes

After TASK-006 is verified, analyze TASK-006 together with the TASK-004/005
history, but give primary causal weight to the **within-allocation TASK-006
comparison**.

Compare:

```text
4x4 column
4x4 row
8x2 column
8x2 row
```

using:

```text
overall GFLOP/s
LU time/rate
IR time / IR-LU
correctness
memory/headroom
rank map
within-shape order delta
between-leader delta
TASK-004/005 repeat movement
4x4-column historical control movement
```

Decision rule for the later Strategic Analyst:

- if one grid/order pair separates repeatably beyond the observed
  within-allocation/control movement, retain it;
- if `4×4 row` and `8×2 column` remain effectively tied, retain both as the
  Phase-2A region and carry both into Phase 2B;
- do not revive 2×8 absent contradictory new evidence.

After that decision, perform the normal dependency checkpoint before any
Phase-2B execution.

### 1.11 Authorization

status: APPROVED

approved_scope: Execute TASK-006 as one same-allocation Phase-2A confirmation on the established 2x8 GAAS NVIDIA HPL-MxP topology. Run exactly four scored configurations in one PBS allocation and in this preferred order: 4x4 column, 4x4 row, 8x2 column, 8x2 row. Fix N=429056, NB=3072, OMP_NUM_THREADS=8, identity GPU affinity 0:1:2:3:4:5:6:7, FP16, MPI panel broadcast=0, separate GEMM stream=1, TRSM/factorization priorities=0, --fill-device 1, --test-loop 1, --skip-tests 0, and --monitor-gpu 0, with all unspecified controls retaining the same package/default behavior as TASK-004/TASK-005. The only scored variables are nprow, npcol, and nporder according to the exact four approved combinations. Use one 2-node x 8-H200 allocation, 16 ranks/one rank per GPU, place=scatter, no mpiprocs, validated container MPI plus pbsdsh bridge, shared de-duplicated slots=8 hostfile, one pre-sweep rank-map probe, pre/post sweep health snapshots, unique attempt-tag evidence, project hpc_ebslee, and only gpu_as or gpu_ded. The four scored candidates must share the same job ID/allocation; do not split them across jobs. Codex may choose between approved queues, select or host-pin an eligible node pair, make scheduler-only adjustments, and perform Track-1 recovery when the same-allocation scientific purpose is preserved. A whole-attempt retry is allowed only if the failed attempt produced no meaningful scored result. Preserve correctness, overall/LU/IR, iteration, memory/headroom, job/node, rank-map, stdout/stderr/PBS evidence and update factual experiment/results/task/progress artifacts. One valid scored attempt per configuration is sufficient. No 2x8 candidates, 1x16/16x1, N/NB changes, affinity permutations, buffer/residency/host-runtime/DGEMV/communication/chunk/precision/kernel/scheduling tuning, baseline rerun, extra statistical repeats, profiling, OpenMxP access, Phase-2B execution, N reopening, or strategic retention/tie analysis is authorized. After execution and verification, strategic analysis will decide whether one grid/order pair separates or whether 4x4 row and 8x2 column remain tied into Phase 2B.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

<!-- Codex completes this section after execution; do not rewrite section 1. -->

### 2.1 Execution Status

status: COMPLETE

### 2.2 Orchestration Summary

One OpenCode worker handled experiment preparation, remote execution, evidence
retrieval, and factual result logging. Codex verified the approved task and
scope, reviewed the preparation and execution tree, checked the returned PBS
and application evidence, and completed this report. Work was sequential:
prepare and validate; commit/push; synchronize an isolated remote worktree;
check live queue eligibility; submit and boundedly monitor one allocation;
retrieve and validate evidence; update factual records. No follow-up job was
needed.

### 2.3 Work Executed

Created `experiments/2x8-GAAS/phase2a-grid-order-confirm/` with a README, one
PBS sweep script, and outputs directory. The script ran the four approved
grid/order candidates sequentially in order: 4x4 column, 4x4 row, 8x2 column,
8x2 row. Fixed N=429056, NB=3072, OMP_NUM_THREADS=8, identity GPU affinity,
FP16, the approved broadcast/stream/priority/fill/test controls, and the
validated container MPI plus `pbsdsh` bridge.

Submitted one host-pinned PBS allocation, job `72845.gaas`, to `gpu_as` under
`hpc_ebslee` on `hpc-gaas-g12` and `hpc-gaas-g15`. Retrieved the four
candidate `.out`/`.err`/`.status` triplets, rank-map log, and PBS `.o`/`.e`.
Added four factual rows to `results/metrics.csv` and regenerated
`results/RESULTS.md`.

### 2.4 Operational Validation

The preparation PBS script passed `bash -n`; mechanical checks confirmed the
exact candidate list/order, P×Q=16 for each candidate, fixed N/NB and controls,
and absence of a candidate-splitting option. `git diff --check` passed for the
reviewed preparation and result files.

The remote primary checkout was dirty at `87fb61e829832a3bc07c2579d8472aa1be279f13`
with 168 status entries. It was left untouched. The clean detached execution
worktree `.codex-worktrees/TASK-006-2192153-phase2a-v1` was verified at
preparation commit `2192153b9841d0db9b11c68e45eeecbf210cf228`, with clean
status, `EXECUTING / codex`, and unchanged Section 1.11 authorization.

Live PBS eligibility showed g12+g15 fully free and eligible for `gpu_as`
(`Qlist=gpu_as,gpu_ppu`); `gpu_ded` had no fully free eligible pair. No
concurrent user job was present at submission. The terminal job record showed
`job_state=F`, `Exit_status=0`, `run_count=1`, walltime `00:04:29`, 16 GPUs,
`place=scatter`, and project `hpc_ebslee`. All four candidate status files
record the same job ID and node pair and the approved sequential order.

The rank-map probe recorded 16/16 ranks across two hosts, eight ranks per
host: ranks 0–7 on g12 and ranks 8–15 on g15. Pre/post hardware-health
snapshots are present in the PBS stdout. All four outputs have normal
benchmark markers, three solver iterations, finite normalized residuals,
`PASSED`, overall and LU performance, and memory/headroom lines. All 15
retrieved files matched the remote worktree by SHA-256. The four result keys
are unique; `metrics.csv` contains 221 data rows with its existing 33-field
schema, and the generated report contains the four new records.

### 2.5 Evidence and Artifacts

Raw evidence and the factual four-arm table are in
`experiments/2x8-GAAS/phase2a-grid-order-confirm/`; structured records are in
`results/metrics.csv` and `results/RESULTS.md`. The remote execution tree was
`.codex-worktrees/TASK-006-2192153-phase2a-v1` at
`2192153b9841d0db9b11c68e45eeecbf210cf228`. Preparation commit:
`2192153b9841d0db9b11c68e45eeecbf210cf228`. Evidence/results commit:
`853117bfd4901e258f50e7c1731306ece693b0ac`. Both were pushed to
`origin/main`.

### 2.6 Files Changed

Added the experiment README, PBS script, outputs placeholder, and 15
attempt-specific evidence files; appended four rows to `results/metrics.csv`;
regenerated `results/RESULTS.md`; completed this Execution Report and added
`progress/2026-09-27-progress_s14.md`. Section 1, strategic planning, and the
pre-existing untracked `hpl-mxp-runs-on-gaas/` directory were not changed.

### 2.7 Missing / Unavailable Evidence

No required run evidence is missing. The terminal `qstat -x -f` record was
read and its key fields recorded in the experiment README and this report,
but was not retained as a separate raw file. PBS `.o`/`.e`, all candidate
outputs/status files, and the rank-map log are preserved. GPU-monitor output
is unavailable by design with `--monitor-gpu 0`.

### 2.8 Execution Errors / Exceptions

No job or candidate failed; no retry or Track-1 patch was needed. The PBS
stderr preserves the recurring `cuda/13.1` module note and
`unknown groupid 1304617061` warnings. The terminal record also reported
`Stageout_status=1`; all expected outputs were present locally and matched
their remote copies. These observations were recorded without patching.

### 2.9 Scope Compliance

Work stayed within the approved TASK-006 scope. Exactly four approved
configurations ran in one allocation with the approved controls, topology,
queue, accounting project, launcher, and evidence requirements. No strategic
retention/tie conclusion, baseline promotion, planning update, Phase 2B work,
or unapproved access/action occurred. Section 1 and its approved scope remain
unchanged.

### 2.10 Handoff to Strategic Analyst

Read the four candidate `.out` files and `.status` files alongside the shared
rank-map and PBS `.o`/`.e` evidence in the experiment directory. All four
reported finite residuals and `PASSED`; their factual output markers and
timings are summarized in the README. The terminal PBS fields are transcribed
there, with the raw PBS stdout/stderr retained. No candidate retention,
tie/noise assessment, percentage comparison, dependency-checkpoint outcome,
or next action is recorded here. Await explicit `ANALYSE_RESULTS` authority
before strategic analysis.
