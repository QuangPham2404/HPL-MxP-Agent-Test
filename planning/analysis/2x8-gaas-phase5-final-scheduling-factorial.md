---
task_id: TASK-2X8-017
title: 2x8 GAAS Phase 5 Final Scheduling Factorial Analysis
analysis_id: 2x8-gaas-phase5-final-scheduling-factorial
status: ANALYSIS_COMPLETE_DEPENDENCY_REVIEW_PENDING
created: 2026-10-02
last_updated: 2026-10-02
---

# Analysis — 2x8 GAAS Phase 5 Final Scheduling 2^3 Factorial

## 1. Quick semantics of the three flags

Tuple order is `(F,T,S)`.

### F — `--prioritize-factorization`

F=1 makes GEMM updates wait for the broader panel-factorization dependency.

Intuitively:

> protect the dependency-producing factorization path from otherwise-ready
> trailing GEMMs.

The retained tuning guide treats this as the broader scheduling gate; it covers
the whole factorization path, including the U-side TRSM dependency.

### T — `--prioritize-trsm`

T=1 makes GEMMs wait specifically for the U-side triangular solve (TRSM).

Intuitively:

> protect the U-producing triangular solve from otherwise-ready trailing GEMMs.

This is narrower than F. F protects the broader factorization path; T protects
only the TRSM portion.

### S — `--use-separate-stream-for-gemm`

S=1 runs GEMM updates on a dedicated CUDA stream.

Intuitively:

> give GEMM its own GPU work queue so it can overlap with independent panel,
> communication, and dependency-producing work when dependencies allow.

S creates concurrency. F/T decide how that concurrency is constrained so the
large GEMMs do not run ahead of work that feeds the LU critical path.

## 2. Result table

A001 control midpoint:

- overall = 6.8271e+06 GFLOP/s
- LU = 7.0921e+06 GFLOP/s
- control spread = 0.285% overall / 0.265% LU

| F | T | S | Overall GFLOP/s | Delta vs 001 midpoint | LU GFLOP/s | Delta LU | LU s |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 0 | 6.8589e+06 | +0.47% | 7.1258e+06 | +0.48% | 7.39 |
| 0 | 0 | 1 | ~6.8271e+06 | control | ~7.0921e+06 | control | ~7.43 |
| 0 | 1 | 0 | 6.7201e+06 | -1.57% | 6.9762e+06 | -1.63% | 7.55 |
| 0 | 1 | 1 | 6.8686e+06 | +0.61% | 7.1363e+06 | +0.62% | 7.38 |
| 1 | 0 | 0 | 6.8366e+06 | +0.14% | 7.1018e+06 | +0.14% | 7.41 |
| 1 | 0 | 1 | **7.2398e+06** | **+6.05%** | **7.5380e+06** | **+6.29%** | **6.99** |
| 1 | 1 | 0 | 6.7228e+06 | -1.53% | 6.9792e+06 | -1.59% | 7.54 |
| 1 | 1 | 1 | 7.1904e+06 | +5.32% | 7.4853e+06 | +5.54% | 7.03 |

Every arm PASSED with:

- IR = 0.29 s;
- 3 refinement iterations;
- normalized residual = 1.416310E-05;
- unchanged host/device memory regime.

Therefore the performance differences are isolated to LU scheduling rather than
refinement, correctness, or memory.

## 3. The dominant interaction is F x S

The factorial's strongest result is not an independent F effect or an
independent S effect. It is their interaction.

### Effect of S at each priority state

| F | T | S: 0 -> 1 overall effect | LU effect |
|---:|---:|---:|---:|
| 0 | 0 | -0.32% | -0.34% |
| 0 | 1 | +2.21% | +2.30% |
| 1 | 0 | **+5.90%** | **+6.14%** |
| 1 | 1 | **+6.96%** | **+7.25%** |

With no priority policy, a separate GEMM stream is neutral/slightly negative.

Once a dependency-producing path is protected, the separate stream becomes
useful.

### Effect of F at each stream/TRSM state

| T | S | F: 0 -> 1 overall effect | LU effect |
|---:|---:|---:|---:|
| 0 | 0 | -0.33% | -0.34% |
| 0 | 1 | **+5.90%** | **+6.15%** |
| 1 | 0 | +0.04% | +0.04% |
| 1 | 1 | **+4.69%** | **+4.89%** |

