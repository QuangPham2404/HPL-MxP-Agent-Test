---
task_id: TASK-010
title: Dependency Re-closure — N, NB, and Grid/Order after Host-Runtime Shift
status: APPROVED
current_owner: codex
parent_task: TASK-009
analysis_id: 2x8-gaas-task010-geometry-reclosure
created: 2026-09-28
last_updated: 2026-09-28
---

# TASK-010 — Dependency Re-closure: N, NB, and Grid/Order after Host-Runtime Shift

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.16. Recoverable Track-1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Re-close the problem-geometry chain that was reopened by TASK-009's verified
host-runtime regime shift on the established **2 GAAS nodes x 8 H200 GPUs/node**
HPL-MxP topology.

TASK-009 established the retained host-runtime control:

~~~text
OMP_NUM_THREADS = 4
--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted
OMP_PLACES omitted
OMP_PROC_BIND omitted
effective launcher defaults = sockets / TRUE
~~~

and showed that the verified IR regime at the retained N changed materially
while LU remained essentially unchanged. The dependency graph therefore
reopens the useful N operating point through E39.

TASK-010 is a **bounded conditional re-closure workflow**. It contains four
execution steps, but Steps B/C/D run only when the preceding evidence actually
requires them:

~~~text
Step A — coarse N re-sweep under verified host runtime
        |
        |-- if N does NOT materially move:
        |      STOP TASK-010
        |      retain N=429056, NB=3072, 4x4 row
        |
        '-- if N DOES materially move:
               ↓
Step B — fine N refinement around the new coarse region
               ↓
Step C — NB re-sweep at the refined N
          |
          '-- optional ONE-SHOT local N back-check if E08 is materially triggered
               ↓
Step D — full bounded grid x nporder matrix at finalized N/NB
               ↓
STOP
~~~

This task deliberately increases execution autonomy while preventing recursive
re-sweeping. A later step may perform only the explicitly authorized bounded
dependency check described below. It must not reopen an earlier step
indefinitely.

Use the word **step**, not phase, for A/B/C/D. These are dependency re-closure
steps inside the existing campaign, not new campaign phases.

### 1.2 Why this task is required

The previous N optimum was selected from the tradeoff:

~~~text
larger N
  -> better LU efficiency / larger credited work
  -> greater FP64 residency/staging/refinement burden
  -> larger IR cost
  -> end-to-end score eventually falls
~~~

TASK-009 did not remove the matrix/residency dependency. It revealed another
causal layer:

~~~text
N / residency / refinement work
        ↓
host runtime processes that work
        ↓
observed IR time
        ↓
final LU/IR balance
~~~

At N=429056 the verified TASK-009 host runtime materially reduced IR relative
to the historical regime while leaving LU unchanged. The old N optimum is
therefore conditional on the former host-runtime state and must be rechecked.

If N materially moves, the dependency graph then requires:

- **E07:** N -> NB re-sweep;
- **E08:** material NB/workspace change -> targeted N recheck;
- **E09:** material N/local-geometry change -> process-grid/order re-sweep;
- **E10:** a material NB change reinforces the grid/order revalidation;
- **E14/E15:** N/residency/headroom must be re-evaluated during the N work.

TASK-010 closes exactly this chain and stops before physical-placement,
host-runtime, DGEMV, communication, scheduling, precision, or kernel work.

### 1.3 Fixed execution topology and retained controls

Unless a step explicitly changes N, NB, nprow, npcol, or nporder, preserve:

~~~text
resource shape:
  2 nodes x 8 H200 GPUs/node
  16 MPI ranks
  one rank/GPU
  place=scatter
  no mpiprocs

project = hpc_ebslee
approved queues = gpu_as or gpu_ded

gpu-affinity = 0:1:2:3:4:5:6:7
cpu-affinity = omitted
mem-affinity = omitted
ucx-affinity = omitted / automatic

OMP_NUM_THREADS = 4
OMP_PLACES = omitted
OMP_PROC_BIND = omitted
effective launcher defaults = sockets / TRUE

sloppy-type = FP16
use-mpi-panel-broadcast = 0
use-separate-stream-for-gemm = 1
prioritize-trsm = 0
prioritize-factorization = 0

