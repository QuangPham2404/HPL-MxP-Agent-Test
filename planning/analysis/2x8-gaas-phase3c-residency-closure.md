---
task_id: TASK-2X8-011
title: 2x8 GAAS Phase 3C Residency Closure
analysis_id: 2x8-gaas-phase3c-residency-closure
status: COMPLETE
parent_task: TASK-010
created: 2026-10-01
last_updated: 2026-10-01
---

# Analysis — 2x8 GAAS Phase 3C Residency Closure

## 1. Summary

TASK-2X8-011 isolates FP64 residency at the retained 2x8 operating point:

```text
N = 429056
NB = 3072
grid/order = 4x4 row
OMP_NUM_THREADS = 4
fill-device / Anq-device / fill buffer = only variables
```

The result is unusually clean.

At fixed N, the amount of mathematical work is fixed and the LU path is
essentially unchanged. As progressively more of the original FP64 matrix is
kept on the GPUs, iterative-refinement time falls monotonically and the final
HPL-MxP score rises monotonically.

| Residency mode | Host memory MAX | Device memory MAX | LU GFLOP/s | LU s | IR s | IR/LU | Overall GFLOP/s |
|---|---:|---:|---:|---:|---:|---:|---:|
| Anq=0 | 86.137 GB | 49.121 GB | 6.7360e+06 | 7.82 | 7.66 | 0.980 | 3.4031e+06 |
| Anq=24576 | 66.450 GB | 68.808 GB | 6.7848e+06 | 7.76 | 5.14 | 0.662 | 4.0811e+06 |
| Anq=49152 | 46.762 GB | 88.496 GB | 6.7757e+06 | 7.77 | 3.60 | 0.463 | 4.6299e+06 |
| Anq=73728 | 27.075 GB | 108.183 GB | 6.7778e+06 | 7.77 | 2.36 | 0.304 | 5.1971e+06 |
| Anq=98304 | 7.387 GB | 127.871 GB | 6.7857e+06 | 7.76 | 1.10 | 0.142 | 5.9457e+06 |
| **fill-device=1, 3048 MB** | **0.004 GB** | **135.254 GB** | **~6.77e+06** | **~7.78** | **0.29** | **0.037** | **~6.53e+06** |

The full-fill controls were highly stable:

```text
F0 = 6.5296e+06
F1 = 6.5238e+06
spread = 0.09%
full-fill reference = 6.5267e+06
```

The best partial-residency point, `Anq-device=98304`, is still **8.90% below**
the full-fill reference.

Therefore Phase 3C closes with:

```text
--fill-device 1
--fill-device-buffer-size 3048
--Anq-device irrelevant/overridden under fill-device=1
```

The buffer bracket further shows that 2048 and 3048 MB are effectively the
same operating regime, while 4096 MB begins to displace FP64 data toward host
memory and raises IR:

| Buffer | Overall GFLOP/s | LU s | IR s | Host memory MAX | Device headroom |
|---:|---:|---:|---:|---:|---:|
| 2048 | 6.5269e+06 | 7.78 | 0.29 | 0.004 GB | 2.767 GB |
| **3048** | **6.5373e+06** | **7.77** | **0.29** | **0.004 GB** | **2.767 GB** |
| 4096 | 6.3963e+06 | 7.79 | 0.44 | 0.520 GB | 3.280 GB |

2048 is only 0.16% below 3048, while 4096 is 2.16% below 3048. The default
3048 MB reserve is retained because it is inside the fast/full-residency
plateau and is the more conservative established control.

## 2. What this proves about the LU + IR balance

### 2.1 TASK-010 and TASK-2X8-011 answer complementary questions

TASK-010 varied N. That changes several things simultaneously:

```text
N
 -> credited work
 -> LU geometry / efficiency
 -> FP64 footprint
 -> residency / staging
 -> IR cost
```

TASK-2X8-011 instead fixes N and therefore fixes the credited work. It changes
only how much of the original FP64 matrix is device-resident.

That gives a much cleaner causal experiment:

```text
same N / same work
same NB / grid / runtime
same LU path
        |
        v
change FP64 residency only
        |
        v
IR time changes strongly
        |
        v
final score changes strongly
```

This confirms the campaign interpretation that end-to-end HPL-MxP performance
is governed by the combined LU + IR time, not by LU throughput alone.

### 2.2 LU is essentially invariant across the residency sweep

Across A0-A4 plus full fill:

```text
LU time:
7.82 -> 7.76 -> 7.77 -> 7.77 -> 7.76 -> ~7.78 s

LU GFLOP/s:
6.7360 -> 6.7848 -> 6.7757 -> 6.7778 -> 6.7857 -> ~6.77 million
```

