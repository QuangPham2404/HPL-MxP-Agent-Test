# 2×8 GAAS HPL-MxP Analysis

This file is the persistent analysis record for HPL-MxP tuning on the **2 GAAS nodes × 8 H200 GPUs/node** topology.

## 1. Phase-0 Baseline

The immutable original baseline is `2x8-GAAS-baseline_n700k_v1` from TASK-000.

### Baseline result

| Field | Value |
|---|---|
| Attempt | `2x8-GAAS-baseline_n700k_v1` |
| PBS job | `72602.gaas` |
| Nodes | `hpc-gaas-g12` + `hpc-gaas-g15` |
| Queue / project | `gpu_as` / `hpc_ebslee` |
| Topology | 2 nodes × 8 H200 GPUs = 16 MPI ranks |
| N | 700000 |
| NB | 3072 |
| Process grid | 4 × 4 |
| Process order | column |
| OMP threads | 8 |
| Sloppy type | FP16 |
| MPI panel broadcast | 0 |
| Separate GEMM stream | 1 |
| Prioritize TRSM | 0 |
| Prioritize factorization | 0 |
| Correctness | **PASSED** |
| Normalized residual | `2.520608E-04` |
| Iterative-refinement iterations | 3 |
| LU time | 29.17 s |
| Iterative-refinement time | 18.44 s |
| LU performance | `7.8390e+06` GFLOP/s |
| Overall performance | **`4.8037e+06` GFLOP/s** |
| Per-GPU overall performance | `300228.24` GFLOP/s |
| Host memory available MIN before matrix generation | 219.944 GB/process |
| Host memory available MIN after matrix generation | 4.168 GB/process |
| Device memory available MIN after matrix generation | 14.005 GB/process |
| PBS exit status | 0 |
| Baseline status | **Immutable 2×8-GAAS original baseline** |

Primary evidence:

- `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.o`
- `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.e`
- `experiments/2x8-GAAS/baseline/README.md`
- `results/metrics.csv`

### Initial observations

#### LU versus iterative-refinement balance

The baseline has a substantial gap between LU-only performance and the final end-to-end score:

- LU: `7.8390e+06` GFLOP/s
- Overall: `4.8037e+06` GFLOP/s
- `T_IR / T_LU = 18.44 / 29.17 ≈ 0.632`

Using the campaign approximation

```text
R_MxP ≈ P_LU / (1 + T_IR / T_LU)
```

gives approximately `4.803e+06` GFLOP/s, essentially matching the reported `4.8037e+06` GFLOP/s.

This makes the Phase-0 decomposition clean: future improvements must be evaluated against both **LU throughput** and **iterative-refinement cost**. Improving LU alone can be cancelled by a slower refinement phase.

#### Memory boundary

`N=700000` is valid, but it is already close to the host-memory boundary. After Matrix Generation, the minimum reported system-memory headroom fell to only **4.168 GB/process**. Device-memory headroom remained larger at **14.005 GB/process**.

The previous `N=737280` attempt was killed by host-memory exhaustion, so the current baseline establishes that the practical N boundary for this resource shape lies above 700000 but below 737280. Any future upward N exploration should therefore be treated as a memory-boundary experiment rather than assumed safe tuning headroom.

### Baseline denominator

All future percentage improvements for the new 2×8-GAAS campaign should use:

```text
Baseline overall performance = 4.8037e+06 GFLOP/s
```

unless a later human-approved workflow explicitly replaces the campaign baseline.

## 2. Phase 1A — Coarse N / FP64-Residency Sweep

TASK-001 executed the blueprint's first Phase-1A coarse sweep on the established 2×8 GAAS topology. All six approved candidates ran sequentially in the same allocation (PBS job `72624.gaas`, `gpu_as`, `hpc-gaas-g12` + `hpc-gaas-g15`) with identical controls except `N`, and every candidate reported a finite residual and `PASSED`.

The sweep used `--fill-device 1` throughout, with `NB=3072`, 4×4 column order, `OMP_NUM_THREADS=8`, FP16, the fixed identity GPU affinity, and the other TASK-001 controls unchanged. The package default `--fill-device-buffer-size=3048` remained constant.

Primary evidence:

- `tasks/TASK-001.md`
- `experiments/2x8-GAAS/phase1a-n-coarse/README.md`
- `experiments/2x8-GAAS/phase1a-n-coarse/outputs/`
- `results/metrics.csv`

### 2.1 Results

The immutable Phase-0 baseline remains `4.8037e+06` GFLOP/s at `N=700000`. The percentage column below is the required campaign-wide comparison against that denominator. Because TASK-001 also enables `--fill-device 1` whereas the original baseline did not, this percentage is **not** an isolated one-variable N effect; the within-TASK-001 trend is the clean evidence for the N/residency operating regime.

| N | N / pivot | Overall GFLOP/s | vs original baseline | LU GFLOP/s | LU time (s) | IR time (s) | IR/LU | IR iterations | Device headroom after matrix generation | Host memory consumption MAX |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 353280 | ~69.93% | `4.5777e+06` | -4.70% | `6.0980e+06` | 4.82 | 1.60 | 0.332 | 3 | 44.286 GB | 0.004 GB |
| 404480 | ~80.07% | `5.1559e+06` | +7.33% | `6.4538e+06` | 6.84 | 1.72 | **0.251** | 3 | 17.450 GB | 0.004 GB |
| 454656 | ~90.00% | **`5.2433e+06`** | **+9.15%** | `6.8301e+06` | 9.17 | 2.78 | 0.303 | 3 | **2.257 GB** | 15.024 GB |
| 504832 | ~99.94% | `5.0179e+06` | +4.46% | `7.0444e+06` | 12.18 | 4.92 | 0.404 | 3 | 2.257 GB | 51.561 GB |
| 556032 | ~110.07% | `5.0139e+06` | +4.38% | `7.4381e+06` | 15.41 | 7.45 | 0.483 | 3 | 2.257 GB | 95.340 GB |
| 606208 | ~120.00% | `4.8789e+06` | +1.57% | **`7.5729e+06`** | 19.61 | 10.83 | 0.552 | 3 | 2.257 GB | 136.519 GB |

All six points passed correctness. No failed/OOM point occurred in this sweep.

### 2.2 Analysis

#### End-to-end performance is governed by the LU/IR balance, not LU throughput alone

The coarse sweep confirms the campaign model:

```text
R_MxP ≈ P_LU / (1 + T_IR / T_LU)
```

LU throughput rises monotonically across the sweep:

```text
6.0980 → 6.4538 → 6.8301 → 7.0444 → 7.4381 → 7.5729 PF/s
```

but end-to-end performance does not. The reported HPL-MxP score rises from `N=353280` through `N=454656`, then declines even while LU continues to improve.

The reason is the growing iterative-refinement penalty:

```text
IR time: 1.60 → 1.72 → 2.78 → 4.92 → 7.45 → 10.83 s
IR/LU:   0.332 → 0.251 → 0.303 → 0.404 → 0.483 → 0.552
```

Thus the larger-N points gain LU efficiency but progressively lose a larger fraction of that gain to refinement. This directly supports the blueprint's requirement to optimize the combined LU + IR critical path rather than the largest fitting N or the fastest LU rate.

#### A clear FP64-residency transition occurs between N=404480 and N=454656

The memory evidence is discontinuous across this interval.

At `N=404480`:

- device headroom after matrix generation is `17.450 GB`;
- reported host-memory consumption MAX is effectively zero (`0.004 GB`).

At `N=454656`:

- device headroom falls to `2.257 GB`;
- host-memory consumption rises to `15.024 GB`.

For every larger candidate, device headroom remains essentially fixed at `2.257 GB`, while host-memory consumption grows strongly:

```text
N=454656:  15.024 GB
N=504832:  51.561 GB
N=556032:  95.340 GB
N=606208: 136.519 GB
```

The evidence therefore indicates that the fill-device path reaches its practical device-residency ceiling in the interval between approximately 404k and 455k. Beyond that transition, additional FP64 matrix demand is increasingly carried outside the device-resident portion, while IR cost rises sharply.

This is the mechanism the Phase-1A sweep was intended to expose.

#### The current numerical leader lies at the residency transition

The highest observed single-run score is:

```text
N=454656
Overall = 5.2433e+06 GFLOP/s
+9.15% vs immutable original baseline
```

However, TASK-001 deliberately required only one scored attempt per candidate and Phase 0 did not establish a numeric noise floor for this exact configuration. Therefore `N=454656` should be treated as the **current numerical leader**, not yet as a unique promoted optimum.

The neighboring `N=404480` point is only about 1.69% slower than `N=454656`, while it remains on the higher-headroom side of the residency transition. `N=504832` is about 4.30% slower than the leader and lies clearly on the low-device-headroom / higher-IR side.

The useful region is therefore bounded well enough for refinement:

- **lower performance-side bracket:** `N=404480`;
- **current numerical leader / transition-side point:** `N=454656`;
- **upper residency-side bracket:** `N=504832`.

The lower `N=353280` point has substantial device headroom but is already below the immutable original baseline, while `N=556032` and `606208` continue the increasing-IR / decreasing-overall-score trend. The present evidence does not justify extending the N search farther in either direction before local refinement.

### 2.3 Dependency checkpoint

The dependency review is **performed**, not skipped.

| Dependency | Material at this checkpoint? | Decision | Reason |
|---|---|---|---|
| E07: `N → NB` | **Yes** | Reopen NB, but defer execution until Phase 1A refinement closes | The retained N region is materially different from the Phase-0 baseline and sits at a residency transition. `NB=3072` is only a provisional control and must be re-swept in Phase 1B. |
| E08: `NB → N / memory boundary` | Not triggered yet | Keep as mandatory post-NB checkpoint | No NB change occurred in TASK-001. Any material NB/workspace change in Phase 1B must recheck the useful N/headroom region locally. |
| E09: `N → process grid/order` | **Yes** | Mark grid/order fully open for Phase 2A; do not sweep it yet | The N/residency regime changed materially. The current 4×4 column grid is an experimental control, not a retained optimum. Blueprint order keeps grid work after Phase 1 geometry. |
| E14/E15: `N ↔ FP64 residency` | **Yes, directly observed** | Continue bounded N/residency refinement now | The 17.450→2.257 GB device-headroom collapse and rising host residency identify the transition that Phase 1A must resolve. |
| E16: residency mode → fill buffer | Potentially material downstream | Keep open for later residency/buffer tuning | `fill-device-buffer-size=3048` was only the unchanged package default. The low 2.257 GB device headroom beyond the transition means buffer choice must not be considered optimized. |
| E18: N / refinement work → host runtime | Material downstream | Revalidate later; no immediate OMP sweep | IR workload changes strongly across the retained N regime. The fixed OMP=8 setting is provisional for 2×8 and will be revisited in the blueprint's host-runtime phase. |
| E22–E24, E28, E34 | Not triggered yet | Defer until NB changes | These dependencies are downstream of the Phase-1B NB decision. |
| E36: precision → residency/headroom | Not triggered | Keep closed for now | Precision stayed FP16 throughout TASK-001. A future precision change must reopen residency/headroom. |

Other downstream controls that depend on problem scale or residency remain provisional. This checkpoint does **not** justify jumping ahead to grid, buffer, host-runtime, communication, or scheduling sweeps before Phase 1 geometry is bounded.

### 2.4 Proposed next step