fill-device = 1
test-loop = 1
skip-tests = 0
monitor-gpu = 0
~~~

**Critical launcher contract:** every scored arm must explicitly export the
selected OMP_NUM_THREADS after environment/module setup, forward it to all MPI
ranks with the validated launcher, and verify the effective value on all
16 ranks. Do not rely on PBS/job-shell inheritance alone.

CPU affinity is **not reopened** by TASK-010. TASK-009 already resolved E19 for
the current launcher/cpuset/topology. A change in N/NB/grid does not by itself
authorize another CPU-affinity matrix.

### 1.4 General carry-forward philosophy

The orchestrator is authorized to carry intermediate operating points from one
step into the next using the bounded rules below. These are execution rules,
not final strategic conclusions.

The guiding principles are:

1. Prefer **regions/plateaus** over false precision from one-shot maxima.
2. Use **2.0%** as the default operational materiality threshold for
   carry-forward unless correctness, memory feasibility, or a clear regime
   transition provides stronger evidence.
3. Do not rerun valid points merely to resolve sub-2% differences.
4. Do not add candidates just because the trend is non-monotonic.
5. Do not recursively reopen a completed step except for the single E08
   local-N back-check explicitly authorized inside Step C.
6. A valid but slower candidate is evidence, not a reason to repeat or expand.
7. Invalid/OOM/correctness-failing candidates are boundary evidence and are
   never promoted.
8. When multiple candidates are effectively tied, prefer the simpler/safer
   control for mechanical carry-forward and preserve the ambiguity for the
   Strategic Analyst.
9. Each step gets **one bounded scientific pass**. Track-1 operational recovery
   is allowed; scientific search expansion is not.

These rules intentionally guide rather than over-constrain the orchestrator.

---

### 1.5 Step A — Coarse N re-sweep

#### 1.5A. Purpose

Test whether the useful N region moves under the verified TASK-009 host-runtime
contract.

Keep fixed:

~~~text
NB = 3072
nprow = 4
npcol = 4
nporder = row
~~~

Vary only N.

#### 1.5B. Approved coarse candidates

Run one scored attempt each at:

~~~text
N = 429056
    454656
    504832
    556032
    606208
~~~

The set deliberately spans:

- the retained high-device-residency control;
- the historical residency transition;
- progressively larger host-resident FP64 regimes;
- the previously valid higher-LU region.

Do not add lower N values. Do not extend above 606208 during Step A.

#### 1.5C. Required evidence

For every candidate capture:

- correctness / finite normalized residual;
- overall HPL-MxP GFLOP/s;
- LU time and LU GFLOP/s;
- IR time;
- solver iterations;
- IR/LU ratio;
- host-memory consumption/headroom;
- device-memory consumption/headroom;
- post-matrix-generation host/device headroom when emitted;
- exact verified OMP environment;
- PBS job/node/queue/timestamps;
- stdout/stderr/status.

The core question is whether the old larger-N IR penalty persists under the
new host runtime.

#### 1.5D. Material-movement branch rule

After all valid Step-A candidates have been attempted:

**STOP TASK-010 after Step A** when all of the following are true:

1. N=429056 is valid; and
2. N=429056 remains within 2.0% of the highest valid end-to-end score; and
3. there is no clear larger-N regime that is both materially faster and
   scientifically distinct in LU/IR behavior.

In that case mechanically retain:

~~~text
N = 429056
NB = 3072
grid/order = 4x4 row
~~~

and hand evidence back for analysis. Do not run Steps B/C/D merely to resolve
noise-level differences.

**Proceed to Step B** when the coarse evidence shows a material move, normally
meaning:

- a valid larger N is >2.0% above N=429056 in end-to-end score; or
- N=429056 falls outside the 2.0% leading region; or
- a clear regime shift in LU/IR plus performance indicates the useful region
  has moved even if a single percentage comparison is borderline.

This third clause is deliberately qualitative. Use it only for a clear
mechanistic regime change, not to chase small noise.

If all larger candidates fail correctness or feasibility, retain N=429056 and
stop TASK-010 after preserving the boundary evidence.

---

### 1.6 Step B — Fine N refinement

#### 1.6A. Trigger and purpose

Run Step B **only when Step A establishes a material N move**.

