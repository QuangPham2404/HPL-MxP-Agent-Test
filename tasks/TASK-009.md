---
task_id: TASK-009
title: Phase 3A/3B — Coordinated OpenMP and CPU Host-Runtime Sweep
status: APPROVED
current_owner: codex
parent_task: TASK-008
analysis_id: 2x8-gaas-phase3ab-host-runtime
created: 2026-09-28
last_updated: 2026-09-28
---

# TASK-009 — Phase 3A/3B: Coordinated OpenMP and CPU Host-Runtime Sweep

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.16. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Run one bounded coordinated host-runtime experiment on the retained 2-node ×
8-H200/node HPL-MxP operating point.

TASK-008 closed UCX device affinity with the automatic/default policy and left
dependency E19 as the next active strong dependency:

- CPU affinity and OpenMP thread/place/bind act on the same scheduled cpuset;
- TASK-007 showed strong refinement-side sensitivity to CPU restriction;
- the historical OMP=8 setting has not been jointly validated with the final
  retained 2×8 placement;
- independently selected OpenMP and CPU-affinity winners must therefore not be
  stacked without a coordinated experiment.

TASK-009 resolves this host-runtime group using three sequential **steps**:

~~~text
Step A — OMP_NUM_THREADS sweep
        ↓ bounded carry-forward
Step B — CPU-affinity matrix at retained thread count(s)
        ↓ bounded carry-forward
Step C — OMP_PLACES × OMP_PROC_BIND matrix at retained host candidate(s)
~~~

Use the word **step**, not phase, for A/B/C throughout execution and
bookkeeping. The overall campaign remains in Phase 3.

The task answers three linked questions:

1. **Step A:** how many OpenMP worker threads per MPI rank give the useful
   balance between host parallelism and thread/runtime overhead?
2. **Step B:** for that concurrency, how much CPU territory should each rank be
   allowed to use so the OpenMP workers do not starve MPI/UCX/runtime/helper
   work?
3. **Step C:** inside the retained CPU territory, how should the OpenMP threads
   be placed and bound?

The carry-forward rules below are operational pruning rules only. They exist to
keep the experiment bounded and comparable. They are **not** authorization for
Codex to make the final strategic host-runtime retention decision.

### 1.2 Fixed retained operating point

Use the retained TASK-008 scientific configuration:

~~~text
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row

--gpu-affinity 0:1:2:3:4:5:6:7

--mem-affinity omitted
--ucx-affinity omitted

--sloppy-type FP16
--use-mpi-panel-broadcast 0
--use-separate-stream-for-gemm 1
--prioritize-trsm 0
--prioritize-factorization 0
--fill-device 1

--test-loop 1
--skip-tests 0
--monitor-gpu 0
~~~

The retained physical-placement state entering TASK-009 is therefore:

~~~text
GPU affinity = identity
memory affinity = omitted
CPU affinity = omitted/free
UCX affinity = omitted/automatic
~~~

TASK-009 may change only the host-runtime controls explicitly authorized in
Steps A/B/C.

Do not reopen N, NB, process grid/order, GPU mapping, memory affinity, UCX
device selection, residency, communication transport, DGEMV, precision, kernel,
or LU scheduling during this task.

### 1.3 OpenMP baseline behavior

The recent retained runs explicitly set only:

~~~text
OMP_NUM_THREADS=8
~~~

while OMP_PLACES and OMP_PROC_BIND are omitted from the job environment. The
installed v26.02 HPL-MxP launcher then applies its package defaults inside the
container:

~~~text
effective OMP_PLACES=sockets
effective OMP_PROC_BIND=TRUE
~~~

This effective package-default behavior is the Step-A control policy.

PBS has previously populated/clobbered OMP_NUM_THREADS with the allocation CPU
count, so TASK-009 must explicitly re-export the selected thread count after
the relevant module/job environment is established. Do not use a literally
unset OMP_NUM_THREADS arm as a scientific candidate.

For every scored arm, preserve both:

