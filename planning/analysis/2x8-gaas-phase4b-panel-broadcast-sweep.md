---
task_id: TASK-2X8-014
title: 2x8 GAAS Phase 4B MPI/NCCL Panel-Broadcast Sweep
analysis_id: 2x8-gaas-phase4b-panel-broadcast-sweep
status: COMPLETE
parent_task: TASK-2X8-013
created: 2026-10-02
last_updated: 2026-10-02
---

# Analysis — 2x8 GAAS Phase 4B MPI/NCCL Panel-Broadcast Sweep

## 1. Executive conclusion

TASK-2X8-014 decisively closes the panel-broadcast policy for the current 2x8
GAAS operating regime.

Retain:

~~~text
--use-mpi-panel-broadcast = 0
~~~

The result is not a narrow numerical win. Every tested positive MPI percentage
causes a large LU-side regression while correctness, IR, memory, GEMM timing,
topology, and the underlying GPU-direct communication stack remain healthy.

Using the Stage-B panel-0 midpoint as the local reference:

| panel % | overall GFLOP/s | overall delta | LU GFLOP/s | LU delta | LU s |
|---:|---:|---:|---:|---:|---:|
| 0 midpoint | 6.54645e+06 | control | 6.7899e+06 | control | ~7.75 |
| 5 | 6.0111e+06 | -8.18% | 6.2154e+06 | -8.46% | 8.47 |
| 10 | 6.0165e+06 | -8.10% | 6.2205e+06 | -8.39% | 8.47 |
| 15 | 5.3034e+06 | -18.99% | 5.4620e+06 | -19.56% | 9.64 |
| 20 | 5.0197e+06 | -23.32% | 5.1612e+06 | -23.99% | 10.20 |
| 25 | 5.2204e+06 | -20.26% | 5.3735e+06 | -20.86% | 9.80 |
| 50 | 3.7761e+06 | -42.32% | 3.8558e+06 | -43.21% | 13.66 |
| 75 | 3.2660e+06 | -50.11% | 3.3256e+06 | -51.02% | 15.83 |
| 100 | 3.2885e+06 | -49.77% | 3.3487e+06 | -50.68% | 15.72 |

Both local control brackets are tight:

~~~text
Stage A panel-0 bracket:
  LU spread      = 0.44%
  overall spread = 0.43%

Stage B panel-0 bracket:
  LU spread      = 0.44%
  overall spread = 0.44%
~~~

Therefore the positive-policy regressions are far outside measured local drift.

Phase 4B is closed with panel policy 0.

## 2. Correct mental model: NCCL vs MPI

A useful shorthand is:

> NCCL is specialized for GPU-to-GPU collective communication and is commonly
> strongest for bandwidth-heavy GPU collectives; MPI is a general-purpose
> message-passing interface and its implementations often provide excellent
> latency and flexible semantics.

However, the statement "MPI is for small/frequent messages" is too strong.

The actual MPI/UCX stack in this experiment is capable of large GPU messages:
Phase 4A and the Stage-C panel-10 diagnostic both show CUDA-aware UCX over
`rc_mlx5` with large-message rendezvous zero-copy. Therefore MPI is not
limited to small messages and its large-message path is not broken.

The more precise distinction for this experiment is:

~~~text
NCCL
  -> specialized GPU collective implementation
  -> topology-aware GPU communication
  -> CUDA-stream-native synchronization/progress
  -> communication algorithms designed specifically for GPU collectives

MPI/UCX
  -> general-purpose MPI semantics
  -> CUDA-aware GPU-buffer support
  -> rc_mlx5 + GPUDirect / rendezvous zero-copy available
  -> protocol selected by message size and endpoint state
  -> not necessarily the best collective algorithm/schedule for this exact
     HPL-MxP GPU panel-broadcast critical path
~~~

Thus a healthy MPI transport does not imply that its broadcast path should beat
NCCL inside HPL-MxP.

## 3. The key HPL-MxP detail: positive percentages select the FIRST steps

NVIDIA documents `--use-mpi-panel-broadcast X` as using MPI for the **first X
percent of panel steps**. It is not a random X% sample of the factorization and
not a continuously blended bandwidth knob.

This matters enormously.

HPL's right-looking LU factorization repeatedly:

1. factors the next NB-wide panel;
2. broadcasts panel/U data;
3. updates a trailing submatrix;
4. repeats on a smaller trailing matrix.

The communication/update size depends on the current trailing dimension.
Early iterations operate on the largest remaining matrix; later iterations
shrink.

For the retained geometry:

~~~text
N  = 429056
NB = 3072