**Recommend exactly one next action: run the Phase-1A ~5% local N refinement across the performance peak and FP64-residency transition.**

Use the same scientific controls as TASK-001 and refine the interval from approximately 80% to 100% of the `N_pivot`:

| Role | N | Approx. pivot fraction |
|---|---:|---:|
| lower coarse bracket / repeat | 404480 | ~80% |
| new refinement point | 429056 | ~85% |
| current numerical leader / repeat | 454656 | ~90% |
| new refinement point | 480256 | ~95% |
| upper coarse bracket / repeat | 504832 | ~100% |

This five-point design is preferred because it does three jobs in one bounded experiment:

1. fills the missing ~5% points on both sides of the current numerical leader;
2. maps the residency transition between `404480` and `454656`; and
3. repeats the three existing coarse anchors in one comparable refinement allocation, providing a first check that the observed shape is reproducible.

Prefer one 2×8 allocation with the five candidates run sequentially, as in TASK-001, to minimize allocation/node variation. Do not add NB, grid, buffer, communication, affinity, or scheduling changes to this refinement task.

After that refinement is analyzed, retain the bounded N/residency regime(s) and proceed to Phase 1B NB tuning. A later NB change must then trigger the E08 dependency review and only a targeted local N reopening if the measured LU/IR or memory regime materially changes.

**Human decision state:** proposed only. No further execution is authorized by this analysis.

## 3. Phase 1A — Local N Refinement and Closure

TASK-002 refined the TASK-001 coarse region with:

```text
N = 404480, 429056, 454656, 480256, 504832
```

using the same 2×8 GAAS allocation pattern and identical scientific controls except N. All five points passed correctness.

Detailed analysis: `planning/analysis/2x8-gaas-phase1a-n-refine.md`.

### 3.1 Results

| N | Overall GFLOP/s | vs original baseline | LU GFLOP/s | LU time | IR time | IR/LU | Device headroom after matgen | Host memory consumption MAX |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 404480 | `5.1045e+06` | +6.26% | `6.4584e+06` | 6.83 s | 1.81 s | 0.265 | 17.450 GB | 0.004 GB |
| **429056** | **`5.6091e+06`** | **+16.77%** | `6.6130e+06` | 7.96 s | **1.43 s** | **0.180** | 2.767 GB | 0.004 GB |
| 454656 | `5.2584e+06` | +9.47% | `6.8314e+06` | 9.17 s | 2.75 s | 0.300 | 2.257 GB | 15.024 GB |
| 480256 | `5.2514e+06` | +9.32% | **`7.1777e+06`** | 10.29 s | 3.78 s | 0.367 | 2.257 GB | 34.205 GB |
| 504832 | `4.9704e+06` | +3.47% | `7.0018e+06` | 12.25 s | 5.01 s | 0.409 | 2.257 GB | 51.561 GB |

The deliberate TASK-001 anchor repeats were stable:

```text
N=404480: -1.00%
N=454656: +0.29%
N=504832: -0.95%
```

relative to their TASK-001 scores. This is not a formal noise study, but the movement is small compared with the approximately 6.7% separation between `N=429056` and the next-best refinement points.

### 3.2 Analysis

`N=429056` is retained as the Phase-1A representative N.

Its advantage is not the highest LU throughput. Larger N values produce faster LU, but their iterative-refinement cost rises enough to reduce the end-to-end score:

```text
N=429056: IR/LU = 0.180
N=454656: IR/LU = 0.300
N=480256: IR/LU = 0.367
N=504832: IR/LU = 0.409
```

All five candidates still use three IR iterations, so the gain at `N=429056` comes from a shorter refinement path rather than fewer iterations.

The FP64-residency transition is now bounded more tightly:

```text
N=429056:
  device headroom = 2.767 GB
  host consumption = 0.004 GB

N=454656:
  device headroom = 2.257 GB
  host consumption = 15.024 GB
```

Thus `N=429056` sits at the useful edge of the high-device-residency regime: it nearly fills practical device capacity while avoiding the host-resident/staged behavior visible at the next point.

The post-transition `N=454656–480256` regime is mechanistically distinct but is approximately 6.3% below `N=429056`, materially larger than the observed repeat-anchor movement. It is therefore not retained as a co-equal performance regime. `N=454656` remains useful as a residency-boundary reference.

### 3.3 Phase-1A decision

**Phase 1A is closed at `N=429056` under the current provisional controls and `--fill-device 1` policy.**

Phase 1 itself remains open because `NB=3072` has not been tuned for the retained N.

### 3.4 Dependency checkpoint

The checkpoint is performed.

- **E07, N → NB:** triggered. Proceed to Phase 1B NB tuning.
- **E08, NB → N/memory boundary:** mandatory after Phase 1B because only 2.767 GB device headroom remains at the retained N.
- **E09, N → grid/order:** grid/order remains open downstream; defer to Phase 2A.
- **E14/E15, N ↔ FP64 residency:** resolved for Phase 1A under the current fill policy; reopen only if NB/workspace or residency policy materially changes.
- **E16, fill/residency → buffer:** open downstream; the package-default buffer is not treated as optimized.
- **E18/E21, N/residency → host runtime/DGEMV:** open downstream and deferred.
- **E22–E24, E28, E34:** become active after the NB decision.
- **E37, N → scheduling:** scheduling is reopened downstream because the retained N materially changes LU geometry, but it is not tuned during Phase 1.

### 3.5 Proposed next step

**Recommended next action: Phase 1B bounded NB screen at fixed `N=429056`.**

Proposed first-stage candidates:

```text
NB = 1024, 2048, 3072, 4096, 5120, 6144
```

Use `NB=3072` as the same-protocol control. Keep N and every non-NB scientific control fixed. These values are search hypotheses only; no single-node NB optimum is transferred to this topology, and `N % NB == 0` is not required.

Because the retained N is close to the device-residency limit, correctness and memory headroom remain hard gates. Upward extension should stop after invalidity/OOM or repeated clear degradation rather than adding larger NB values automatically.

After Phase 1B, perform the mandatory E08 dependency review and reopen N only locally if the retained NB materially changes the residency boundary, feasibility, ranking, or LU/IR balance.

**Human decision state:** proposed only. No Phase-1B execution is authorized by this analysis.

## 4. Phase 1B — NB Screen and Phase-1 Closure

TASK-003 screened NB at fixed `N=429056` using the retained Phase-1A controls. All six approved NB values ran successfully and passed correctness.

Detailed analysis: `planning/analysis/2x8-gaas-phase1b-nb-screen.md`.

### 4.1 Results

| NB | Overall GFLOP/s | vs original baseline | vs TASK-003 NB=3072 | LU GFLOP/s | LU time | IR time | IR/LU | Device headroom after matgen | Host memory consumption MAX |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1024 | `4.5905e+06` | -4.44% | -17.11% | `5.3920e+06` | 9.77 s | 1.71 s | 0.175 | **5.700 GB** | 0.004 GB |
| 2048 | `5.5286e+06` | +15.09% | -0.17% | `6.5865e+06` | 7.99 s | 1.53 s | 0.191 | 2.237 GB | 0.517 GB |
| **3072** | **`5.5381e+06`** | **+15.29%** | control | **`6.5950e+06`** | **7.98 s** | **1.53 s** | 0.192 | 2.767 GB | **0.004 GB** |
| 4096 | `5.3738e+06` | +11.87% | -2.97% | `6.4400e+06` | 8.18 s | 1.62 s | 0.198 | 2.284 GB | 6.123 GB |
| 5120 | `5.1301e+06` | +6.79% | -7.37% | `6.1330e+06` | 8.59 s | 1.68 s | 0.196 | 2.319 GB | 2.554 GB |
| 6144 | `5.0524e+06` | +5.18% | -8.77% | `5.9792e+06` | 8.81 s | 1.62 s | 0.184 | 2.362 GB | 11.900 GB |

All six candidates used three refinement iterations and reported finite residuals with `PASSED`.

The same-protocol `NB=3072` control moved from `5.6091e+06` in TASK-002 to `5.5381e+06` in TASK-003 (-1.27%). The within-job difference between `NB=2048` and `NB=3072` is only 0.17%, so they form a performance plateau rather than a proven unique winner.

### 4.2 Analysis

The NB sweep primarily changes **LU performance**, not iterative-refinement behavior.

`NB=1024` provides the most device headroom but performs poorly because its many small panels increase panel/factorization/broadcast/synchronization overhead and create weaker trailing-update geometry. Moving to `NB=2048–3072` sharply improves LU while IR remains approximately 1.53 s.

Above `NB=3072`, LU time rises progressively. The likely mechanism is that larger panels reduce panel count but increase per-panel dependency, communication, workspace, and synchronization granularity while changing GEMM/update shapes. The useful region is therefore `NB=2048–3072`, not a monotonic large-NB trend.

#### Why memory headroom changes with NB at fixed N

Global `N` is fixed, but NB changes the benchmark's memory layout and workspaces:

1. block-cyclic local row/column ownership and remainder placement change with NB;
2. panel/factorization/TRSM/update workspace scales with panel width;
3. panel communication and staging buffers change size;
4. with `--fill-device 1`, those allocations change how much of the FP64 matrix can remain resident while the configured 3048 MB device buffer zone is preserved.

Illustrative worst-rank FP64 local-matrix arithmetic under the 4×4 block-cyclic distribution:

| NB | max local row/column extent | approx. worst-rank FP64 local matrix |
|---:|---:|---:|
| 1024 | 107520 | 92.48 GB |
| 2048 | 108544 | 94.25 GB |
| 3072 | 107520 | 92.48 GB |
| 4096 | 109568 | 96.04 GB |
| 5120 | 107520 | 92.48 GB |
| 6144 | 110592 | 97.84 GB |

This is explanatory arithmetic, not a reconstruction of the benchmark's total memory counters. Actual reported memory also includes low-precision data, runtime workspaces, communication/staging buffers, and host allocations.

The host-memory-consumption metric is therefore not a pure FP64-spill counter. Its non-monotonic behavior is expected when both block ownership and temporary workspace change.

Memory headroom is a **hard constraint and mechanism**, not a direct optimization target: `NB=1024` has 5.700 GB device headroom but is the slowest candidate, whereas `NB=2048–3072` runs much faster while operating closer to the device-memory ceiling.

### 4.3 Retained NB decision

Retain the **`NB=2048–3072` performance plateau**, with **`NB=3072` as the representative Phase-1 control** because:

- performance is effectively tied with 2048;
- it is the same NB used throughout the retained Phase-1A geometry;
- it has more device headroom than 2048 in this run;
- reported host consumption is essentially zero;
- LU and IR are effectively identical to 2048.

This does not claim that 3072 is uniquely faster.

### 4.4 Mandatory dependency checkpoint

The checkpoint is performed.

- **E08, NB → N/memory boundary:** the dependency is directly visible because NB materially changes host/device headroom. However, the retained representative NB remains 3072, the same value used to establish `N=429056`. **Keep N closed; no targeted N resweep is required.**
- The retained `N=429056, NB=3072` point has now been repeated across TASK-002 and TASK-003: `5.6091e+06` and `5.5381e+06` (-1.27%). The lower repeat still remains clearly above the bracketing Phase-1A N points.
- **E10, NB → grid/order:** no retained NB change, but E09 already requires a fresh Phase-2A grid/order sweep because the N/residency regime changed materially.
- **E22, NB → panel transport:** communication remains open downstream and deferred until geometry/placement is established.
- **E23/E24, NB/N/npcol → U-panel chunk:** default chunking remains provisional and must be recalculated after a grid change.
- **E28, NB → scheduling:** scheduling remains open downstream; no immediate revalidation before Phase 2A because retained NB is unchanged.
- **E34, NB → GEMM kernel:** remains open downstream; no immediate action.
- **E16, residency → fill buffer:** default buffer remains unoptimized and is deferred to its blueprint phase.

