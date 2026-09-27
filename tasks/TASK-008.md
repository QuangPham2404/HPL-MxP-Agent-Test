---
task_id: TASK-008
title: Phase 2C — Bracketed UCX Affinity Confirmation
status: EXECUTING
current_owner: codex
parent_task: TASK-007
analysis_id: 2x8-gaas-phase2c-ucx-affinity-confirm
created: 2026-09-28
last_updated: 2026-09-28
---

# TASK-008 — Phase 2C: Bracketed UCX Affinity Confirmation

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.11. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Run one minimal same-allocation confirmation of the unresolved TASK-007 UCX
device-affinity result.

TASK-007 measured:

```text
C0 automatic UCX:   5.5828e+06 GFLOP/s, IR 1.64 s
C1 PIX-paired UCX:  5.6949e+06 GFLOP/s, IR 1.47 s

C1 vs C0 = +2.008%
```

The measured C1 gain was mechanistically plausible but smaller than the
approximately 2.68% span observed across repeated identical controls inside
TASK-007. Therefore Phase 2C is not strategically closed.

This task answers exactly one question:

> Does explicit rank-to-PIX-HCA UCX affinity reproduce an end-to-end and
> iterative-refinement advantage when bracketed by the unchanged automatic
> UCX control inside one allocation?

Run exactly:

```text
C0a — UCX automatic
C1  — explicit GPU-PIX-paired HCA affinity
C0b — UCX automatic repeat
```

No other scientific variable is tuned.

### 1.2 Fixed retained operating point

Use exactly:

```text
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row

OMP_NUM_THREADS = 8

--gpu-affinity 0:1:2:3:4:5:6:7
--mem-affinity omitted
--cpu-affinity omitted

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

Preserve the same installed/package OpenMP behavior used by TASK-007:

```text
OMP_PLACES / OMP_PROC_BIND not explicitly changed by this task
installed launcher defaults remain the effective policy
```

Do not introduce explicit CPU or memory affinity in this confirmation.

### 1.3 Approved candidate order

Run exactly these three scored arms, sequentially, in one allocation:

#### C0a — automatic UCX control

```text
--ucx-affinity omitted
```

The current automatic/default device policy has previously been observed as
`UCX_NET_DEVICES=all`.

#### C1 — explicit GPU-PIX-paired UCX affinity

With retained identity GPU mapping:

```text
--ucx-affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_8:mlx5_9
```

The installed launcher must continue to map node-local rank to:

```text
UCX_NET_DEVICES=<mlx5_X>:1
```

using the exact local-rank/HCA order above.

#### C0b — automatic UCX repeat

Identical to C0a:

```text
--ucx-affinity omitted
```

Do not add a second C1 repeat or any other arm. The purpose is a minimal local
drift bracket, not a general statistical sweep.

### 1.4 Required evidence

For all three scored arms preserve:

- arm ID: C0a / C1 / C0b;
- PBS job ID, queue, nodes, timestamps;
- effective GPU / memory / CPU / UCX-affinity settings;
- fixed N/NB/grid/order and fixed scientific controls;
- exit status;
- correctness verdict and finite normalized residual;
- overall HPL-MxP GFLOP/s;
- LU time and LU GFLOP/s;
- iterative-solver time;
- solver iteration count;
- IR/LU ratio;
- host/device memory consumption and post-matgen headroom when emitted;
- stdout/stderr/status evidence.

Before scored work, preserve one lightweight rank map confirming:

```text
16 MPI ranks
8 ranks/node
global rank
local rank
hostname
```

Reuse the accepted TASK-007/Phase-0 topology evidence when the allocated
hardware matches. Perform only the lightweight checks needed to verify that
the approved GPU-to-HCA map is still valid.

For the UCX comparison, capture cheap per-HCA `port_xmit_data` snapshots on
the mother node:

```text
before C0a
after C0a / before C1
after C1 / before C0b
after C0b
```

Use the same eight 400G IB HCAs:

```text
mlx5_0 mlx5_1 mlx5_2 mlx5_3 mlx5_4 mlx5_5 mlx5_8 mlx5_9
```

These counters are informational. Do not add profiling/tracing.

### 1.5 Interpretation boundary

Execution may report factual derived quantities such as:

```text
C1 vs C0a percentage
C1 vs C0b percentage
C0b vs C0a drift
C1 relative to the arithmetic mean of C0a/C0b
IR-time differences
per-HCA transmitted-data deltas
```

but must **not** make the strategic retain/reject decision.

The post-task Strategic Analyst will determine whether the C1 effect is
credible using the complete bracket.

The intended later interpretation is:

- a repeated C1 advantage that remains outside the local C0 bracket and
  preserves the IR-time improvement supports retaining PIX affinity;
- a C1 result that falls inside ordinary C0a↔C0b movement does not establish
  a meaningful affinity gain, in which case automatic UCX remains the simpler
  policy.

This is guidance for evidence collection only, not authorization for Codex to
close Phase 2C.

### 1.6 Explicitly deferred controls

Do **not** set, sweep, or modify:

```text
--ucx-tls
UCX_TLS
--use-mpi-panel-broadcast
--mpi-use-mpi
--use-host-mpi
--u-panel-chunk-nbs

OMP_NUM_THREADS
OMP_PLACES
OMP_PROC_BIND

--cpu-affinity
--mem-affinity