The objective is to refine the new coarse N region before introducing NB as
another variable.

Keep every Step-A scientific control fixed, including NB=3072 and 4x4 row.
Vary only N.

#### 1.6B. Fine-sweep construction guide

Do not use a permanently hard-coded fine set because the Step-A leader is not
known in advance.

Construct a **bounded 5-point refinement** around the leading coarse region:

1. Include the Step-A numerical leader.
2. Include its nearest valid lower and upper coarse neighbors when they exist.
3. Add intermediate N values between the leader and those neighbors so the
   local spacing is approximately half the Step-A coarse spacing.
4. Maximum scored Step-B candidates: **5**.
5. Reusing a Step-A anchor in Step B is allowed when it materially improves
   local comparability, but repeated anchors are not mandatory when the same
   allocation/evidence already provides adequate comparability.
6. Do not search below 429056.
7. If the Step-A leader is the upper endpoint N=606208 and performance is still
   clearly rising, Step B may refine upward with at most **two** additional
   values above 606208, but:
   - do not exceed N=700000;
   - preserve at least one lower bracketing point;
   - treat host-memory headroom and correctness as hard gates;
   - do not extend again if the Step-B upper endpoint remains the leader.
8. If the Step-A leader is an interior point, do not extend outside its two
   neighboring coarse brackets.

This creates one local refinement pass and guarantees Step B terminates.

#### 1.6C. Step-B carry-forward

After the five-or-fewer valid refinement points:

1. Identify the highest valid score and the local leading region.
2. Mechanically carry **one refined N** into Step C:
   - use the numerical leader when it is >2.0% above its valid local
     alternatives;
   - otherwise prefer the smaller/safer N within the <=2.0% plateau when it
     preserves the same qualitative LU/IR regime and materially better memory
     headroom;
   - if two near-tied points represent genuinely different residency regimes,
     carry the higher-scoring one operationally and preserve the ambiguity in
     the carry-forward log for strategic analysis.
3. Do not repeat/refine Step B again.
4. Do not reopen OMP, CPU affinity, memory affinity, or grid during Step B.

The carried N is an **operational Step-C control**, not the final strategic N
decision.

---

### 1.7 Step C — NB re-sweep with one-shot E08 N back-check

#### 1.7A. Trigger and purpose

Run Step C only after Step B has produced a refined operational N.

E07 is now materially triggered: N changed, so NB must be re-swept.

Fix N to the Step-B carried value and vary only NB.

#### 1.7B. Approved NB candidates

Run:

~~~text
NB = 1024
     2048
     3072
     4096
     5120
     6144
~~~

NB=3072 is the historical control, not an automatic winner.

All six should normally be attempted. A larger remaining NB may be skipped
only after an attempted candidate establishes a clear memory/workspace/
correctness safety boundary under unchanged controls.

#### 1.7C. NB carry-forward guide

After the valid NB sweep:

1. Identify the highest valid score and the <=2.0% leading region.
2. If NB=3072 remains in the leading region and no other NB materially changes
   memory/residency/feasibility, mechanically retain NB=3072 and proceed to
   Step D with the Step-B N.
3. If another NB is >2.0% above 3072, or materially changes the residency/
   headroom/LU-IR regime while remaining competitive, mechanically carry that
   NB and perform the E08 local N back-check below.
4. If multiple non-3072 NBs are tied inside 2.0%, prefer the simpler/safer NB
   with better correctness/headroom evidence for the mechanical back-check.
   Preserve the tie; do not run an NB fine sweep.

#### 1.7D. ONE-SHOT E08 local N back-check

This is the **only authorized feedback from Step C to N**.

Trigger it only when Step C carries an NB materially different from 3072 or
shows a materially changed workspace/residency regime.

Run a maximum of **3 N points** at the carried NB:

~~~text
one lower local N
Step-B carried N
one upper local N
~~~

Derive the lower/upper points from the nearest useful Step-B refinement spacing
and known feasibility boundary.

Rules:

1. Keep every non-N scientific control fixed.
2. Maximum three scored points.
3. No new coarse sweep.
4. No second fine sweep.
5. No return to Step C after this back-check.
6. No NB re-sweep after the back-check.
7. Choose the operational N from these three using the same 2.0% plateau /
   smaller-safer tie principle.