### 4.5 Phase-1 decision

**Phase 1 is closed with the retained representative geometry:**

```text
N = 429056
NB = 3072
grid/order = 4x4 column only as a provisional control
fill-device = 1
```

The retained NB region is `2048–3072`, with 3072 carried forward as the representative control.

### 4.6 Proposed next step

**Recommended next action: Phase 2A process-grid shape screening at fixed `N=429056`, `NB=3072`.**

Follow the blueprint staging:

1. keep all retained Phase-1 controls fixed;
2. screen a bounded set of valid 16-rank process-grid shapes using one fixed order/mapping;
3. retain useful shapes based on end-to-end performance, phase balance, memory/rank symmetry, and communication behavior;
4. compare row versus column order only for retained shapes;
5. do not combine the initial grid screen with GPU-affinity or communication tuning.

The exact Phase-2A candidate set should be specified in the next human-approved task.

**Human decision state:** proposed only. No Phase-2A execution is authorized by this analysis.

## 5. Phase 2A — Joint TASK-004 / TASK-005 / TASK-006 Grid × Order

TASK-004, TASK-005, and TASK-006 are analyzed as one Phase-2A study.

Detailed analysis: `planning/analysis/2x8-gaas-phase2a-grid-order-matrix.md`.

Fixed retained geometry entering Phase 2A:

```text
N = 429056
NB = 3072
OMP_NUM_THREADS = 8
gpu-affinity = 0:1:2:3:4:5:6:7
fill-device = 1
```

TASK-004 supplied the initial column-order shape screen, TASK-005 supplied the row-order counterparts, and TASK-006 supplied the same-allocation confirmation used to close the remaining ambiguity. All three tasks measured the same physical rank placement:

```text
global ranks 0-7   -> hpc-gaas-g12
global ranks 8-15  -> hpc-gaas-g15
```

### 5.1 Initial matrix — TASK-004 + TASK-005

| Grid | Order | Overall GFLOP/s | LU GFLOP/s | LU s | IR s | IR/LU | Device headroom | Host consumption MAX |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 2×8 | column | `5.3746e+06` | `6.3307e+06` | 8.32 | 1.48 | 0.178 | 2.163 GB | 6.395 GB |
| 2×8 | row | `5.0562e+06` | `6.4670e+06` | 8.14 | 2.27 | 0.279 | 2.304 GB | 6.292 GB |
| 4×4 | column | `5.4505e+06` | `6.5964e+06` | 7.98 | 1.68 | 0.211 | 2.767 GB | 0.004 GB |
| **4×4** | **row** | **`5.6347e+06`** | **`6.7803e+06`** | **7.77** | **1.58** | 0.203 | 2.767 GB | 0.004 GB |
| 8×2 | column | `5.5487e+06` | `6.5155e+06` | 8.08 | 1.41 | 0.175 | 2.302 GB | 2.937 GB |
| 8×2 | row | `5.4331e+06` | `6.5199e+06` | 8.08 | 1.62 | 0.200 | 2.161 GB | 3.040 GB |

The initial matrix established a shape×order interaction:

```text
2x8: row vs column = -5.92%
4x4: row vs column = +3.38%
8x2: row vs column = -2.08%
```

There is no universal row/column winner. The order changes which logical HPL communicator crosses the node boundary.

The initial matrix dropped 2×8 from serious contention but could not distinguish 4×4 row from 8×2 column confidently because their gap was only 1.55%, below observed cross-allocation control movement.

### 5.2 Same-allocation confirmation — TASK-006

TASK-006 ran all four surviving arms sequentially in one allocation, PBS job `72845.gaas`, on g12+g15.

| Grid | Order | Overall GFLOP/s | vs original baseline | LU GFLOP/s | LU s | IR s | IR/LU | Device headroom | Host consumption MAX |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 4×4 | column | `5.5602e+06` | +15.75% | `6.6245e+06` | 7.95 | 1.52 | 0.191 | 2.767 GB | 0.004 GB |
| **4×4** | **row** | **`5.6860e+06`** | **+18.37%** | **`6.7792e+06`** | **7.77** | **1.50** | 0.193 | **2.767 GB** | **0.004 GB** |
| 8×2 | column | `5.4880e+06` | +14.25% | `6.5267e+06` | 8.07 | 1.53 | 0.190 | 2.302 GB | 2.937 GB |
| 8×2 | row | `5.4794e+06` | +14.07% | `6.5147e+06` | 8.08 | 1.53 | 0.189 | 2.161 GB | 3.040 GB |

Within TASK-006:

```text
4x4 row vs 4x4 column = +2.26%
4x4 row vs 8x2 column = +3.61%
4x4 row vs 8x2 row    = +3.77%
8x2 column vs 8x2 row = +0.16%
```

Repeated-arm movement relative to TASK-004/005 was:

```text
4x4 row    +0.91%
4x4 column +2.01%
8x2 column -1.09%
8x2 row    +0.85%
```

The +3.61% same-allocation separation between 4×4 row and 8×2 column is larger than the observed repeat movement of either arm and preserves the direction of the earlier matrix. TASK-006 therefore resolves the previous ambiguity.

### 5.3 Analysis and retained grid/order

The retained operating point is:

```text
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row
fill-device = 1
```

The 4×4-row arm is retained because it combines:

- the best confirmed end-to-end score;
- the fastest LU time;
- essentially the fastest IR time;
- identical 2.767 GB device headroom and 0.004 GB host consumption to the clean 4×4-column control;
- stable repeat behavior across TASK-005 and TASK-006.

The earlier apparent 8×2 column-order advantage does not repeat: TASK-006 shows 8×2 column and row within 0.16%. The 8×2 shape itself remains slower than 4×4 row.

Identity GPU affinity remains only a control:

```text
--gpu-affinity 0:1:2:3:4:5:6:7
```

It is not yet claimed as the optimized physical placement.

**Phase 2A is closed at 4×4 row.**

### 5.4 Dependency checkpoint

The checkpoint is performed.

- **E02 topology/rank count → grid/order:** satisfied for the current 2-node / 16-rank topology.
- **E09 N → grid/order:** satisfied at retained `N=429056`.
- **E10 NB → grid/order:** satisfied at retained `NB=3072`.
- **E11 grid/order → rank/GPU/NIC placement:** **triggered now.** The retained order changed from the provisional 4×4-column control to 4×4 row, so logical neighbor placement changes even with identity GPU affinity. Proceed next to Phase 2B.
- **E12 grid/order → panel transport:** triggered downstream. Row order changes which communicator crosses nodes; transport must be revalidated after placement is established.
- **E24 N/NB/npcol → U-panel chunk validity/usefulness:** no geometry-validity-driven reopen is required because final `N`, `NB`, and `npcol=4` are unchanged from the Phase-1 4×4 control. Chunk remains provisional for the later communication phase.
- **E29 grid/order → LU scheduling:** triggered downstream because order changed node crossings and LU timing.
- **E38 nprow → DGEMV:** not triggered by the final selection because retained `nprow=4` is unchanged and IR remains small/stable.
- **N/residency reopening:** **not triggered.** 4×4 row has the same 2.767 GB device headroom and 0.004 GB host consumption as 4×4 column. No new memory/residency regime was crossed.

The next active dependency is therefore **E11: physical GPU placement**.

### 5.5 Proposed next step

**Recommended next action: Phase 2B GPU placement at fixed 4×4 row.**

Carry forward:

```text
N = 429056
NB = 3072
4x4 row
fill-device = 1
```

Use identity GPU affinity as the control, then test only **mechanism-distinct rank↔GPU mappings**.

The per-node H200 topology is all-pairs NV18, so arbitrary permutations that merely reshuffle GPUs inside the equivalent NVLink fabric are low-value. Candidate mappings should instead target meaningful differences in GPU↔NUMA/NIC association and logical process-row/process-column placement relative to the two host NUMA/NIC groups.

Do not combine Phase 2B with UCX transport selection, panel-broadcast tuning, U-panel chunking, host-runtime tuning, or LU scheduling.

**Human decision state:** Phase 2A is closed. Phase 2B is proposed only; no Phase-2B execution is authorized by this analysis.


## 6. Phase 2B/2C — Placement and Locality

TASK-007 tested GPU/NUMA/CPU/NIC placement at the retained Phase-2A geometry.

Detailed analysis: `planning/analysis/2x8-gaas-phase2bc-placement-locality.md`.

All ten arms ran sequentially in one allocation, PBS job `72879.gaas`, on
g12+g15. All passed with the same residual and three IR iterations.

### 6.1 Results and main mechanism

| Arm | Change | Exact affinity flags | Overall GFLOP/s | LU s | IR s |
|---|---|---|---:|---:|---:|
| A0 | G0 identity, mem omitted | `--gpu-affinity 0:1:2:3:4:5:6:7`; mem/cpu/ucx affinity omitted | 5.7363e+06 | 7.79 | 1.39 |
| A1 | G0 + mem affinity | `--gpu-affinity 0:1:2:3:4:5:6:7 --mem-affinity 0:0:0:0:1:1:1:1`; cpu/ucx omitted | 5.6984e+06 | 7.79 | 1.45 |
| A2 | G1 column-local, mem omitted | `--gpu-affinity 0:4:2:6:1:5:3:7`; mem/cpu/ucx affinity omitted | 5.5378e+06 | 7.78 | 1.73 |
| A3 | G1 + matching mem affinity | `--gpu-affinity 0:4:2:6:1:5:3:7 --mem-affinity 0:1:0:1:0:1:0:1`; cpu/ucx omitted | 5.6699e+06 | 7.78 | 1.51 |
| B0 | CPU free | `--gpu-affinity 0:1:2:3:4:5:6:7`; mem/cpu/ucx affinity omitted | 5.6247e+06 | 7.81 | 1.56 |
| B1 | CPU loose | `--gpu-affinity 0:1:2:3:4:5:6:7 --cpu-affinity 0-49:0-49:0-49:0-49:56-101:56-101:56-101:56-101`; mem/ucx omitted | 5.5530e+06 | 7.77 | 1.72 |
| B2 | CPU medium, 10 CPUs/rank | `--gpu-affinity 0:1:2:3:4:5:6:7 --cpu-affinity 0-9:10-19:20-29:30-39:56-65:66-75:76-85:86-95`; mem/ucx omitted | 5.6912e+06 | 7.78 | 1.48 |
| B3 | CPU strict, 8 CPUs/rank | `--gpu-affinity 0:1:2:3:4:5:6:7 --cpu-affinity 0-7:8-15:16-23:24-31:56-63:64-71:72-79:80-87`; mem/ucx omitted | 5.3783e+06 | 7.77 | 2.02 |
| C0 | UCX automatic | `--gpu-affinity 0:1:2:3:4:5:6:7`; mem/cpu/ucx affinity omitted | 5.5828e+06 | 7.80 | 1.64 |
| C1 | PIX-paired UCX HCA | `--gpu-affinity 0:1:2:3:4:5:6:7 --ucx-affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_8:mlx5_9`; mem/cpu omitted | 5.6949e+06 | 7.78 | 1.47 |