- what TASK-009 explicitly supplied; and
- the effective OpenMP values seen inside the execution environment.

### 1.4 Strategic questions / hypotheses

Working hypotheses:

1. Too few OpenMP threads under-parallelize host-side refinement, launch,
   auxiliary, and data-movement work.
2. Too many OpenMP threads can increase scheduling/coordination overhead and
   reduce CPU headroom for MPI/UCX/runtime/helper activity.
3. The useful thread-count region should therefore form a plateau rather than
   requiring a uniquely sharp single-run maximum.
4. CPU affinity controls a different dimension from thread count:
   OMP_NUM_THREADS controls how many workers exist, while --cpu-affinity
   controls the CPU territory available to those workers and the rest of the
   rank's host-side work.
5. TASK-007's strict 8-CPU/rank policy was harmful under OMP=8, while the
   10-CPU/rank medium policy was promising. This suggests that some spare CPU
   capacity beyond the OpenMP workers may matter.
6. OMP_PLACES and OMP_PROC_BIND are meaningful only relative to the effective
   scheduled cpuset and any HPL CPU-affinity mask. Their matrix must therefore
   be evaluated only after Steps A/B establish the useful concurrency and CPU
   territory.
7. Memory affinity remains deliberately outside TASK-009. Any E19-triggered
   memory-affinity revalidation will be decided by the post-task Strategic
   Analyst, not by the execution orchestrator.

### 1.5 Step A — OMP_NUM_THREADS sweep

#### 1.5A. Controls

For Step A:

~~~text
--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted

OMP_PLACES omitted from job environment
OMP_PROC_BIND omitted from job environment
~~~

The installed launcher/package defaults must therefore remain the same
effective placement/binding policy used by TASK-008.

Vary only OMP_NUM_THREADS.

#### 1.5B. Approved candidates

Run one scored attempt each at:

~~~text
OMP_NUM_THREADS = 4, 6, 8, 10, 12
~~~

OMP=8 is the retained campaign control.

Before the sweep, record the allocated cpuset on both nodes and confirm that
the five thread counts are executable without changing the approved resource
shape. Step A intentionally allows the runtime to use the retained free CPU
policy; the candidate list does not imply one private CPU per OpenMP thread.

Do not add finer thread counts during execution.

#### 1.5C. Step-A interpretation

Primary evidence:

- overall HPL-MxP GFLOP/s;
- LU time and LU GFLOP/s;
- iterative-refinement time;
- IR/LU ratio;
- solver iteration count;
- correctness/residual;
- cheap CPU-utilization/oversubscription evidence when available without
  profiling;
- any obvious runtime/placement failure.

The intended mechanism is:

~~~text
too few threads
  -> insufficient host parallelism / host-feed capacity

useful plateau
  -> enough parallelism with adequate MPI/UCX/runtime headroom

too many threads
  -> coordination/oversubscription/contention or reduced progress headroom
~~~

#### 1.5D. Step-A bounded carry-forward guide

After all valid Step-A candidates have been attempted, apply this bounded rule:

1. Identify the highest valid end-to-end score.
2. Treat candidates within **2.0%** of that score as the Step-A operational
   plateau for carry-forward purposes.
3. Carry **one candidate** when one thread count is >2.0% above every other
   valid candidate.
4. Otherwise carry **at most two candidates** from the plateau.
5. When more than two candidates lie within the plateau, prefer two
   representative counts that preserve the useful uncertainty:
   - include the numerical leader;
   - choose one neighboring/lower-overhead count that is also within 2.0%,
     preferring the smaller thread count when scores are effectively tied
     because it preserves more host headroom.
6. OMP=8 does not receive automatic promotion merely because it is the old
   control.
7. Invalid candidates cannot be promoted.
8. Do **not** repeat valid Step-A points merely to resolve a sub-2% difference.
   Preserve the ambiguity and move to Step B.
