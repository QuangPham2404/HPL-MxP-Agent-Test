---
task_id: TASK-010
title: 2x8 GAAS Geometry Re-closure after Host-Runtime Shift
analysis_id: 2x8-gaas-task010-geometry-reclosure
status: COMPLETE
parent_task: TASK-009
created: 2026-10-01
last_updated: 2026-10-01
---

# Analysis — 2x8 GAAS Geometry Re-closure after Host-Runtime Shift

## 1. Summary

TASK-010 tested whether the much faster verified host-runtime/IR regime from
TASK-009 moved the useful matrix-size operating point above the retained
`N=429056`.

It did not.

The five-point same-allocation sweep retained `N=429056` decisively:

| N | Overall GFLOP/s | vs N=429056 | vs original 2x8 baseline | LU GFLOP/s | LU s | IR s | IR/LU | Host memory MAX | Device headroom after matgen |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **429056** | **6.4431e+06** | control | **+34.13%** | 6.6784e+06 | 7.85 | **0.29** | **0.037** | **0.004 GB** | **2.767 GB** |
| 454656 | 5.9212e+06 | -8.10% | +23.26% | 6.9761e+06 | 8.98 | 1.60 | 0.178 | 15.024 GB | 2.257 GB |
| 504832 | 5.2147e+06 | -19.07% | +8.56% | 7.1739e+06 | 11.96 | 4.49 | 0.375 | 51.561 GB | 2.257 GB |
| 556032 | 5.0581e+06 | -21.50% | +5.30% | 7.6101e+06 | 15.06 | 7.60 | 0.505 | 95.340 GB | 2.257 GB |
| 606208 | 4.3901e+06 | -31.86% | -8.61% | **7.7508e+06** | 19.16 | **14.67** | **0.766** | **136.519 GB** | 2.257 GB |

All five candidates passed correctness with three iterative-refinement
iterations. The result is therefore not caused by failed convergence or a
change in iteration count.

The main conclusion is:

> TASK-009 created substantial IR headroom at `N=429056`, but that headroom
> is **not transferable uniformly to larger N**. `N=429056` remains at the
> useful edge of the device-resident FP64 regime. Moving to `N=454656`
> crosses a sharp residency boundary: device usage saturates, host memory
> allocation appears, and the cost per refinement iteration rises abruptly.
> Larger N continues to improve LU throughput, but the refinement/residency
> penalty grows much faster and dominates the end-to-end score.

TASK-010 therefore closes the E39 geometry revalidation with the same retained
geometry:

```text
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row
```

Steps B/C/D were correctly unnecessary.

## 2. Analysis

### 2.1 Why expecting a larger N was reasonable

TASK-009 changed the verified host-runtime regime at the retained N very
strongly. At `N=429056`, LU stayed around 7.7–7.9 s while IR fell to
approximately 0.29 s.

That suggested a reasonable hypothesis:

```text
larger N
  -> better LU efficiency
  -> accept some additional IR
  -> potentially higher total HPL-MxP score
```

This is exactly the tradeoff expressed by the campaign approximation:

```text
R_MxP ≈ P_LU / (1 + T_IR / T_LU)
```

If the new host-runtime regime had kept IR near 0.29 s while larger N improved
LU throughput, the larger-N points would indeed have won.

Using each TASK-010 point's measured LU time and LU throughput but
counterfactually holding IR at 0.29 s gives:

| N | Actual score | Arithmetic score if IR stayed 0.29 s | Hypothetical change vs N=429056 |
|---:|---:|---:|---:|
| 429056 | 6.4431e+06 | 6.440e+06 | ~0% |
| 454656 | 5.9212e+06 | 6.758e+06 | +4.9% |
| 504832 | 5.2147e+06 | 7.004e+06 | +8.7% |
| 556032 | 5.0581e+06 | 7.466e+06 | +15.9% |
| 606208 | 4.3901e+06 | 7.635e+06 | +18.5% |

This is not a predicted run; it is only a decomposition. It shows that the
original reasoning was sound. **The hypothesis failed because IR did not stay
cheap as N increased.**

### 2.2 LU does improve with N, but only moderately

