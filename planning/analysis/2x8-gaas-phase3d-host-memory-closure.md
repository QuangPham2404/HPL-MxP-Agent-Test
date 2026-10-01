---
task_id: TASK-2X8-012
title: 2x8 GAAS Phase 3D Host / Memory Closure
analysis_id: 2x8-gaas-phase3d-host-memory-closure
status: COMPLETE
parent_task: TASK-2X8-011
created: 2026-10-01
last_updated: 2026-10-01
---

# Analysis — 2x8 GAAS Phase 3D Host / Memory Closure

## 1. Summary

TASK-2X8-012 directly closes the two remaining Phase-3D controls at the
retained 2x8 operating point.

Retain:

```text
--cuda-host-register-step = 2048
--call-dgemv-with-multiple-threads = 0
```

Phase 3 is ready to close. No upstream resweep is required.

The important new finding is that large host-register steps are not merely a
registration-timing control on this stack. At 4096/8192 they materially change
the observed memory/residency state and therefore IR. This creates a new
dependency, E40:

```text
host-register step -> effective FP64 residency / device headroom
```

E40 is inactive at the retained 2048 setting and does not block Phase 4.

The immutable 2x8 campaign baseline is 4.8037e+06 GFLOP/s.

## 2. Stage A — cuda-host-register-step

| Arm | Step | Overall | vs baseline | vs 2048 midpoint | LU s | IR s | Host GB | Device headroom |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| R0a | 2048 | 6.5311e+06 | +35.96% | -0.06% | 7.78 | 0.29 | 0.004 | 2.767 GB |
| R1 | 512 | 6.5578e+06 | +36.52% | +0.35% | 7.74 | 0.29 | 0.004 | 3.997 GB |
| R2 | 1024 | 6.5198e+06 | +35.72% | -0.23% | 7.79 | 0.29 | 0.004 | 3.587 GB |
| R3 | 4096 | 6.3877e+06 | +32.97% | **-2.25%** | 7.72 | **0.52** | **1.136** | 2.257 GB |
| R4 | 8192 | 6.1579e+06 | +28.19% | **-5.77%** | 7.76 | **0.79** | **4.418** | 2.257 GB |
| R0b | 2048 | 6.5384e+06 | +36.11% | +0.06% | 7.77 | 0.29 | 0.004 | 2.767 GB |

The 2048 controls differ by only 0.11%.

### 2.1 512-2048 is a performance plateau

512, 1024, and 2048 all retain:

```text
IR = 0.29 s
host allocation = 0.004 GB/process
3 refinement iterations
PASSED verification
```

Their score differences are sub-percent and do not correspond to meaningful
phase movement.

There is nevertheless a clear memory trend:

```text
step                 512      1024      2048
device consumption 134.023   134.433   135.254 GB/process
device headroom       3.997     3.587     2.767 GB/process
```

Thus 512/1024 are validated low-step **headroom fallbacks**, but not proven
performance winners.

Retain 2048 because it is the established/default control and changing to 512
would perturb the memory environment before Phase 4 without a material score
benefit.

### 2.2 4096/8192 cross a memory-residency threshold

The large-step points change regime:

```text
step          2048        4096        8192
host GB       0.004       1.136       4.418
device GB   135.254     135.762     135.762
IR s          0.29        0.52        0.79
score       ~6.535M       6.388M      6.158M
```

LU remains flat, so the regression is an IR/memory-state penalty rather than
an LU penalty. Iteration count remains three.

The exact allocator mechanism is not directly traced, so do not interpret the
reported host number byte-for-byte. The controlled observation is sufficient:
larger register steps alter memory allocation/headroom, host allocation appears,
IR rises, and the final score falls.

Constructor timing does not explain the loss: 4096/8192 both report about
0.16 s versus about 0.21-0.24 s for the 2048 controls.

## 3. Stage B — DGEMV

| Arm | DGEMV | Overall | vs baseline | vs zero midpoint | LU s | IR s |
|---|---:|---:|---:|---:|---:|---:|
| D0a | 0 | 6.5455e+06 | +36.26% | -0.10% | 7.76 | 0.29 |
| D1 | 128 | 6.5644e+06 | +36.65% | +0.19% | 7.73 | 0.29 |
| D2 | 512 | 6.5459e+06 | +36.27% | -0.09% | 7.76 | 0.29 |
| D3 | 2048 | 6.5456e+06 | +36.26% | -0.09% | 7.76 | 0.29 |
| D4 | 4096 | 6.5634e+06 | +36.63% | +0.18% | 7.74 | 0.29 |
| D5 | 8192 | 6.5586e+06 | +36.53% | +0.11% | 7.74 | 0.29 |
| D6 | 15360 | 6.5480e+06 | +36.31% | -0.06% | 7.75 | 0.29 |
| D7 | 30720 | 6.5564e+06 | +36.49% | +0.07% | 7.74 | 0.29 |
| D0b | 0 | 6.5579e+06 | +36.52% | +0.10% | 7.74 | 0.29 |