9. Do **not** remain in Step A trying additional counts unless the approved
   experiment is not executable because of a genuine control/launcher
   contradiction. Ordinary non-monotonic performance is evidence, not a reason
   to expand the sweep.

This rule is deliberately permissive: it prevents a noisy one-shot winner from
being over-promoted while guaranteeing that Step A terminates after one bounded
pass.

### 1.6 Step B — CPU-affinity matrix

#### 1.6A. Purpose

For each Step-A carried thread count T, answer:

> Given T OpenMP workers per rank, how much CPU territory should the rank be
> allowed to use?

Keep the Step-A thread count fixed within each mini-matrix. OMP_PLACES and
OMP_PROC_BIND remain omitted so the same launcher package defaults continue to
apply during Step B.

Memory affinity and UCX affinity remain omitted.

#### 1.6B. Policies

For every Step-A carried T, compare:

~~~text
B0 = free   -> omit --cpu-affinity
B1 = loose  -> broad NUMA-local shared CPU territory
B2 = medium -> non-overlapping rank-local CPU slices with modest spare
               helper/progress capacity beyond T where legal
B3 = strict -> narrow non-overlapping rank-local CPU slices sized as close
               as legally possible to T CPUs/rank
~~~

The exact CPU masks must be derived from the live scheduled cpuset and retained
identity GPU/NUMA map:

~~~text
local ranks 0-3 -> GPU0-3 -> NUMA0
local ranks 4-7 -> GPU4-7 -> NUMA1
~~~

Use the TASK-007 mask construction as prior mechanism evidence, not as fixed
literal strings for every T.

Definitions:

- **free:** no HPL --cpu-affinity.
- **loose:** each rank receives the broad CPU set associated with the NUMA
  domain of its assigned GPU, allowing same-NUMA ranks to share that broad
  territory as in TASK-007.
- **medium:** use non-overlapping rank-local slices sized approximately
  T + 2 CPUs/rank when legal, or the nearest legal non-overlapping slice that
  still leaves meaningful helper/progress headroom.
- **strict:** use a non-overlapping rank-local slice sized approximately T
  CPUs/rank when legal, with no deliberate extra helper/progress headroom.

The orchestrator must verify every proposed mask is inside the scheduled cpuset
and consistent with the retained GPU/NUMA topology before running it.

#### 1.6C. Feasibility rule

Do not force an impossible CPU policy merely to complete a rectangular matrix.

In particular, if a retained T is too large for a topology-aligned,
non-overlapping medium or strict policy on the actual NUMA cpuset:

1. record that arm as **not scientifically instantiated / infeasible under the
   approved topology constraint**;
2. do not create cross-NUMA or overlapping masks merely to satisfy the label;
3. continue with the remaining legal B0/B1/B2/B3 arms;
4. do not stop the whole task unless no meaningful Step-B comparison remains.

A medium policy that collapses to exactly the same effective mask as strict
should not be run twice. Preserve the reason and continue.

This is an explicit anti-stall rule.

#### 1.6D. Step-B bounded carry-forward guide

Evaluate each explicit CPU policy against the **same-T B0 free control**.

For each retained T:

1. An explicit B1/B2/B3 policy is operationally promotable when it is valid and
   >2.0% above the same-T free control in end-to-end GFLOP/s.
2. If no explicit policy clears that gate, the free policy remains the
   carry-forward candidate for that T.
3. If multiple explicit policies clear the gate, carry only the highest valid
   policy for that T unless two are within 2.0% of each other and represent
   materially different CPU-territory mechanisms; in that case both may remain
   eligible for the cross-T pruning below.
4. Across all Step-A thread counts, carry **at most two total host candidates**
   into Step C.
5. If one host candidate is >2.0% above all other valid host candidates, carry
   only that one.
6. Otherwise carry the best two candidates needed to preserve the meaningful
   thread-count and/or CPU-territory ambiguity.
7. Prefer the simpler/free policy when an explicit policy does not establish a
   >2.0% advantage over its matched control.