The important result is that LU is essentially flat (7.77–7.81 s) across the
entire sweep while IR ranges from 1.39 to 2.02 s. Placement therefore affects
the host/NUMA/MPI/refinement side much more strongly than the H200 LU path.

The identical G0/no-mem/free/auto control appears as A0, B0, and C0 and moves
`5.7363e+06 -> 5.6247e+06 -> 5.5828e+06`, a same-allocation span of about
2.68%. One-shot 1–2% effects are therefore treated cautiously.

### 6.2 GPU and memory placement

G1 without matching memory affinity loses 3.46% versus A0 entirely through
IR (1.39 -> 1.73 s), not LU. Matching G1 memory affinity recovers 2.39% and
cuts IR to 1.51 s, showing a real GPU-map × memory-locality interaction.

Under G0, explicit memory affinity is slightly negative (-0.66%) and does not
change LU.

#### What A0 versus A2 actually changes

At the retained `4x4 row` process grid, global ranks are arranged as:

```text
          process columns
          c0   c1   c2   c3

row 0      0    1    2    3
row 1      4    5    6    7
row 2      8    9   10   11
row 3     12   13   14   15
```

Ranks 0-7 reside on one node and ranks 8-15 on the other.

With the retained identity GPU map:

```text
A0:
--gpu-affinity 0:1:2:3:4:5:6:7

local ranks 0-3 -> GPU0-3 -> NUMA0
local ranks 4-7 -> GPU4-7 -> NUMA1
```

the process rows are NUMA-local within each node:

```text
row 0: ranks 0 1 2 3   -> NUMA0
row 1: ranks 4 5 6 7   -> NUMA1
row 2: ranks 8 9 10 11 -> NUMA0 on node 2
row 3: ranks12 13 14 15-> NUMA1 on node 2
```

but a process column alternates between the two NUMA domains on each node:

```text
col 0: ranks 0 4 8 12
       NUMA0 NUMA1 NUMA0 NUMA1
```

A2 deliberately reverses that local NUMA preference:

```text
A2:
--gpu-affinity 0:4:2:6:1:5:3:7
```

For example, the same-node members of process column 0 become:

```text
rank 0  -> GPU0 -> NUMA0
rank 4  -> GPU1 -> NUMA0

rank 8  -> GPU0 -> NUMA0 on node 2
rank 12 -> GPU1 -> NUMA0 on node 2
```

so each local pair belonging to the same process column is placed in the same
NUMA domain. The corresponding process rows now alternate between NUMA0 and
NUMA1.

This is an important distinction: **the inter-node path still exists in both
A0 and A2.** A2 does not make an entire process column node-local; it only
improves the NUMA locality of the two same-node members of each inter-node
process column.

#### Row versus column communication interpretation

The useful HPL mental model is:

```text
process-column side:
  panel factorization / cooperation on the current panel
  plus column-direction data movement needed by the update path

process-row side:
  broadcast of the factorized L panel across the process row

trailing GEMM:
  local GPU computation once the required L/U panel data has arrived
```

Therefore process-row communication is not literally "the GEMM
communication." GEMM itself is local. Rather, row-direction panel broadcast is
one of the communication paths that determines when ranks can enter the large
trailing-update GEMMs and how well update/look-ahead work can overlap.

The original intuition behind A2 was therefore reasonable: in classical HPL,
panel factorization is a critical-path bottleneck, so making the ranks that
cooperate in a process column more local could plausibly help.

However, **TASK-007 does not show an LU benefit from that change**:

```text
A0 identity:
LU = 7.79 s
IR = 1.39 s

A2 column-local GPU map:
LU = 7.78 s
IR = 1.73 s
```

LU is effectively unchanged, while IR becomes about 24% slower. Therefore the
A0-versus-A2 GPU-affinity experiment should be interpreted primarily as a
**host/NUMA/refinement sensitivity result**, not as direct evidence that one
LU communicator is faster than the other.

The stronger LU-side clue comes from the earlier Phase-2A
`nporder=row` versus `nporder=column` experiment, where the logical
row/column placement changed and **LU itself moved materially**. Taken
together, the evidence suggests the following working hypothesis for this
HPL-MxP operating point:

> Fine-grained NUMA localization of the process-column/panel ranks is not a
> meaningful LU bottleneck under the current 2x8 H200 topology. The A0-versus-A2
> GPU-affinity remapping leaves LU essentially unchanged and mainly affects IR
> through the host/NUMA relationship. The separate Phase-2A `nporder`
> experiment is the evidence that broader logical row/column placement can
> change LU; that LU result should not be attributed to the fine-grained
> GPU-affinity/NUMA remapping tested here.

This is intentionally a **working mechanism**, not a universal HPL rule. A0
versus A2 alone cannot prove that row communication dominates column
communication in LU because their LU times are identical. The row-versus-
column LU conclusion comes from the Phase-2A order experiment; TASK-007 adds
the complementary observation that forcing better local process-column GPU
placement does not improve LU and can disturb refinement-side locality.

With all eight GPUs connected through the same NV18 fabric and the current
NCCL-heavy panel policy (`--use-mpi-panel-broadcast 0`), the extra
same-node column locality provided by A2 is therefore not worth the loss of
the natural row/NUMA alignment.

#### Memory-affinity interaction

The A2 -> A3 recovery is still valuable evidence:

```text
A2: G1, mem omitted   IR = 1.73 s
A3: G1 + matching mem IR = 1.51 s
```

Matching memory affinity repairs much of the penalty introduced by the G1 GPU
permutation without changing LU. This confirms that the main A2 penalty is a
GPU-map × host-memory/NUMA interaction on the refinement side, rather than an
LU communication effect.

Retain:

```text
gpu-affinity = 0:1:2:3:4:5:6:7
mem-affinity = omitted
```

Identity preserves the natural process-row/NUMA alignment, is simpler, and is
at least as fast. G1+memory is not proven intrinsically inferior, but it
provides no LU advantage and does not justify the extra placement complexity.

### 6.3 CPU affinity

B2 medium is the only promising explicit CPU policy:

```text
B2 vs B0:
  overall +1.18%
  IR 1.56 -> 1.48 s
```

but the gain is below measured control drift.

B3 strict is clearly harmful:

```text
overall -4.38%
IR 1.56 -> 2.02 s (+29.49%)
```

while LU remains flat. Eight CPUs/rank for eight OMP threads leaves too little
host-side headroom for progress/helper/refinement work. The 10-CPU/rank B2
result suggests that some private CPU ownership plus spare capacity may be
useful.

Keep CPU affinity free as the representative control, but preserve B2 as the
main hypothesis for the E19 coordinated OMP/CPU revalidation.

### 6.4 UCX affinity

C1 PIX-paired UCX affinity gives:

```text
overall +2.008% vs C0
LU 7.80 -> 7.78 s
IR 1.64 -> 1.47 s (-10.37%)
```

The g12 HCA counters show that both C0 and C1 already distribute essentially
equal traffic across all eight HCAs; mean transmitted traffic differs by only
~0.016%. Therefore C1, if real, is not winning by activating more rails or
moving more aggregate bytes. The plausible mechanism is more deterministic
rank-to-local-PIX-HCA routing / lower path-locality overhead.

However, +2.01% is smaller than the 2.68% identical-control span. The
pre-authorized execution rule correctly promoted C1, but strategic closure
requires a bracketed confirmation.

### 6.5 Dependency checkpoint

- **E03:** current g12/g15 physical mapping is validated; remap on another
  topology rather than transferring affinity strings.
- **E11:** satisfied for retained 4x4 row.
- **E12/E13:** panel transport remains fully open downstream; grid/order and
  physical placement both require Phase-4 transport revalidation.
- **E18:** host runtime remains open because IR is clearly placement-sensitive.
- **E19:** strongly triggered. CPU affinity and OMP thread/place/bind must be
  revalidated as one coordinated group; do not independently stack B2 with an
  old OMP policy.
- **E20:** defer DGEMV until host runtime closes.
- **E25/E26/E29:** chunk and scheduling remain downstream of final
  communication/transport decisions.
- N/NB/residency stay closed because every TASK-007 arm has the same memory
  regime.

### 6.6 Proposed next step

**Recommended next action: one minimal bracketed UCX-affinity confirmation.**

At fixed G0 / no memory affinity / CPU free / OMP=8, run:

```text
C0 automatic
C1 PIX-paired
C0 automatic repeat
```

inside one allocation.

If C1 remains above the local C0 bracket and reproduces the IR reduction,
retain PIX affinity and close Phase 2C. If it falls inside bracket drift,
retain automatic UCX and close Phase 2C.

After placement closes, proceed to the E19-required coordinated OpenMP + CPU
host-runtime revalidation, keeping B2 medium as the main explicit-CPU
candidate.

Do not start `UCX_TLS × use-mpi-panel-broadcast` yet; that remains Phase 4.

**Human decision state:** TASK-007 analysis complete. UCX confirmation proposed
only; no execution is authorized.


### 6.7 TASK-008 — UCX-affinity confirmation and Phase-2C closure

TASK-008 bracketed the unresolved TASK-007 UCX result in one allocation:

| Arm | UCX policy | Overall GFLOP/s | LU s | IR s |
|---|---|---:|---:|---:|
| C0a | automatic | 5.6421e+06 | 7.76 | 1.57 |
| C1 | PIX-paired HCA | 5.5794e+06 | 7.75 | 1.69 |
| C0b | automatic repeat | 5.6285e+06 | 7.75 | 1.61 |

The automatic controls differ by only 0.24%. C1 is 1.11% below C0a, 0.87%
below C0b, and 0.99% below their mean. Its IR time is also 4.97-7.64% slower
than the two automatic controls while LU is unchanged.

The earlier TASK-007 +2.01% PIX result therefore does not reproduce under a
local control bracket. The previous IR improvement also reverses direction.

**Phase 2C is closed with:**

```text
--ucx-affinity omitted
UCX device selection = automatic/default
```

Retained physical placement:

```text
gpu-affinity = 0:1:2:3:4:5:6:7
mem-affinity = omitted
cpu-affinity = omitted/free   # provisional pending host-runtime tuning
ucx-affinity = omitted/automatic
```

Detailed analysis:
`planning/analysis/2x8-gaas-phase2c-ucx-affinity-confirm.md`.

Dependency checkpoint:

- E11 is satisfied: physical placement triggered by retained 4x4 row is closed.
- E12/E13 remain downstream obligations for Phase-4 panel transport.
- E18 remains active for host runtime.
- **E19 is now the next active strong dependency:** CPU affinity and OpenMP
  thread/place/bind must be revalidated as a coordinated group.
- E20 DGEMV remains deferred until the host-runtime group is closed.
- N/NB/grid/residency remain closed.

**Proposed next action:** coordinated Phase-3A/3B host-runtime revalidation.
First establish an OpenMP thread-count plateau with CPU/memory/UCX affinity
unset; then compare free CPU placement against a topology-aligned
non-overlapping medium policy at the retained OMP count(s); only after that
test meaningful OMP place/bind policies. Do not independently stack TASK-007
B2 with a separately selected OpenMP winner.

**Human decision state:** Phase 2C closed. Host-runtime tuning is proposed only;
no execution is authorized.

## 7. Phase 3A/3B — Coordinated Host Runtime

