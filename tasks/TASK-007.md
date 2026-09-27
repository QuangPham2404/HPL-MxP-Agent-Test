---
task_id: TASK-007
title: Phase 2B/2C — 2x8 GAAS Placement and Locality Sweep
status: EXECUTING
current_owner: codex
parent_task: TASK-006
analysis_id: 2x8-gaas-phase2bc-placement-locality
created: 2026-09-27
last_updated: 2026-09-27
---

# TASK-007 — Phase 2B/2C: 2×8 GAAS Placement and Locality Sweep

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.11. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Run one bounded **physical placement/locality sweep** on the retained 2-node ×
8-H200/node HPL-MxP operating point.

The task combines the blueprint's Phase 2B GPU placement and Phase 2C NIC/device
placement work, and deliberately pulls the closely related CPU/memory-locality
controls into the same experiment so the physical mapping can be established
before later host-runtime and communication tuning.

The sweep has three sequential stages:

```text
A. GPU affinity × memory affinity
        ↓ pre-authorized mechanical carry-forward
B. CPU affinity: free / loose / medium / strict
        ↓ pre-authorized mechanical carry-forward
C. UCX device affinity: automatic vs GPU-PIX-paired HCA
```

This task answers:

> Where should each local MPI rank physically live — GPU, host NUMA/CPU
> resources, and network HCA — under the retained 4×4-row process grid?

This task does **not** tune UCX transport families. `--ucx-tls` is explicitly
deferred to Phase 4, where it can be tested jointly with
`--use-mpi-panel-broadcast` and other communication-policy controls.

### 1.2 Context

Phase 2A is closed at:

```text
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row
fill-device = 1
```

Retained fixed controls:

```text
OMP_NUM_THREADS=8

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

TASK-006 retained 4×4 row because it separated from the alternatives in one
same-allocation confirmation. The Phase-2A dependency checkpoint triggered
E11: grid/order → rank/GPU/NIC placement.

The current identity GPU map:

```text
0:1:2:3:4:5:6:7
```

is only the Phase-2A control; it has not been optimized.

The current Phase-0 hardware probe for both g12 and g15 records an identical
topology:

```text
PBS-visible CPUs:
  NUMA0 = 0-49
  NUMA1 = 56-101

GPU0-3 -> NUMA0
GPU4-7 -> NUMA1

all GPU-GPU paths = NV18

GPU0 -> PIX mlx5_0
GPU1 -> PIX mlx5_1
GPU2 -> PIX mlx5_2
GPU3 -> PIX mlx5_3
GPU4 -> PIX mlx5_4
GPU5 -> PIX mlx5_5
GPU6 -> PIX mlx5_8
GPU7 -> PIX mlx5_9

all eight listed mlx5 HCAs are 400G InfiniBand
```

Under the retained 4×4 row-major grid and contiguous 8-rank/node placement,
each node contains two complete process rows. The same-node members of each
process column are local-rank pairs:

```text
(0,4), (1,5), (2,6), (3,7)
```

This creates a useful topology hypothesis:

- identity GPU mapping keeps each process row inside one NUMA domain;
- an alternate mapping can instead keep each same-node process-column pair
  inside one NUMA domain.

Historical single-node affinity results are prior mechanism evidence only.
They showed that narrow CPU binding can starve the HPL-MxP host path and that
explicit memory affinity was flat/slightly negative in that old regime. Those
numerical conclusions must not be transferred to this 2×8 topology.

### 1.3 Strategic Question / Hypotheses

Primary question:

> Does topology-aware GPU/NUMA/NIC placement materially improve the retained
> 4×4-row 2×8 operating point, and if so which physical mapping should be
> carried forward into later host-runtime and communication phases?

Working hypotheses:

1. Because all GPUs are NV18-connected, arbitrary GPU permutations are
   low-value; the useful distinction is **host NUMA/NIC locality**.
2. Identity mapping may win because it keeps each node-local process row inside
   one NUMA domain.
3. A column-local mapping may win because the retained row-major grid makes
   process columns the inter-node communicator and can therefore benefit from
   cleaner GPU/NUMA/NIC association.
4. Explicit memory affinity may help only when it matches the GPU's NUMA
   domain; if it is flat or worse, omission is preferable.
5. Explicit CPU binding may have a useful middle ground: full-socket binding is
   loose, 10 cores/rank gives eight OpenMP threads plus some helper/progress
   slack, and 8 cores/rank is deliberately strict.
6. GPU-PIX-paired UCX device affinity may reduce remote NIC selection, but UCX
   automatic/multi-rail behavior may already be as good or better.
7. `--ucx-tls` is not isolated here because its value can depend on how much
   panel traffic uses CUDA-aware MPI versus NCCL.

### 1.4 Required Evidence / Deliverables

#### A. Fixed scientific controls

All scored runs must keep exactly:

```text
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row
OMP_NUM_THREADS = 8

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