The useful LU metric is throughput, not raw LU time. Raw LU time must increase
because a larger matrix performs much more work.

Across TASK-010:

```text
N:             429056 -> 454656 -> 504832 -> 556032 -> 606208
LU GFLOP/s:      6.678 ->  6.976 ->  7.174 ->  7.610 ->  7.751 million
```

Relative to `N=429056`:

- `N=454656`: N +5.97%, LU throughput +4.46%;
- `N=504832`: N +17.66%, LU throughput +7.42%;
- `N=556032`: N +29.59%, LU throughput +13.95%;
- `N=606208`: N +41.29%, LU throughput +16.06%.

So the expected LU-efficiency benefit is real. At the upper end the LU path is
about 16% faster in throughput terms.

The problem is that this gain is much smaller than the refinement penalty.

### 2.3 The IR penalty grows dramatically faster than the LU gain

IR time changes as:

```text
0.29 -> 1.60 -> 4.49 -> 7.60 -> 14.67 s
```

From `N=429056` to `606208`, N increases by about 41%, LU throughput
improves by about 16%, but IR time becomes about **50.6x** larger.

The score impact is cleanly visible through `IR/LU`:

```text
N=429056: IR/LU = 0.037
N=454656: IR/LU = 0.178
N=504832: IR/LU = 0.375
N=556032: IR/LU = 0.505
N=606208: IR/LU = 0.766
```

Equivalently, using the same score decomposition, the fraction of LU-only
throughput lost to the IR term rises approximately as:

| N | IR/LU | Effective IR tax on LU-only throughput |
|---:|---:|---:|
| 429056 | 0.037 | 3.6% |
| 454656 | 0.178 | 15.1% |
| 504832 | 0.375 | 27.3% |
| 556032 | 0.505 | 33.6% |
| 606208 | 0.766 | 43.4% |

This answers the central question directly: **yes, under this geometry the
effect of N on refinement cost is much stronger than the incremental LU
efficiency benefit once N leaves the retained residency regime.**

The first step alone demonstrates it:

```text
429056 -> 454656

N:             +5.97%
LU throughput: +4.46%
IR time:       0.29 -> 1.60 s  (~5.5x)
overall score: -8.10%
```

The tradeoff is therefore not a smooth "gain some LU, lose a little IR"
curve. It contains a sharp regime transition.

### 2.4 The sharp drop is explained by the FP64 residency cliff

The memory evidence aligns almost perfectly with the IR transition.

At `N=429056`:

```text
device consumption MAX = 135.254 GB/process
device headroom         = 2.767 GB/process
host consumption MAX    = 0.004 GB/process
IR                      = 0.29 s
```

At the very next point, `N=454656`:

```text
device consumption MAX = 135.762 GB/process
device headroom         = 2.257 GB/process
host consumption MAX    = 15.024 GB/process
IR                      = 1.60 s
```

For every still-larger N, device consumption remains essentially pinned at
~135.763 GB/process and device headroom remains ~2.257 GB/process, while host
memory consumption rises strongly:

```text
N=454656:  15.024 GB/process
N=504832:  51.561 GB/process
N=556032:  95.340 GB/process
N=606208: 136.519 GB/process
```

At the same time:

```text
IR = 1.60 -> 4.49 -> 7.60 -> 14.67 s
```

This is strong same-allocation evidence that the GPU has reached its practical
FP64-residency ceiling. Additional matrix demand increasingly moves into the
host-resident/staged regime, and refinement becomes much more expensive.

The exact host-memory number should not be interpreted as a byte-for-byte
measurement of only the spilled FP64 matrix; it includes the application's
reported host allocation. The mechanistic conclusion does not require that
assumption. The important observed pattern is:

1. device usage saturates;
2. host allocation appears and then grows strongly;
3. IR cost rises at the same boundary;
4. the number of refinement iterations remains fixed at three.

Therefore the rising IR is primarily a **higher cost per refinement
iteration**, consistent with the larger FP64 working set and host/device
staging/residency burden, rather than an algorithmic convergence failure.

### 2.5 What TASK-009 actually improved