TASK-009 jointly revalidated OpenMP thread count, HPL CPU affinity, and OpenMP
place/bind policy at the retained `N=429056`, `NB=3072`, `4x4 row`
operating point.

Detailed analysis:
`planning/analysis/2x8-gaas-phase3ab-host-runtime.md`.

### 7.1 Step A — OMP thread count

| OMP threads | Overall GFLOP/s | LU s | IR s | IR/LU |
|---:|---:|---:|---:|---:|
| **4** | **6.5632e+06** | 7.74 | **0.29** | 0.037 |
| 6 | 6.5459e+06 | 7.75 | 0.29 | 0.037 |
| 8 | 6.5437e+06 | 7.76 | 0.29 | 0.037 |
| 10 | 6.4302e+06 | 7.78 | 0.41 | 0.053 |
| 12 | 6.2635e+06 | 7.77 | 0.63 | 0.081 |

Threads 4–8 form one plateau. LU is flat; the degradation at 10–12 threads
comes from IR. Retain `OMP_NUM_THREADS=4` as the representative plateau
control because it is the numerical leader and uses the least host-thread
budget.

TASK-009 explicitly forwards and verifies `OMP_NUM_THREADS` on all 16 ranks.
The closest TASK-008 control on the same node pair had LU 7.76 s and IR
1.57 s, whereas TASK-009 T=8 has LU 7.76 s and IR 0.29 s. Because the old
remote-rank OpenMP environment is not recorded, this cross-task difference is
not a clean causal measurement, but it establishes a materially different
verified host-runtime/IR regime.

This does **not** blanket-invalidate TASK-001–008. Within-task comparisons
remain useful when every arm shared the same launcher state. The dependency
impact is selective: N is reopened because its ranking depended heavily on IR;
TASK-007 CPU-affinity conclusions are superseded by the coordinated E19 test;
DGEMV reopens downstream. LU-dominated NB and grid/order conclusions are not
discarded automatically, but they may reopen later if the newly retained N
moves materially through their existing dependency edges.

### 7.2 Step B — CPU affinity

At both retained thread counts, free and broad loose CPU territory are tied,
while narrow private slices hurt IR strongly:

```text
T=4:
free   6.5632e+06, IR 0.29
loose  6.5433e+06, IR 0.29
medium 6.2703e+06, IR 0.60
strict 6.1713e+06, IR 0.77

T=6:
free   6.5459e+06, IR 0.29
loose  6.5505e+06, IR 0.29
medium 6.2819e+06, IR 0.58
strict 6.3429e+06, IR 0.56
```

The mechanism is broader than “leave exactly two spare CPUs.” The repeated
result is that **narrow private CPU territories themselves are harmful to the
refinement/progress path**, while broad free/shared territory is sufficient.
This is consistent with the OS/runtime already scheduling the broad CPU pool
adequately: explicit affinity adds no measured benefit here, while narrow
manual partitioning removes scheduling flexibility and slows IR.

Retain:

```text
--cpu-affinity omitted
```

### 7.3 Step C — OpenMP place/bind

Socket-level policies are flat at both T=4 and T=6. Explicit
`sockets/CLOSE` and `sockets/SPREAD` remain within 0.5% of the omitted
package-default control and leave LU/IR unchanged.

Every `OMP_PLACES=cores` policy collapses performance to about
`1.84–1.86e+06 GFLOP/s`, with LU rising to about 12.7–13.1 s and IR to
15.5–16.0 s. The likely failure has two coupled parts: every free MPI rank sees
the same full two-NUMA cpuset, so singleton core places can bind a rank's host
threads to cores remote from its GPU/NIC NUMA side, and independent ranks may
also choose overlapping singleton core places and contend. TASK-009 does not
enumerate the actual Intel OpenMP place-to-thread mapping, so cross-NUMA
misplacement versus contention cannot be separated quantitatively. Core-level
binding is therefore rejected under the current free-rank/cpuset launcher
contract.

Retain:

```text
OMP_PLACES omitted
OMP_PROC_BIND omitted
effective launcher policy = sockets / TRUE
```

### 7.4 Retained host-runtime control

```text
OMP_NUM_THREADS = 4
cpu-affinity = omitted
mem-affinity = omitted
ucx-affinity = omitted / automatic
OMP_PLACES = omitted
OMP_PROC_BIND = omitted
effective OpenMP placement = sockets / TRUE
```

T=4 is a representative of the 4–8 plateau, not a uniquely proven optimum.

### 7.5 Dependency checkpoint

- **E18 + E39:** host runtime is validated at N=429056, but the useful N
  operating point is reopened because TASK-009 materially changes the IR/LU
  regime that originally selected N=429056. N remains fundamentally a
  matrix/residency variable; the new insight is that host runtime is an
  additional causal layer controlling how expensive N-induced refinement work
  becomes.
- **E19:** CPU/OpenMP interaction is now directly observed and resolved for the
  current launcher/cpuset. No immediate memory-affinity resweep is required
  because the retained CPU policy remains free and socket-level; retain memory
  affinity omitted.
- **E20/E21:** DGEMV is technically reopened by the host-runtime change but is
  deferred. At the current point IR is only 0.29 s / IR-LU 0.037, and N must
  be reclosed first.
- **E07/E09/E14/E15/E37:** become conditionally active if the reopened N moves
  materially.
- **E12/E13:** Phase-4 communication remains deferred until the upstream N
  operating point is reclosed.

### 7.6 Proposed next action

Run a bounded N re-sweep under the **verified** retained host-runtime contract:

```text
N = 429056, 454656, 504832, 556032, 606208
```

Keep NB=3072, 4x4 row, identity GPU affinity, CPU/memory/UCX affinity omitted,
OMP_NUM_THREADS=4, OMP place/bind omitted, and every other current scientific
control fixed. Explicitly forward and verify OMP_NUM_THREADS on all 16 ranks.

This re-tests the old LU-versus-IR tradeoff across the known FP64-residency
transition under the corrected/verified host-runtime contract. The purpose is
not to assume larger N will win, but to determine whether the previous larger-N
decline was intrinsic matrix/residency cost or was materially amplified by the
former host-runtime state. Do not start DGEMV or Phase-4 communication before
this N revalidation closes.

**Human decision state:** TASK-009 analysis complete. N re-sweep proposed only;
no execution is authorized.


## 8. TASK-010 — Geometry Re-closure after Host-Runtime Shift

TASK-010 re-swept N under the verified TASK-009 host-runtime contract to test
whether the large IR reduction at `N=429056` created room for a larger N.

Detailed analysis:
`planning/analysis/2x8-gaas-task010-geometry-reclosure.md`.

### 8.1 Results

| N | Overall GFLOP/s | vs N=429056 | LU GFLOP/s | LU s | IR s | IR/LU | Host memory MAX | Device headroom |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **429056** | **6.4431e+06** | control | 6.6784e+06 | 7.85 | **0.29** | **0.037** | **0.004 GB** | **2.767 GB** |
| 454656 | 5.9212e+06 | -8.10% | 6.9761e+06 | 8.98 | 1.60 | 0.178 | 15.024 GB | 2.257 GB |
| 504832 | 5.2147e+06 | -19.07% | 7.1739e+06 | 11.96 | 4.49 | 0.375 | 51.561 GB | 2.257 GB |
| 556032 | 5.0581e+06 | -21.50% | 7.6101e+06 | 15.06 | 7.60 | 0.505 | 95.340 GB | 2.257 GB |
| 606208 | 4.3901e+06 | -31.86% | **7.7508e+06** | 19.16 | **14.67** | **0.766** | **136.519 GB** | 2.257 GB |

All five points passed correctness with three refinement iterations.

### 8.2 Main conclusion

The expectation that a larger N might win was reasonable: larger N does
improve LU throughput. From 429056 to 606208, LU throughput rises about 16%.

However, the TASK-009 host-runtime improvement did **not** remove the
N/residency penalty. It lowered the IR floor at the retained N. The
FP64-residency cliff remains between 429056 and 454656:

```text
N=429056:
  host consumption = 0.004 GB/process
  device headroom  = 2.767 GB/process
  IR               = 0.29 s

N=454656:
  host consumption = 15.024 GB/process
  device headroom  = 2.257 GB/process
  IR               = 1.60 s
```

Above that point, device use is effectively saturated while host allocation
continues to rise to 136.519 GB/process at N=606208. IR rises in parallel from
0.29 to 14.67 s while the iteration count stays fixed at three. Therefore the
dominant penalty is higher cost per refinement iteration in the
host-resident/staged FP64 regime, not extra iterations.

The end-to-end tradeoff becomes increasingly unfavorable:

```text
IR/LU:
0.037 -> 0.178 -> 0.375 -> 0.505 -> 0.766
```

The effective IR tax on LU-only throughput rises from about 3.6% at N=429056
to about 43.4% at N=606208. That overwhelms the 16% LU-throughput gain.

Thus N=429056 remains near the useful knee: large enough for good LU
efficiency, but just below the costly FP64 host-residency transition.

### 8.3 Dependency checkpoint

- **E39:** resolved for the verified TASK-009 runtime. The host-runtime shift
  required an N recheck, but the useful N remains 429056.
- **E14/E15:** strongly reconfirmed; the N/residency cliff remains the main
  reason larger N loses.
- **E07:** not triggered because N did not move; NB=3072 remains closed.
- **E09/E10:** not triggered; 4x4 row remains the retained grid/order.
- **E18/E19:** no N-driven host-runtime reopening; retain the TASK-009 host
  policy.
- **E20/E21:** DGEMV is not worth the next sweep at IR=0.29 s / IR-LU=0.037.
  Keep the default as a conditional control and reopen only if a later change
  makes IR material.
- **E12/E13:** now unblocked. Geometry, placement, host runtime, and N are
  stable enough to proceed to communication.
- **E37:** no N-driven reopening; keep scheduling downstream of communication.