Do not change OpenMP placement/binding policy in this task. Preserve the
installed launcher/package behavior used by the retained campaign control and
record the effective `OMP_PLACES` / `OMP_PROC_BIND` values when practical.

All unspecified controls retain the same package/default behavior as TASK-006.

#### B. Stage A — GPU affinity × memory affinity

Run exactly this 2×2 matrix first:

| Arm | GPU affinity | Memory affinity |
|---|---|---|
| A0 control | `0:1:2:3:4:5:6:7` | omitted |
| A1 | `0:1:2:3:4:5:6:7` | `0:0:0:0:1:1:1:1` |
| A2 | `0:4:2:6:1:5:3:7` | omitted |
| A3 | `0:4:2:6:1:5:3:7` | `0:1:0:1:0:1:0:1` |

Interpretation of the two GPU maps:

```text
G0 identity:
  local ranks 0-3 -> GPU0-3 -> NUMA0
  local ranks 4-7 -> GPU4-7 -> NUMA1
  process rows are NUMA-local

G1 column-local:
  rank pair (0,4) -> GPU0,GPU1 -> NUMA0
  rank pair (1,5) -> GPU4,GPU5 -> NUMA1
  rank pair (2,6) -> GPU2,GPU3 -> NUMA0
  rank pair (3,7) -> GPU6,GPU7 -> NUMA1
  same-node process-column pairs are NUMA-local
```

Do not add arbitrary GPU permutations.

##### Stage-A mechanical carry-forward rule

This rule is pre-authorized execution logic, not strategic campaign analysis.

1. Within G0, retain matching memory affinity only if A1 is **>2.0%** above A0
   in valid end-to-end HPL-MxP GFLOP/s. Otherwise retain G0 with memory affinity
   omitted.
2. Within G1, retain matching memory affinity only if A3 is **>2.0%** above A2.
   Otherwise retain G1 with memory affinity omitted.
3. Compare the retained G1 variant against the retained G0 variant. Carry G1
   into Stage B only if it is **>2.0%** above retained G0. Otherwise carry G0.
4. Invalid/failed candidates cannot be promoted. If A0 itself is not a valid
   control, stop rather than deriving a carry-forward decision from a broken
   baseline.
5. Preserve all four results regardless of the carry-forward branch.

A result at or below the 2% gate is treated operationally as insufficient to
justify the extra explicit mapping for this task; the Strategic Analyst may
later revisit the evidence after execution.

#### C. Stage B — CPU affinity

With the Stage-A retained GPU mapping and retained memory-affinity state fixed,
run exactly:

```text
B0 = free / no --cpu-affinity
B1 = loose
B2 = medium
B3 = strict
```

The CPU masks must follow the NUMA domain of the GPU assigned to that local
rank.

If Stage A retains **G0 identity**, use:

```text
B1 loose:
0-49:0-49:0-49:0-49:56-101:56-101:56-101:56-101

B2 medium (10 CPUs/rank):
0-9:10-19:20-29:30-39:56-65:66-75:76-85:86-95

B3 strict (8 CPUs/rank):
0-7:8-15:16-23:24-31:56-63:64-71:72-79:80-87
```

If Stage A retains **G1 column-local**, use:

```text
B1 loose:
0-49:56-101:0-49:56-101:0-49:56-101:0-49:56-101

B2 medium (10 CPUs/rank):
0-9:56-65:10-19:66-75:20-29:76-85:30-39:86-95

B3 strict (8 CPUs/rank):
0-7:56-63:8-15:64-71:16-23:72-79:24-31:80-87
```

The meanings are:

- free = no explicit HPL-MxP CPU binding;
- loose = whole local NUMA/socket cpuset available to each rank;
- medium = non-overlapping 10-CPU slices, allowing eight OMP threads plus
  limited helper/progress slack;
- strict = non-overlapping 8-CPU slices, intentionally testing the boundary
  where each rank has essentially only its eight OMP cores.