TASK-009 should not be interpreted as having removed the N/residency penalty.
It improved the **host-runtime layer** that processes refinement work.

The cleanest historical comparison is the same `N=429056`, `NB=3072`,
4x4-row geometry from TASK-006:

```text
TASK-006 4x4 row:
  LU = 7.77 s
  IR = 1.50 s
  overall = 5.6860e+06

TASK-010 N=429056:
  LU = 7.85 s
  IR = 0.29 s
  overall = 6.4431e+06
```

These runs use different node pairs and the older run did not have the same
verified all-rank OpenMP contract, so the full cross-task delta is not a clean
one-variable measurement. Still, the phase movement is highly informative:
LU is essentially unchanged while IR is much lower under the verified current
runtime.

At larger N, the historical-to-current IR improvement rapidly shrinks. The
older N sweeps used 4x4 column order and different runtime/node conditions, so
these are only contextual comparisons, not isolated causal measurements:

```text
N=454656: old IR 2.75 -> current 1.60 s
N=504832: old IR 5.01 -> current 4.49 s
N=556032: old IR 7.45 -> current 7.60 s
N=606208: old IR 10.83 -> current 14.67 s
```

The useful interpretation is not that the new runtime becomes intrinsically
worse at large N. Rather:

> The host-runtime correction removes a large software/runtime penalty in the
> low-host-residency regime, but as N increases the intrinsic
> matrix/residency/staging workload becomes the dominant IR cost. The runtime
> improvement therefore changes the **IR floor/intercept** much more than it
> changes the steep **N/residency slope**.

This explains why TASK-009 created apparent "space" at `N=429056` without
moving the optimum.

### 2.6 Why N=429056 is a particularly strong operating point

The retained N is not simply the smallest tested point.

It combines three useful properties:

1. **Near-full device utilization for the FP64 matrix path.**
   Device headroom is only 2.767 GB/process, so the GPUs are being used
   aggressively.
2. **Essentially zero reported host allocation for this matrix regime.**
   The next tested N immediately enters a materially different host-resident
   regime.
3. **Enough N to preserve good LU efficiency.**
   LU throughput is already 6.6784e+06 GFLOP/s, while moving 41% higher in N
   produces only a further 16% LU-throughput gain.

So `N=429056` is located close to the knee of the curve: high enough to
amortize LU efficiently, but just below the refinement/residency cliff.

The fact that `N=454656` and `N=556032` are exact multiples of
`NB=3072` but are still much slower also confirms that N/NB divisibility is
not the explanation for this transition.

### 2.7 TASK-010 versus the campaign baseline

The retained TASK-010 control scores `6.4431e+06` GFLOP/s, **+34.13%**
over the immutable original 2x8 baseline `4.8037e+06`.

It is about 1.83% below TASK-009's `6.5632e+06` T=4/free control. TASK-009
ran on g13+g15 while TASK-010 ran on g12+g14, so this small cross-allocation
difference should not be interpreted as a regression or a new tuning effect.

TASK-010's purpose was geometry re-closure, not promotion of a new performance
record. The retained scientific configuration remains unchanged.

## 3. Dependency checkpoint

The dependency review is performed.

### E39 — host runtime/locality -> useful N / LU-IR operating point

**Resolved for the current verified host-runtime contract.**

TASK-009 correctly triggered the bounded N reopening. TASK-010 shows that the
new host runtime does not materially move the useful N region: `N=429056`
remains the clear leader.

The important refinement to E39 is that a host-runtime improvement need not
translate uniformly across N. It can sharply reduce the low-N IR floor while
the N-driven FP64-residency/staging cost remains steep.

### E14 / E15 — N <-> FP64 residency

**Strongly reconfirmed.**

TASK-010 gives especially clean evidence because the transition happens
between adjacent tested points:

```text
N=429056: host 0.004 GB, device headroom 2.767 GB, IR 0.29 s
N=454656: host 15.024 GB, device headroom 2.257 GB, IR 1.60 s
```

The retained N remains on the favorable side of the residency cliff.

### E07 — N -> NB

**Not triggered.**

N did not move materially, so the retained `NB=3072` result does not need a
new sweep.