8. Do not rerun a valid Step-B arm simply because the difference is small or
   unexpected.
9. Do not create new CPU-mask widths during execution to chase an apparent
   local optimum.

Again, this is execution pruning only. The Strategic Analyst will later inspect
the complete Step-B matrix rather than treating the carried candidate as a
final winner.

### 1.7 Step C — OMP_PLACES × OMP_PROC_BIND matrix

#### 1.7A. Purpose

For each Step-B carried host candidate, answer:

> Given the retained OpenMP concurrency and CPU territory, how should the
> OpenMP workers be placed and bound within that territory?

Step C is the final execution step. It does **not** mechanically select the
final campaign host-runtime winner.

#### 1.7B. Required pre-check

Before scored Step-C arms:

- record the effective rank cpuset / --cpu-affinity mask;
- verify the OpenMP place list produced by each proposed OMP_PLACES policy;
- verify that the policy does not create obvious out-of-mask placement,
  pathological cross-rank crowding, or an impossible binding request.

This is a lightweight legality check, not permission for profiling.

#### 1.7C. Candidate matrix

For each retained Step-B host candidate, include the existing package-default
behavior as the control:

~~~text
C0 default control:
  OMP_PLACES omitted
  OMP_PROC_BIND omitted
  expected effective policy = sockets / TRUE
~~~

Then test the following meaningful explicit families when legal:

~~~text
OMP_PLACES = sockets
  OMP_PROC_BIND = CLOSE
  OMP_PROC_BIND = SPREAD

OMP_PLACES = cores
  OMP_PROC_BIND = TRUE
  OMP_PROC_BIND = CLOSE
  OMP_PROC_BIND = SPREAD
~~~

Do not add OMP_PROC_BIND=FALSE unless the actual runtime/launcher semantics
show that it answers a distinct placement question not represented by C0.
Adding FALSE requires a documented execution-level reason and must not expand
Step C beyond the bounded maximum below.

Do not run a cell whose verified effective placement is identical to another
already-scored cell under the same carried host candidate. Record it as
redundant and continue.

#### 1.7D. Step-C bounded execution rule

For each Step-B carried host candidate:

- run C0 plus all legal, non-redundant approved Step-C cells;
- maximum scored Step-C arms per carried host candidate: **6**;
- no adaptive fine-grained placement search;
- no repeats solely to resolve small score differences;
- preserve every valid/invalid result and finish the step.

TASK-009 ends after the approved Step-C matrix is complete or the remaining
cells are documented as illegal/redundant under the verified cpuset.

No final carry-forward decision is made by Codex.

### 1.8 Required evidence / deliverables

Create a dedicated experiment area, preferably:

~~~text
experiments/2x8-GAAS/phase3ab-host-runtime/
~~~

with:

~~~text
README.md
scripts/
outputs/
~~~

For every scored arm preserve:

- task step and arm ID;
- OMP_NUM_THREADS;
- whether OMP_PLACES / OMP_PROC_BIND were explicit or omitted;
- effective OMP_PLACES / OMP_PROC_BIND;
- effective --cpu-affinity or omission;
- effective --mem-affinity omission;
- effective --ucx-affinity omission;
- retained GPU affinity;
- PBS job ID, queue, nodes, timestamps;
- allocated cpuset and NUMA topology;
- exact N/NB/grid/order and fixed scientific controls;
- exit status;
- correctness verdict and finite normalized residual;
- overall HPL-MxP GFLOP/s;
- LU time and LU GFLOP/s;
- iterative-refinement time;
- solver iteration count;
- IR/LU ratio;
- host/device memory consumption and post-matgen device headroom when emitted;
- cheap CPU/runtime evidence available from normal execution;
- stdout/stderr/status.

Preserve a factual carry-forward log containing:

- Step-A valid scores and the one/two carried T values;
- Step-B legal/infeasible policy matrix and the one/two carried host candidates;
- Step-C legality/redundancy decisions;
- the exact rule that produced each operational branch.

Append factual rows to:

~~~text
results/metrics.csv
results/RESULTS.md
~~~

Update only factual execution artifacts and task/progress bookkeeping.

Do not update strategic conclusions in planning/2x8-GAAS.md and do not create
the final TASK-009 strategic analysis during execution.

### 1.9 Relevant dependencies and scope boundary

TASK-009 directly addresses:

- **E18 — N/refinement work -> host runtime/locality**
- **E19 — CPU/memory affinity -> OpenMP policy**, limited in this task to the
  coordinated OpenMP + CPU-affinity portion

Memory affinity is intentionally deferred from execution. After TASK-009 is
verified and analyzed, the Strategic Analyst must decide whether the retained
CPU/OpenMP configuration materially changes NUMA locality enough to reopen a
small memory-affinity validation.

TASK-009 also has a downstream consequence:

- **E20 — host runtime/locality -> DGEMV partition**

Do not execute DGEMV tuning in TASK-009. If TASK-009 materially changes the
host-runtime policy, E20 must be reviewed after this task.

The following remain outside TASK-009:

- E12/E13 Phase-4 panel-transport revalidation;
- UCX_TLS / --ucx-tls;
- MPI/NCCL panel-broadcast policy;
- U-panel chunking;
- memory-affinity revalidation;
- DGEMV revalidation;
- residency/buffer tuning;
- LU scheduling;
- precision/kernel work.

The task should finish with evidence, not branch into these downstream
dependencies.

### 1.10 Execution scope and anti-stall rules

#### Allowed

Codex may:

- create the dedicated TASK-009 experiment area;
- adapt the validated TASK-008 2×8 launcher/evidence structure;
- run Step A exactly once across the five approved thread counts;
- mechanically carry at most two Step-A candidates into Step B;
- derive legal Step-B CPU masks from the live cpuset and retained GPU/NUMA map;
- skip/document Step-B cells that cannot be legally instantiated without
  violating topology/non-overlap intent;
- mechanically carry at most two host candidates into Step C;
- verify Step-C effective place lists;
- skip/document Step-C cells that are illegal or effectively redundant;
- keep the experiment inside one allocation when practical;
- choose gpu_as or gpu_ded based on live eligibility;
- use an eligible topology-matching node pair;
- perform minimal rank/cpuset/OpenMP legality checks;
- preserve all evidence;
- perform Track-1 recovery for scheduler/worktree/output/transfer mechanics
  while scientific scope remains unchanged;
- update experiment/results/task/progress bookkeeping;
- commit/push approved execution artifacts.

#### Prohibited

Codex and workers must not:

- add new Step-A thread counts;
- repeat valid points to chase sub-2% differences;
- remain in a step indefinitely trying to identify a unique winner;
- invent new CPU-affinity widths after seeing results;
- use illegal/out-of-cpuset or knowingly cross-NUMA masks simply to complete a
  nominal matrix;
- add broad profiling/tracing without a concrete execution contradiction;
- tune or set --mem-affinity;
- tune or set --ucx-affinity;
- change GPU affinity;
- change N, NB, grid, order;
- change fill-device/residency/buffer policy;
- tune DGEMV;
- change precision/GEMM kernel;
- change panel-broadcast/UCX transport/MPI fallback/chunk policy;
- change TRSM/factorization/separate-stream scheduling;
- perform final strategic retention/closure analysis;
- begin the memory-affinity, DGEMV, or Phase-4 follow-on tasks.

### 1.11 Same-allocation / comparability guidance

Prefer one 2-node × 8-H200 PBS allocation for the complete TASK-009 sequence so
Step A/B/C share:

- one node pair;
- one launcher/container environment;
- one cpuset/resource contract;
- one contemporaneous platform state.

Because TASK-009 contains conditional carry-forward, the exact arm count is not
known until execution. The PBS script may implement the approved branching
inside one allocation.

However, same-allocation comparability must not become an execution trap:

1. If the allocation can legally and safely accommodate the conditional
   sequence, run the task in one allocation.