Do not test fewer than 8 CPUs/rank.

##### Stage-B mechanical carry-forward rule

Compare B1/B2/B3 against B0 inside this task.

- An explicit CPU policy is eligible for carry-forward only if it is **>2.0%**
  above B0 and valid.
- If more than one explicit policy clears the gate, carry the highest valid
  score into Stage C.
- If none clears the gate, carry B0 / no explicit CPU affinity.
- Preserve all four Stage-B results.

Do not alter `OMP_NUM_THREADS`, `OMP_PLACES`, or `OMP_PROC_BIND` in
response to Stage-B results. Their interaction is handled by the post-task
dependency review.

#### D. Stage C — UCX device affinity

With the Stage-A GPU/memory placement and Stage-B CPU policy fixed, run:

```text
C0 = --ucx-affinity omitted
C1 = explicit GPU-PIX-paired HCA mapping
```

C0 is the automatic/default device policy. The current container default has
been observed as:

```text
UCX_NET_DEVICES=all
```

For C1, map each local rank to the 400G IB HCA that is PIX-paired with its
assigned GPU.

If retained GPU map is **G0 identity**:

```text
--ucx-affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_8:mlx5_9
```

If retained GPU map is **G1 column-local**:

```text
--ucx-affinity mlx5_0:mlx5_4:mlx5_2:mlx5_8:mlx5_1:mlx5_5:mlx5_3:mlx5_9
```

The launcher implementation must continue to use the installed
`--ucx-affinity` behavior that converts the local-rank map to
`UCX_NET_DEVICES=<mlx5_X>:1`.

##### Stage-C mechanical carry-forward rule

- Retain explicit PIX-paired UCX affinity only if C1 is **>2.0%** above valid
  C0.
- Otherwise retain the automatic/default device policy.
- Preserve both C0 and C1 evidence.
- This is only an execution carry-forward result. Final strategic closure is
  performed after explicit `ANALYSE_RESULTS`.

#### E. Explicitly deferred communication controls

Do **not** use or modify:

```text
--ucx-tls
UCX_TLS
--use-mpi-panel-broadcast
--mpi-use-mpi
--use-host-mpi
--u-panel-chunk-nbs
```

except that the already-retained fixed
`--use-mpi-panel-broadcast 0` remains unchanged as the campaign control.

Reason:

`--ucx-tls` selects the UCX software transport family and can interact with
the MPI/NCCL panel-broadcast policy. It belongs in Phase 4, where a bounded
`UCX_TLS × --use-mpi-panel-broadcast` communication experiment can test that
interaction directly.

`--ucx-affinity` remains in TASK-007 because it is primarily a physical
NIC/device-association control.

#### F. Same-allocation requirement

Run all scored Stage A → Stage B → Stage C candidates sequentially inside one
2×8 PBS allocation whenever the validated TASK-006 launch contract permits it.

This yields exactly:

```text
4 Stage-A scored runs
4 Stage-B scored runs
2 Stage-C scored runs
----------------------
10 scored runs total
```

The Stage-B and Stage-C exact argument strings depend only on the
pre-authorized carry-forward rules above.

All scored runs should therefore share:

- one PBS job/allocation;
- one node pair;
- one rank-placement contract;
- one software/container environment.

If the allocation terminates after scientifically meaningful results have been
produced and the remaining stages cannot continue in that allocation, preserve
the partial evidence and return PARTIAL/BLOCKED rather than silently comparing
later stages across another allocation.

A fresh whole-task attempt may be used under Track-1 recovery only if the failed
attempt produced no scientifically meaningful scored result.

#### G. Rank/topology and lightweight placement evidence

Before the first scored arm, preserve one lightweight 16-rank mapping record:

```text
global_rank
local_rank
hostname
```

Also preserve the current allocated-node topology needed to verify:

- PBS-visible cpuset;
- NUMA CPU ranges;
- GPU→NUMA mapping;
- GPU→PIX-HCA mapping;
- IB HCA inventory/link state.

Reuse accepted Phase-0 evidence when the allocated hardware matches it; do not
repeat a broad hardware characterization without a concrete contradiction.

For Stage C, preserve enough lightweight evidence to reconstruct the effective
local-rank → GPU → HCA mapping. Per-HCA traffic counters may be captured when
cheap and non-perturbing, but profiling/tracing is not required.

#### H. Experiment area and result logging

Create a dedicated experiment area, preferably:

```text
experiments/2x8-GAAS/phase2bc-placement-locality/
```

with:

```text
README.md
scripts/
outputs/
```

Use unique attempt/candidate names and never overwrite prior evidence.

For every scored candidate preserve, when emitted:

- stage/arm ID;
- effective GPU, memory, CPU, and UCX-affinity values;
- PBS job ID, queue, nodes;
- N/NB/grid/order and fixed controls;
- exit status;
- correctness verdict and finite residual;
- overall HPL-MxP GFLOP/s;
- LU time / LU GFLOP/s;
- IR time / iteration count / IR-LU;
- device headroom and host-memory consumption;
- ordinary rank/timing imbalance markers when available;
- stdout/stderr/status.

Append factual rows to:

```text
results/metrics.csv
results/RESULTS.md
```

Update the experiment README with:

- execution provenance;
- exact candidate order;
- Stage-A/B/C carry-forward decisions as mechanical task-rule outcomes;
- raw evidence paths;
- factual result tables.

Do not update strategic conclusions in `planning/2x8-GAAS.md` or create a
final analysis report during execution.

### 1.5 Relevant Inputs and References

Primary repository:

`QuangPham2404/HPL-MxP-Agent-Test`

Primary references:

- `tasks/TASK-006.md`
- `planning/analysis/2x8-gaas-phase2a-grid-order-matrix.md`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `scripts/probing_report.md`
- `scripts/outputs/phase0_2x8_probe_v1_node_hpc-gaas-g12.log`
- `scripts/outputs/phase0_2x8_probe_v1_node_hpc-gaas-g15.log`
- `planning/analysis/affinity-491k.md`
- `planning/analysis/omp-sweep.md`
- `scripts/gaas-internode-coms-debug/resource-alloc/README.md`
- `scripts/comm_transport_probe_report.md`
- `HPL_MxP_TuningParam_Guide.md`
- `todo.md` for the captured v26.02 launcher implementation
- `workflow/07-Workflow.md`
- `workflow/08-Workflow-Multinode-Tuning.md`
- root `AGENTS.md`
- `results/metrics.csv`

Historical single-node mappings/settings are mechanism evidence only. Do not
transfer a historical winner without the TASK-007 measurement.

No OpenMxP access is required or authorized.

### 1.6 Execution Scope

#### Allowed

Codex may:

- create `experiments/2x8-GAAS/phase2bc-placement-locality/`;
- reuse/adapt the validated TASK-006 2×8 launcher and evidence structure;
- run exactly the 10 approved Stage-A/B/C scored arms;
- mechanically apply the >2% carry-forward rules in Section 1.4;
- derive the Stage-B CPU string from the retained G0/G1 map exactly as
  specified;
- derive the Stage-C HCA string from the retained G0/G1 map exactly as
  specified;
- keep all scored runs in one 2×8 allocation;
- choose `gpu_as` or `gpu_ded` based on live queue/node eligibility;
- use scheduler-selected eligible nodes or host-pin an eligible matching pair;
- prefer a clean/quiet eligible pair when available without turning this into a
  separate contention experiment;
- run lightweight rank/topology/placement checks;
- capture lightweight HCA counters when cheap;
- perform minimal script/argument validation;
- submit and boundedly monitor the approved job;
- preserve all attempt-specific evidence;
- perform Track-1 recovery for worktree/scheduler/output/transfer/submission
  mechanics while scientific scope remains unchanged;
- update experiment/results/task/progress bookkeeping;
- commit/push approved execution artifacts.

Scheduler-only changes such as output paths, attempt tags, eligible host
pinning, and sufficient walltime are allowed if they do not alter the
scientific design.

#### Prohibited

Codex and workers must not:

- change N, NB, grid, or order;
- add arbitrary GPU permutations;
- add memory-affinity policies beyond A0-A3;
- add CPU policies beyond B0-B3;
- use fewer than 8 CPUs/rank;
- add UCX device mappings beyond automatic and the exact PIX-paired mapping;
- set or sweep `--ucx-tls` / `UCX_TLS`;
- change `--use-mpi-panel-broadcast 0`;
- tune MPI/NCCL broadcast policy, U-panel chunking, MPI fallbacks, or host MPI;
- change OMP thread count/place/bind policy;
- tune DGEMV;
- change fill-device/buffer/Anq-device;
- change precision or GEMM kernel;
- change factorization/TRSM/GEMM-stream scheduling;
- rerun N/NB/grid sweeps;
- perform profiling/tracing without a concrete execution contradiction;
- add statistical repeats beyond the approved 10-arm design;
- access OpenMxP;
- perform final strategic retention/closure analysis;
- begin Phase 4 communication tuning.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and active Workflow v2.
2. Substantive execution must be delegated through the approved OpenCode worker
   workflow; Codex orchestrates, validates, and performs permitted bookkeeping.
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

