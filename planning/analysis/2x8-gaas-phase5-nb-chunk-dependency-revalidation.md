---
task_id: TASK-2X8-018
title: 2x8 GAAS Phase 5 NB × U-Panel Chunk Dependency Revalidation Analysis
analysis_id: 2x8-gaas-phase5-nb-chunk-dependency-revalidation
status: COMPLETE
parent_task: TASK-2X8-017
created: 2026-10-03
last_updated: 2026-10-03
---

# Analysis — TASK-2X8-018: Phase 5 NB × U-Panel Chunk Dependency Revalidation

## 1. Executive conclusion

TASK-2X8-018 resolves the Phase-5 dependency reopening created after
TASK-2X8-017 selected scheduler 101:

~~~text
prioritize-factorization = 1
prioritize-trsm = 0
use-separate-stream-for-gemm = 1
~~~

The result is clean:

1. **NB=3072 remains the retained block size.** It is the best NB at every
   chunk value shared with competing NBs. The old 2048-3072 near-tie does not
   survive under the final stack: the best NB=2048 point is 3.85% below the
   NB=3072/chunk=4 control midpoint overall.
2. **Chunk is now a broad plateau at NB=3072.** All tested valid values
   2/4/8/16 lie within about 1.1% overall. Chunk 4 and chunk 8 are effectively
   identical: 7.2303e+06 versus 7.2296e+06 GFLOP/s, a 0.01% difference.
3. **NB × chunk interaction is real globally, but not strategically active at
   the retained NB.** The preferred chunk changes across NB values and the
   matrix records many order reversals, validating the decision to use a joint
   matrix rather than a sequential sweep. However, NB=3072 dominates regardless
   of chunk, so no alternate NB/chunk branch survives.
4. **No retained memory/refinement regime changes.** The retained 3072 points
   remain at IR=0.29 s, host allocation=0.004 GB/process, and device
   consumption=135.254 GB/process. Larger or smaller rejected NBs can change
   host/device allocation and IR, but those regimes are not retained.
5. **No further scored confirmation run is scientifically necessary.** The
   exact final candidate NB=3072/chunk=4/scheduler101 now has three scored
   observations across two PBS jobs:
   - TASK-2X8-017 A101: 7.2398e+06 GFLOP/s;
   - TASK-2X8-018 opening control: 7.2303e+06;
   - TASK-2X8-018 closing control: 7.2406e+06.
   The TASK-2X8-018 control midpoint is 7.23545e+06, only 0.06% below
   TASK-2X8-017 A101. The TASK-2X8-018 opening/closing spread is only 0.1425%
   overall and 0.1541% LU.

The dependency checkpoint therefore re-closes E27/E28 and does not reopen any
earlier phase.

Recommended next action: **formally close Phase 5 with the retained final
stack; do not run another benchmark task.**

## 2. Measurement quality

TASK-2X8-018 provides a strong same-allocation matrix:

~~~text
job = 77344.gaas
nodes = hpc-gaas-g14 + hpc-gaas-g15
22 / 22 arms valid
all PASSED
all settings echoes PASS
all scheduler flags = 101
no HCA error/discard/recovery deltas
~~~

The retained control bracket is especially tight:

| Metric | C3072K4a | C3072K4b | Midpoint | Spread |
|---|---:|---:|---:|---:|
| Overall GFLOP/s | 7.2303e+06 | 7.2406e+06 | 7.23545e+06 | 0.1425% |
| LU GFLOP/s | 7.5266e+06 | 7.5382e+06 | 7.5324e+06 | 0.1541% |
| LU time | 7.00 s | 6.99 s | ~7.00 s | negligible |
| IR | 0.29 s | 0.29 s | 0.29 s | none |
| Iterations | 3 | 3 | 3 | none |
| Residual | 1.416310E-05 | 1.416310E-05 | same | none |

The midpoint is +50.62% over the immutable original 2x8 baseline
4.8037e+06 GFLOP/s.

The cross-task reproduction is also unusually strong:

~~~text
TASK-2X8-017 A101 overall = 7.2398e+06
TASK-2X8-018 control midpoint = 7.23545e+06

difference = -0.06%
~~~

Therefore the conclusions below are not being driven by allocation drift.

## 3. NB result

### 3.1 Best valid point at each NB

| NB | Best tested chunk | Best overall GFLOP/s | Delta vs 3072/4 midpoint |
|---:|---:|---:|---:|
| 1024 | 16 | 5.7008e+06 | -21.21% |
| 2048 | 8 | 6.9567e+06 | -3.85% |
| **3072** | **4** | **7.2303e+06** | **-0.07% vs midpoint** |
| 4096 | 8 | 6.5382e+06 | -9.64% |
| 5120 | 4 | 6.4324e+06 | -11.10% |
| 6144 | 4 | 6.0386e+06 | -16.54% |