The entire LU-throughput spread is below about 0.75%.

Therefore the large movement in final performance cannot be explained by LU.

This is important because it separates two concepts that were coupled in the
N sweep:

- larger N can improve LU efficiency;
- residency controls do not materially improve LU at the retained N.

Residency is primarily controlling the cost of iterative refinement.

### 2.3 IR tracks host/device residency almost monotonically

The memory transition is smooth and directly aligned with IR:

```text
Anq       host GB     device GB     IR s
0          86.137       49.121      7.66
24576      66.450       68.808      5.14
49152      46.762       88.496      3.60
73728      27.075      108.183      2.36
98304       7.387      127.871      1.10
full fill   0.004      135.254      0.29
```

Every arm still performs exactly three refinement iterations. The difference is
therefore the **cost per refinement iteration**, not a change in convergence
count.

The mechanism is consistent with the expected FP64 path: as more of the
original matrix remains on the GPUs, less host-resident data must participate
in residual/refinement staging, so IR becomes cheaper.

The application-reported host/device memory numbers are allocation/headroom
evidence, not byte-level transfer traces. The causal conclusion does not
require a byte-for-byte interpretation because the same-allocation monotonic
relationship among residency setting, memory displacement, IR time, and final
score is already strong.

### 2.4 The simple score decomposition explains the entire curve

The campaign approximation is:

```text
R_MxP ~= P_LU / (1 + T_IR / T_LU)
```

Using the measured LU throughput/time and IR time predicts the observed scores
to within about 0.05% for the residency curve.

For example:

```text
Anq=0:
P_LU = 6.7360M
IR/LU = 7.66 / 7.82 ~= 0.980
predicted score ~= 3.403M
observed score  = 3.4031M

full fill:
P_LU ~= 6.77M
IR/LU = 0.29 / 7.78 ~= 0.037
predicted score ~= 6.53M
observed score  ~= 6.53M
```

So the final-score curve is almost completely explained by a nearly fixed LU
rate multiplied by a progressively smaller IR penalty.

This is the cleanest direct validation so far of the campaign's LU+IR model.

## 3. Relationship to TASK-010

TASK-010 established that increasing N beyond 429056 improves LU throughput
but crosses the FP64 residency boundary and causes IR to rise much faster.

TASK-2X8-011 now shows the other side of the same mechanism at fixed N:

> If the FP64 matrix is deliberately moved back toward host memory without
> changing N, LU stays almost unchanged and IR rises strongly.

Together the two tasks give a coherent causal picture:

```text
                 more useful LU work / efficiency
larger N  -------------------------------------------->
    |
    | increases FP64 footprint
    v
less practical device residency
    |
    v
more host-resident/staged refinement work
    |
    v
larger IR time
    |
    v
end-to-end score falls once IR growth exceeds the LU gain
```

TASK-010 showed the transition by increasing matrix size.

TASK-2X8-011 reproduces the same performance mechanism directly by changing
residency while holding matrix size fixed.

This substantially strengthens E14/E15: the N optimum is not an arbitrary
numerical peak. It is tied to the point where the useful LU/work benefit can
still coexist with near-complete FP64 device residency.

## 4. Buffer interpretation

The buffer is not behaving like a smooth fine-tuning knob. It is primarily a
residency/headroom policy.

### 4.1 2048 and 3048 MB are one practical plateau

2048 and 3048 produce essentially identical observations:

```text
buffer       2048          3048
score        6.5269M       6.5373M
IR           0.29 s        0.29 s
host         0.004 GB      0.004 GB
device       135.254 GB    135.254 GB
headroom     2.767 GB      2.767 GB
```

The score difference is only -0.16% for 2048 versus 3048.

The unchanged reported device allocation/headroom despite the different
requested reserve suggests that both values map to the same practical
full-residency allocation state under this N/package/workspace combination.
No finer buffer search is justified.

### 4.2 4096 MB begins to sacrifice useful residency

At 4096 MB:

```text
host allocation: 0.004 -> 0.520 GB/process
device use:      135.254 -> 134.739 GB/process
IR:              0.29 -> 0.44 s
overall:         6.5373M -> 6.3963M  (-2.16%)
LU:              essentially unchanged
```

This is the same residency mechanism at smaller scale: reserving more VRAM
forces a measurable amount of FP64 data away from the device, which increases
IR while leaving LU nearly unchanged.

