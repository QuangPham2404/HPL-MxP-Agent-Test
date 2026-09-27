# Analysis — 2x8 GAAS Phase 2A Grid × Order Matrix

Analysis ID: `2x8-gaas-phase2a-grid-order-matrix`

This analysis intentionally combines **TASK-004 and TASK-005 as one Phase-2A experiment**.

Source evidence:

- `tasks/TASK-004.md`
- `tasks/TASK-005.md`
- `experiments/2x8-GAAS/phase2a-grid-shape/`
- `experiments/2x8-GAAS/phase2a-grid-row/`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `results/metrics.csv`

Fixed controls across all six scored points:

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

TASK-004 used `nporder=column`; TASK-005 used `nporder=row`. Both allocations used the same physical rank placement:

```text
global ranks 0-7   -> hpc-gaas-g12
global ranks 8-15  -> hpc-gaas-g15
```

## Results

Immutable campaign baseline for percentage reporting: `4.8037e+06` GFLOP/s from TASK-000.

> Baseline percentages are campaign-progress context only. TASK-000 used a different N and did not use the same fill-device policy, so these percentages are not an isolated grid/order causal comparison.

| Grid | Order | Overall GFLOP/s | vs original baseline | vs matrix best | LU GFLOP/s | LU s | IR s | IR/LU | Device headroom | Host consumption MAX |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2×8 | column | `5.3746e+06` | +11.88% | -4.62% | `6.3307e+06` | 8.32 | 1.48 | 0.178 | 2.163 GB | 6.395 GB |
| 2×8 | row | `5.0562e+06` | +5.26% | -10.27% | `6.4670e+06` | 8.14 | 2.27 | 0.279 | 2.304 GB | 6.292 GB |
| 4×4 | column | `5.4505e+06` | +13.46% | -3.27% | `6.5964e+06` | 7.98 | 1.68 | 0.211 | **2.767 GB** | **0.004 GB** |
| **4×4** | **row** | **`5.6347e+06`** | **+17.30%** | **0.00%** | **`6.7803e+06`** | **7.77** | **1.58** | 0.203 | **2.767 GB** | **0.004 GB** |
| **8×2** | **column** | **`5.5487e+06`** | **+15.51%** | **-1.53%** | `6.5155e+06` | 8.08 | **1.41** | **0.175** | 2.302 GB | 2.937 GB |
| 8×2 | row | `5.4331e+06` | +13.10% | -3.58% | `6.5199e+06` | 8.08 | 1.62 | 0.200 | 2.161 GB | 3.040 GB |

All six points passed correctness with finite residuals and three iterative-refinement iterations.

### Row-vs-column effect within each shape

| Grid | Row vs column overall | LU-time change | IR-time change | Interpretation |
|---|---:|---:|---:|---|
| 2×8 | **-5.92%** | -2.16% | **+53.38%** | row improves LU slightly but IR becomes dramatically slower |
| 4×4 | **+3.38%** | **-2.63%** | **-5.95%** | row improves both LU and IR in these two allocations |
| 8×2 | **-2.08%** | ~0% | **+14.89%** | LU is unchanged; row loses almost entirely through slower IR |

## Analysis

### Grid and order must be treated as an interaction, not two independent knobs

The full matrix confirms that there is no globally preferred `nporder`.

At `2×8`, column beats row materially.
At `4×4`, row is the higher single-run result.
At `8×2`, column is better.

Therefore a rule such as "row order is better" or "column order is better" is unsupported. The effect of order depends on P×Q and the physical rank placement.

### The verified node mapping explains what nporder changes physically

The repository tuning guide defines `nporder` as the PMAP-style row-major/column-major rank layout.

Given contiguous ranks 0-7 on g12 and 8-15 on g15:

#### Column order

Ranks fill process columns first.

- process **columns are node-local**;
- process **rows cross the two-node boundary**.

This produces:

| Grid | Node-local process columns | Cross-node process rows |
|---|---|---|
| 2×8 | 8 columns of 2 ranks; four columns/node | 2 rows of 8 ranks; four ranks/node |
| 4×4 | 4 columns of 4 ranks; two columns/node | 4 rows of 4 ranks; two ranks/node |
| 8×2 | 2 columns of 8 ranks; one whole column/node | 8 rows of 2 ranks; one rank/node |

#### Row order

Ranks fill process rows first.

- process **rows are node-local**;
- process **columns cross the two-node boundary**.

This produces:

| Grid | Node-local process rows | Cross-node process columns |
|---|---|---|
| 2×8 | 2 rows of 8 ranks; one whole row/node | 8 columns of 2 ranks; one rank/node |
| 4×4 | 4 rows of 4 ranks; two rows/node | 4 columns of 4 ranks; two ranks/node |
| 8×2 | 8 rows of 2 ranks; four rows/node | 2 columns of 8 ranks; four ranks/node |

This is precisely why TASK-004 and TASK-005 had to be paired. `nporder` changes which HPL communicator is local versus inter-node without changing P×Q or the local GPU-affinity list.

### The order effect is mostly communication / solver-path behavior, not memory capacity

Within each shape the row/column memory footprint is very similar:

```text
2x8:
  column  host 6.395 GB, device headroom 2.163 GB
  row     host 6.292 GB, device headroom 2.304 GB

4x4:
  column  host 0.004 GB, device headroom 2.767 GB
  row     host 0.004 GB, device headroom 2.767 GB

8x2:
  column  host 2.937 GB, device headroom 2.302 GB
  row     host 3.040 GB, device headroom 2.161 GB
```

