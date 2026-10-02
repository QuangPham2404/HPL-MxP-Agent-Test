
---
task_id: TASK-2X8-015
title: 2x8 GAAS Phase 4C UCX Transport Characterization and U-Panel Chunk Sweep
analysis_id: 2x8-gaas-phase4c-ucx-transport-and-u-panel-chunk
status: COMPLETE
parent_task: TASK-2X8-014
created: 2026-10-02
last_updated: 2026-10-02
---

# Analysis — 2x8 GAAS Phase 4C UCX Transport Characterization and U-Panel Chunk Sweep

## Executive conclusion

TASK-2X8-015 gives two different conclusions.

UCX transport-family forcing is effectively closed. Retain UCX_TLS unset / AUTO.
AUTO, RC, RC-X, DC, and UD are all within about 0.6% LU of the AUTO midpoint,
with no fabric errors and essentially identical aggregate HCA traffic.

The U-panel chunk result is material. Relative to the chunk-8 control midpoint:

| chunk | Overall GFLOP/s | Overall delta | LU GFLOP/s | LU delta | LU s |
|---:|---:|---:|---:|---:|---:|
| 2 | 6.7662e+06 | +3.24% | 7.0260e+06 | +3.37% | 7.49 |
| 4 | 6.8223e+06 | +4.10% | 7.0862e+06 | +4.26% | 7.43 |
| 8 midpoint | 6.55365e+06 | control | 6.7968e+06 | control | about 7.745 |
| 16 | 6.3538e+06 | -3.05% | 6.5819e+06 | -3.16% | 8.00 |

The chunk-8 bracket is only 0.16% LU / 0.18% overall, so the chunk effect is
well outside local drift.

Retain u-panel-chunk-nbs = 4 as the best tested representative, while recording
2-4 as the strong fine-grained region. The 2-vs-4 gap is only about 0.8%, below
the campaign 2% materiality convention, so do not overstate a unique optimum.

## 1. Why UCX families look the same

The flat end-to-end result does not mean RC, RC-X, DC, and UD are intrinsically
the same transport.

Their designs differ:

- RC: reliable connected transport, a natural small-scale choice.
- RC-X: accelerated mlx5-only RC realization.
- DC: dynamic connection transport designed for better endpoint scalability.
- UD: unreliable datagram transport used for scalable/fallback/bootstrap roles.

The key reason they look the same here is workload placement.

The retained panel policy is use-mpi-panel-broadcast = 0, so the dominant
U-panel broadcast path is NCCL. UCX_TLS therefore changes only the remaining
MPI/UCX traffic, not the main NCCL U-panel communication path.

The Stage-A numbers support that interpretation:

| family | Overall delta vs AUTO midpoint | LU delta vs AUTO midpoint |
|---|---:|---:|
| RC | -0.08% | -0.10% |
| RC-X | -0.49% | -0.54% |
| DC | +0.27% | +0.26% |
| UD | +0.10% | +0.08% |

The fabric evidence is even stronger. AUTO, RC, RC-X, DC, and UD all show almost
identical HCA totals and shares:

- g14 total TX about 82.795e9 raw units;
- g15 total TX about 59.036e9 raw units;
- g14 rail CV 0.58%;
- g15 rail CV 39.81%;
- usable port_xmit_wait counters remain in the same regime;
- no new HCA errors.

So forcing a UCX family does not materially change the aggregate communication
shape of this HPL-MxP configuration.

### Intuitive comparison

AUTO:
UCX is free to choose based on scale, topology, message type, and memory type.
Phase 4A already showed AUTO using rc_mlx5 plus large-message zero-copy where
UCX is involved.

RC:
At 2 nodes / 16 ranks, RC is exactly the kind of transport UCX normally favors
at small scale. It therefore looks very similar to AUTO.

RC-X:
The rc alias already prefers accelerated transports when available. Forcing
rc_x removes fallback choices but does not create a new faster path. The small
-0.5% movement is not material.

DC:
DC is mainly valuable when the number of endpoints becomes large enough that
fully connected RC state is expensive. Sixteen ranks are far from that regime.
Its +0.26% LU result is noise-level relative to the campaign threshold.