### 8.4 Retained operating point

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
sloppy-type = FP16
```

### 8.5 Proposed next action

**Proceed to Phase 4 communication tuning** under the fixed retained stack.

Do not spend the next task on DGEMV: with IR only 0.29 s, even eliminating the
entire refinement phase would offer only about 3.6% theoretical end-to-end
headroom, and DGEMV changes only part of that phase. Communication tuning can
instead target the dominant LU path and closes the E12/E13 obligations that
were intentionally deferred until the N re-closure finished.

The first communication task should remain bounded and should not combine
panel/transport changes with N/NB/grid, OMP/CPU, precision, DGEMV, or LU
scheduling changes.

**Human decision state:** TASK-010 analysis complete. Phase 4 communication is
recommended only; no new execution is authorized.


## 9. TASK-2X8-011 — Phase 3C Residency Closure

TASK-2X8-011 isolated FP64 residency at the retained `N=429056`,
`NB=3072`, 4x4-row, OMP=4 operating point.

Detailed analysis:
`planning/analysis/2x8-gaas-phase3c-residency-closure.md`.

### 9.1 Residency curve

| Residency mode | Host memory MAX | Device memory MAX | LU GFLOP/s | LU s | IR s | IR/LU | Overall GFLOP/s |
|---|---:|---:|---:|---:|---:|---:|---:|
| Anq=0 | 86.137 GB | 49.121 GB | 6.7360e+06 | 7.82 | 7.66 | 0.980 | 3.4031e+06 |
| Anq=24576 | 66.450 GB | 68.808 GB | 6.7848e+06 | 7.76 | 5.14 | 0.662 | 4.0811e+06 |
| Anq=49152 | 46.762 GB | 88.496 GB | 6.7757e+06 | 7.77 | 3.60 | 0.463 | 4.6299e+06 |
| Anq=73728 | 27.075 GB | 108.183 GB | 6.7778e+06 | 7.77 | 2.36 | 0.304 | 5.1971e+06 |
| Anq=98304 | 7.387 GB | 127.871 GB | 6.7857e+06 | 7.76 | 1.10 | 0.142 | 5.9457e+06 |
| **fill-device=1** | **0.004 GB** | **135.254 GB** | **~6.77e+06** | **~7.78** | **0.29** | **0.037** | **~6.53e+06** |

The full-fill bracket F0/F1 differed by only 0.09%. The best partial-residency
point, `Anq=98304`, remained 8.90% below the full-fill reference.

The key isolation is that LU is essentially unchanged across the entire curve:
LU time remains ~7.76-7.82 s and LU throughput stays within about 0.75%.
Final performance therefore follows the IR penalty, which falls from 7.66 s at
Anq=0 to 0.29 s under full fill.

This directly validates the campaign model:

```text
R_MxP ~= P_LU / (1 + T_IR / T_LU)
```

At fixed N/work, increasing FP64 device residency mainly reduces refinement
time; it does not materially accelerate LU.

### 9.2 Buffer closure

| Buffer | Overall GFLOP/s | LU s | IR s | Host memory MAX | Device headroom |
|---:|---:|---:|---:|---:|---:|
| 2048 | 6.5269e+06 | 7.78 | 0.29 | 0.004 GB | 2.767 GB |
| **3048** | **6.5373e+06** | **7.77** | **0.29** | **0.004 GB** | **2.767 GB** |
| 4096 | 6.3963e+06 | 7.79 | 0.44 | 0.520 GB | 3.280 GB |

2048 and 3048 are one practical plateau; their score difference is only
0.16% and their observed memory/IR regimes are identical. At 4096 MB, the
larger reserve begins to displace useful FP64 residency: host allocation rises,
IR increases to 0.44 s, and the score falls 2.16% versus the final 3048
control while LU remains flat.

Retain the established 3048 MB default because 2048 provides no measured
performance benefit while nominally reserving less workspace.

### 9.3 Phase-3C and dependency closure

Retain:

```text
--fill-device 1
--fill-device-buffer-size 3048
--Anq-device irrelevant/overridden
```

Dependency checkpoint:

- **E14/E15:** strengthened. TASK-010 showed larger N crossing the residency
  cliff; TASK-2X8-011 reproduces the same IR penalty by directly reducing
  residency at fixed N. Because full fill remains retained, no N reopen is
  triggered.
- **E16:** resolved at the current N/NB/release. 2048-3048 is the fast safe
  plateau; 4096 is valid but begins to sacrifice useful residency.
- **E17:** keep `cuda-host-register-step=2048` closed. Retained host-resident
  FP64 allocation is essentially zero, so the registration mechanism is
  currently irrelevant.
- **E20/E21:** keep `call-dgemv-with-multiple-threads=0` closed for Phase 3.
  IR is only 0.29 s / IR-LU 0.037, so solver-side tuning has little current
  leverage. Precision can reopen it later through E35.
- **E12/E13:** remain unblocked for Phase 4 communication.

### 9.4 Phase-3 closure

The blueprint makes Phase 3D conditional on observed host staging or solver
cost. The retained Phase-3C state has:

```text
host consumption ~= 0.004 GB/process
IR ~= 0.29 s
IR/LU ~= 0.037
```

Therefore no additional Phase-3D performance sweep is justified in the current
regime. Retain:

```text
--cuda-host-register-step = 2048
--call-dgemv-with-multiple-threads = 0
```

Phase 3 is closed conditionally for the retained stack.

### 9.5 Proposed next action

**Proceed to Phase 4 communication tuning.**

The upstream geometry, placement, host runtime, N/residency, buffer, and
remaining host/refinement controls are now closed. The next task should vary
communication controls only, preserving the retained Phase-3 stack.

**Human decision state:** TASK-2X8-011 analysis complete. Phase 4 communication
is recommended only; no new execution is authorized.


## 10. TASK-2X8-012 — Phase 3D Host / Memory Closure

TASK-2X8-012 directly swept the two remaining Phase-3D controls on the
retained 2x8 stack.

Detailed analysis:
`planning/analysis/2x8-gaas-phase3d-host-memory-closure.md`.

### 10.1 Host-register step

| Step | Overall GFLOP/s | LU s | IR s | Host memory | Device headroom |
|---:|---:|---:|---:|---:|---:|
| 512 | 6.5578e+06 | 7.74 | 0.29 | 0.004 GB | 3.997 GB |
| 1024 | 6.5198e+06 | 7.79 | 0.29 | 0.004 GB | 3.587 GB |
| **2048** | **~6.535e+06** | **~7.77** | **0.29** | **0.004 GB** | **2.767 GB** |
| 4096 | 6.3877e+06 | 7.72 | 0.52 | 1.136 GB | 2.257 GB |
| 8192 | 6.1579e+06 | 7.76 | 0.79 | 4.418 GB | 2.257 GB |

The 2048 bracket spread was only 0.11%. Steps 512-2048 are a performance
plateau with identical low IR and no reported host allocation. Smaller steps
also reduce the observed device-memory footprint, so 512/1024 are useful
headroom fallbacks.

4096/8192 cross a different memory regime: host allocation appears, IR rises,
and the final score falls while LU remains flat. This creates a new dependency
(E40): host-register step can alter effective residency/headroom under
full fill.

Retain `cuda-host-register-step=2048` because it is the established/default
control and 512 does not provide a material score benefit. The lower values
remain available if a later phase creates VRAM pressure.

### 10.2 DGEMV

The bracketed 0-30720 sweep is flat:

```text
IR = 0.29 s for every candidate
LU ~= 7.73-7.76 s
host = 0.004 GB/process
device = 135.254 GB/process
headroom = 2.767 GB/process
```

All candidates lie within ±0.20% of the zero-control midpoint; the zero
bracket itself differs by only 0.19%.

Retain:

```text
--call-dgemv-with-multiple-threads = 0
```

### 10.3 Dependency checkpoint

- **E17:** directly revalidated and closed at register-step 2048.
- **E40 (new):** register-step can alter effective memory residency/headroom.
  It is inactive at the retained 2048 point; a future material register-step
  change must recheck memory/IR and only reopen N/buffer if the regime changes.
- **E16/E15:** not reopened; retained buffer/residency and N are unchanged.
- **E20/E21:** closed for the current OMP=4 / N=429056 / full-residency
  regime because DGEMV is flat across 0-30720.
- **E35/E36:** remain future reopen paths after a material precision change.
- **E12/E13:** communication is unblocked.

### 10.4 Phase-3 closure

Retain the complete Phase-3 stack:

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

fill-device = 1
fill-device-buffer-size = 3048
cuda-host-register-step = 2048
call-dgemv-with-multiple-threads = 0

sloppy-type = FP16
```

**Phase 3 is closed. No immediate dependency-driven resweep is required.**

### 10.5 Proposed next action

Proceed to **Phase 4 communication tuning** while keeping the full retained
Phase-3 stack fixed.

If later communication/precision work creates material VRAM pressure,
register-step 512/1024 are validated low-IR headroom fallback candidates, but
they should be introduced explicitly through E40 rather than silently stacked.

**Human decision state:** TASK-2X8-012 analysis complete. Phase 4 communication
is recommended only; no new execution is authorized.


## 11. TASK-2X8-013 — Phase 4A Communication Fast-Path Characterization

TASK-2X8-013 characterized the retained 2x8 communication path without tuning
it.

Detailed analysis:
`planning/analysis/2x8-gaas-phase4a-fast-path-characterization.md`.

### 11.1 Clean Phase-4 reference

```text
A0 overall = 6.5324e+06 GFLOP/s
LU         = 7.77 s / 6.7741e+06 GFLOP/s
IR         = 0.29 s
IR/LU      = 0.037
PASSED
```

The A1 diagnostic clone scored 6.5354e+06 (+0.046% versus A0) with identical
LU and IR, and reproduced the same per-HCA traffic shape. The diagnostic
instrumentation therefore did not materially perturb the run.

### 11.2 Fast-path result

Automatic MPI/UCX is healthy:

```text
PML = ucx
UCX_TLS = unset / automatic
UCX_NET_DEVICES = unset / automatic
inter-node transport = rc_mlx5
large GPU-buffer protocol = rendezvous zero-copy
TCP inter-node lanes = 0
frag-host staging rows = 0
```

Automatic NCCL is also healthy:

```text
backend = IBext_v11
inter-node channel lines = 128
GDRDMA-tagged = 128
GDRDMA fraction = 1.00
Socket channels = 0
```

Thus Phase 4 is not repairing a broken inter-node stack. Both candidate
communication families have functional GPU-direct paths.

### 11.3 Fabric result

All eight physical 400-Gb HCAs are active with no new
error/discard/recovery counters.

g14 TX is nearly perfectly balanced across all eight rails (CV 0.58%). g15 TX
is directionally asymmetric: mlx5_4/5/8/9 carry about 70% of g15's outgoing
volume while mlx5_0-3 carry about 30%. The opposite-node RX counters mirror the
same pattern, and A0/A1 reproduce it exactly.

Interpretation: the asymmetry is deterministic application/rank/communicator
traffic direction, not evidence that four rails are unused or faulty. Keep
UCX affinity closed/automatic.

`port_xmit_wait` is nonzero on every HCA and is consistently higher on
mlx5_4/5/8/9. Preserve it as a Phase-4 explanatory metric; do not treat it as
a fault or tuning target by itself.

### 11.4 Dependency checkpoint

- **E06/E12:** fast paths are characterized, but panel transport remains open
  for Phase 4B policy optimization.
- **E13:** automatic placement uses all eight physical rails; no placement
  reopen is justified by 4A.
- **E22:** Phase 4B remains fixed at NB=3072.
- **E23/E24/E25:** U-panel chunk remains downstream for Phase 4C.
- **E26/E29:** scheduling remains downstream of communication.
- No new dependency edge is required.

### 11.5 Proposed next action

Proceed to a bounded **Phase 4B panel-policy experiment**.

Because AUTO UCX already selects `rc_mlx5` zero-copy, the primary optimization
axis should be `--use-mpi-panel-broadcast`. Keep AUTO UCX as the main
control and include at most one explicitly constrained rc_mlx5-based UCX
transport family as a small interaction/confirmation check rather than a broad
`UCX_TLS` sweep.

Continue recording per-HCA TX/RX/`port_xmit_wait` so a LU improvement can be
connected to a real communication-path change.

Stop before U-panel chunk tuning; Phase 4C should operate only on the retained
Phase-4B communication policies.

**Human decision state:** TASK-2X8-013 analysis complete. Phase 4A is closed.
Phase 4B is recommended only; no new execution is authorized.


## 12. TASK-2X8-014 — Phase 4B MPI/NCCL Panel-Broadcast Sweep

Detailed analysis:
`planning/analysis/2x8-gaas-phase4b-panel-broadcast-sweep.md`.

### 12.1 Result

Phase 4B decisively retains:

```text
--use-mpi-panel-broadcast = 0
```