N / NB ~= 139.7
=> roughly 140 panel steps
~~~

So approximately:

~~~text
panel=5   -> MPI owns first ~7 steps
panel=10  -> MPI owns first ~14 steps
panel=25  -> MPI owns first ~35 steps
panel=50  -> MPI owns first ~70 steps
panel=100 -> MPI owns all steps
~~~

Those first steps are exactly the bandwidth-heavy part of the factorization.

This creates a strong mechanistic explanation for the observed shape:

> A small positive percentage does not hand MPI a few harmless small
> messages. It hands MPI the earliest and largest panel/update communication.

If NCCL is better matched to these large GPU-resident panel collectives, even
5% can produce a visible critical-path penalty.

## 4. Why message size is a credible part of the explanation

Several pieces of evidence support the large-message / collective-efficiency
interpretation.

### 4.1 The MPI path is healthy, so the regression is not a transport failure

Panel-10 Stage-C diagnostic:

~~~text
UCX:
  rc_mlx5
  rendezvous zero-copy rows = 693
  frag-host rows = 0
  TCP inter-node lanes = 0
  UCX WARN = 0

NCCL:
  backend = IBext_v11
  inter-node channel lines = 128
  GDRDMA-tagged = 128 / 128
  Socket channels = 0
  WARN = 0
~~~

This rules out the simplest bad-path explanations:

- no TCP fallback;
- no loss of GPU-direct capability;
- no host-staged large-message fallback;
- no fabric/link error.

MPI is slower here despite using a valid high-performance transport.

### 4.2 HPL-MxP's own component tests strongly favor NCCL for these GPU broadcasts

Every positive-policy run executes HPL-MxP's pre-matgen communication component
tests.

Representative panel-10 component timings:

~~~text
NCCL U broadcast       ~0.17 s
MPI U broadcast        ~6.02 s
second MPI U test      ~8.52 s
MPI U Sendrecv         ~8.56 s

NCCL L2 broadcast      ~0.19 s
MPI L2 broadcast       ~0.70 s
MPI L2 Sendrecv        ~0.70 s
~~~

These component-test numbers are **not LU timing** and must not be added to the
7.7-15.8 s LU phase.

Nevertheless, they are useful mechanistic evidence: on HPL-MxP's own GPU
communication test structures, the CUDA-aware MPI U-panel operations are far
more expensive than the NCCL U broadcast, while the smaller L2 operation has a
much narrower gap.

That pattern is qualitatively consistent with:

> NCCL has a major advantage on the large U-panel collective; the relative
> penalty is smaller on the smaller communication object.

This is supporting evidence, not a direct per-LU-step bandwidth measurement.

## 5. The result is not explained by compute or refinement

The main GEMM component timing stays essentially invariant:

~~~text
panel 0  GEMM AVG ~= 5.96 s
panel 5  GEMM AVG ~= 5.95 s
panel 10 GEMM AVG ~= 5.97 s
panel 15 GEMM AVG ~= 5.96 s
panel 20 GEMM AVG ~= 5.96 s
panel 25 GEMM AVG ~= 5.96 s
~~~

Likewise:

~~~text
IR = 0.29 s
iterations = 3
residual = 1.416310E-05
device memory = 135.254 GB
~~~

for every scored policy.

Therefore:

> The policy changes communication/synchronization behavior while leaving the
> compute engine and refinement regime intact.

This is exactly the signature expected from a panel-broadcast critical-path
effect.

## 6. A second likely cause: overlap/progress and collective semantics

Message size alone is probably not the full explanation.

NCCL is specialized for GPU collectives and integrates directly with CUDA
streams. HPL's panel broadcast lies on the critical path and is intentionally
overlapped with trailing-matrix work.

MPI/UCX has a different progress/completion model. A GPU buffer can still use
GPUDirect RDMA and yet incur worse critical-path behavior because of:

- collective algorithm choice;
- root/rank synchronization;
- host-side MPI progress;
- stream synchronization boundaries;
- readiness/completion semantics;
- less favorable overlap with GEMM/update work.

The 4B data supports this category of explanation:

~~~text
GEMM stays flat
but
LU expands dramatically
~~~

So the lost time is outside GEMM itself and appears as extra communication /
readiness / synchronization delay.

This is likely at least as important as raw link bandwidth.

## 7. Fabric evidence: useful, but do not overclaim it

There is a striking HCA pattern.

Panel 0 on g14:

~~~text
TX spread across all eight HCAs
rail CV ~= 0.58%
max/mean ~= 1.011
~~~

Positive policies progressively concentrate TX around mlx5_0 / mlx5_1:

~~~text
panel 5:  g14 CV = 71.83%
panel 10: g14 CV = 77.35%
panel 15: g14 CV = 81.97%
panel 20: g14 CV = 86.37%
panel 25: g14 CV = 90.85%
panel 50: g14 CV = 108.59%
panel 75: g14 CV = 118.99%
panel 100:g14 CV = 122.46%
~~~

This is consistent with MPI/UCX and NCCL exercising substantially different
collective/rank/HCA traffic structures.

However, whole-arm HCA counters include the pre-run HPL-MxP communication
component tests. Any positive panel policy also activates expensive MPI
component tests, so the abrupt positive-policy increase in total arm traffic
cannot be attributed directly to LU.

Therefore:

- rail-shape changes are real;
- the exact whole-arm traffic volume is contaminated by component tests;
- the data suggests a topology/collective-routing difference;
- it does **not** prove that rail imbalance itself caused the LU loss.

Also, the available `port_xmit_wait` counters generally decrease rather than
increase as MPI percentage rises on the HCAs where the counter is usable.
There are no new link/errors.

So the evidence does **not** support a simple "MPI overloads/congests the IB
fabric" explanation.

## 8. Why the curve is not perfectly monotonic

The broad trend is clear:

~~~text
more early steps on MPI
-> worse LU
~~~

But the exact fine curve is not monotonic:

~~~text
5  ~= 10
15 worse
20 worst in fine sweep
25 partially recovers
~~~

and 100 is slightly better than 75.

This is expected for this flag because it chooses a **discrete prefix of panel
steps**, not a continuously varying message size.

Changing the percentage changes exactly which panel iterations, process-grid
roots, local ownership states, and trailing dimensions use MPI.

Therefore small local reversals can arise from:

- block-cyclic root rotation;
- communicator/root placement;
- discrete panel count rounding;
- changing message size as the trailing matrix shrinks;
- overlap/readiness interactions.

The non-monotonicity is not evidence against the main conclusion because all
positive policies remain far below panel 0.

## 9. Cause ranking

### High confidence

1. **NCCL is substantially better matched to the GPU panel-broadcast critical
   path in this 2x8 topology.**

2. **Positive percentages assign MPI to the earliest/largest steps**, which
   makes the flag especially hostile to MPI if NCCL's advantage grows with
   collective size.

3. **The loss is communication/synchronization-side, not compute/IR-side.**
   GEMM, IR, memory, residual, and iterations remain effectively unchanged.

### Medium confidence

4. **NCCL likely provides better collective scheduling / CUDA-stream overlap
   than the MPI/UCX path.** The transport is healthy but the LU critical path
   is much worse.

5. **MPI and NCCL create different rail/rank traffic structures.** Positive
   policies strongly concentrate observed g14 traffic, which may contribute
   to poorer effective collective bandwidth/overlap.

### Not supported by the evidence

- broken GPUDirect RDMA;
- TCP fallback;
- host-staged large-message MPI;
- HCA/link faults;
- memory pressure;
- refinement regression;
- GEMM regression;
- simple IB congestion inferred from `port_xmit_wait`.

## 10. Dependency and campaign decision

Phase 4B closes with:

~~~text
use-mpi-panel-broadcast = 0
~~~

No positive MPI panel policy should be carried as a performance candidate into
Phase 4C.

The 5/10% policies are useful mechanism controls only; they are already ~8.4%
behind in LU, far beyond both local drift and the campaign materiality
threshold.

Dependency consequences:

- E06/E12 panel transport is resolved for the current 2x8 geometry/topology.
- E13 remains closed: no evidence justifies reopening UCX affinity.
- E25 can now pass a single retained panel policy into chunk/readiness tuning.
- Phase 4C should vary only `--u-panel-chunk-nbs` with panel broadcast fixed
  at 0.
- Scheduling dependencies remain downstream.

## 11. Recommended Phase 4C framing

Phase 4C should **not** form a panel-policy x chunk matrix.

Use only:

~~~text
--use-mpi-panel-broadcast=0
~~~

and test U-panel granularity around the retained:

~~~text
--u-panel-chunk-nbs=8
~~~

For the current geometry, the previously calculated validity constraint allows
at least:

~~~text
2, 4, 8, 16
~~~

The purpose is now narrowly:

> With the winning NCCL panel path fixed, can earlier/finer U-panel readiness
> improve overlap enough to reduce LU time, or is chunk=8 already on the useful
> plateau?

No new MPI panel-policy testing is justified unless a later geometry/topology
change reopens the communication dependency.