UD:
UD has a different connection model and is useful for scalable/fallback and
bootstrap roles, but in this workload the UCX-controlled traffic is not the
dominant LU path. Hence even forcing UD barely moves end-to-end performance.

Conclusion:
The experiment proves UCX transport-family choice is low-leverage here. It does
not prove the raw transports would benchmark identically in isolation.

## 2. Why smaller U-panel chunks help even with NCCL

u-panel-chunk-nbs is a scheduling/readiness knob, not a transport-selection
knob.

The pipeline is conceptually:

panel/TRSM produces U data
-> a U chunk becomes ready
-> NCCL broadcasts that chunk
-> remote GPUs receive enough data
-> dependent update/GEMM work can continue

Larger chunks reduce launch/bookkeeping overhead, but delay the first moment at
which useful U data becomes available to downstream consumers.

Smaller chunks become ready earlier and therefore expose more overlap.

This is why a faster transport such as NCCL does not imply that the largest
chunk should win. The benchmark cares about time-to-readiness on the LU critical
path, not standalone collective bandwidth.

### Observed tradeoff

Chunk 16:
- largest/coarsest unit;
- LU 8.00 s;
- likely waits too long before dependent work can proceed.

Chunk 8:
- better, about 7.745 s midpoint.

Chunk 4:
- LU 7.43 s;
- best tested balance between early readiness and chunk overhead.

Chunk 2:
- LU 7.49 s;
- still much better than 8, but likely starts paying extra launch,
  synchronization, and bookkeeping overhead from being too fine-grained.

So the curve is consistent with a classic granularity optimum:

too coarse -> poor readiness / overlap
middle -> good overlap with manageable overhead
too fine -> overhead starts to recover some of the gain

The component-test evidence supports the structural interpretation. NCCL
U-broadcast test time scales with chunk size:

- chunk 2: about 0.05 s
- chunk 4: about 0.09 s
- chunk 8: about 0.17 s
- chunk 16: about 0.33 s

These are pre-run component timings, not LU decomposition, but they confirm the
flag changes U-broadcast granularity in the expected direction.

Whole-arm HCA traffic also changes strongly with chunk, but skip-tests=0 means
the component tests contaminate those counters. Therefore total byte volume
must not be interpreted as real LU communication volume.

A useful secondary pattern is that g15 rail imbalance rises with chunk size:

- chunk 2 CV about 14.9%
- chunk 4 CV about 25.2%
- chunk 8 CV about 39.8%
- chunk 16 CV about 56.7%

This is consistent with finer chunks producing less bursty / more distributed
traffic, but it remains supporting evidence rather than proof of causality.

Exact CUDA-stream gaps, launch dependencies, and critical producer/consumer
ranks require Nsight Systems and are intentionally deferred.

## 3. Chunk 16 residual

Chunk 16 produced normalized residual 1.587984E-05 versus 1.416310E-05 for
chunks 2, 4, and both chunk-8 controls, about 12.1% higher.

However:

- verification still PASSED;
- iterative solver stayed at 0.29 s;
- refinement stayed at 3 iterations;
- memory regime stayed unchanged.

So this is not an accuracy failure and does not affect the performance decision.

The most plausible interpretation is that chunk granularity changes readiness
and execution ordering inside the mixed-precision LU pipeline. Floating-point
arithmetic is non-associative, especially in low precision, so changing update
ordering can produce a slightly different approximate LU / preconditioner and
therefore a different final normalized residual.

The fact that only chunk 16 changes the residual is suggestive that the coarse
schedule crosses a threshold that changes operation ordering more visibly.

But there is only one chunk-16 sample, so this is suggestive, not proven.
Ordinary low-precision run-to-run nondeterminism cannot be excluded without a
repeat.

Because convergence, IR time, and pass/fail are unchanged, no dedicated
accuracy experiment is justified now.

## 4. Dependency consequences

Retain:

- UCX_TLS unset / AUTO
- use-mpi-panel-broadcast = 0
- u-panel-chunk-nbs = 4

Chunk 2 is a strong nearby alternative, not a separate campaign branch.

The new result updates the communication dependency reading:

- UCX transport-family forcing is closed for the current 2x8 / panel=0 regime.
- E23/E24 chunk validity/usefulness is resolved at the current geometry.
- E25 changes materially: at panel=0, chunk is not flat; 2/4 clearly beat 8/16.
- E27 becomes active because moving chunk 8 -> 4 materially changes readiness
  granularity; downstream stream/priority settings deserve light revalidation.
- E26 remains relevant because LU scheduling policy depends on communication
  readiness.
- Geometry, UCX affinity, panel policy, residency, and IR dependencies stay
  closed.

## 5. Recommended next direction

Do not spend another task on UCX transport.

Do not deep-profile chunk behavior yet.

Proceed through the remaining exposed LU scheduling flags with:

- UCX_TLS = AUTO
- panel broadcast = 0
- u-panel-chunk-nbs = 4

Because chunk changed materially, lightly revalidate the downstream scheduling
controls such as prioritize-trsm, prioritize-factorization, and
use-separate-stream-for-gemm under the new chunk-4 readiness regime.

Nsight Systems remains the later mechanism tool after the exposed flags are
closed.


## 6. TASK-2X8-016 confirmation and formal Phase-4 closure

TASK-2X8-016 repeated the retained chunk-4 configuration exactly once under a
fresh scored run.

Comparison:

| Metric | TASK-2X8-015 K4 | TASK-2X8-016 confirmation | Relative difference |
|---|---:|---:|---:|
| Overall GFLOP/s | 6.8223e+06 | 6.8196e+06 | -0.04% |
| LU GFLOP/s | 7.0862e+06 | 7.0833e+06 | -0.04% |
| LU time | 7.43 s | 7.43 s | effectively identical |
| IR | 0.29 s | 0.29 s | identical |
| Iterations | 3 | 3 | identical |
| Normalized residual | 1.416310E-05 | 1.416310E-05 | identical |
| Verification | PASSED | PASSED | identical |

The confirmation reproduced not only performance but also the communication
shape:

- g14 total TX: 59,734,562,922 raw units in TASK-2X8-015 K4 versus
  59,734,554,418 in the confirmation;
- g15 total TX: 47,522,091,290 versus 47,522,083,006;
- g14 rail CV: 0.81% in both;
- g15 rail CV: 25.17% in both;
- no new HCA error/discard/recovery counters in either run.

This is substantially tighter than the ordinary local control variation seen in
earlier tasks. The retained chunk-4 behavior is therefore repeatable in both
score and fabric signature.

The required provenance gate also passed before execution:

- image:
  `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`;
- SHA-256:
  `123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628`;
- NVIDIA HPC Benchmarks v26.02;
- launcher CUDA path `/usr/local/cuda/lib64`, resolving to
  `/usr/local/cuda-13.1` (CUDA 13.1).

### Phase-4 closure decision

Phase 4 — Communication is now **CLOSED** for the current 2x8 GAAS operating
regime.

The blueprint closing condition is satisfied:

- the intended GPU-direct communication path is validated;
- mapping/rail behavior is understood and stable;
- panel-broadcast policy is bounded and resolved at NCCL-only
  (`use-mpi-panel-broadcast=0`);
- UCX transport forcing has no material benefit and AUTO remains retained;
- U-panel granularity has a clear useful fine-grained region;
- chunk 4 materially beats chunk 8 and reproduces almost exactly in an
  independent confirmation run;
- correctness, refinement, memory, rank mapping, and fabric health are stable;
- further communication-mechanism refinement is lower ROI than moving to the
  downstream scheduling phase.

Retained Phase-4 communication configuration:

~~~text
UCX_TLS = unset / AUTO
UCX_NET_DEVICES = unset / AUTO
ucx-affinity = omitted / AUTO
use-mpi-panel-broadcast = 0
u-panel-chunk-nbs = 4
~~~

Chunk 2 remains a strong neighboring point, but the 2-vs-4 gap is below the
campaign materiality convention and does not justify additional Phase-4
refinement.

Per the blueprint, the material change in chunk/readiness reopens downstream LU
scheduling dependencies. The next phase should therefore be Phase 5, beginning
with lightweight revalidation of the scheduling controls under the retained
chunk-4 readiness regime.
