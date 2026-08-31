# Optimization Plans

## Current baseline

- Baseline run: `baseline-sweep_v1` — n=370000, nb=1024, 2x4 row,
  1.4432e+06 GFLOPS, PASSED.

## Optimization directions

| Direction | Analysis ID/file | Analysis date | Scope | Status | Main finding | Suggested follow-up |
|---|---|---|---|---|---|---|
| N / NB / grid sweep review | `planning/analysis/sweep-data-review.md` | 2026-08-19 | all recorded sweeps | Analyzed | NB=3072 (4x2 column) is the best recorded config: 1.8441e+06 GFLOPS (~28% over baseline); NB is the strongest lever; N-sweep_402k is a ~half-performance anomaly | Re-run N-sweep_402k; finer NB scan around 3072; joint NB+N scan at 4x2 column |
| Basic parameter sweep | `planning/analysis/basic_params_sweep.md` | 2026-08-20 | all 19 rows in `results/metrics.csv` | Analyzed | Best recorded result is N=399360, NB=3072, 4x2 column at 1.8441e+06 GFLOP/s (27.78% over baseline); NB and grid shape/order are confirmed levers; N-sweep_402k remains anomalous | Repeat N-sweep_402k and the best candidate; refine NB and N at 4x2 column with repetitions |
| Basic parameter sweep 2 | `planning/analysis/basic_param_sweep2.md` | 2026-08-20 | all 19 rows in `results/metrics.csv` | Analyzed | NB=3072 is the sampled local peak; 4x2 column gives the best tested grid; best result is 1.8441e+06 GFLOP/s (27.78% over baseline); N-sweep_402k remains a performance anomaly | Repeat the best candidate and the N-sweep_402k anomaly; locally refine NB and N at 4x2 column with repeated controls |
| Affinity and OpenMP thread flags | `planning/analysis/affinity.md` | 2026-08-20 | five `affinity-sweep` attempts; CPU/memory affinity and `OMP_NUM_THREADS=10` | Analyzed | Memory affinity matches the 4x2-column control within 0.07%; CPU-affinity results range from -8.25% to +0.84%; the single 10-thread run is -52.80% | Repeat matched memory/CPU affinity controls and add an explicit OpenMP default-thread control before a small thread-count sweep |
| FP64 matrix memory placement | `planning/analysis/fp64-matrix-mem-placement.md` | 2026-08-20 | fourteen `matrix-placement-control` attempts; default fill, buffer sweep, and register-step sweeps at buffers 32768 and 3048 | Analyzed | Buffer 3048 register resweep peaks at step 512 with 2.2002e+06 (+1.10% vs its control); buffer 32768 peaks at step 1024; no stable step winner yet | Repeat both register-step/buffer controls on comparable nodes before selecting settings |
| N sweep (baseline nb=1024, 2x4 row) | `planning/analysis/n-sweep-370k-510k.md` | 2026-08-21 | `N-sweep` 370000–510000 in 10k steps | Analyzed | Monotonic +26.75% to peak at N=490000 (1.8293e+06); hard memory wall just above N=500000, OOM at 510000; no gradual rolloff | Repeat N sweep at nb=3072 4x2 column; re-run 490k/500k to confirm peak; guard against g13 node noise |
| NB sweep (fixed N=490000, 2x4 row) | `planning/analysis/nb-sweep.md` | 2026-08-24 | `nb-sweep` 1024–8192 in 1024 steps at N=490000 | Analyzed | Peak at nb=3072: 2.1726e+06 (+50.54% over baseline); two straight degradations at 7168/8192; nb=1024 reproduces N-sweep 490k to +0.51% | Combine nb=3072 + N=490000 on 4x2 column/placement tuning; repeat 3072/4096 to pin the broad plateau |
| N-NB resweep (N aligned to nb=3072, 2x4 row) | `planning/analysis/N-NB-resweep.md` | 2026-08-24 | `N-nb-resweep` 488448–509952 in 3072 steps | Analyzed | No meaningful gain from N%NB==0: aligned points scatter ±~1% around 490000/nb3072; peak 491520 = 2.1974e+06 (+52.26%); OOM at 506880/509952 | Drop alignment as a lever; combine N≈491520 + nb=3072 on 4x2 column + placement, and repeat peak candidates |
| Process grid/order sweep (N=491520, nb=3072) | `planning/analysis/np-sweep.md` | 2026-08-24 | `np-sweep` 2x4/4x2 × row/column | Analyzed | 2x4 row best: 2.2067e+06 (+52.90%); 2x4 > 4x2 by ~1.1–1.8%; optimal grid is N-dependent (4x2 col was best at N=399360) | Adopt 2x4 row + N=491520 + nb=3072 as shipping config; optionally test placement levers at N=491520 |
| CPU/memory affinity re-sweep (N=491520, nb=3072) | `planning/analysis/affinity-491k.md` | 2026-08-24 | `affinity-sweep` mem off/on + cpu free/2/4/8/12/socket cores | Analyzed | No affinity is best: no cpu/mem binding = 2.1980e+06 (+52.30%); <8 cores/rank collapses (2c −87%, 4c −18%); mem-affinity −1.45%; container cpuset is 0-49/56-101 | Keep no-affinity config as shipping; revisit matrix-placement levers at N=491520 |
| OpenMP thread/placement sweep (N=491520, nb=3072) | `planning/analysis/omp-sweep.md` | 2026-08-26 | `omp-sweep` `OMP_NUM_THREADS` 1–20 + `OMP_PLACES`×`OMP_PROC_BIND` at 8 threads | Analyzed | `OMP_NUM_THREADS=8` + `OMP_PLACES=sockets` + `OMP_PROC_BIND=TRUE` = 2.3204e+06 (+60.79%), highest result yet; `cores`+bind oversubscribes low cores and collapses (~0.9e+06) | Repeat top sockets candidates to separate ~1% ordering from node noise; then revisit matrix-placement levers at N=491520 |
| Matrix-placement re-run (N=491520, nb=3072) | `planning/analysis/matrix-placement-491k.md` | 2026-08-26 | `matrix-placement-control` `491k_*` fill-device / buffer / register-step | Analyzed | `--fill-device 1` is a ~+2.3% win over the fill-off shipping config; buffer has flat optimum 1024–2048 and a VRAM cliff at ≤512 (FAILED); register-step is sub-noise | Adopt fill-device 1 + buffer 1024 (reg-step default); pin buffer/reg-step ties with node-matched repetition; next orthogonal levers are gemm-kernel/precision and scheduling/panel-broadcast |
| Matrix-placement N re-sweep (fill-device=1, N down) | `planning/analysis/matrix-placement-N-resweep.md` | 2026-08-26 | `matrix-placement-N-resweep` N ∈ {491520,460800,430080,399360,368640} | Analyzed | Solver time falls 13.07→4.09 s (share 39%→29%) but LU efficiency loss cancels it; GFLOP/s flat, no peak below 491520 — hypothesis rejected as net gain | Keep N=491520; no refine; next orthogonal levers: gemm-kernel/precision, LU scheduling, panel-broadcast |
| N fine re-sweep (1024-step below 491520, node-matched) | `planning/analysis/matrix-placement-N-resweep.md` (follow-up section) | 2026-08-27 | `matrix-placement-N-fine` 8 × 1024-step N below 491520 + same-node controls | Analyzed | No fine peak: fine points are a ~1% noise band (2.357–2.382e+06); none beats 491520 beyond intra-node drift (max +0.12% vs −0.36% control drift); N dimension closed | Keep N=491520; N fully closed; next orthogonal levers only |
| MPI/NCCL panel-broadcast + U-panel chunk study | `planning/analysis/mpi-nccl-coms-sweep.md`; [`planning/panel_u_chunk_effect.md`](panel_u_chunk_effect.md) | 2026-08-31 | Clean sweep plus Nsight profiles: broadcast 0/25/50/75/100; chunk 4/8/16; profiled chunk-4 trace | Analyzed | Chunk 4 changes scheduling granularity (many more kernel launches and less recorded collective wait) but leaves dominant kernel time and clean GFLOP/s within noise; no repeatable end-to-end gain | Keep chunk 8 and broadcast 50; move to dependency-priority (`--prioritize-trsm`/`--prioritize-factorization`) |
| Nsight mechanism study: broadcast 100 | `planning/mpi_panel_broadcast_effect.md` | 2026-08-31 | Nsight 50 control vs `--use-mpi-panel-broadcast 100`; 8 ranks; fixed N/NB/grid/placement | Analyzed | MPI-heavy policy cuts NCCL broadcast-kernel time ~43% but raises cumulative MPI waits ~23% and stream waits ~19%; dominant `nvjet` time is unchanged; profiled score difference is confounded by solver time and node mismatch | Keep 50; target dependency-priority controls with repeated clean runs |
| Dependency priorities (trsm/factorization) | `planning/analysis/factorization-priority.md` | 2026-08-31 | `factorization-priority-test` four 0/1 combinations at fixed best config | Analyzed | `--prioritize-factorization 1` gives LU +6.6%, end-to-end +3.5%, new best 2.4203e+06 (+67.70% over baseline); `--prioritize-trsm 1` neutral | Adopt factorization 1; repeat `fp_0_1` to confirm, then compute/precision levers (gemm-kernel, sloppy-type) |
| Separate GEMM stream | `planning/analysis/separate-stream-for-gemm.md` | 2026-08-31 | `separate-stream-for-gemm` toggle 0/1 at current best (factorization 1) | Analyzed | `--use-separate-stream-for-gemm 0` loses -1.89% end-to-end / -3.73% LU vs default 1; default correct | Keep 1; LU-scheduling axis closed, move to compute/precision levers |