2. If a scheduler/runtime limit makes the complete approved sequence impossible
   before any meaningful scored evidence is collected, a clean whole-task
   Track-1 retry with sufficient walltime is allowed.
3. If an allocation ends after meaningful scored evidence has been collected,
   preserve the partial result and return PARTIAL/BLOCKED rather than silently
   stitching the remaining steps across unrelated allocations.
4. Do not rerun completed valid steps merely to obtain a cosmetically complete
   matrix in a new allocation without new human authority.

### 1.12 Resource and launcher constraints

Use the validated TASK-008 2×8 launch contract:

~~~text
PBS compute nodes only
2 nodes × 8 H200
16 MPI ranks
1 rank/GPU
place=scatter
no mpiprocs

project = hpc_ebslee
authorized queues = gpu_as or gpu_ded
~~~

Verify live queue/node eligibility before host-pinning. A node being free does
not alone prove queue eligibility.

Reuse the validated container MPI + pbsdsh bridge and shared de-duplicated
slots=8/node hostfile pattern.

Prefer a clean/quiet eligible topology-matching pair. Reuse of g12/g13/g15 is
not mandatory; a replacement pair must satisfy the retained topology
assumptions before CPU-mask derivation.

### 1.13 Stop / escalation conditions

Stop and return for Human/Strategic Analyst direction when:

- the retained identity GPU/NUMA mapping cannot be realized on the allocated
  nodes;
- the scheduled cpuset/topology materially differs so the Step-B policy
  meanings cannot be constructed;
- the launcher no longer applies the captured OpenMP semantics;
- the Step-A control family cannot execute under the approved scientific
  configuration;
- no meaningful legal Step-B comparison remains after feasibility checks;
- multiple candidates show a common correctness/runtime failure suggesting a
  systemic platform/scientific issue;
- completing the task requires changing a prohibited scientific control;
- the conditional sequence cannot remain scientifically comparable after
  meaningful evidence has already been collected.

Do **not** escalate merely because:

- a candidate is slower;
- the Step-A curve is non-monotonic;
- several Step-A counts are within 2%;
- an explicit CPU policy is infeasible for one retained T while other legal
  policies remain;
- a Step-C cell is illegal or redundant;
- the preferred node pair is unavailable;
- a valid candidate gives an unexpected LU/IR split;
- the operational carry-forward leaves two candidates instead of one.

Ambiguity is allowed. Preserve it and finish the bounded task.

### 1.14 Success criteria

TASK-009 is operationally complete when:

- the dedicated host-runtime experiment area exists;
- Step A attempted exactly OMP_NUM_THREADS 4/6/8/10/12 once each unless a
  documented systemic blocker prevented execution;
- Step-A carry-forward retained no more than two candidates using Section
  1.5D;
- Step B compared free/loose/medium/strict for each retained T wherever those
  policies were legally distinct and instantiable;
- infeasible/redundant Step-B arms are explicitly documented rather than
  replaced with improvised masks;
- Step-B carry-forward retained no more than two total host candidates using
  Section 1.6D;
- Step C tested the default control and the legal, non-redundant approved
  OMP_PLACES × OMP_PROC_BIND families for each carried host candidate;
- Step C did not exceed six scored arms per carried host candidate;
- all scored arms retain N=429056, NB=3072, 4×4 row, identity GPU affinity,
  memory affinity omitted, automatic UCX affinity, FP16,
  use-mpi-panel-broadcast=0, separate GEMM stream=1,
  TRSM/factorization priorities=0, fill-device=1, test-loop=1, skip-tests=0,
  and monitor-gpu=0;
- valid arms report normal output, finite residual, and PASSED;
- effective OpenMP/CPU settings and overall/LU/IR/iteration/memory evidence are
  preserved;
- carry-forward decisions are logged factually;
- result rows and raw evidence are committed/pushed;
- no memory-affinity, DGEMV, Phase-4 communication, residency, precision,
  kernel, or scheduling follow-on work is executed;