N
NB
nprow
npcol
nporder

fill-device / device-buffer controls
DGEMV controls
precision
GEMM kernel
TRSM / factorization / stream scheduling
```

The fixed campaign value remains:

```text
--use-mpi-panel-broadcast 0
```

`UCX_TLS × use-mpi-panel-broadcast` remains a Phase-4 communication study
and is explicitly out of scope.

The coordinated CPU-affinity × OpenMP revalidation required by dependency E19
also remains out of scope until Phase 2C is closed.

### 1.7 Same-allocation requirement

All three scored arms must run sequentially in one 2-node × 8-H200 PBS
allocation whenever the validated launcher contract permits it:

```text
C0a -> C1 -> C0b
```

All three must therefore share:

- one PBS job/allocation;
- one node pair;
- one rank-placement contract;
- one container/software environment.

Do not compare arms split across multiple allocations.

If the allocation terminates after scientifically meaningful evidence is
produced, preserve the partial result and return PARTIAL/BLOCKED rather than
silently completing the bracket in another allocation.

A fresh whole-task Track-1 retry is allowed only if the failed attempt produced
no scientifically meaningful scored result.

### 1.8 Resource and launcher constraints

Use the validated TASK-007 2×8 launch contract:

```text
PBS compute nodes only
2 nodes × 8 H200
16 MPI ranks
1 rank/GPU
place=scatter
no mpiprocs

project = hpc_ebslee
authorized queues = gpu_as or gpu_ded
```

Verify live queue/node eligibility before host-pinning. A node being `free`
does not by itself prove queue eligibility.

Reuse the validated container MPI + `pbsdsh` bridge and shared de-duplicated
slots=8/node hostfile pattern from TASK-007.

Prefer a clean/quiet eligible pair. g12+g15 are acceptable if eligible and
clean, but they are not mandatory; any replacement pair must satisfy the same
topology assumptions required by the exact HCA mapping.

### 1.9 Experiment area and bookkeeping

Create a dedicated experiment area, preferably:

```text
experiments/2x8-GAAS/phase2c-ucx-affinity-confirm/
```

with:

```text
README.md
scripts/
outputs/
```

Use unique attempt names and never overwrite existing evidence.

Suggested arm labels:

```text
c0a-ucx-auto
c1-ucx-pix
c0b-ucx-auto
```

Append the three factual rows to:

```text
results/metrics.csv
results/RESULTS.md
```

Update only factual execution artifacts and task/progress bookkeeping.

Do not update strategic conclusions in `planning/2x8-GAAS.md` and do not
create the final Phase-2C analysis during execution.

### 1.10 Success criteria

TASK-008 is operationally complete when:

- the dedicated experiment area exists;
- exactly C0a, C1, C0b have been attempted in that order;
- all three share one PBS allocation and one node pair;
- all three use the exact fixed scientific controls in Section 1.2;
- C1 uses exactly the approved PIX-paired HCA map;
- C0a and C0b omit `--ucx-affinity`;
- no UCX transport family or MPI/NCCL communication policy is changed;
- no OpenMP/CPU/memory-affinity tuning occurs;
- valid arms report normal output, finite residual, and `PASSED`;
- overall/LU/IR/memory evidence is preserved;
- the four HCA-counter snapshots are preserved when available;
- result rows and raw evidence are committed/pushed;
- no strategic Phase-2C closure or next-phase execution is performed;
- lifecycle handoff becomes:

```text
status: EXECUTED
current_owner: strategic-analyst
```

### 1.11 Authorization

status: APPROVED

approved_scope: Execute one minimal bracketed UCX device-affinity confirmation at the retained 2x8 GAAS HPL-MxP operating point. Fix N=429056, NB=3072, 4x4 row, OMP_NUM_THREADS=8, identity GPU affinity 0:1:2:3:4:5:6:7, memory affinity omitted, CPU affinity omitted, FP16, use-mpi-panel-broadcast=0, separate GEMM stream=1, TRSM/factorization priorities=0, fill-device=1, test-loop=1, skip-tests=0, and monitor-gpu=0. Run exactly three scored arms sequentially in one allocation in the order C0a automatic UCX, C1 explicit PIX-paired UCX affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_8:mlx5_9, C0b automatic UCX repeat. Preserve rank mapping, PBS provenance, exact effective settings, correctness, overall/LU/IR/iteration/memory evidence, and lightweight per-HCA port_xmit_data snapshots before C0a, between each arm, and after C0b. Use the validated 2-node x 8-H200 PBS/container launcher contract, project hpc_ebslee, queue gpu_as or gpu_ded only, 16 ranks/one rank per GPU, place=scatter, no mpiprocs. Do not set or sweep UCX_TLS/--ucx-tls, do not change use-mpi-panel-broadcast=0 or other MPI/NCCL/chunk/fallback controls, do not change OpenMP, CPU affinity, memory affinity, N/NB/grid, residency, precision, kernel, DGEMV, or scheduling controls. Execution may compute factual bracket deltas but must not make the strategic retain/reject decision or start the E19 host-runtime or Phase-4 communication work. Substantive execution must be delegated through the approved OpenCode worker workflow; Codex orchestrates, validates, and performs permitted bookkeeping.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

<!-- Codex completes this section after execution; do not rewrite Section 1. -->

### 2.1 Execution Status

status: IN_PROGRESS

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