This is even clearer:

> Factorization priority does essentially nothing when GEMM shares the ordinary
> stream. Factorization priority becomes a ~5-6% lever only when GEMM has its
> own stream.

The mechanical factorial summary also identifies F x S as the dominant positive
pairwise interaction contrast:

- F x S overall contrast = +186,100 GFLOP/s
- T x S = +58,750 GFLOP/s
- F x T = -14,050 GFLOP/s

The interaction, not either flag in isolation, explains the best result.

## 4. Why F x S is synergistic

A useful simplified blocked-LU picture is:

```text
panel factorization / dependency work
              |
              v
           U-TRSM
              |
              v
       panel/U readiness
              |
              v
   communication / consumption
              |
              v
      large trailing GEMMs
```

Large GEMMs are throughput work. Panel/factorization/TRSM work produces the
dependencies needed to advance the LU step.

### S=0: limited concurrency

With GEMM on the ordinary stream, execution is already strongly ordered.

Changing F from 0 to 1 mostly changes ordering inside an execution path that is
already serialized:

```text
000 -> 100
overall: -0.33%
LU:      -0.34%
```

There is little useful concurrency for F to regulate.

### S=1 without F: concurrency can backfire

Putting GEMM on another stream creates a chance to overlap work:

```text
panel/factorization stream:  F1 -------- F2 -------- F3
GEMM stream:                    GGGGGGGGG   GGGGGGGGG
```

But the next LU step still depends on factorization-side results becoming ready.

If a large GEMM is allowed to run aggressively while that dependency-producing
work is still pending, the attempted overlap can become self-defeating:

```text
start GEMM concurrently
        |
        v
GEMM occupies/competes for GPU scheduling resources
        |
        v
factorization-side dependency becomes ready later
        |
        v
next LU step eventually has to wait for that dependency anyway
        |
        v
the pipeline stalls after paying the cost of the poorly scheduled overlap
```

So the intuition is:

> S tries to "sneak in" GEMM concurrency, but without a priority rule that
> concurrency can delay the very factorization dependency that later LU work
> needs.

That is consistent with:

```text
000 -> 001
overall: -0.32%
LU:      -0.34%
```

More concurrency is not automatically better if it interferes with the
critical dependency chain.

### F=1 plus S=1: keep the overlap, protect the dependency

With both enabled, the intended behavior is conceptually:

```text
panel/factorization stream:  F1 ---- F2 ---- F3
                                  \      \
GEMM stream:                 GGGGG  GGGGG  GGGGG
                               ^      ^
                               |      |
                      GEMM is constrained where
                      factorization must progress
```

The important point is that F does **not** mean "finish all factorization before
allowing GEMM." GEMM can still use its separate stream and overlap whenever the
dependency structure allows it.

Instead, the interpretation is:

1. S exposes concurrency by giving GEMM an independent work queue.
2. F protects factorization-side dependency progress at the points where the LU
   pipeline needs it.
3. Once those dependencies are satisfied, GEMM can continue to overlap with
   independent work.

So the combination is:

```text
separate stream
    = create concurrency

factorization priority
    = stop that concurrency from delaying a critical LU dependency

both together
    = useful overlap instead of overlap that later causes a dependency stall
```

That explains the large conditional effect:

```text
F effect with S=0:
000 -> 100 ~= no change

F effect with S=1:
001 -> 101 ~= +6%
```

This is the strongest mechanism consistent with the factorial.

### Black-box boundary

The NVIDIA HPL-MxP container does not expose the exact implementation of this
priority policy. We know the logical scheduling intent and the measured LU-side
interaction, but we do **not** know exactly whether NVIDIA implements it through:

- CUDA stream priorities;
- CUDA events/waits;
- explicit synchronization;
- altered enqueue order;
- another internal dependency scheduler;
- or some combination of these.

Likewise, "factorization priority" should be treated as a logical description of
the broader factorization-side dependency policy, not as proof that one monolithic
"factorization kernel" is given hardware priority.

Therefore "GEMM competes for GPU resources and delays factorization" is the
strongest mechanism-level interpretation of the factorial, not a directly
observed implementation fact. Nsight Systems would be required to locate the
exact waits, stream interactions, and resource-contention pattern.

