# Analysis — 2x8 GAAS Phase 1B NB Screen

Analysis ID: `2x8-gaas-phase1b-nb-screen`

Source evidence:

- `tasks/TASK-003.md`
- `experiments/2x8-GAAS/phase1b-nb-screen/README.md`
- `experiments/2x8-GAAS/phase1b-nb-screen/outputs/`
- `experiments/2x8-GAAS/phase1a-n-refine/`
- `planning/analysis/2x8-gaas-phase1a-n-refine.md`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `results/metrics.csv`

## Result summary

TASK-003 screened NB at fixed `N=429056` with all other scientific controls held at the retained Phase-1A configuration.

| NB | Overall GFLOP/s | vs original baseline | vs TASK-003 NB=3072 | LU GFLOP/s | LU time | IR time | IR/LU | Device headroom after matgen | Host memory consumption MAX |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1024 | `4.5905e+06` | -4.44% | -17.11% | `5.3920e+06` | 9.77 s | 1.71 s | 0.175 | **5.700 GB** | 0.004 GB |
| 2048 | `5.5286e+06` | +15.09% | -0.17% | `6.5865e+06` | 7.99 s | 1.53 s | 0.191 | 2.237 GB | 0.517 GB |
| **3072** | **`5.5381e+06`** | **+15.29%** | control | **`6.5950e+06`** | **7.98 s** | **1.53 s** | 0.192 | 2.767 GB | **0.004 GB** |
| 4096 | `5.3738e+06` | +11.87% | -2.97% | `6.4400e+06` | 8.18 s | 1.62 s | 0.198 | 2.284 GB | 6.123 GB |
| 5120 | `5.1301e+06` | +6.79% | -7.37% | `6.1330e+06` | 8.59 s | 1.68 s | 0.196 | 2.319 GB | 2.554 GB |
| 6144 | `5.0524e+06` | +5.18% | -8.77% | `5.9792e+06` | 8.81 s | 1.62 s | 0.184 | 2.362 GB | 11.900 GB |

All six candidates reported finite residuals and `PASSED`, with three iterative-refinement iterations.

The same-protocol `NB=3072` control moved from `5.6091e+06` in TASK-002 to `5.5381e+06` in TASK-003, a -1.27% cross-allocation change. The `NB=2048` versus `NB=3072` separation inside TASK-003 is only 0.17%, therefore smaller than the observed control movement and should be treated as a plateau rather than a proven unique performance difference.

## Analysis

### NB=2048–3072 is the retained performance plateau

The dominant NB effect is on LU rather than iterative refinement.

```text
NB      LU time   LU GFLOP/s   IR time
1024      9.77       5.3920      1.71
2048      7.99       6.5865      1.53
3072      7.98       6.5950      1.53
4096      8.18       6.4400      1.62
5120      8.59       6.1330      1.68
6144      8.81       5.9792      1.62
```

`NB=1024` creates many small panels. This improves memory headroom and keeps the refinement fraction low, but the LU path pays more panel/factorization/broadcast/synchronization overhead and uses smaller trailing-update shapes, causing the severe end-to-end loss.

Increasing to `NB=2048–3072` reduces panel frequency and gives a much stronger LU/update geometry without materially increasing IR time. This is the useful region.

Beyond `NB=3072`, larger panels do not continue improving LU. Instead LU time rises progressively. The likely mechanism is the opposite side of the block-size tradeoff: fewer but larger panels increase per-panel dependency/communication/workspace cost, reduce pipeline granularity/overlap, and alter trailing GEMM shapes. The sweep therefore shows a real broad optimum around `2048–3072`, not a monotonic "larger NB is better" rule.

### Why NB changes host/device memory even though N is fixed

The total mathematical matrix size `N×N` is fixed, but the benchmark does not allocate only one ideal, perfectly balanced matrix buffer.

NB is the panel/block width. Changing it changes:

1. **2-D block-cyclic local ownership and padding.** The global matrix is distributed in NB-sized blocks across the 4×4 process grid. Different NB values produce different numbers of blocks and different remainder placement, so the worst rank can own a different local row/column extent even though global N is unchanged.
2. **LU panel/workspace size.** Factorization, TRSM, update, panel broadcast, and temporary buffers scale with NB and with the local blocked geometry.
3. **Communication and staging buffers.** Larger panels mean larger per-panel messages/buffers; chunking is expressed in units of NB and therefore also changes byte volume per chunk.
4. **FP64 fill-device placement.** With `--fill-device 1`, HPL-MxP puts as much of the original FP64 matrix on the GPU as practical while leaving the configured device buffer zone (`fill-device-buffer-size=3048` MB). If the local blocked matrix plus runtime/workspace allocation changes, the amount of FP64 matrix that fits on-device can change; the remainder and host-side workspaces increase host consumption.

Illustrative block-cyclic arithmetic for `N=429056`, 4×4 grid, before counting low-precision copies or runtime workspaces:

| NB | max local row/column extent | approx. worst-rank FP64 local matrix |
|---:|---:|---:|
| 1024 | 107520 | 92.48 GB |
| 2048 | 108544 | 94.25 GB |
| 3072 | 107520 | 92.48 GB |
| 4096 | 109568 | 96.04 GB |
| 5120 | 107520 | 92.48 GB |
| 6144 | 110592 | 97.84 GB |

