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

## 5. Phase 2A — Joint TASK-004 / TASK-005 Grid × Order Matrix

TASK-004 and TASK-005 are analyzed as one Phase-2A experiment.

Detailed analysis: `planning/analysis/2x8-gaas-phase2a-grid-order-matrix.md`.

Fixed geometry and controls:

```text
N = 429056
NB = 3072
OMP_NUM_THREADS = 8
gpu-affinity = 0:1:2:3:4:5:6:7
fill-device = 1
```

TASK-004 supplied the three `nporder=column` arms; TASK-005 supplied the corresponding three `nporder=row` arms. Both used the same physical rank placement:

```text
global ranks 0-7   -> hpc-gaas-g12
global ranks 8-15  -> hpc-gaas-g15
```

### 5.1 Results

| Grid | Order | Overall GFLOP/s | vs original baseline | LU GFLOP/s | LU s | IR s | IR/LU | Device headroom | Host consumption MAX |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 2×8 | column | `5.3746e+06` | +11.88% | `6.3307e+06` | 8.32 | 1.48 | 0.178 | 2.163 GB | 6.395 GB |
| 2×8 | row | `5.0562e+06` | +5.26% | `6.4670e+06` | 8.14 | 2.27 | 0.279 | 2.304 GB | 6.292 GB |
| 4×4 | column | `5.4505e+06` | +13.46% | `6.5964e+06` | 7.98 | 1.68 | 0.211 | **2.767 GB** | **0.004 GB** |
| **4×4** | **row** | **`5.6347e+06`** | **+17.30%** | **`6.7803e+06`** | **7.77** | **1.58** | 0.203 | **2.767 GB** | **0.004 GB** |
| **8×2** | **column** | **`5.5487e+06`** | **+15.51%** | `6.5155e+06` | 8.08 | **1.41** | **0.175** | 2.302 GB | 2.937 GB |
| 8×2 | row | `5.4331e+06` | +13.10% | `6.5199e+06` | 8.08 | 1.62 | 0.200 | 2.161 GB | 3.040 GB |

All six candidates passed correctness with three iterative-refinement iterations.

Baseline percentages use the immutable TASK-000 `4.8037e+06` GFLOP/s denominator for campaign-progress context only; TASK-000 used a different N/fill-device configuration and is not an isolated grid/order causal control.

### 5.2 Analysis

Grid and order show a real interaction:

```text
2x8: row vs column = -5.92%
4x4: row vs column = +3.38%
8x2: row vs column = -2.08%
```

No global row/column rule is therefore retained.

The phase timings reveal the mechanism more clearly:

- **2×8:** row order improves LU time slightly (8.32 -> 8.14 s), but IR rises 1.48 -> 2.27 s (+53.4%), causing the large end-to-end loss.
- **4×4:** row order improves both LU (7.98 -> 7.77 s) and IR (1.68 -> 1.58 s) in these runs.
- **8×2:** LU is effectively unchanged at 8.08 s, while row order raises IR 1.41 -> 1.62 s (+14.9%).

The row/column memory footprints within each shape are similar, and are identical for 4×4. The order effect is therefore primarily a **rank-layout / communicator / synchronization effect**, not a device-capacity effect.

Given the contiguous two-node rank map:

- `nporder=column` makes process columns node-local and process rows inter-node;
- `nporder=row` makes process rows node-local and process columns inter-node.

The preferred choice changes with P×Q, confirming that abstract process-grid shape and physical rank layout must be optimized together.

### 5.3 Current retention state

`2×8` is dropped from serious Phase-2A contention:

- its column arm is 4.62% below the current matrix leader;
- its row arm is 10.27% below;
- row order causes a large IR penalty.

The two strongest combinations are:

```text
4x4 row    = 5.6347e+06 GFLOP/s
8x2 column = 5.5487e+06 GFLOP/s
difference = 1.55%
```

That separation is not sufficient to close Phase 2A because the same 4×4-column control has moved across allocations:

```text
TASK-002: 5.6091e+06
TASK-003: 5.5381e+06
TASK-004: 5.4505e+06
```

The approximately 2.9% TASK-002-to-TASK-004 spread is larger than the current 1.55% top-two gap.

Therefore:

- **4×4 row is the current numerical leader;**
- **8×2 column is a co-leading serious candidate;**
- 4×4 column and 8×2 row remain useful order controls for one confirmation experiment;
- **Phase 2A remains open.**

### 5.4 Dependency checkpoint

The checkpoint is performed.

- **E02 topology/rank count → grid/order:** satisfied for the current 2×8/16-rank topology.
- **E09 N → grid/order:** satisfied at retained `N=429056`.
- **E10 NB → grid/order:** satisfied at retained `NB=3072`.
- **E11 grid/order → rank/GPU/NIC placement:** triggered and deferred until Phase 2A closes. Phase 2B must evaluate physical placement for the retained pair(s).
- **E12 grid/order → panel transport:** triggered downstream. Process-grid/order materially changes communicator size and node crossings; panel-transport results must later be revalidated.
- **E24 N/NB/npcol → U-panel chunk:** triggered downstream. The final npcol must be known before chunk validity/usefulness is recalculated.
- **E29 grid/order → LU scheduling:** triggered downstream because ownership, timing, and node-crossing behavior changed.
- **N/residency reopening:** conditional only. Do not reopen N before the grid/order ambiguity is resolved. If the final retained pair materially changes the residency/LU-IR regime from the Phase-1 control, use only a targeted local N revalidation.

Do not start affinity, communication, chunk, N, host-runtime, or scheduling tuning before the remaining Phase-2A ambiguity is resolved.

### 5.5 Proposed next step

**Recommended next action: one bounded same-allocation Phase-2A confirmation with exactly:**

```text
4x4 row
4x4 column
8x2 column
8x2 row
```

Keep `N=429056`, `NB=3072`, identity GPU affinity, and every other scientific control unchanged.

This confirmation:

1. removes the already-dominated 2×8 shape;
2. directly compares the two leaders in one allocation;
3. repeats 4×4 column as the established campaign control;
4. checks whether the apparent 4×4 row advantage and 8×2 column advantage are repeatable.

After the confirmation:

- retain one pair if it separates repeatably beyond within-allocation/control movement;
- if 4×4 row and 8×2 column remain tied, retain both as the Phase-2A region and carry both to Phase 2B where physical placement may break the tie.

**Human decision state:** proposed only. No confirmation run or Phase-2B execution is authorized by this analysis.

