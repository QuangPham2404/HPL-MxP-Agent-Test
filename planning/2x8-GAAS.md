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