8. The resulting N/NB pair proceeds directly to Step D.

This explicitly prevents an N -> NB -> N -> NB recursion.

If the E08 back-check is not triggered, Step-D N is simply the Step-B carried N.

---

### 1.8 Step D — Full bounded grid x nporder matrix

#### 1.8A. Trigger and purpose

Run Step D only when Steps A/B established a material N move and the N/NB pair
has been operationally finalized through Step C.

A material N change triggers E09, so the old grid pruning is no longer assumed
valid. Step D therefore re-evaluates the serious 16-rank factor pairs rather
than only the previous TASK-006 finalists.

#### 1.8B. Exact matrix

Run exactly:

~~~text
2x8 column
2x8 row

4x4 column
4x4 row

8x2 column
8x2 row
~~~

Do not add 1x16 or 16x1 unless a future human-approved task explicitly wants
those diagnostic extremes.

For all six arms fix the Step-C finalized N/NB and every other retained
scientific/host control.

#### 1.8C. Execution and interpretation rule

All six arms should be attempted in one allocation when practical because
same-allocation comparison is scientifically valuable.

However, do not block the whole task merely because operational constraints
require an equivalent split. If a split is necessary:

- preserve identical scientific controls;
- prefer the same node pair where practical;
- include at least one common 4x4-row control in each allocation when doing so
  does not materially expand cost;
- do not repeat the entire matrix solely to align node pairs.

Step D is the final scientific execution step.

Codex may record factual ranking and <=2.0% leading-region membership, but
must not make the final strategic grid/order retention decision.

---

### 1.9 Dependency interpretation and explicit non-reopenings

TASK-010 directly executes:

- **E39:** host runtime/locality -> useful N / LU-IR operating point;
- **E14/E15:** N <-> residency/headroom during N re-sweep;
- **E07:** N -> NB, only after material N movement;
- **E08:** NB -> N/memory boundary, via one bounded local N back-check only;
- **E09:** N -> process grid/order, only after material N movement;
- **E10:** NB -> grid/order as reinforcement after Step C.

TASK-010 deliberately does **not** reopen:

- **E19 CPU affinity / OpenMP placement:** TASK-009 already resolved the
  coordinated host-placement group for the current launcher/cpuset/topology.
  N/NB/grid changes alone do not authorize another CPU-affinity matrix.
- **E20/E21 DGEMV:** remain downstream until the new N/residency/IR regime is
  strategically analyzed.
- **E11 rank/GPU/NIC placement:** if Step D ultimately changes grid/order, the
  Strategic Analyst will decide a separate placement task after TASK-010.
- **E12/E13 panel transport:** remain Phase-4 downstream work.
- **E16 fill buffer:** no buffer tuning inside TASK-010.
- **E37 LU scheduling:** remains downstream even if N changes.

E18 should be reviewed after TASK-010 if the finalized N materially changes the
IR workload, but TASK-010 does **not** execute another OMP sweep. Any later
host-runtime check should be light and separately authorized.

### 1.10 Allocation strategy and comparability

Scientific preference:

- run all candidates **within each step** sequentially in one 2x8 allocation;
- same-step same-allocation evidence is more important than forcing all four
  steps into one very long allocation;
- Steps A/B/C/D may use separate equivalent 2x8 allocations.

Operational freedom:

- choose gpu_as or gpu_ded from live eligibility;
- use any topology-matching eligible GAAS pair;
- host-pin when useful;
- reuse the same node pair across steps when practical;
- do not delay/repeat a scientifically complete step merely to recover an old
  node pair.

Do not interpret cross-step absolute movement as a one-variable effect unless
the relevant controls/allocation are demonstrably comparable.

### 1.11 Required evidence and artifacts

Create a dedicated experiment area, preferably:

~~~text
experiments/2x8-GAAS/task010-geometry-reclosure/
  README.md
  scripts/
  outputs/
~~~

Preserve a factual carry-forward log that records:

- Step-A scores, memory/residency evidence, and STOP-vs-Step-B branch;
- exact reason Step B did or did not trigger;
- Step-B generated candidate set and refinement rule;
- Step-B operational N carry-forward;
- Step-C NB matrix and whether E08 back-check triggered;
- exact three-or-fewer E08 N points when used;
- finalized operational N/NB passed to Step D;
- Step-D exact grid/order matrix;
- every skipped/invalid candidate and the reason;
- the specific bounded rule used for every branch.

For every scored arm preserve at minimum:

- task step and arm label;
- N, NB, nprow, npcol, nporder;
- OMP_NUM_THREADS supplied and effective;
- OMP_PLACES / OMP_PROC_BIND supplied and effective;
- GPU/CPU/memory/UCX affinity supplied/omitted;
- PBS job ID, queue, nodes, timestamps;
- rank mapping / local-rank structure when grid interpretation needs it;
- correctness / residual;
- overall GFLOP/s;
- LU time / LU GFLOP/s;
- IR time / IR/LU;
- solver iterations;
- host/device memory and headroom;
- stdout/stderr/status.

Append factual results to:

~~~text
results/metrics.csv
results/RESULTS.md
~~~

Update task/progress/experiment bookkeeping only.

Do not write strategic conclusions into `planning/2x8-GAAS.md` during
execution. Final interpretation remains with the Strategic Analyst.

### 1.12 Anti-loop / anti-overfitting rules

These rules are mandatory:

1. Step A runs once.
2. Step B runs at most once and only if Step A materially moves N.
3. Step C runs at most once.
4. E08 may cause exactly one local 3-point N back-check.
5. That back-check may not trigger another NB sweep.
6. Step D runs at most once.
7. No valid point is repeated solely because two candidates are within 2.0%.
8. No new candidate family is invented after seeing a surprising valid result.
9. No step is expanded to seek a uniquely smooth or monotonic curve.
10. No recursive optimization loop is allowed.
11. Preserve ambiguity instead of spending jobs to erase sub-noise differences.
12. A failed candidate may be rerun only for a documented Track-1 execution
    mechanic that prevented a scientifically valid measurement, not because
    its performance was disappointing.
13. If a branch condition is genuinely borderline, choose the path that
    performs **less additional work** unless correctness, memory safety, or a
    clear dependency/regime shift argues otherwise.

### 1.13 Track-1 operational recovery

Codex may recover without new approval from:

- queue/node eligibility changes;
- scheduler-only failures;
- worktree/synchronization issues;
- evidence-transfer problems;
- output/parser bookkeeping bugs;
- a launcher/preflight bug discovered before meaningful scientific data;
- individual candidate launch failure caused by ordinary infrastructure
  mechanics.

Recovery must preserve the approved scientific candidate/control set.

If a whole-step retry is needed after **no meaningful scored data** were
collected, a clean retry is allowed.

After meaningful step data exist, do not stitch arbitrary unrelated reruns
into a fake same-allocation comparison. Preserve the valid data and continue
only where the approved scientific comparison remains interpretable.

### 1.14 Stop / escalation conditions

Stop the affected task and hand back for human/Strategic-Analyst direction only
when:

- the 2x8 topology/resource shape cannot be obtained;
- the validated container/launcher behavior materially changes;
- explicit OMP_NUM_THREADS propagation cannot be verified on all ranks;
- execution requires a scientific control outside this task;
- Step-A evidence requires searching below N=429056 or above N=700000;
- Step-B cannot construct a meaningful bounded local refinement without
  violating its bracketing/safety rules;
- Step-C requires an NB outside the approved set;
- the E08 back-check would require more than three N points to be meaningful;
- Step-D would require a grid outside the approved six-arm matrix;
- multiple candidates show a common correctness/runtime failure suggesting a
  systemic platform/scientific issue rather than a candidate-specific
  boundary;
- further interpretation would require new profiling or a new diagnostic
  experiment.

Do **not** escalate merely because:

- the historical node pair is unavailable;
- gpu_as versus gpu_ded must change;
- a valid candidate is slower;
- a result is non-monotonic;
- several candidates are within 2.0%;
- a later step does not trigger;
- Step A stops the task early;
- the task uses more than one equivalent allocation;
- one candidate establishes a clear memory/workspace safety boundary.

### 1.15 Completion criteria

TASK-010 is complete when either:

#### Early completion path