4096 remains correct and safe, so this is not a correctness cliff. It is the
first tested point where the conservative reserve is large enough to reduce
useful FP64 residency and measurably hurt end-to-end performance.

### 4.3 Retain 3048 rather than 2048

Although 2048 and 3048 are performance-equivalent, retain the existing 3048 MB
default because:

- it already produces effectively full FP64 residency at N=429056;
- it has the same measured IR and memory state as 2048;
- 2048 provides no measurable performance benefit;
- 3048 retains more nominal workspace reserve and is the established package
  control.

Therefore there is no reason to trade away nominal safety reserve for a
sub-noise performance difference.

## 5. Retained Phase-3C configuration

Retain:

```text
--fill-device 1
--fill-device-buffer-size 3048
--Anq-device = irrelevant/overridden while fill-device=1
```

At the retained geometry this gives:

```text
host consumption ~= 0.004 GB/process
device consumption ~= 135.254 GB/process
post-matgen device headroom ~= 2.767 GB/process
IR ~= 0.29 s
IR/LU ~= 0.037
```

The same-allocation full-fill results are around 6.53e+06 GFLOP/s, about
35.9-36.1% above the immutable original 2x8 baseline of 4.8037e+06 GFLOP/s.
This is contextual campaign performance, not a new baseline promotion.

## 6. Dependency checkpoint

### E14 — N -> FP64 residency

**Strengthened and closed at the current N.**

TASK-010 showed that increasing N crosses the residency cliff. TASK-2X8-011
now independently shows that reducing residency at fixed N recreates the same
IR/end-to-end penalty while LU remains flat.

### E15 — FP64 residency -> feasible/useful N

**No N reopening is triggered.**

The task retains the same full-fill residency mode that was already used when
TASK-010 reclosed N=429056. Therefore the residency regime has not materially
changed and E15 does not require another N sweep.

If a later task changes precision or residency materially, E15 remains active
and N must be reconsidered then.

### E16 — residency mode -> fill buffer

**Resolved for the current N/NB/release.**

The useful safe region includes 2048-3048 MB. 4096 MB is valid but measurably
slower because it begins to displace FP64 residency. Retain 3048 MB.

### E17 — residency / host-resident fraction -> host-register step

**Keep closed at the default 2048.**

Under the retained full-fill control, application-reported host consumption is
only ~0.004 GB/process. The mechanism that host registration is intended to
optimize is therefore essentially absent. A new register-step sweep has very
low expected value.

Reopen only after a later material residency/interconnect change creates
meaningful host-resident FP64 staging.

### E20 / E21 — host runtime/residency -> DGEMV partition

**Keep the current DGEMV default closed for Phase 3.**

The retained IR is only ~0.29 s with IR/LU ~0.037. TASK-2X8-011 confirms that
the way to keep solver cost small is high FP64 residency; there is no current
evidence of a material solver-side host bottleneck worth a DGEMV sweep.

Per E35, precision changes later can reopen solver/DGEMV behavior.

### E12 / E13 — communication

Still unblocked. Residency is now also closed upstream, so communication can
be studied without an unresolved memory-policy variable.

## 7. Phase-3 closure consequence

The blueprint's Phase 3D controls are explicitly conditional:

- tune `--cuda-host-register-step` only with material host-resident staging;
- tune `--call-dgemv-with-multiple-threads` only with material solver cost.

TASK-2X8-011 gives the opposite conditions:

```text
host-resident amount ~= 0.004 GB/process
IR ~= 0.29 s
IR/LU ~= 0.037
```

Therefore **no additional Phase-3D performance sweep is justified in the
current regime**.

Phase 3 can close with the defaults:

```text
--cuda-host-register-step = 2048
--call-dgemv-with-multiple-threads = 0
```

This is not a claim that these are universal optima. It is a conditional
closure: their mechanisms are currently too small to warrant tuning, and both
must be reconsidered after an upstream change that materially increases
host-resident FP64 data or refinement work.

## 8. Recommended next action

**Proceed to Phase 4 communication tuning** with the fully closed Phase-3
stack:

```text
N = 429056
NB = 3072
4x4 row

gpu-affinity = identity
cpu-affinity = omitted
mem-affinity = omitted
ucx-affinity = omitted / automatic

OMP_NUM_THREADS = 4
OMP_PLACES = omitted
OMP_PROC_BIND = omitted

fill-device = 1
fill-device-buffer-size = 3048
cuda-host-register-step = 2048
call-dgemv-with-multiple-threads = 0

sloppy-type = FP16
```

The next experiment should target communication only. No N/NB/grid/runtime/
residency/DGEMV change is justified before that communication study.