NB=3072 is not merely a narrow numerical winner. It wins at every chunk value
where a direct cross-NB comparison exists:

~~~text
chunk 2:  3072 > 4096 > 5120 > 6144
chunk 4:  3072 > 2048 > 4096 > 5120 > 6144
chunk 8:  3072 > 2048 > 4096 > 5120 > 6144 > 1024
chunk 16: 3072 > 2048 > 4096 > 5120 > 6144 > 1024
~~~

This removes the main concern behind E28. If another NB had won, the
factorization/TRSM/stream factorial would have been outside its retained
geometry and would need reopening. No such geometry change occurs.

### 3.2 The former 2048-3072 plateau is no longer the final-stack plateau

Phase 1B found NB=2048 and NB=3072 only 0.17% apart under its earlier control
stack.

Under the current final stack, the best NB=2048 point is:

~~~text
NB=2048, chunk=8
overall = 6.9567e+06
LU      = 7.3086e+06
IR      = 0.36 s
~~~

Relative to the current 3072/4 control midpoint:

~~~text
overall = -3.85%
LU      = -2.97%
~~~

So the current evidence supports a real retained NB=3072 region rather than
the earlier broad 2048-3072 tie.

This task does not isolate which intervening stack change created that
separation, so it should not be described as a pure scheduler×NB factorial
effect. It is nevertheless the correct final-stack dependency result.

## 4. Chunk result

At retained NB=3072:

| Chunk | Overall GFLOP/s | Delta vs 3072/4 midpoint | LU GFLOP/s | IR |
|---:|---:|---:|---:|---:|
| 2 | 7.1815e+06 | -0.75% | 7.4754e+06 | 0.29 s |
| **4** | **7.2303e+06** | **-0.07%** | 7.5266e+06 | 0.29 s |
| 8 | 7.2296e+06 | -0.08% | **7.5274e+06** | 0.29 s |
| 16 | 7.1564e+06 | -1.09% | 7.4472e+06 | 0.29 s |

The complete spread is only 1.03% overall, below the campaign's 2% materiality
convention.

Therefore the correct Phase-5 reading is:

> Under scheduler 101 at NB=3072, chunk 2-16 is a performance plateau, with
> chunk 4 and 8 essentially indistinguishable.

Retain chunk 4 as the representative because:

- it is the already-retained Phase-4 value;
- TASK-2X8-018 brackets it with two fresh controls;
- changing to chunk 8 would provide no measurable performance gain;
- keeping 4 avoids creating a new downstream scheduling condition for no
  benefit.

Do not claim chunk 4 is a unique numerical optimum.

## 5. What changed from Phase 4?

Phase 4C under the older scheduling state F=0/T=0/S=1 found chunk 4 about 4.1%
above the chunk-8 midpoint.

TASK-2X8-018 under F=1/T=0/S=1 finds chunk 4 and 8 equal to within 0.01%
overall.

This is strong evidence that chunk usefulness is conditional on the scheduling
regime, consistent with E27:

~~~text
chunk granularity
    -> readiness cadence
    -> scheduling/overlap opportunity

factorization priority + separate GEMM stream
    -> changes how strongly readiness cadence affects the critical path
~~~

A reasonable mechanism-level interpretation is that scheduler 101 protects the
dependency-producing factorization path strongly enough that the earlier
chunk-4 readiness advantage is largely hidden or absorbed.

This is not a direct trace of CUDA events/resources, so do not claim the exact
internal mechanism is proven.

The important experimental conclusion is simpler: **the old 4-vs-8 chunk
difference does not transfer to the 101 scheduler.**

## 6. NB × chunk interaction

The matrix contains many strict chunk-order reversals across NB values:

- NB=1024 prefers chunk 16 over 8;
- NB=2048 prefers 8;
- NB=3072 has 4≈8;
- NB=4096 prefers 8;
- NB=5120 prefers 4;
- NB=6144 prefers 4.

Therefore chunk is not a globally independent knob. The matrix validates E23
and the choice to test NB×chunk jointly.

However, this interaction does not create a new branch because:

1. NB=3072 wins across every shared chunk;
2. within NB=3072 every chunk remains inside ~1.1%;
3. no alternate pair beats the retained control;
4. no retained correctness, memory, or IR regime changes.

No fine NB or chunk sweep is justified.