7. `free` node state does not prove queue eligibility. Verify live Qlist /
   queue eligibility before host-pinning.
8. Preserve the validated container MPI + `pbsdsh` bridge and shared,
   de-duplicated slots=8/node hostfile contract from TASK-006.
9. Keep all fixed scientific controls from Section 1.4A unchanged.
10. Keep all 10 scored arms in one allocation unless a genuine blocker ends the
    attempt; do not silently combine allocations.
11. One valid scored attempt per approved arm is sufficient.
12. Preserve unique evidence names; never overwrite prior evidence.
13. A genuine correctness/runtime/placement failure is evidence and must be
    preserved.
14. Do not rerun a valid arm simply because it is slower or unexpected.
15. Perform only the minimal feasibility checks needed before submission:
    scheduler eligibility, resource availability, host-memory feasibility, and
    argument/cpuset legality.
16. Do not repeat accepted Phase-0/GDR/NCCL/UCX diagnostics unless new evidence
    contradicts them.

### 1.8 Success Criteria

TASK-007 is operationally complete when:

- the dedicated placement/locality experiment exists;
- all four Stage-A arms have been attempted;
- the Stage-A carry-forward rule has been applied mechanically;
- all four Stage-B CPU policies have been attempted under the carried Stage-A
  base;
- the Stage-B carry-forward rule has been applied mechanically;
- both Stage-C UCX-device arms have been attempted under the carried Stage-B
  base;
- all scored points use N=429056, NB=3072, 4×4 row, OMP=8, and the fixed
  retained scientific controls;
- the alternative GPU/memory/CPU/HCA argument strings match Section 1.4;
- the expected 16-rank / 8-rank-per-node map is preserved;
- valid scored arms report normal HPL-MxP output, finite residual, and
  `PASSED`;
- overall/LU/IR/memory evidence and effective placement settings are preserved;
- factual rows are added to project results;
- execution evidence is committed/pushed;
- no UCX-TLS or communication-policy tuning occurs;
- no OpenMP change occurs;
- task handoff becomes:

  ```text
  status: EXECUTED
  current_owner: strategic-analyst
  ```

Operational completion does not itself close Phase 2B/2C or prove a final
placement winner.

### 1.9 Stop / Escalation Conditions

Stop and return for Strategic Analyst / Human direction when:

- the current A0 control is invalid, so Stage-A branching has no valid basis;
- the approved G0/G1 GPU maps cannot be realized consistently on both nodes;
- the allocated cpuset/topology materially differs from the accepted Phase-0
  topology and the exact approved CPU/HCA strings are no longer valid;
- the installed launcher no longer implements the captured affinity semantics;
- completing the experiment requires changing N, NB, grid/order, OMP policy,
  broadcast policy, UCX transport family, or another scientific control;
- the 10-arm sequence cannot remain scientifically comparable inside one
  allocation after meaningful scored evidence has already been collected;
- another resource shape, queue, or accounting project is required;
- multiple arms show a common correctness/runtime failure indicating a
  systemic platform/scientific issue;
- a required diagnostic exceeds Section 1.11 authorization.

Do not escalate merely because:

- the preferred g12/g15 pair is unavailable;
- another eligible matching node pair must be used;
- `gpu_as` versus `gpu_ded` changes before submission within the approved
  set;
- a candidate is slower;
- an explicit affinity candidate fails while the valid control and remaining
  approved candidates can still run safely;
- ordinary worktree/output/transfer/submission mechanics require Track-1
  recovery.

### 1.10 Strategic Analyst Notes

After TASK-007 execution is verified and the Human explicitly authorizes
`ANALYSE_RESULTS`, analyze the complete Stage A/B/C evidence rather than only
the mechanically carried final stack.

Key questions:

1. Did G0 row-NUMA locality or G1 process-column NUMA locality explain a
   repeatable performance difference?
2. Did explicit memory affinity help either GPU map, or was omission sufficient?
3. Did CPU binding show a real optimum between free, loose, medium, and strict?
4. If CPU affinity materially changed the retained placement, apply dependency
   E19 and decide the bounded OpenMP revalidation required later.
