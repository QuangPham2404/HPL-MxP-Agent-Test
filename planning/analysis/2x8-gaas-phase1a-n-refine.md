# Analysis — 2x8 GAAS Phase 1A Local N / FP64-Residency Refinement

Analysis ID: `2x8-gaas-phase1a-n-refine`

Source evidence:

- `tasks/TASK-002.md`
- `experiments/2x8-GAAS/phase1a-n-refine/README.md`
- `experiments/2x8-GAAS/phase1a-n-refine/outputs/`
- `experiments/2x8-GAAS/phase1a-n-coarse/`
- `results/metrics.csv`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`

## Result summary

TASK-002 refined the TASK-001 coarse N region using the same 2×8 GAAS topology, launcher, node pair, scientific controls, and `--fill-device 1` policy.

| N | Overall GFLOP/s | vs immutable baseline | LU GFLOP/s | LU time | IR time | IR/LU | Device headroom after matgen | Host memory consumption MAX |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 404480 | `5.1045e+06` | +6.26% | `6.4584e+06` | 6.83 s | 1.81 s | 0.265 | 17.450 GB | 0.004 GB |
| **429056** | **`5.6091e+06`** | **+16.77%** | `6.6130e+06` | 7.96 s | **1.43 s** | **0.180** | 2.767 GB | 0.004 GB |
| 454656 | `5.2584e+06` | +9.47% | `6.8314e+06` | 9.17 s | 2.75 s | 0.300 | 2.257 GB | 15.024 GB |
| 480256 | `5.2514e+06` | +9.32% | **`7.1777e+06`** | 10.29 s | 3.78 s | 0.367 | 2.257 GB | 34.205 GB |
| 504832 | `4.9704e+06` | +3.47% | `7.0018e+06` | 12.25 s | 5.01 s | 0.409 | 2.257 GB | 51.561 GB |

All five points reported finite residuals and `PASSED`, with three iterative-refinement iterations.

The immutable campaign denominator remains `4.8037e+06` GFLOP/s from `2x8-GAAS-baseline_n700k_v1`.

## Reproducibility check against TASK-001 anchors

The three deliberate repeated anchors were stable:

| N | TASK-001 | TASK-002 | Change |
|---:|---:|---:|---:|
| 404480 | `5.1559e+06` | `5.1045e+06` | -1.00% |
| 454656 | `5.2433e+06` | `5.2584e+06` | +0.29% |
| 504832 | `5.0179e+06` | `4.9704e+06` | -0.95% |

This is not a formal statistical noise study, but the repeated-anchor drift is small compared with the separation of the leading refinement point. `N=429056` is approximately 6.7% above `N=454656` and 6.8% above `N=480256`, well beyond the roughly ±1% repeat movement observed at the anchors.

## Analysis

### N=429056 is the retained Phase-1A operating point

`N=429056` is the strongest valid refinement result and is mechanistically consistent with the Phase-1 hypothesis rather than merely having the fastest LU.

Its LU throughput, `6.6130e+06` GFLOP/s, is lower than both `N=454656` and `N=480256`. The end-to-end advantage comes from the refinement path:

```text
N=429056: IR/LU = 1.43 / 7.96 = 0.180
N=454656: IR/LU = 2.75 / 9.17 = 0.300
N=480256: IR/LU = 3.78 / 10.29 = 0.367
```

Using the campaign model

```text
R_MxP ≈ P_LU / (1 + T_IR / T_LU)
```

explains the result directly. The extra LU efficiency of the larger N values is outweighed by their larger IR fraction.

All candidates still required three solver iterations, so the improvement at `N=429056` is not caused by reducing the iteration count. It is a reduction in refinement-path time per completed valid solve.

### The residency transition is now bounded between N=429056 and N=454656

The refinement tightens the transition identified in TASK-001:

At `N=429056`:

- device headroom after matrix generation: `2.767 GB`;
- host-memory consumption MAX: `0.004 GB`.

At `N=454656`:

- device headroom: `2.257 GB`;
- host-memory consumption MAX: `15.024 GB`.

For larger N, device headroom stays pinned near `2.257 GB` while host consumption rises.

Therefore the useful interpretation is not simply "smaller N is faster." The retained point sits at the **edge of the high-device-residency regime**: it uses almost all practical device capacity while avoiding the host-resident/staged behavior visible at the next refinement point.

That is exactly the operating regime Phase 1A was designed to identify.

### The post-transition regime is not retained as a second performance regime

The blueprint allows multiple N regimes when their end-to-end scores are close but their mechanisms differ.

Here the post-transition `N=454656–480256` regime is mechanistically distinct, but its end-to-end score is approximately 6.3% below `N=429056`. That gap is materially larger than the observed anchor-repeat movement.

Therefore:

- retain `N=429056` as the Phase-1A representative N;
- keep `N=454656` as a useful residency-boundary reference, not as a co-equal performance regime;
- do not carry multiple N regimes into the initial NB screen.

### Phase 1A closes; Phase 1 remains open

The Phase-1A evidence now satisfies the intended broad→refine logic:

- the useful N region was found by a coarse sweep;
- the leading region and residency transition were refined;
- neighboring points bound the retained result;
- repeated anchors show the coarse shape is reproducible enough for the next stage;
- the retained N is valid and safely below the host-memory boundary;
- the mechanism is explained through LU, IR, and residency evidence.

**Phase 1A is therefore closed at `N=429056` under the current provisional controls and `--fill-device 1` policy.**

This does **not** close Phase 1. NB is still provisional and must be tuned in Phase 1B.

## Dependency checkpoint

The checkpoint is performed.

| Dependency | Decision | Reason |
|---|---|---|
| E07: `N → NB` | **Trigger Phase 1B NB screen now** | The retained N changed materially from the Phase-0 baseline and NB=3072 has only been a provisional control in this 2×8 regime. |
| E08: `NB → N / memory boundary` | **Mandatory after Phase 1B** | `N=429056` has only 2.767 GB post-matgen device headroom. A different NB/workspace requirement can move the residency boundary or useful N region. |
| E09: `N → grid/order` | Keep open, defer to Phase 2A | The retained N/residency regime is materially different; 4×4 column remains a control, not an optimized conclusion. |
| E14/E15: `N ↔ FP64 residency` | **Resolved for Phase 1A under current fill policy** | The useful high-residency edge is now bounded between 429056 and 454656. Reopen only if NB/workspace or residency policy materially changes. |
| E16: residency → fill buffer | Open downstream, defer | The 3048 buffer is still a package-default control. Low remaining VRAM means it must not be treated as optimized. |
| E18/E21: N/residency → host runtime / DGEMV | Open downstream, defer | Refinement behavior changed materially, but blueprint order places these after geometry/decomposition. |
| E22-E24, E28, E34 | Trigger only after an NB decision | NB changes panel communication, chunk validity, scheduling balance, and GEMM shapes. |
| E37: N/problem scale → scheduling | Open downstream, defer | The new retained N materially changes LU geometry; priority/stream conclusions must not be assumed globally transferable. |

## Recommended next action

**Proceed to Phase 1B with one bounded NB screen at fixed `N=429056`.**

Use `NB=3072` as the same-protocol control and span smaller/larger panel sizes without creating an N×NB Cartesian sweep. A suitable bounded first screen is:

```text
NB = 1024, 2048, 3072, 4096, 5120, 6144
```

Rationale:

- `1024` and `2048` test smaller panels;
- `3072` preserves the current control;
- `4096`, `5120`, and `6144` test progressively larger panels;
- the values are historical hypotheses only, not transferred optima;
- `N % NB == 0` is not required;
- larger-N alternatives are not simultaneously varied.

Because the retained N has only `2.767 GB` device headroom after matrix generation, the NB task should correctness-gate every point and treat any device OOM/invalidity as boundary evidence. A staged stopping rule should stop extending upward after invalidity or repeated clear degradation rather than adding still larger NB values.

After the NB screen, perform the mandatory E08 dependency review. Only if NB materially changes the residency boundary, N ranking, feasibility, or LU/IR balance should N reopen locally.

**Human decision state:** proposed only. No Phase-1B execution is authorized by this analysis.