## Next direction

### Separate-stream result (2026-08-31)

The `separate-stream-for-gemm` experiment toggled
`--use-separate-stream-for-gemm` (0/1) at the current best config
(`--prioritize-factorization 1`). Turning the separate GEMM stream off costs
`-1.89%` end-to-end and `-3.73%` in the LU phase, confirming the package
default `1` is correct. The LU-scheduling axis (panel-broadcast, chunk size,
dependency priorities, separate-stream) is now effectively closed. See
[`planning/analysis/separate-stream-for-gemm.md`](analysis/separate-stream-for-gemm.md).
Next orthogonal direction: the compute/precision path — `--preset-gemm-kernel`,
`--sloppy-type` (`FP4`/`FP8` vs `FP16`), and conditional `--Anq-device`
residency — which targets the unchanged dominant `nvjet` kernel.

### Dependency-priority result (2026-08-31)

The `factorization-priority-test` experiment swept the two LU-scheduling flags
at the fixed best config (N=491520, NB=3072, 2x4 row, `--fill-device 1`,
buffer 2048, register-step 2048): `--prioritize-trsm` and
`--prioritize-factorization` each at 0/1. `--prioritize-factorization 1` is a
clear win — LU phase `+6.6%`, end-to-end `+3.5%`, and a new best result
`2.4203e+06` (`+67.70%` over the original `1.4432e+06` baseline, `+0.96%` over
the previous master best `2.3974e+06`). `--prioritize-trsm 1` is neutral
(`-0.10%`), and combining both adds nothing over factorization-only. All four
runs used one node (`hpc-gaas-g16`) and passed verification. See
[`planning/analysis/factorization-priority.md`](analysis/factorization-priority.md).
Next step: repeat `fp_0_1` once to pin the `+3.5%` margin, then move to the
compute/precision levers (`--preset-gemm-kernel`, `--sloppy-type`) that target
the unchanged `nvjet` kernel.