5. Did PIX-paired `--ucx-affinity` improve end-to-end behavior or rail/locality
   evidence compared with UCX automatic selection?
6. Apply E13 after the final rank/GPU/NIC placement: panel transport must be
   revalidated later under the retained physical placement.
7. Keep `--ucx-tls` open for Phase 4. The planned communication study should
   consider a small `UCX_TLS × --use-mpi-panel-broadcast` interaction screen
   before chunk/fallback refinement rather than freezing UCX transport from
   TASK-007.

The mandatory dependency checkpoint after this combined placement/locality task
should review at least E03/E11-E13 and E19. It must decide whether OpenMP needs
bounded revalidation and what physical placement is carried into Phase 4.

No Phase-4 experiment is authorized by TASK-007.

### 1.11 Authorization

status: APPROVED

approved_scope: Execute TASK-007 as one bounded same-allocation placement/locality sweep on the retained 2x8 GAAS HPL-MxP operating point. Fix N=429056, NB=3072, 4x4 row, OMP_NUM_THREADS=8, FP16, use-mpi-panel-broadcast=0, separate GEMM stream=1, TRSM/factorization priorities=0, fill-device=1, test-loop=1, skip-tests=0, monitor-gpu=0, and unchanged package/default controls. Stage A must run exactly the four approved GPU-affinity x memory-affinity arms: identity/no-mem, identity/0:0:0:0:1:1:1:1, column-local 0:4:2:6:1:5:3:7/no-mem, and that map with mem 0:1:0:1:0:1:0:1. Apply the exact pre-authorized >2% Stage-A carry-forward rules in Section 1.4. Stage B must then run exactly free, loose, medium 10-CPU/rank, and strict 8-CPU/rank policies using the exact CPU masks specified for the retained G0 or G1 map, while holding Stage-A GPU/memory placement fixed; carry an explicit CPU policy only when it is >2% above free, otherwise carry free. Stage C must then compare UCX device affinity omitted versus the exact GPU-PIX-paired HCA map corresponding to retained G0 or G1; carry PIX affinity only if it is >2% above the default control. Run the 4+4+2 = 10 scored arms sequentially in one 2-node x 8-H200 PBS allocation when the validated launch contract permits, 16 ranks/one rank per GPU, place=scatter, no mpiprocs, project hpc_ebslee, queue gpu_as or gpu_ded only, validated container MPI plus pbsdsh bridge and shared slots=8 hostfile. Preserve rank/topology/effective-placement evidence, correctness, overall/LU/IR, iteration, memory/headroom, stdout/stderr/status, PBS provenance, and factual result rows; update experiment/results/task/progress artifacts and commit/push them. Substantive execution must be delegated to OpenCode workers. Explicitly do not set or sweep --ucx-tls/UCX_TLS, do not change use-mpi-panel-broadcast=0, do not tune MPI/NCCL/chunk/fallback controls, do not change OpenMP settings, and do not tune N/NB/grid/residency/precision/kernel/DGEMV/scheduling. UCX transport selection is deferred to Phase 4 for joint communication testing with MPI/NCCL panel-broadcast policy. No final strategic placement closure, dependency conclusion, or Phase-4 execution is authorized; those require verified execution followed by explicit ANALYSE_RESULTS.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

<!-- Codex completes this section after execution; do not rewrite section 1. -->

### 2.1 Execution Status

status: <COMPLETE | PARTIAL | BLOCKED | FAILED>

### 2.2 Orchestration Summary

*Workers, responsibilities, dependencies, and follow-ups.*

### 2.3 Work Executed

*Factual work performed.*

### 2.4 Operational Validation

*Evidence, correctness, provenance, consistency, and scope checks.*

### 2.5 Evidence and Artifacts

*Reference raw evidence paths and revisions; do not duplicate outputs.*

### 2.6 Files Changed

*List files or state None.*

### 2.7 Missing / Unavailable Evidence

*List gaps or state None.*

### 2.8 Execution Errors / Exceptions

*List failures and exceptions or state None. Record authorized Track 1
recovery and the exact resume action if incomplete; do not mark a recoverable
operational condition BLOCKED or transfer ownership to the user.*

### 2.9 Scope Compliance

*State whether work stayed within the approved scope.*

### 2.10 Handoff to Strategic Analyst

*Give factual reading guidance, without strategic interpretation.*