The zero controls differ by 0.19%. Every nonzero value lies within ±0.20% of
their midpoint.

Across the complete 0-30720 range:

```text
IR = 0.29 s
iterations = 3
host allocation = 0.004 GB/process
device consumption = 135.254 GB/process
device headroom = 2.767 GB/process
LU ~= 7.73-7.76 s
```

Therefore DGEMV is experimentally flat in this low-IR regime. Retain zero.

The constructor-time spikes at 128/512 (1.11/1.16 s) do not propagate into LU,
IR, score, memory, or arm wall-clock in a consistent direction. They are an
isolated setup observation and do not justify reopening/profiling DGEMV.

## 4. Cross-task consistency

TASK-2X8-011's final full-fill control on g12+g14 was 6.5373e+06 GFLOP/s with
IR=0.29 s and host allocation=0.004 GB/process.

TASK-2X8-012's default controls on g14+g15 are ~6.53-6.56e+06 with the same
IR and memory regime. This cross-allocation agreement strengthens the
conclusion that the retained Phase-3 state is stable.

The lower reported host-available memory on g14+g15 (~69-73 GB/process versus
~238 GB/process in TASK-2X8-011) did not alter the default memory regime or
score and therefore does not trigger another dependency.

## 5. Dependency checkpoint

### E17 — residency -> host-register step

**Resolved more strongly.**

A direct target-topology sweep now exists. Low/default steps are flat; large
steps are harmful because the memory regime changes. Retain 2048.

Reopen after a material N/residency/precision/interconnect change that creates
meaningful host staging.

### E40 — host-register step -> effective residency / memory headroom

**New: Strong, OBSERVED + MECHANISTIC.**

TASK-2X8-012 shows:

```text
larger register step
 -> larger observed runtime/device allocation
 -> lower device headroom
 -> host allocation appears
 -> IR rises
```

After a material register-step change, recheck host/device memory and IR.
Reopen fill-buffer/residency or N only if the retained memory regime actually
changes.

E40 is **inactive now** because 2048 is retained and reproduces the closed
Phase-3C regime.

### E16 — fill buffer

**Not reopened.** The same 2048 register-step and 3048 buffer used by
TASK-2X8-011 remain retained and reproduce the same full-residency state.

### E15 — residency -> useful N

**Not reopened.** No retained residency change occurred. Rejected 4096/8192
candidate regimes do not replace the retained operating point.

### E20 — host runtime -> DGEMV

**Closed for the current OMP=4 regime.** The direct 0-30720 sweep shows no
measurable benefit.

### E21 — N/residency -> DGEMV

**Closed for the retained N/full-residency regime.** Reopen only after a
material N/residency/IR change.

### E35/E36 — precision

Remain future reopen paths. A later precision change can alter convergence,
IR, workspaces, and residency, which can conditionally reopen DGEMV,
register-step, buffer, or N.

### E12/E13 — communication

**Unblocked.** No Phase-3 dependency blocks communication tuning.

## 6. Phase-3 closure

Retained Phase-3 stack:

```text
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row

gpu-affinity = 0:1:2:3:4:5:6:7
cpu-affinity = omitted
mem-affinity = omitted
ucx-affinity = omitted / automatic

OMP_NUM_THREADS = 4
OMP_PLACES = omitted
OMP_PROC_BIND = omitted
effective launcher policy = sockets / TRUE

fill-device = 1
fill-device-buffer-size = 3048
cuda-host-register-step = 2048
call-dgemv-with-multiple-threads = 0

sloppy-type = FP16
```

**Phase 3 is closed. No immediate dependency-driven resweep is required.**

## 7. Recommended next action

Proceed to **Phase 4 communication tuning** with the complete retained Phase-3
stack fixed.

If a later communication or precision experiment creates material VRAM
pressure, 512/1024 register-step are validated low-IR headroom fallback
candidates, but they must be introduced explicitly through E40 rather than
silently stacked into another experiment.