### Communication study result (2026-08-27)

The `mpi-nccl-coms-sweep` study (see
[`planning/analysis/mpi-nccl-coms-sweep.md`](analysis/mpi-nccl-coms-sweep.md))
swept the two panel-traffic levers at the fixed best config (N=491520, NB=3072,
buffer+register 2048): `--use-mpi-panel-broadcast` 0/25/50/75/100, then
`--u-panel-chunk-nbs` 4/8/16 at the two Phase-1 winners (75, 50). Both are
effectively flat: the 15-run spread (~2.6%) is the same as the same-node
`50/8` control drift, the broadcast mix moves only the LU phase by ≤2.3%
(NCCL-only `0` is slightly worst, `75` a soft peak), and the chunk size has no
resolvable effect. The MPI↔NCCL transport mix is therefore not a first-order
lever on this NVSwitch-connected single node. Next orthogonal direction:
dependency priorities (`--prioritize-trsm`, `--prioritize-factorization`),
which target the panel-readiness stalls seen in the Nsight trace rather than
the transport mix.

### Updated direction after consolidated raw-output review (2026-08-27)

The nine recent reports and their raw artifacts establish the current control
as `N=491520`, `NB=3072`, `2x4` row, no explicit HPL CPU/memory affinity,
`OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`,
`--fill-device 1`, and a 1024–2048 MB fill buffer. The register-step 1536
result is not a confirmed improvement because it is within cross-node noise.

The N, alignment, affinity, and fine register-step directions should remain
closed for this workload. The next analysis direction should target the
remaining end-to-end bottlenecks in this order: sloppy precision (FP4/FP8), LU
scheduling/overlap, panel communication mix, GEMM-kernel selection appropriate
for H200/SM90, and conditional `--Anq-device` residency with fill-device off.
Each candidate must be evaluated with LU and iterative-solver timings, device
headroom, finite residuals, and `PASSED` verification; a phase-level speedup is
not sufficient if total GFLOP/s does not improve.

A node-matched fine N sweep (2026-08-27, `matrix-placement-N-fine`) ruled out a
narrow peak below N=491520: eight 1024-step values span a ~1% noise band
(2.357–2.382e+06) and none beats the same-node 491520 control beyond intra-node
drift. The N dimension is now fully closed at N=491520 for this workload.