Using the Stage-B panel-0 midpoint as the local reference:

| panel % | overall GFLOP/s | overall delta | LU GFLOP/s | LU delta |
|---:|---:|---:|---:|---:|
| 0 midpoint | 6.54645e+06 | control | 6.7899e+06 | control |
| 5 | 6.0111e+06 | -8.18% | 6.2154e+06 | -8.46% |
| 10 | 6.0165e+06 | -8.10% | 6.2205e+06 | -8.39% |
| 15 | 5.3034e+06 | -18.99% | 5.4620e+06 | -19.56% |
| 20 | 5.0197e+06 | -23.32% | 5.1612e+06 | -23.99% |
| 25 | 5.2204e+06 | -20.26% | 5.3735e+06 | -20.86% |
| 50 | 3.7761e+06 | -42.32% | 3.8558e+06 | -43.21% |
| 75 | 3.2660e+06 | -50.11% | 3.3256e+06 | -51.02% |
| 100 | 3.2885e+06 | -49.77% | 3.3487e+06 | -50.68% |

Control drift was only ~0.44% in both the coarse and fine stages, so all
positive-policy regressions are decisively material.

IR stayed 0.29 s / 3 iterations with the same residual and memory footprint.
GEMM component timing also stayed ~5.95-5.97 s across the fine sweep. The
regression is therefore LU communication/readiness-side, not compute,
refinement, or residency-side.

### 12.2 Mechanism

The useful shorthand is that NCCL is specialized for GPU collectives while
MPI/UCX is a general-purpose communication stack. MPI is **not** inherently
small-message-only: Phase 4A and the panel-10 diagnostic both show healthy
CUDA-aware UCX over rc_mlx5 with large-message rendezvous zero-copy.

The critical HPL-MxP detail is that a positive
`--use-mpi-panel-broadcast=X` applies MPI to the **first X percent of panel
steps**. Early HPL iterations operate on the largest trailing matrix, so even a
small positive X assigns MPI to the bandwidth-heavy early panel traffic.

This matches the measured shape: 5-10% already cost ~8.4% LU, and larger MPI
prefixes progressively lose much more.

HPL-MxP's pre-matgen component tests also strongly favor NCCL for U-panel
broadcasts (NCCL ~0.17 s versus MPI multi-second U-panel tests), while the L2
gap is much smaller. These test timings are supporting mechanism evidence only,
not an LU-time decomposition.

A second likely contributor is collective scheduling/progress/overlap:
NCCL's GPU-collective/CUDA-stream path is better matched to the panel critical
path, while MPI/UCX can remain fully GPU-direct yet impose less favorable
readiness/completion behavior.

### 12.3 Fabric evidence

Panel-0 g14 traffic is nearly perfectly spread across eight HCAs (CV ~0.58%).
Positive policies produce a substantially more concentrated rail pattern,
progressively favoring mlx5_0/1.

However, whole-arm HCA counters include the pre-run communication component
tests, so the positive-policy jump in total bytes cannot be attributed directly
to LU.

No new errors/discards/recovery counters appear. Available port_xmit_wait
counters do not increase with MPI percentage, so the evidence does not support
a simple fabric-congestion explanation.

### 12.4 Dependency checkpoint

- **E06/E12:** panel transport resolved for the retained 2x8 regime.
- **E13:** no UCX-affinity reopen is justified.
- **E22:** NB=3072 remains fixed.
- **E25:** pass a single retained broadcast policy into Phase 4C.
- **E23/E24:** U-panel chunking remains the next communication variable.
- **E26/E29:** scheduling remains downstream.

### 12.5 Proposed next action

Proceed to Phase 4C with:

```text
--use-mpi-panel-broadcast=0
```

fixed.

Do not carry positive MPI-panel policies as performance candidates. Tune only
`--u-panel-chunk-nbs` around the retained value 8, using the previously
validated legal range (for example 2,4,8,16) and the same LU/fabric evidence.

**Human decision state:** TASK-2X8-014 analysis complete. Phase 4B is closed.
Phase 4C is recommended only; no new execution is authorized.


## 13. TASK-2X8-015 — Phase 4C UCX Transport and U-Panel Chunk

Detailed analysis:
planning/analysis/2x8-gaas-phase4c-ucx-transport-and-u-panel-chunk.md

### 13.1 UCX transport result

Retain UCX_TLS unset / AUTO.

AUTO, RC, RC-X, DC, and UD all remained within about 0.6% LU of the AUTO
midpoint. AUTO bracket drift was 0.14% LU / 0.08% overall.

The flat result does not mean the transports are intrinsically equal. With
use-mpi-panel-broadcast=0, the dominant U-panel path is NCCL, so UCX_TLS only
changes the remaining MPI/UCX traffic. Aggregate HCA totals, rail shares, and
usable port_xmit_wait counters were essentially identical across the Stage-A
families, confirming that UCX family choice is low-leverage in this regime.

### 13.2 U-panel chunk result

Chunk tuning is material:

| chunk | overall GFLOP/s | delta vs chunk-8 midpoint | LU GFLOP/s | LU delta |
|---:|---:|---:|---:|---:|
| 2 | 6.7662e+06 | +3.24% | 7.0260e+06 | +3.37% |
| 4 | 6.8223e+06 | +4.10% | 7.0862e+06 | +4.26% |
| 8 midpoint | 6.55365e+06 | control | 6.7968e+06 | control |
| 16 | 6.3538e+06 | -3.05% | 6.5819e+06 | -3.16% |

The 8a/8b bracket was only 0.16% LU / 0.18% overall.

Interpretation: chunk controls U-panel readiness granularity, not NCCL transport.
Smaller chunks make useful U data available sooner and improve overlap. Chunk 16
is too coarse; chunk 2 begins paying extra fine-grained launch/synchronization
overhead; chunk 4 is the strongest tested balance.

Retain u-panel-chunk-nbs=4. Chunk 2 remains a strong nearby alternative; the
2-vs-4 difference is below the 2% campaign materiality convention.

### 13.3 Numerical note

Chunk 16 residual was 1.587984E-05 versus 1.416310E-05 for chunks 2/4/8,
about 12.1% higher, but PASSED with the same 0.29 s IR and 3 iterations.

This suggests coarse chunking may alter mixed-precision operation ordering
enough to perturb the final residual slightly, but there is no convergence or
performance issue. No dedicated accuracy study is required now.

### 13.4 Dependency checkpoint

- UCX transport-family forcing is closed under panel=0.
- E23/E24 chunk validity/usefulness is resolved for the current geometry.
- E25 is updated by new evidence: at panel=0, chunk is not flat; 2/4 beat 8/16.
- E27 is active: chunk 8 -> 4 materially changes readiness, so downstream
  stream/priority controls deserve light revalidation.
- E26 remains relevant.
- Geometry, UCX affinity, panel policy, residency, and IR remain closed.

### 13.5 Proposed next action

Proceed through the remaining LU scheduling flags with:

UCX_TLS = AUTO
use-mpi-panel-broadcast = 0
u-panel-chunk-nbs = 4

Prioritize lightweight revalidation of prioritize-trsm,
prioritize-factorization, and use-separate-stream-for-gemm before any Nsight
profiling.

Human decision state: TASK-2X8-015 analysis complete. Phase 4C is closed.


## 14. TASK-2X8-016 — Chunk-4 Confirmation and Phase-4 Closure

TASK-2X8-016 repeated the retained chunk-4 configuration once under a fresh
scored run.

| Metric | TASK-2X8-015 K4 | TASK-2X8-016 confirmation | Relative difference |
|---|---:|---:|---:|
| Overall GFLOP/s | 6.8223e+06 | 6.8196e+06 | -0.04% |
| LU GFLOP/s | 7.0862e+06 | 7.0833e+06 | -0.04% |
| LU time | 7.43 s | 7.43 s | effectively identical |
| IR | 0.29 s | 0.29 s | identical |
| Residual | 1.416310E-05 | 1.416310E-05 | identical |
| Verification | PASSED | PASSED | identical |

The HCA traffic signature also reproduced effectively exactly, with the same
rail CVs and no new errors/discards/recovery events.

**Phase 4 — Communication is CLOSED.**

Retained communication configuration:

~~~text
UCX_TLS = unset / AUTO
UCX_NET_DEVICES = unset / AUTO
ucx-affinity = omitted / AUTO
use-mpi-panel-broadcast = 0
u-panel-chunk-nbs = 4
~~~

The blueprint repeatability/closure condition is satisfied. Chunk 2 remains a
strong neighboring point, but no further Phase-4 refinement is justified.

Next direction: Phase 5 LU scheduling revalidation under chunk 4.


## 15. Phase 5 — Final Scheduling and Dependency Revalidation

Phase 5 started from the formally closed Phase-4 stack:

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

test-loop = 1
skip-tests = 0
monitor-gpu = 0
~~~

Phase 5 focused on the remaining exposed LU scheduling controls:

~~~text
F = --prioritize-factorization
T = --prioritize-trsm
S = --use-separate-stream-for-gemm
~~~

FP16 and the effective package-default / SM90 GEMM preset remained fixed
controls in this first pass rather than independent sweep variables.

Detailed analyses:

- `planning/analysis/2x8-gaas-phase5-final-scheduling-factorial.md`
- `planning/analysis/2x8-gaas-phase5-nb-chunk-dependency-revalidation.md`
- `planning/analysis/2x8-gaas-phase5-closure.md`

### 15.1 TASK-2X8-017 — Final scheduling 2^3 factorial

TASK-2X8-017 ran the complete factorial over F/T/S, with the retained
`001` state bracketed at the beginning and end.

The retained `001` control midpoint was:

~~~text
overall = 6.8271e+06 GFLOP/s
LU      = 7.0921e+06 GFLOP/s
LU time ~= 7.43 s
IR      = 0.29 s
~~~

The bracket spread was only about 0.285% overall and 0.265% LU, so the
factorial had a tight local noise reference.

| F | T | S | Overall GFLOP/s | Delta vs 001 midpoint | LU GFLOP/s | LU delta | LU s | IR s |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 0 | 6.8589e+06 | +0.47% | 7.1258e+06 | +0.48% | 7.39 | 0.29 |
| 0 | 1 | 0 | 6.7201e+06 | -1.57% | 6.9762e+06 | -1.63% | 7.55 | 0.29 |
| 0 | 1 | 1 | 6.8686e+06 | +0.61% | 7.1363e+06 | +0.62% | 7.38 | 0.29 |
| 1 | 0 | 0 | 6.8366e+06 | +0.14% | 7.1018e+06 | +0.14% | 7.41 | 0.29 |
| **1** | **0** | **1** | **7.2398e+06** | **+6.05%** | **7.5380e+06** | **+6.29%** | **6.99** | **0.29** |
| 1 | 1 | 0 | 6.7228e+06 | -1.53% | 6.9792e+06 | -1.59% | 7.54 | 0.29 |
| 1 | 1 | 1 | 7.1904e+06 | +5.32% | 7.4853e+06 | +5.54% | 7.03 | 0.29 |

All arms PASSED with three refinement iterations and the expected residual.
IR and memory state remained unchanged, so the gain is on the LU scheduling /
overlap path rather than refinement or residency.

### 15.2 Scheduling interpretation

The dominant result is the interaction between factorization priority and the
separate GEMM stream.

Individually:

~~~text
S=1 with F=0:
  no meaningful gain

F=1 with S=0:
  no meaningful gain