- no final strategic host-runtime winner is declared;
- lifecycle handoff becomes:

~~~text
status: EXECUTED
current_owner: strategic-analyst
~~~

### 1.15 Strategic Analyst notes for later

After execution is verified and the Human explicitly authorizes
ANALYSE_RESULTS, analyze the **entire** Step-A/B/C dataset, not only the
mechanically carried path.

The later dependency checkpoint should answer at least:

1. What thread-count region is actually useful, and is there a plateau rather
   than a unique optimum?
2. Does CPU territory explain the TASK-007 strict-vs-medium IR behavior?
3. Does the best explicit CPU policy win by enough to justify its added
   topology complexity over free placement?
4. Do OMP_PLACES / OMP_PROC_BIND materially interact with the retained CPU
   territory or thread count?
5. Did TASK-009 materially change CPU/NUMA locality enough to reopen a small
   memory-affinity validation under E19?
6. Does the retained host-runtime change trigger a DGEMV revalidation under
   E20?
7. Are any small apparent gains inside the known drift/noise envelope and in
   need of a separate confirmation before final retention?

No post-TASK-009 dependency experiment is authorized by this task.

### 1.16 Authorization

status: APPROVED

approved_scope: Execute TASK-009 as one bounded coordinated Phase-3 host-runtime experiment on the retained 2x8 GAAS HPL-MxP operating point. Keep N=429056, NB=3072, 4x4 row order, identity GPU affinity 0:1:2:3:4:5:6:7, memory affinity omitted, UCX affinity omitted/automatic, FP16, use-mpi-panel-broadcast=0, separate GEMM stream=1, TRSM/factorization priorities=0, fill-device=1, test-loop=1, skip-tests=0, and monitor-gpu=0. Step A must run exactly OMP_NUM_THREADS 4,6,8,10,12 with CPU/memory/UCX affinity omitted and OMP_PLACES/OMP_PROC_BIND omitted so the retained launcher package defaults remain effective; use the bounded 2% plateau rule to carry no more than two thread counts and do not add/repeat valid counts to chase small differences. Step B must compare free, loose, medium, and strict CPU-affinity policies for each carried thread count, deriving legal topology-aligned masks from the live scheduled cpuset and retained GPU/NUMA map; medium should provide modest helper/progress headroom beyond the OpenMP workers where legal, strict should be approximately T CPUs/rank where legal, and infeasible/redundant policies must be documented and skipped rather than replaced with cross-NUMA/overlapping improvised masks. Apply the bounded carry-forward rules to retain no more than two total host candidates. Step C must test, for each carried host candidate, the package-default control plus legal/non-redundant combinations from sockets×{CLOSE,SPREAD} and cores×{TRUE,CLOSE,SPREAD}, with a maximum of six scored Step-C arms per carried candidate, after verifying the effective place list. No final strategic winner is selected during execution. Prefer one 2-node x 8-H200 PBS allocation with 16 ranks/one rank per GPU, place=scatter, no mpiprocs, project hpc_ebslee, queue gpu_as or gpu_ded only, validated container MPI plus pbsdsh bridge and shared slots=8 hostfile. Preserve rank/cpuset/effective OpenMP/CPU settings, correctness, overall/LU/IR/iteration/memory evidence, raw stdout/stderr/status, PBS provenance, and factual carry-forward logs; update experiment/results/task/progress artifacts and commit/push them. Substantive execution must be delegated through the approved OpenCode worker workflow; Codex orchestrates, validates, and performs permitted bookkeeping. Do not tune memory affinity, UCX affinity/TLS, communication policy, DGEMV, N/NB/grid, residency/buffer, precision/kernel, or LU scheduling, and do not begin any dependency follow-on task. Memory-affinity and E20/DGEMV decisions are deferred to post-task strategic analysis.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

<!-- Codex completes this section after execution; do not rewrite Section 1. -->

### 2.1 Execution Status

status: NOT_STARTED

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