This table is an allocation-mechanism illustration, not a reconstruction of the benchmark's reported memory counters. It explains why NB can create non-monotonic local memory demand: the block distribution/remainder changes with NB, not simply "larger NB = more matrix bytes."

The measured data then includes those local-shape effects **plus** benchmark workspaces and fill-device placement:

- `NB=1024`: device consumption only 132.289 GB and 5.700 GB remains after matrix generation. The blocked local representation/workspace does not force the GPU close to its practical fill ceiling.
- `NB=2048`: device consumption reaches 135.763 GB and headroom falls to 2.237 GB; host consumption is 0.517 GB.
- `NB=3072`: 135.254 GB device consumption, 2.767 GB headroom, and essentially zero reported host consumption.
- `NB=4096/5120/6144`: device use remains near the practical ceiling while host consumption becomes several GB and reaches 11.900 GB at 6144.

The reported host-memory-consumption field must **not** be interpreted as a pure "FP64 spill counter." It can include host-side benchmark allocations/workspaces as well as FP64 data that cannot remain device-resident. The non-monotonic `4096 → 5120 → 6144` host numbers are a strong reason to treat it as total benchmark host allocation evidence rather than a simple spill formula.

### Memory headroom affects feasibility and IR, but more headroom is not automatically faster

TASK-003 demonstrates this directly:

- `NB=1024` has the most GPU headroom (5.700 GB) and effectively no host consumption, but is the slowest valid candidate because LU is poor.
- `NB=2048/3072` uses much more GPU memory but is roughly 20% faster than NB=1024 because the LU geometry is much better.
- larger NB values consume additional host/workspace memory and also lose LU performance.

Therefore memory should be treated as:

```text
hard constraint + mechanism
not
optimization objective by itself
```

Headroom matters when it approaches OOM, forces FP64 staging, or changes the refinement path. Otherwise the faster point is determined by the combined LU+IR critical path.

### Retain NB=3072 as the representative control inside the 2048–3072 plateau

Performance alone does not distinguish 2048 from 3072: they differ by only 0.17%, well inside the observed cross-allocation movement.

However, `NB=3072` is the stronger representative for the next phase because:

- it matches the retained Phase-1A control;
- it has essentially zero reported host consumption versus 0.517 GB at NB=2048;
- it has 2.767 GB device headroom versus 2.237 GB at NB=2048;
- LU and IR are effectively identical between the two.

Thus retain the **NB=2048–3072 plateau**, with **NB=3072 as the representative Phase-1 geometry control**. This is not a claim that 3072 is uniquely faster.

## Mandatory dependency checkpoint

### E08 — NB → N / memory boundary

The dependency is empirically visible: changing NB at fixed N changes both host and device headroom.

However the retained representative NB remains `3072`, the same NB used to establish `N=429056` in Phase 1A. TASK-003 did not identify a superior NB that materially changes the residency regime.

Therefore:

- **keep N closed at 429056;**
- **do not run a targeted N resweep now.**

The retained geometry has already been independently repeated:

```text
TASK-002: N=429056, NB=3072 -> 5.6091e+06
TASK-003: N=429056, NB=3072 -> 5.5381e+06
difference = -1.27%
```

Even the lower repeat remains 5.32% above the TASK-002 `N=454656` neighbor and 8.49% above the `N=404480` neighbor, so the Phase-1 N conclusion survives the repeat.

### Other dependency consequences

- **E10, NB → grid/order:** retained NB did not change, but E09 already requires a fresh Phase-2A grid/order sweep because the N/residency regime changed materially. Proceed with full 2A screening rather than preserving 4×4 column as an optimum.
- **E22, NB → panel transport:** the current broadcast setting remains provisional for the 2×8 multinode topology; tune it later after grid/placement is established.
- **E23/E24, NB/N/npcol → U-panel chunk:** default chunk=8 remains a provisional control. Its validity/usefulness must be recalculated after process-grid changes because npcol changes the documented chunk constraint.
- **E28, NB → LU scheduling:** priority/stream settings remain open downstream; the retained NB is unchanged, so no immediate revalidation is required before Phase 2A.
- **E34, NB → GEMM kernel:** kernel choice remains open downstream; no immediate action because NB=3072 remains retained.
- **E16, residency → fill buffer:** the default 3048 MB buffer remains unoptimized and should be revisited in its blueprint phase, not folded into Phase 2A.

## Phase-1 decision

**Close Phase 1 with the retained representative geometry:**

```text
N = 429056
NB = 3072
grid/order = 4x4 column only as a provisional control
fill-device = 1
```

The retained NB region is `2048–3072`, but `3072` is the representative control carried forward.

No targeted N resweep is justified because the representative NB did not change and the N=429056 / NB=3072 geometry has already survived a cross-allocation repeat.

## Recommended next action

**Proceed to Phase 2A: process-grid shape screening at fixed N=429056 and NB=3072.**

Follow the blueprint's staged design:

1. hold all retained Phase-1 controls fixed;
2. screen a bounded set of 16-rank process-grid **shapes** first using one fixed order/mapping;
3. retain several useful shapes;
4. compare row versus column order only for the retained shapes;
5. do not combine the initial shape screen with GPU-affinity permutations or downstream communication tuning.

The exact grid candidate set should be specified in the next human-approved task after reviewing topology-aligned and contrasting 16-rank factors.

**Human decision state:** proposed only. No Phase-2A execution is authorized by this analysis.