~~~

Together:

~~~text
F=1, S=1:
  about +6% overall
  about +6.3% LU
~~~

The useful mechanism-level interpretation is:

~~~text
separate GEMM stream
    -> exposes more update concurrency

factorization priority
    -> prevents that concurrency from delaying dependency-producing
       factorization work

F=1 + S=1
    -> overlap is available, but the critical panel/factorization path
       remains protected
~~~

Without factorization priority, GEMM work can compete for resources while the
next dependency-producing work is still pending. The apparent extra
concurrency can therefore backfire by delaying the work that later GEMMs are
waiting on anyway.

With factorization priority enabled, the critical dependency path advances
first and the separate GEMM stream can exploit otherwise-idle overlap more
usefully.

This is a mechanism-level interpretation of the black-box application, not a
claim about the exact internal CUDA-event or stream implementation.

TRSM priority adds no benefit in the retained regime:

~~~text
101 = 7.2398e+06 GFLOP/s
111 = 7.1904e+06 GFLOP/s
~~~

The ~0.7% gap is small but consistently favors leaving TRSM priority off.
The likely interpretation is that factorization priority is already the
important broader dependency protection, while separately prioritizing TRSM is
redundant or slightly over-constraining.

Retain:

~~~text
prioritize-factorization = 1
prioritize-trsm = 0
use-separate-stream-for-gemm = 1
~~~

### 15.3 Phase-5 dependency review

The scheduler change was large enough that the most dependency-sensitive
earlier controls had to be checked before Phase 5 could close.

The dependency review kept the following closed:

- N / FP64-residency operating point;
- process grid/order;
- GPU/CPU/NUMA placement;
- OpenMP and CPU-affinity policy;
- fill-device / buffer / host-register policy;
- DGEMV;
- panel-broadcast policy;
- UCX transport and affinity.

The two settings worth reopening were:

- **NB**, because panel width/frequency and GEMM geometry directly affect the
  factorization-vs-update scheduling balance;
- **U-panel chunk**, because readiness granularity determines when update work
  becomes schedulable.

TASK-2X8-018 therefore ran a joint valid NB × chunk matrix under fixed
scheduler `101`, rather than a sequential NB-then-chunk sweep.

### 15.4 TASK-2X8-018 — NB × U-panel chunk revalidation

The control `NB=3072, chunk=4, scheduler=101` was bracketed at the beginning
and end:

| Metric | Opening | Closing | Midpoint | Spread |
|---|---:|---:|---:|---:|
| Overall GFLOP/s | 7.2303e+06 | 7.2406e+06 | **7.23545e+06** | **0.1425%** |
| LU GFLOP/s | 7.5266e+06 | 7.5382e+06 | **7.5324e+06** | **0.1541%** |
| LU time | 7.00 s | 6.99 s | ~7.00 s | negligible |
| IR | 0.29 s | 0.29 s | 0.29 s | none |

This control midpoint is only about 0.06% below TASK-2X8-017 A101, showing
excellent cross-task reproducibility of the final stack.

#### NB result

Best valid point at each NB:

| NB | Best tested chunk | Best overall GFLOP/s | Delta vs 3072/4 midpoint |
|---:|---:|---:|---:|
| 1024 | 16 | 5.7008e+06 | -21.21% |
| 2048 | 8 | 6.9567e+06 | -3.85% |
| **3072** | **4** | **7.2303e+06** | **-0.07% vs midpoint** |
| 4096 | 8 | 6.5382e+06 | -9.64% |
| 5120 | 4 | 6.4324e+06 | -11.10% |
| 6144 | 4 | 6.0386e+06 | -16.54% |

NB=3072 wins every shared-chunk comparison:

~~~text
chunk 2:  3072 > 4096 > 5120 > 6144
chunk 4:  3072 > 2048 > 4096 > 5120 > 6144
chunk 8:  3072 > 2048 > 4096 > 5120 > 6144 > 1024
chunk 16: 3072 > 2048 > 4096 > 5120 > 6144 > 1024
~~~

The earlier Phase-1B 2048-3072 near-tie is therefore no longer the final-stack
result. Under the final stack, the best NB=2048 point is already about 3.85%
behind overall and about 2.97% behind in LU.

Retain:

~~~text
NB = 3072
~~~

#### U-panel chunk result at retained NB=3072

| Chunk | Overall GFLOP/s | Delta vs 3072/4 midpoint | LU GFLOP/s | IR |
|---:|---:|---:|---:|---:|
| 2 | 7.1815e+06 | -0.75% | 7.4754e+06 | 0.29 s |
| **4** | **7.2303e+06** | **-0.07%** | 7.5266e+06 | 0.29 s |
| **8** | **7.2296e+06** | **-0.08%** | **7.5274e+06** | 0.29 s |
| 16 | 7.1564e+06 | -1.09% | 7.4472e+06 | 0.29 s |

At scheduler 101, chunk 2/4/8/16 is a sub-2% plateau and chunk 4 versus 8 is
effectively identical.

This is a major change in interpretation from Phase 4C, where chunk 4 was
about 4.1% above the chunk-8 midpoint under the older scheduling state.

The result confirms that chunk usefulness is conditional on the scheduling
regime:

~~~text
chunk granularity
    -> readiness cadence

scheduler 101
    -> protects dependency-producing factorization work
    -> changes how strongly readiness cadence limits the critical path
~~~

The matrix also shows genuine NB × chunk interaction globally: different NBs
prefer different chunks. That validates using the paired matrix instead of
sequential sweeps.

However, the interaction does not create a new retained branch because
NB=3072 wins regardless of chunk and all chunks are close inside the retained
NB.

Retain:

~~~text
u-panel-chunk-nbs = 4
~~~

as the established representative of the plateau, not as a uniquely proven
numerical optimum.

### 15.5 Memory / refinement behavior across the NB matrix

TASK-2X8-018 also reconfirmed that NB can change the memory/refinement regime:

~~~text
NB=1024:
  host = 0.004 GB/process
  device = 132.289 GB/process
  IR = 0.37 s

NB=2048:
  host = 0.517 GB/process
  device = 135.763 GB/process
  IR = 0.36 s

NB=3072:
  host = 0.004 GB/process
  device = 135.254 GB/process
  IR = 0.29 s

NB=4096:
  host = 6.123 GB/process
  device = 135.762 GB/process
  IR = 0.69-0.77 s

NB=5120:
  host = 2.554 GB/process
  device = 135.762 GB/process
  IR = 0.59-0.67 s

NB=6144:
  host = 11.900 GB/process
  device = 135.763 GB/process
  IR = 0.99-1.13 s
~~~

The host-allocation pattern is not monotonic because NB changes block-cyclic
geometry, padding, and workspace requirements; it should not be interpreted as
a direct spill-volume counter.

For the dependency decision, the important point is that the retained
NB=3072 state exactly reproduces the favorable low-IR/full-residency regime:

~~~text
host = 0.004 GB/process
IR = 0.29 s
device = 135.254 GB/process
~~~

Rejected NBs that enter a worse memory/IR state do not reopen N or residency
because they are not retained.

### 15.6 Final dependency checkpoint

- **E27 — chunk -> scheduling:** reclosed. Chunk was directly revalidated under
  scheduler 101.
- **E28 — NB -> scheduling:** reclosed. NB=3072 remains the retained geometry,
  so the scheduling factorial remains inside its valid regime.
- **E08 / E14 / E15 — NB/N/residency:** not reopened. Retained NB and memory
  state remain unchanged.
- **E10 — NB -> grid/order:** not reopened because NB stays 3072.
- **E22 / E26 — NB/transport -> scheduling:** not reopened because retained
  NB, topology, and panel policy remain unchanged.
- **E18 / E19 — host runtime:** not reopened; OMP=4/free host policy is
  unchanged and retained IR remains 0.29 s.
- **E16 / E17 / E40 — buffer/register/residency:** not reopened at retained
  NB=3072.
- **E20 / E21 — DGEMV:** not reopened; retained IR remains too small for a new
  solver-side sweep.
- **E34 — NB <-> GEMM kernel:** not triggered because retained NB remains
  3072.
- **E37 — N -> scheduling:** not triggered because N remains 429056.
- No trace/profiling branch is required; the scored evidence already resolves
  the retention decision.

No earlier phase requires a full re-sweep or light revalidation.

### 15.7 Phase-5 closure

**Phase 5 is CLOSED.**

Retained Phase-5 scheduling/readiness state:

~~~text
NB = 3072
u-panel-chunk-nbs = 4

prioritize-factorization = 1
prioritize-trsm = 0
use-separate-stream-for-gemm = 1
~~~

The exact final candidate now has three scored observations across two jobs:

~~~text
TASK-2X8-017 A101:
  7.2398e+06 GFLOP/s

TASK-2X8-018 opening control:
  7.2303e+06 GFLOP/s

TASK-2X8-018 closing control:
  7.2406e+06 GFLOP/s
~~~

The TASK-2X8-018 midpoint is `7.23545e+06` GFLOP/s, only about 0.06% below
TASK-2X8-017 A101. The opening/closing spread is only 0.1425% overall and
0.1541% LU.

Therefore the final stack is already repeat-confirmed. A separate additional
confirmation run would duplicate evidence and is not required.

Phase-5 scope note: FP16 and the effective package-default / SM90 GEMM preset
were retained as fixed controls rather than exhaustively swept. That does not
leave Phase 5 open for this first-pass campaign; any deliberate
precision/kernel study belongs to a later second-pass reopening.

## 16. 2x8 GAAS First-Pass Campaign Closure

With Phase 5 closed, the first structured end-to-end HPL-MxP optimization pass
for the **2 GAAS nodes × 8 H200 GPUs/node** topology is also **COMPLETE**.

The adopted blueprint terminates at Phase 5, and every phase is now closed for
the executed scope:

~~~text
Phase 0
  characterization + immutable baseline

Phase 1
  N / NB geometry and FP64-residency operating point

Phase 2
  process grid / order / GPU-NUMA-NIC placement

Phase 3
  host runtime / CPU locality / residency / remaining host-memory controls

Phase 4
  communication / panel transport / U-panel readiness

Phase 5
  scheduling / final-stack dependency validation
~~~

### 16.1 Final retained 2x8 stack

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

### 16.2 Baseline-to-final improvement

Immutable original 2x8 baseline:

~~~text
4.8037e+06 GFLOP/s
~~~

Final retained TASK-2X8-018 control midpoint:

~~~text
7.23545e+06 GFLOP/s
~~~

Campaign improvement:

~~~text
+50.62%
~~~

The final point is also repeatable: the three final-stack observations from
TASK-2X8-017 and TASK-2X8-018 are all within roughly 0.13% of one another.

### 16.3 Final campaign state

- Phase 5: **CLOSED**
- TASK-2X8-017: **ANALYZED**
- TASK-2X8-018: **ANALYZED**
- E27 / E28: **RECLOSED**
- Earlier phases: **remain closed**
- Additional first-pass tuning task: **none pending**
- 2x8 GAAS first-pass optimization campaign: **COMPLETE**

This closure means the first structured campaign has finished, not that a
global mathematical optimum over every possible HPL-MxP control has been
proven.

In particular, FP16 and the effective package-default / SM90 GEMM kernel were
fixed rather than independently swept. A future precision/kernel study, new
runtime control, software release, or materially different operating regime
would be a **second-pass reopening**, not unfinished work from this campaign.

