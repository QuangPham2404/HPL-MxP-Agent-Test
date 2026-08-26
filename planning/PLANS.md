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

## Next direction

The matrix-placement re-run (2026-08-26) at N=491520 confirms `--fill-device 1`
as a ~+2.3% win over the fill-off shipping config and bounds the
`--fill-device-buffer-size` optimum to 1024–2048 (flat), with a hard VRAM cliff
at ≤512 (verification FAILED); `--cuda-host-register-step` is sub-noise and can
be left at its 2048 default. The recommended config is N=491520 + NB=3072 +
2x4 row + no affinity + OMP 8/sockets/TRUE + `--fill-device 1
--fill-device-buffer-size 1024`, reaching ~2.39e+06 (+66% over the original
1.4432e+06 baseline). Because the top buffer (1024 vs 2048) and register-step
candidates differ by <1% (within ±3–7% node noise), the immediate next step is a
small node-matched repetition to pin those ties. Remaining orthogonal,
untested-at-this-N levers for separate experiments: the compute/precision group
(`--preset-gemm-kernel`, `--sloppy-type`, and `--Anq-device` as a partial-residency
fallback), the LU-scheduling group (`--use-separate-stream-for-gemm`,
`--prioritize-trsm`, `--prioritize-factorization`, `--u-panel-chunk-nbs`), and the
panel-broadcast/transport group (`--use-mpi-panel-broadcast`).

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