Step A validly completes and the bounded branch rule retains N=429056 without
material movement. In this path:

- Steps B/C/D are correctly skipped;
- the reason is recorded;
- all Step-A evidence is preserved;
- task ownership returns to Strategic Analyst.

#### Full conditional path

Step A materially moves N and:

- Step B performs one bounded fine-N refinement;
- Step C performs one bounded NB sweep;
- at most one E08 local N back-check is performed when triggered;
- Step D performs the exact six-arm grid/order matrix;
- no recursive re-sweeping occurs;
- all factual evidence and branch decisions are preserved;
- task ownership returns to Strategic Analyst.

In both paths:

- all valid arms report normal output, finite residual, and PASSED;
- invalid/OOM candidates remain preserved as boundary evidence;
- factual results/bookkeeping are updated;
- no final strategic N/NB/grid winner is declared by Codex;
- no downstream placement, OMP, DGEMV, communication, scheduling, precision,
  kernel, or buffer tuning is started.

### 1.16 Authorization

status: APPROVED

approved_scope: Execute TASK-010 as the bounded conditional geometry re-closure workflow on the established 2-node x 8-H200 GAAS NVIDIA HPL-MxP topology. Step A must run exactly the coarse N set {429056,454656,504832,556032,606208} at fixed NB=3072 and 4x4 row under the retained TASK-009 verified host-runtime contract: OMP_NUM_THREADS=4 explicitly exported, forwarded and verified on all 16 ranks; OMP_PLACES/OMP_PROC_BIND omitted with effective launcher defaults sockets/TRUE; CPU/memory/UCX affinity omitted; identity GPU affinity; FP16; MPI panel broadcast=0; separate GEMM stream=1; TRSM/factorization priorities=0; fill-device=1; test-loop=1; skip-tests=0; monitor-gpu=0. If N=429056 remains within the 2.0% leading region without a clear larger-N regime shift, TASK-010 must terminate after Step A and skip Steps B/C/D. If Step A materially moves N, Codex may autonomously execute Step B as one bounded <=5-point fine-N refinement around the coarse leading region, using the task's bracketing rules and no repeated fine sweep; if the upper coarse endpoint leads and performance is still rising, Step B may use at most two safe upward points but never N>700000. Step C then runs exactly NB {1024,2048,3072,4096,5120,6144} at the Step-B carried N. If Step C materially changes NB/workspace/residency, Codex may execute exactly one E08 local N back-check of at most three points (lower/current/upper) at the carried NB; that back-check may not trigger another NB sweep. Step D then runs exactly the six grid/order arms {2x8 column,2x8 row,4x4 column,4x4 row,8x2 column,8x2 row} at the operationally finalized N/NB. Each step should use one same-allocation candidate pass when practical; different steps may use separate equivalent 2x8 allocations. Codex may choose gpu_as or gpu_ded, select or host-pin eligible topology-matching nodes, perform Track-1 operational recovery, skip unsafe larger candidates only after documented memory/workspace/correctness boundary evidence, preserve all factual branch/carry-forward evidence, and update experiment/results/task/progress bookkeeping. No CPU-affinity, memory-affinity, OMP place/bind/thread re-sweep, GPU remap, DGEMV, UCX transport, MPI/NCCL communication, chunk, fill-buffer, scheduling, precision, kernel, profiling, or other downstream tuning is authorized. No recursive N<->NB loop, second fine-N sweep, NB fine sweep, repeat-for-noise, or adaptive candidate expansion is authorized. Codex must return the completed evidence to the Strategic Analyst without making the final strategic N/NB/grid/order retention decision.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

<!-- Codex completes this section after execution; do not rewrite Section 1. -->

### 2.1 Execution Status

status: PENDING

### 2.2 Orchestration Summary

Pending execution.

### 2.3 Work Executed

Pending execution.

### 2.4 Operational Validation

Pending execution.

### 2.5 Evidence and Artifacts

Pending execution.

### 2.6 Files Changed

Pending execution.

### 2.7 Missing / Unavailable Evidence

Pending execution.

### 2.8 Execution Errors / Exceptions

Pending execution.

### 2.9 Scope Compliance

Pending execution.

### 2.10 Handoff to Strategic Analyst

Pending execution.
