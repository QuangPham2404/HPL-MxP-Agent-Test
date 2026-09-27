# Analysis — 2x8 GAAS Phase 2A Grid × Order

Analysis ID: `2x8-gaas-phase2a-grid-order-matrix`

This analysis combines **TASK-004, TASK-005, and TASK-006 as one Phase-2A grid/order study**.

TASK-004 supplied the initial column-order shape screen, TASK-005 supplied the row-order counterparts, and TASK-006 supplied the same-allocation confirmation used to close the remaining ambiguity.

Source evidence:

- `tasks/TASK-004.md`
- `tasks/TASK-005.md`
- `tasks/TASK-006.md`
- `experiments/2x8-GAAS/phase2a-grid-shape/`
- `experiments/2x8-GAAS/phase2a-grid-row/`
- `experiments/2x8-GAAS/phase2a-grid-order-confirm/`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `results/metrics.csv`

Fixed controls across the scored points:

```text
N = 429056
NB = 3072
OMP_NUM_THREADS = 8
gpu-affinity = 0:1:2:3:4:5:6:7
sloppy-type = FP16
use-mpi-panel-broadcast = 0
use-separate-stream-for-gemm = 1
prioritize-trsm = 0
prioritize-factorization = 0
fill-device = 1
test-loop = 1
skip-tests = 0
monitor-gpu = 0
```

All three tasks measured the same physical rank placement:

```text
global ranks 0-7   -> hpc-gaas-g12
global ranks 8-15  -> hpc-gaas-g15
```

## Results

Immutable campaign baseline for percentage reporting: `4.8037e+06` GFLOP/s from TASK-000.

> Baseline percentages are campaign-progress context only. TASK-000 used a different N and did not use the same fill-device policy, so these percentages are not an isolated grid/order causal comparison.

### Initial 3×2 matrix — TASK-004 + TASK-005

| Grid | Order | Overall GFLOP/s | vs original baseline | LU GFLOP/s | LU s | IR s | IR/LU | Device headroom | Host consumption MAX |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 2×8 | column | `5.3746e+06` | +11.88% | `6.3307e+06` | 8.32 | 1.48 | 0.178 | 2.163 GB | 6.395 GB |
| 2×8 | row | `5.0562e+06` | +5.26% | `6.4670e+06` | 8.14 | 2.27 | 0.279 | 2.304 GB | 6.292 GB |
| 4×4 | column | `5.4505e+06` | +13.46% | `6.5964e+06` | 7.98 | 1.68 | 0.211 | **2.767 GB** | **0.004 GB** |
| **4×4** | **row** | **`5.6347e+06`** | **+17.30%** | **`6.7803e+06`** | **7.77** | **1.58** | 0.203 | **2.767 GB** | **0.004 GB** |
| 8×2 | column | `5.5487e+06` | +15.51% | `6.5155e+06` | 8.08 | **1.41** | **0.175** | 2.302 GB | 2.937 GB |
| 8×2 | row | `5.4331e+06` | +13.10% | `6.5199e+06` | 8.08 | 1.62 | 0.200 | 2.161 GB | 3.040 GB |

All six candidates passed correctness with finite residuals and three iterative-refinement iterations.

The initial row-vs-column effects were:

```text
2x8: row vs column = -5.92%
4x4: row vs column = +3.38%
8x2: row vs column = -2.08%
```

This established a real shape×order interaction and removed 2×8 from serious contention, but the leading 4×4-row versus 8×2-column gap was only 1.55%, smaller than observed cross-allocation control movement. TASK-006 was therefore required.

### Same-allocation confirmation — TASK-006

All four confirmation arms ran sequentially in PBS job `72845.gaas` on g12+g15 with one shared rank map and unchanged controls.

| Grid | Order | Overall GFLOP/s | vs original baseline | LU GFLOP/s | LU s | IR s | IR/LU | Device headroom | Host consumption MAX |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 4×4 | column | `5.5602e+06` | +15.75% | `6.6245e+06` | 7.95 | 1.52 | 0.191 | **2.767 GB** | **0.004 GB** |
| **4×4** | **row** | **`5.6860e+06`** | **+18.37%** | **`6.7792e+06`** | **7.77** | **1.50** | 0.193 | **2.767 GB** | **0.004 GB** |
| 8×2 | column | `5.4880e+06` | +14.25% | `6.5267e+06` | 8.07 | 1.53 | 0.190 | 2.302 GB | 2.937 GB |
| 8×2 | row | `5.4794e+06` | +14.07% | `6.5147e+06` | 8.08 | 1.53 | 0.189 | 2.161 GB | 3.040 GB |

Within this single allocation:

```text
4x4 row vs 4x4 column  = +2.26%
4x4 row vs 8x2 column  = +3.61%
4x4 row vs 8x2 row     = +3.77%
8x2 column vs 8x2 row  = +0.16%
```

Cross-run movement for repeated configurations was:

```text
4x4 row:    5.6347 -> 5.6860  (+0.91%)
4x4 column: 5.4505 -> 5.5602  (+2.01%)
8x2 column: 5.5487 -> 5.4880  (-1.09%)
8x2 row:    5.4331 -> 5.4794  (+0.85%)
```

The same-allocation 4×4-row advantage over 8×2-column, +3.61%, is larger than the observed repeat movement of each of the four confirmation arms. It also preserves the direction already seen in TASK-004/005, where 4×4 row was 1.55% above 8×2 column.

## Analysis

### Grid and order are coupled

There is no global best `nporder`.

Given contiguous ranks 0-7 on g12 and 8-15 on g15:

- `nporder=column` makes process columns node-local and process rows inter-node;
- `nporder=row` makes process rows node-local and process columns inter-node.