The matrix-placement N re-sweep (2026-08-26) tested lowering N under
`--fill-device 1` to reach full FP64 residency. The iterative-solver time fell
13.07 → 4.09 s (its runtime share 39.2% → 29.1%) as N dropped 491520 → 368640,
confirming the mechanism, but the net GFLOP/s stayed flat because declining LU
efficiency at smaller N cancelled the solver gain; there is no peak below
491520. N=491520 + `--fill-device 1` therefore remains the recommended array
size. The matrix-placement levers are now closed for this workload: keep
`--fill-device 1` (buffer 1024–2048, register-step default), ~2.37–2.39e+06
(+66% over the original 1.4432e+06 baseline). The remaining orthogonal,
untested-at-this-N directions for separate experiments are: compute/precision
(`--preset-gemm-kernel`, `--sloppy-type`, `--Anq-device`), LU scheduling
(`--use-separate-stream-for-gemm`, `--prioritize-trsm`,
`--prioritize-factorization`, `--u-panel-chunk-nbs`), and panel-broadcast
(`--use-mpi-panel-broadcast`).

The new baseline N sweep (2026-08-21) shows N can be pushed from the 370000
baseline to N=490000 for a +26.75% gain before hitting the system-memory wall
(OOM at N=510000). The natural next step is to combine this larger-N win with
the stronger grid/block size: re-run the N sweep at `--nb 3072`, `4x2` column
order, and re-run N=490000/N=500000 to pin the peak boundary. Guard every
boundary run against node-level memory noise (notably `hpc-gaas-g13`).

The NB sweep (2026-08-24) at fixed N = 490000 confirms `nb = 3072` as the
best block size (2.1726e+06, +50.54% over baseline), with a broad 3072–6144
plateau and two straight degradations at 7168/8192. The natural next step is to
combine the two strongest levers — N = 490000 and `nb = 3072` — with the `4x2`
column grid and the best matrix-placement settings, then repeat `nb = 3072` /
`4096` to pin the plateau.

The N-NB resweep (2026-08-24) tested the N % NB == 0 alignment hypothesis and
found no meaningful gain: aligned N values (multiples of 3072) scatter within
~±1% of the unaligned 490000/nb=3072 reference. Its best point, N = 491520 /
nb = 3072 (2.1974e+06, +52.26%), is the highest single result on the 2x4-row
grid to date, and confirms the memory wall just above N ≈ 504k (OOM at
506880/509952). Alignment should be dropped as a lever; the next step is to
combine N ≈ 491520 + nb = 3072 with the 4x2 column grid and matrix-placement
tuning, with repetitions to bound node noise.

The process-grid sweep (2026-08-24) at N = 491520 / nb = 3072 confirms 2x4 row
as the best grid (2.2067e+06, +52.90% over baseline, the highest single result
in this workload family), with 2x4 > 4x2 by ~1.1–1.8% and `row` very slightly
ahead of `column`. This reverses the earlier N = 399360 result (4x2 column best),
so the optimal grid is N-dependent. 2x4 row + N = 491520 + nb = 3072 is the
recommended shipping configuration; any remaining gain would come from layering
the matrix-placement levers onto this N.

The affinity re-sweep (2026-08-24) shows neither `--cpu-affinity` nor
`--mem-affinity` helps at N = 491520: the plain no-affinity default is best
(2.1980e+06, and cpu binding with <8 cores/rank is catastrophic). Affinity is
now closed for this workload. The recommended shipping configuration is
N = 491520 + nb = 3072 + 2x4 row with no CPU/memory affinity, and the only
remaining untested lever at this N is the matrix-placement controls
(`--fill-device-buffer-size` / register step) that previously reached ~2.20e+06
at smaller N.

Affinity analysis additionally recommends matched affinity and OpenMP-control
repetitions before selecting a placement/thread configuration. The
matrix-placement analysis additionally recommends repeating fill-device 3048
against the matched control before testing buffer refinements or register
steps.

The OpenMP sweep (2026-08-26) established the host-thread configuration for
this workload: `OMP_NUM_THREADS = 8` (+3.6% over no-OMP), with
`OMP_PLACES = sockets` adding a further ~1.5% and `OMP_PROC_BIND = TRUE` reaching
2.3204e+06 (+60.79% over the 1.4432e+06 baseline) — the highest single result
recorded for this workload family. `OMP_PLACES=cores` with any bind mode is
catastrophic (~0.9e+06) and must be avoided. The recommended next step is to
repeat the top `sockets` candidates (`TRUE`, `SPREAD`, `FALSE`) on comparable
nodes to separate their ~1% ordering from node noise, then layer the remaining
untested matrix-placement lever (`--fill-device-buffer-size` / register step)
onto the finalized OpenMP setting at N = 491520.

Awaiting user confirmation before preparing the next experiment.