### E09 / E10 — geometry -> process grid/order

**Not triggered.**

The retained N/NB geometry remains `429056/3072`, so the previously closed
4x4-row result remains valid. TASK-010 Steps C/D were correctly skipped.

### E18 / E19 — N/refinement work and host-runtime placement

**Remain closed for the retained operating point.**

TASK-009 already resolved the coordinated host-runtime group and TASK-010
returns to the same N. There is no N-driven reason to repeat OMP or CPU
affinity.

### E20 / E21 — DGEMV

The major host-runtime change technically reopened DGEMV as a conditional
dependency, but TASK-010 now shows that IR at the retained operating point is
only 0.29 s with `IR/LU=0.037`.

Even eliminating all IR time would improve the score by only about 3.6%; a
DGEMV flag can affect only part of that phase and has previously carried
threading/synchronization risk.

Therefore **do not spend the next experiment on DGEMV**. Keep the installed
default (`--call-dgemv-with-multiple-threads 0`) as the conditional control.
Reopen it only if a later precision, residency, grid/local-row, or host-runtime
change makes IR material again.

### E16 / residency buffer

TASK-010 does not create a reason to squeeze the fill-device reserve. At the
retained N the FP64 regime is already essentially fully device-resident while
maintaining 2.767 GB/process headroom. Reducing the reserve cannot recover a
meaningful host-resident fraction that is visible in the current evidence;
crossing the other direction into host residency is clearly expensive.

Keep the package/default buffer as the current control unless a later
residency/precision change alters headroom.

### E12 / E13 — panel transport

**Now unblocked.**

These dependencies were intentionally deferred until geometry, placement,
host runtime, and the reopened N operating point were stable. TASK-010 closes
the last of those upstream uncertainties.

### E37 — LU scheduling

No N-driven reopening occurs because N stayed at 429056. Scheduling remains
downstream of communication because a material panel-transport/readiness
change can reopen it through E26/E29.

## 4. Recommended next action

**Recommend exactly one next action: proceed to Phase 4 communication tuning
at the retained geometry/runtime stack.**

Carry forward:

```text
N = 429056
NB = 3072
grid/order = 4x4 row

gpu-affinity = 0:1:2:3:4:5:6:7
cpu-affinity = omitted
mem-affinity = omitted
ucx-affinity = omitted / automatic

OMP_NUM_THREADS = 4
OMP_PLACES = omitted
OMP_PROC_BIND = omitted
effective launcher policy = sockets / TRUE

fill-device = 1
sloppy-type = FP16
```

The first Phase-4 task should be a bounded communication/panel-policy screen
under this fixed stack, with same-allocation/bracketed controls. The purpose is
to attack the still-dominant LU path and close E12/E13 rather than spend runs
on a currently tiny 0.29 s refinement phase.

Do not combine the first communication task with DGEMV, N/NB/grid reopening,
CPU/OpenMP changes, precision, or LU scheduling.

**Human decision state:** TASK-010 analysis complete. Phase 4 communication is
recommended only; no new execution is authorized by this analysis.

## 5. Provenance and limitations

Primary evidence:

- `tasks/TASK-010.md`
- `experiments/2x8-GAAS/task010-geometry-reclosure/README.md`
- `experiments/2x8-GAAS/task010-geometry-reclosure/outputs/`
- `results/metrics.csv`
- `planning/analysis/2x8-gaas-phase1a-n-refine.md`
- `planning/analysis/2x8-gaas-phase2a-grid-order-matrix.md`
- `planning/analysis/2x8-gaas-phase3ab-host-runtime.md`
- `planning/dependency-graph/README.md`

Interpretation limits:

- TASK-010 itself is the clean causal N sweep: one allocation, only N varied.
- Cross-task comparisons to TASK-001/002/006/009 are contextual because node
  pairs, process order, and/or verified host-runtime state differ.
- The reported host-memory number is application-level host consumption, not
  a direct byte-level trace of FP64 transfers.
- No profiler is needed to establish the present conclusion: the same-run
  phase timing, iteration count, and memory-residency transition already
  explain the score shape. A trace would only be justified later for a more
  specific staging/transfer question.