The largest timing difference occurs at `2×8`, where IR rises from 1.48 s to 2.27 s under row order even though memory residency is nearly unchanged. The same pattern appears more mildly at `8×2`: LU is effectively identical but IR rises from 1.41 s to 1.62 s.

Therefore the observed order interaction is not plausibly explained by "more FP64 data spilled to host." The primary hypothesis is different communicator placement / synchronization / refinement communication under the changed rank layout.

The evidence does **not** identify the exact collective or network path responsible; that would require a later targeted communication investigation if the effect remains important after geometry/placement is settled.

### 2×8 is no longer a serious Phase-2A candidate

Both 2×8 arms are below the leading region.

The column arm is 4.62% below the matrix-best single run, and the row arm is 10.27% below. More importantly, row order creates a large IR penalty while not creating a compensating LU benefit.

The evidence is sufficient to drop 2×8 from the Phase-2A refinement set.

### The remaining decision is 4×4 versus 8×2, and it is not resolved yet

The two strongest single-run combinations are:

```text
4x4 row    = 5.6347e+06 GFLOP/s
8x2 column = 5.5487e+06 GFLOP/s
gap        = 1.55%
```

That 1.55% gap is too small to establish a unique retained pair because the same `4×4 column, N=429056, NB=3072` control has already moved across allocations:

```text
TASK-002: 5.6091e+06
TASK-003: 5.5381e+06
TASK-004: 5.4505e+06
```

The TASK-002-to-TASK-004 spread is approximately 2.9%.

This is not a formal noise model, but it is enough to show that the 1.55% separation between the current top two is inside observed allocation/run movement.

The 4×4 row-versus-column result also cannot yet be treated as a robust +3.38% order win, because the historical 4×4-column TASK-002 result (`5.6091e+06`) is only 0.46% below the new 4×4-row result.

Therefore:

- `4×4 row` is the current numerical leader;
- `8×2 column` is a co-leading serious candidate;
- `4×4 column` remains a useful bracketing control because it has repeated historical evidence;
- `8×2 row` is useful as the within-shape order control for confirming whether the column preference is repeatable;
- `2×8` can be dropped.

**Phase 2A remains open.**

## Dependency checkpoint

The dependency review is performed.

| Dependency | Decision | Reason |
|---|---|---|
| E02 topology/rank count → grid/order | **Satisfied for current topology** | The 2-node/16-rank topology has now been explicitly screened as a bounded grid×order matrix. |
| E09 N → grid/order | **Satisfied at N=429056** | The grid/order sweep was redone after the material Phase-1 N/residency change. |
| E10 NB → grid/order | **Satisfied at NB=3072** | The matrix uses the retained representative NB. |
| E11 grid/order → rank/GPU/NIC placement | **Triggered, defer until Phase 2A closes** | Different grid/order pairs create different physical logical-neighbor paths even with identity affinity. Phase 2B must rebuild/evaluate placement for the retained pair(s). |
| E12 grid/order → panel transport | **Triggered downstream** | P×Q and order materially change communicator sizes and node crossings. Existing panel-transport conclusions are not globally transferable. Revisit after placement is established. |
| E24 N/NB/npcol → U-panel chunk | **Triggered downstream** | Candidate npcol values were 8, 4, and 2. Chunk validity/usefulness depends on npcol, so the default chunk=8 remains provisional and must be recalculated for the final retained grid. |
| E29 grid/order → LU scheduling | **Triggered downstream** | Ownership, node-boundary crossings, LU timing, and arrival behavior changed. Stream/priority controls must be revalidated in the later scheduling phase. |
| Residency / N reopening | **Conditional, not triggered yet** | Final grid/order has not been selected. If the retained pair materially changes local residency/headroom or LU/IR balance from the Phase-1 control, perform only a targeted local N revalidation; do not launch it before the Phase-2A repeat resolves the pair. |

No communication, affinity, chunk, N, host-runtime, or scheduling sweep should be started before the remaining Phase-2A ambiguity is resolved.

## Recommended next step

**Run one bounded same-allocation Phase-2A confirmation over the two surviving shapes and both relevant orders:**

```text
4x4 row
4x4 column
8x2 column
8x2 row
```

Keep N=429056, NB=3072, identity GPU affinity, and every other scientific control unchanged.

Rationale:

1. It drops the now-dominated 2×8 shape.
2. It puts the `4×4 row` and `8×2 column` leaders in the **same allocation**, removing the largest current comparability weakness.
3. It repeats `4×4 column` as the long-running campaign control and directly tests whether the apparent row advantage at 4×4 is stable.
4. It repeats `8×2 row` to verify whether the observed column preference is stable.
5. Four ~one-minute arms are inexpensive relative to the value of cleanly closing Phase 2A.

Closing rule after that confirmation:

- if one grid/order pair separates repeatably beyond the within-allocation/control movement, retain it;
- if `4×4 row` and `8×2 column` remain within noise, retain both as a tied Phase-2A region and carry both into Phase 2B, where physical GPU/NIC placement may break the tie;
- do not revive 2×8 absent contradictory new evidence.

After the retained pair(s) are established, perform the normal dependency review and proceed to Phase 2B GPU-affinity / physical placement. Any targeted N revalidation remains conditional on whether the retained grid materially changes the residency/LU-IR regime.

**Human decision state:** proposed only. No confirmation run or Phase-2B execution is authorized by this analysis.