The preferred order changes with P×Q because order changes which logical HPL communicator crosses the node boundary.

For the tested shapes:

| Grid/order | Node-local grouping | Cross-node grouping |
|---|---|---|
| 4×4 column | process columns | process rows |
| 4×4 row | process rows | process columns |
| 8×2 column | process columns | process rows |
| 8×2 row | process rows | process columns |

TASK-006 confirms that the interaction is not simply "row good" or "column good": 4×4 benefits from row order, whereas 8×2 is essentially order-insensitive in the confirmation run.

### 4×4 row has the strongest repeatable operating point

TASK-006 resolves the prior ambiguity.

The retained candidate, 4×4 row, leads the confirmation on both the LU critical path and end-to-end score:

```text
4x4 row:
  LU = 7.77 s
  IR = 1.50 s
  overall = 5.6860e+06 GFLOP/s

8x2 column:
  LU = 8.07 s
  IR = 1.53 s
  overall = 5.4880e+06 GFLOP/s
```

The difference is not caused by a more favorable memory-residency regime. 4×4 row and 4×4 column have identical reported memory behavior, while 8×2 carries slightly lower device headroom and several GB of host consumption.

The important observation is that 4×4 row does not win through one pathological phase. It has:

- the fastest LU;
- essentially the fastest IR;
- the best overall score;
- the cleanest memory behavior;
- the same 4×4 local geometry and memory regime used through Phase 1.

Its repeat is also stable:

```text
TASK-005 4x4 row = 5.6347e+06
TASK-006 4x4 row = 5.6860e+06
movement = +0.91%
```

### The earlier 8×2 order preference was not robust

TASK-004/005 suggested:

```text
8x2 column = 5.5487e+06
8x2 row    = 5.4331e+06
difference ≈ 2.1%
```

TASK-006 instead gives:

```text
8x2 column = 5.4880e+06
8x2 row    = 5.4794e+06
difference = 0.16%
```

Therefore the earlier apparent 8×2 column-order advantage should not be promoted to a stable mechanism. The 8×2 shape itself remains slower than 4×4 row in the stronger same-allocation comparison.

### Final Phase-2A retention decision

**Retain one representative grid/order pair:**

```text
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row
fill-device = 1
```

Identity GPU affinity remains only the Phase-2A control:

```text
--gpu-affinity 0:1:2:3:4:5:6:7
```

It is **not yet claimed as the optimized physical placement**.

Dropped from Phase-2A contention:

```text
2x8 row
2x8 column
8x2 row
8x2 column
4x4 column
```

The dropped arms remain useful historical controls, but they do not need to be carried into Phase 2B.

**Phase 2A is closed.**

## Dependency checkpoint

The dependency review is performed after the final 4×4-row selection.

| Dependency | Decision | Reason |
|---|---|---|
| E02 topology/rank count → grid/order | **Satisfied** | The current 2-node/16-rank topology has a completed grid/order screen plus same-allocation confirmation. |
| E09 N → grid/order | **Satisfied at N=429056** | Grid/order was reopened and retuned after the Phase-1 N/residency change. |
| E10 NB → grid/order | **Satisfied at NB=3072** | The retained representative NB was held fixed through Phase 2A. |
| E11 grid/order → rank/GPU/NIC placement | **Triggered now** | The retained order changed from the provisional 4×4-column control to 4×4 row. The physical logical-neighbor map therefore changes even with the same local GPU-affinity list. Proceed to Phase 2B GPU placement. |
| E12 grid/order → panel transport | **Triggered downstream** | Row order changes which 4-rank communicator crosses nodes. Panel transport must be revalidated after physical placement is established. |
| E24 N/NB/npcol → U-panel chunk validity/usefulness | **No validity-driven reopen from Phase 2A** | Final `N=429056`, `NB=3072`, and `npcol=4` are unchanged from the Phase-1 4×4 control, so the documented geometry-based chunk-validity expression does not change. Chunk remains provisional for the later communication phase because transport/order changes can still change usefulness. |
| E29 grid/order → LU scheduling | **Triggered downstream** | Row order changes node-boundary crossings and produced a measurable LU improvement. Scheduling must be revalidated later under the retained geometry. |
| E38 nprow → DGEMV | **Not triggered by final selection** | Retained `nprow=4` is unchanged from the Phase-1 control and IR remains small/stable at 1.50 s with three iterations. |
| N / residency reopening | **Not triggered** | Retained 4×4 row has exactly the same reported 2.767 GB device headroom and 0.004 GB host consumption as 4×4 column. No new residency regime or memory boundary was crossed. Keep N closed. |

The key consequence is that the next active dependency is **E11: physical GPU placement**, not N, NB, residency, chunk, or communication tuning.

## Recommended next step

Proceed to **Phase 2B — GPU placement** at the retained Phase-2A geometry:

```text
N = 429056
NB = 3072
4x4 row
fill-device = 1
```

Follow the blueprint rule: overlay the retained logical grid on the actual node/GPU fabric and test only **mechanism-distinct rank↔GPU maps**.

The current identity map:

```text
0:1:2:3:4:5:6:7
```

is the Phase-2B control, not a winner.

Because each H200 node reports an all-pairs NV18 GPU fabric, arbitrary permutations that only reshuffle GPUs inside an equivalent NVLink fabric are low-value. Phase 2B should focus on mappings that materially change GPU↔NUMA/NIC association or the placement of logical process-row/process-column ranks relative to the two host NUMA/NIC groups.

Do not start UCX transport selection, panel-broadcast tuning, U-panel chunking, host-runtime tuning, or LU scheduling in the same task. Those remain downstream of physical placement.

**Human decision state:** Phase 2A analysis complete. Phase 2B is proposed only; no Phase-2B execution is authorized by this analysis.
