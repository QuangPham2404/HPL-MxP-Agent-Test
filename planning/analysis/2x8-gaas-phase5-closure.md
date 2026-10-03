---
title: 2x8 GAAS Phase 5 and First-Pass Campaign Closure
status: COMPLETE
created: 2026-10-03
last_updated: 2026-10-03
---

# 2x8 GAAS Phase 5 and First-Pass Campaign Closure

## 1. Formal Phase-5 closure

Phase 5 is formally closed.

The closing evidence chain is:

1. TASK-2X8-017 completed the full 2^3 scheduling factorial over:
   - factorization priority;
   - TRSM priority;
   - separate GEMM stream.
2. Scheduler 101 was selected:
   - prioritize-factorization = 1
   - prioritize-trsm = 0
   - use-separate-stream-for-gemm = 1
3. The mandatory dependency review reopened only NB and U-panel chunk for
   bounded final-stack revalidation.
4. TASK-2X8-018 executed the complete valid NB × chunk matrix under scheduler
   101.
5. NB=3072 remained the clear retained NB.
6. At NB=3072, chunk 2/4/8/16 formed a sub-2% plateau; chunk 4 and 8 were
   effectively identical. Chunk 4 is retained as the representative.
7. No earlier phase was reopened by the dependency checkpoint.
8. The exact final candidate reproduced three times across TASK-2X8-017 and
   TASK-2X8-018, so no additional final confirmation run is required.

TASK-2X8-018 opening/closing control evidence:

~~~text
NB=3072
chunk=4
scheduler=101

opening overall = 7.2303e+06 GFLOP/s
closing overall = 7.2406e+06 GFLOP/s
midpoint        = 7.23545e+06 GFLOP/s
overall spread  = 0.1425%

opening LU      = 7.5266e+06 GFLOP/s
closing LU      = 7.5382e+06 GFLOP/s
LU midpoint     = 7.5324e+06 GFLOP/s
LU spread       = 0.1541%
~~~

TASK-2X8-017 A101 was 7.2398e+06 GFLOP/s, only about 0.06% above the
TASK-2X8-018 midpoint.

This satisfies the Phase-5 closing condition: repeatable final stack,
correctness preserved, and targeted dependency revalidation complete.

## 2. Retained final 2x8 stack

~~~text
N = 429056
NB = 3072

nprow = 4
npcol = 4
nporder = row

gpu-affinity = 0:1:2:3:4:5:6:7
cpu-affinity = omitted
mem-affinity = omitted
ucx-affinity = omitted / AUTO
UCX_TLS = unset / AUTO
UCX_NET_DEVICES = unset / AUTO

OMP_NUM_THREADS = 4
OMP_PLACES = omitted
OMP_PROC_BIND = omitted
effective launcher policy = sockets / TRUE

fill-device = 1
fill-device-buffer-size = 3048
cuda-host-register-step = 2048
call-dgemv-with-multiple-threads = 0

sloppy-type = FP16
preset-gemm-kernel = effective package default / SM90

use-mpi-panel-broadcast = 0
u-panel-chunk-nbs = 4

prioritize-factorization = 1
prioritize-trsm = 0
use-separate-stream-for-gemm = 1

test-loop = 1
skip-tests = 0
monitor-gpu = 0
~~~

Chunk 4 is retained as the representative of the current plateau, not as a
claimed unique optimum.

## 3. First-pass 2x8 campaign closure

The blueprint terminates at Phase 5. Therefore closing Phase 5 also closes
this first full optimization pass for the 2-node × 8-H200 GAAS topology.

Campaign path completed:

~~~text
Phase 0  characterization + immutable baseline
Phase 1  N / NB geometry and residency operating point
Phase 2  grid / order / placement
Phase 3  host runtime / locality / residency / host-memory controls
Phase 4  communication / panel transport / U-panel readiness
Phase 5  scheduling / final-stack dependency validation
~~~

No active dependency remains that requires another experiment before declaring
this pass complete.

The immutable original 2x8 baseline was:

~~~text
4.8037e+06 GFLOP/s
~~~

The final retained stack's TASK-2X8-018 control midpoint is:

~~~text
7.23545e+06 GFLOP/s
~~~

which is approximately:

~~~text
+50.62%
~~~

over the immutable original baseline.

## 4. Scope qualification

"First-pass campaign complete" does not mean global mathematical optimality
over every NVIDIA HPL-MxP control.

In particular, this pass intentionally kept the following as fixed controls:

- sloppy-type = FP16;
- preset-gemm-kernel = effective package default / SM90.

They were not exhaustively swept as independent Phase-5 variables in the 2x8
campaign.

Therefore the correct claim is:

> The first structured end-to-end optimization pass on 2x8 GAAS is complete,
> with all phases in the adopted campaign blueprint closed for the executed
> scope.

A future second pass may deliberately reopen selected areas such as precision,
GEMM kernel selection, or newly discovered software/runtime controls, but that
would be a new campaign/revision rather than unfinished work from this pass.

## 5. Closure state

- Phase 5: CLOSED
- TASK-2X8-017: analyzed
- TASK-2X8-018: analyzed
- E27/E28: reclosed
- Earlier phases: remain closed
- Additional final confirmation run: not required
- 2x8 GAAS first-pass optimization campaign: COMPLETE