## 7. Memory and refinement interpretation

The NB sweep reproduces the known fact that NB changes more than LU geometry.

Representative regimes:

~~~text
NB=1024:
  device = 132.289 GB
  host   = 0.004 GB
  IR     = 0.37 s
  LU     = 8.87-9.08 s

NB=2048:
  device = 135.763 GB
  host   = 0.517 GB
  IR     = 0.36 s

NB=3072:
  device = 135.254 GB
  host   = 0.004 GB
  IR     = 0.29 s

NB=4096:
  device = 135.762 GB
  host   = 6.123 GB
  IR     = 0.69-0.77 s

NB=5120:
  device = 135.762 GB
  host   = 2.554 GB
  IR     = 0.59-0.67 s

NB=6144:
  device = 135.763 GB
  host   = 11.900 GB
  IR     = 0.99-1.13 s
~~~

The host-allocation pattern is non-monotonic because NB changes block-cyclic
ownership/padding and workspaces; it should not be read as a simple spill
counter.

What matters for the dependency decision is that the retained 3072 regime
reproduces the favorable low-IR/full-residency state exactly. Rejected NB
values that enter worse memory/IR regimes do not themselves reopen N,
residency, or DGEMV.

## 8. Mandatory dependency checkpoint

| Earlier decision | Relevant edge(s) | Material retained upstream change? | Action | Evidence |
|---|---|---|---|---|
| N=429056 / residency boundary | E08, E14, E15 | No | **Keep closed** | Retained NB remains 3072 and reproduces host=0.004 GB, device=135.254 GB, IR=0.29 s. Rejected NBs changing memory state do not replace the retained regime. |
| 4x4 row grid/order | E10 | No | **Keep closed** | Retained NB did not move. No ownership/topology change. |
| Panel transport = NCCL-only / panel=0 | E22, E26 | No | **Keep closed** | Retained NB and topology remain unchanged; no fabric errors; no transport path changed. |
| U-panel chunk | E23, E24 | Yes — explicitly re-evaluated | **Re-close** | Full valid NB×chunk matrix executed. At NB=3072, 2/4/8/16 are within ~1.1%; retain 4 as representative. |
| Scheduler F/T/S=1/0/1 | E27, E28, E30, E31 | Yes — dependency was triggered and tested | **Re-close** | NB remains 3072; retained chunk remains 4; exact 101 final candidate reproduced twice in TASK-018 and matches TASK-017 within 0.06%. |
| Host runtime / OMP / CPU affinity | E18, E19 | No | **Keep closed** | OMP=4 and host-runtime contract unchanged; retained IR remains 0.29 s. |
| Residency buffer / register step | E16, E17/E40 | No | **Keep closed** | Retained memory regime unchanged at 3072. |
| DGEMV=0 | E20, E21 | No | **Keep closed** | Retained IR remains only 0.29 s; larger-IR rejected NBs do not become the operating point. |
| GEMM kernel/default SM90 | E34 | No | **Keep closed** | Retained NB remains 3072. No kernel-dependent geometry change occurred. |
| N-driven scheduling | E37 | No | **Keep closed** | N is unchanged. |
| Trace/profiling branch | blueprint trace rules | No anomaly requiring it | **Do not open** | Results are repeatable and already determine the next action. A trace would not change the retention decision. |

### Dependency verdict

No earlier phase needs a full resweep or light revalidation.

E27 and E28 were the only active Phase-5 reopenings. TASK-2X8-018 resolves
both.

## 9. Final retained 2x8 Phase-5 stack

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

Chunk 4 is the retained representative of the current 2-16 plateau, not a
claimed unique optimum.

## 10. Phase-5 closing-condition review

The blueprint requires:

- high-value exposed controls resolved or intentionally fixed;
- a repeatable final-stack candidate;
- valid residual/correctness;
- targeted dependency revalidation with no material upstream regression.

For the approved Phase-5 campaign scope these conditions are now satisfied:

- scheduling 101 was selected from the complete 2^3 factorial;
- the exact final stack has three scored observations across two jobs;
- all three reproduce within ~0.13%, with the TASK-018 midpoint only 0.06%
  below TASK-017 A101;
- all relevant runs PASSED with three refinement iterations;
- E27/E28 dependency revalidation found no retained geometry/readiness change;
- no other earlier dependency reopens.

A separate one-point confirmation task would duplicate evidence already
collected by the TASK-2X8-018 opening/closing controls and is not justified.

## 11. Recommended next action

**Formally close Phase 5 and record the retained stack above.**

Do not launch another scored experiment for Phase-5 confirmation.