## 5. TRSM priority behaves differently

T is not a positive standalone tuning lever in this matrix.

Conditional T effects:

| F | S | T: 0 -> 1 overall effect | LU effect |
|---:|---:|---:|---:|
| 0 | 0 | -2.02% | -2.10% |
| 0 | 1 | +0.47% | +0.49% |
| 1 | 0 | -1.67% | -1.73% |
| 1 | 1 | -0.68% | -0.70% |

So:

- with S=0, T clearly hurts;
- with S=1 and F=0, T becomes roughly neutral/slightly positive;
- with F=1 and S=1, T is slightly harmful.

The simple main-effect average is therefore negative.

### Why

T protects only the narrower U-TRSM stage.

If TRSM is not the true dominant readiness bottleneck, forcing GEMMs to wait for
it can delay useful update work without advancing the overall panel critical
path enough to compensate.

A separate GEMM stream mitigates that cost because independent GEMM work can be
scheduled more flexibly after the TRSM dependency is satisfied. That is why:

```text
010 -> 011
S gives +2.21% overall
```

But `011` itself is only +0.61% over the retained 001 control.

Therefore this should not be interpreted as "T becomes a strong winner with S."
A better interpretation is:

> S rescues an otherwise harmful TRSM-priority schedule.

## 6. Why 101 beats 111

This is the most informative comparison for T:

```text
101 = F=1, T=0, S=1
111 = F=1, T=1, S=1
```

Measured:

- 101 overall = 7.2398e+06
- 111 overall = 7.1904e+06
- 111 vs 101 = about -0.68%

LU:

- 101 = 7.5380e+06
- 111 = 7.4853e+06
- about -0.70%

The tuning guide's semantic distinction explains this naturally:

- F protects the broader factorization path;
- that broader path already includes the U-side TRSM dependency;
- T separately protects only TRSM.

Therefore once F is already enabled, T adds little new critical-path
protection. It can instead add another scheduling constraint/wait.

That makes T redundant or mildly over-constraining on top of F.

Hence the cleanest interpretation is:

```text
F + S = strong synergy
T     = unnecessary once F + S is active
```

## 7. Evidence that this is scheduling, not raw compute/network

The normal component-test timings are nearly invariant across the factorial:

- GEMM component test ~5.95 s;
- NCCL U broadcast ~0.09 s;
- NCCL L2 broadcast ~0.18 s.

These component tests occur outside the measured LU and must not be summed into
LU time, but their stability shows there is no gross change in standalone GEMM
or NCCL behavior.

At the same time:

- LU moves from ~7.4-7.5 s down to 6.99 s;
- IR remains exactly 0.29 s;
- residual and iterations are identical;
- memory is identical;
- no HCA error state appears.

That pattern strongly supports a change in ordering/overlap on the LU critical
path rather than faster kernels, faster networking, memory pressure, or solver
behavior.

## 8. Cross-check against historical evidence

The result is consistent with older single-node evidence:

- factorization priority previously helped materially;
- separate GEMM stream previously helped when factorization priority was
  already enabled;
- the historical experiments did not fully cross F x S.

TASK-2X8-017 closes that missing interaction cleanly on the current multinode
stack: factorization priority and separate GEMM stream are strongly
complementary.

TRSM priority again fails to add on top of factorization priority, consistent
with the earlier observation that the broader factorization dependency is the
more important path.

## 9. Current Phase-5 interpretation

The strongest tested scheduling configuration is:

```text
--prioritize-factorization = 1
--prioritize-trsm = 0
--use-separate-stream-for-gemm = 1
```

Measured A101:

- overall = 7.2398e+06 GFLOP/s;
- +6.05% versus the retained 001 midpoint;
- LU = 7.5380e+06 GFLOP/s;
- +6.29% versus the retained 001 midpoint;
- LU time = 6.99 s;
- IR = 0.29 s;
- PASSED with unchanged residual/iterations.

A111 is the nearest strong alternative but is lower by ~0.7%, and its extra
TRSM priority has no demonstrated benefit.

This analysis does not yet close Phase 5. The blueprint's mandatory Phase-5
dependency-review checkpoint remains pending human direction before the final
confirmation task is created.
