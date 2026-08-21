# Analysis: N sweep on the baseline nb=1024, 2x4 row configuration

## 1. Concise summary

We re-ran a clean N (matrix-size) sweep on the untouched baseline
configuration (`--nb 1024`, `--nprow 2 --npcol 4 --nporder row`, 8 GPUs),
starting at N = 370000 and stepping in +10000 increments, to find where
HPL-MxP performance peaks and where it starts to deteriorate.

Performance **increases monotonically** from N = 370000 to N = 490000, peaks at
**1.8293e+06 GFLOP/s (+26.75% over the original 1.4432e+06 baseline)**, then
**drops slightly at N = 500000** (1.8152e+06, +25.78%) and **fails (OOM) at
N = 510000** when the 2000 GB cgroup memory limit is exceeded. There is no
broad "three consecutive deteriorations" plateau: the limiting factor is a
hard system-memory wall just above N ≈ 500000, not a soft compute peak.

Two single-run dips (N = 390000 and N = 450000) were traced to a specific
node (`hpc-gaas-g13`) that was transiently memory-starved during the iterative
solver; both were re-run and recovered to the monotonic trend.

## 2. Scope and evaluation criteria

- **Source/package**: NVIDIA HPC Benchmarks v26.02 container
  (`hpc-benchmarks_26.02.sif`), HPL-MxP 26.2.0.
- **Environment**: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`,
  `gocryptfs/2.5.0`; `mpirun -np 8 --bind-to none` (one GPU per rank).
- **Hardware**: 1 node, 8x NVIDIA H200 (GH100 SXM, ~140 GB VRAM each),
  ~2 TB system RAM per node, `gpu_as` queue, 8 GPUs.
- **Workload**: fixed baseline tuning `--nb 1024`, `2x4` row-order grid,
  `--gpu-affinity 0:1:2:3:4:5:6:7`, `--skip-tests 1` plus GPU monitoring.
- **Baseline for comparison**: original `baseline-sweep_v1`,
  n = 370000, 1.4432e+06 GFLOP/s (the project's recorded original baseline).
- **Correctness**: every retained run reported `PASSED` with a finite residual
  within the 1e-12 tolerance. The N = 510000 attempt produced no result marker
  and was OOM-killed (exit 137, `cgroup/OOM`), recorded as `failed`/`unknown`.
- **Included**: 17 new `N-sweep` attempts from 370000–510000 (two anomalies were
  re-run as `_r1`). Excluded from the clean trend (but retained in metrics)
  are the two `hpc-gaas-g13` node-noise dips.
- **Metric**: the reported HPL-MxP GFLOP/s performance marker.

## 3. Data and analysis

### 3.1 Clean N trace (anomalies replaced by their `_r1` re-runs)

| N | Node | GFLOP/s | % vs baseline (1.4432e6) |
|---:|---|---:|---:|
| 370000 | g11 | 1.4747e+06 | +2.18% |
| 380000 | g12 | 1.5274e+06 | +5.83% |
| 390000 | g11 (`_r1`) | 1.5592e+06 | +8.04% |
| 400000 | g14 | 1.5739e+06 | +9.06% |
| 410000 | g11 | 1.6077e+06 | +11.40% |
| 420000 | g12 | 1.6172e+06 | +12.06% |
| 430000 | g14 | 1.6407e+06 | +13.68% |
| 440000 | g12 | 1.6963e+06 | +17.54% |
| 450000 | g11 (`_r1`) | 1.6995e+06 | +17.76% |
| 460000 | g14 | 1.7225e+06 | +19.35% |
| 470000 | g12 | 1.7424e+06 | +20.73% |
| 480000 | g13 | 1.7619e+06 | +22.08% |
| 490000 | g14 | 1.8293e+06 | **+26.75%** |
| 500000 | g11 | 1.8152e+06 | +25.78% |
| 510000 | g12 | OOM (no result) | — |

GFLOP/s rises steadily (with typical run-to-run and node-to-node noise of
roughly ±1–2%) across the whole usable range. The largest single step is not a
drop but the gain from 370000 → 490000 (+26.75%).

### 3.2 Memory progression and the wall

The second system-memory report (after matrix generation, before LU) shows
per-process free memory shrinking as N grows, and it is the binding limit:

| N | free system mem/rank | outcome |
|---:|---:|---|
| 440000 | ~17.2 GB | PASSED |
| 480000 | ~9.1 GB | PASSED |
| 490000 | ~13.6 GB | PASSED |
| 500000 | ~8.9 GB | PASSED |
| 510000 | — (host 243 GB/rank, device 128/140 GB) | OOM-killed |

At N = 510000 the FP64 working set exceeds the per-rank cgroup memory budget
(~2000 GB/8 = 250 GB), and the device memory also fills (128 of ~140 GB), so
the job is OOM-killed during matrix generation.

### 3.3 Anomalies (node noise, not N effects)

| Attempt | N | Node | GFLOP/s | free sys mem | re-run |
|---|---:|---:|---:|---:|---|
| N-sweep_390000 | 390000 | **g13** | 1.2724e+06 | ~2.8 GB | 1.5592e+06 (`_r1`, g11) |
| N-sweep_450000 | 450000 | **g13** | 1.6209e+06 | ~1.8 GB | 1.6995e+06 (`_r1`, g11) |

Both dips landed on `hpc-gaas-g13`, which reported only ~1.8–2.8 GB free
system memory during the iterative solver (versus ~9–22 GB on g11/g12/g14),
inflating solver time and depressing GFLOP/s. Both re-runs recovered cleanly to
the monotonic trend, confirming these are node/co-tenancy artifacts rather than
a genuine N-dependent optimum.

## 4. Insights gained

1. **Confirmed win**: pushing N from 370000 to 490000 yields +26.75% on the
   unchanged baseline configuration, with no correctness degradation.
2. **The limit is memory, not compute.** On this 8-GPU H200 node, the usable N
   is bounded by the ~2000 GB cgroup RAM (per-rank ~250 GB), reached at
   N ≈ 500000–510000. Device VRAM (~140 GB/GPU) fills at nearly the same point.
3. **No soft peak.** Unlike a typical BLAS-bound sweep, GFLOP/s does not roll
   off gradually at large N; it stays flat/high and then the job OOMs. The
   user's "three consecutive deteriorations" criterion is therefore not
   reachable here — the true stopping point is the memory wall.
4. **Node-level noise matters.** `hpc-gaas-g13` intermittently reported very
   low free system memory, producing two ~10–20% slow outliers that a single
   un-repeated run could have misled us into calling "deterioration." Runs at
   the memory boundary should be repeated and node-recorded.
5. **Context**: 1.83e6 GFLOP/s at N = 490000 (nb=1024, 2x4 row) is still well
   below the ~2.0–2.2e6 GFLOP/s previously recorded with nb=3072 on a `4x2`
   column grid at N ≈ 399k. N alone is a real but smaller lever than nb/grid.

## 5. Suggested next section

Before considering this N direction resolved, I recommend:

1. **Confirm the wall with a repetition**: re-run N = 490000 and N = 500000 on
   clearly free nodes to pin the peak/vs-wall boundary, since the 490000→500000
   difference (−0.77%) is within noise.
2. **Move the N win onto the stronger grid**: repeat the N sweep at the best
   prior config (`--nb 3072`, `4x2` column order) to see whether N ≈ 490000
   combined with the larger block size pushes GFLOP/s above the current
   2.0–2.2e6 best. This is the natural joint N + nb/grid next step the prior
   planning already flagged.
3. **Guard against node noise**: collect `allocated_node` + the reported free
   system memory for every run, and re-run any run whose free memory is an
   outlier (as done here for g13).

These are recommendations for review, not authorization to execute.

## 6. Provenance

- Source CSV: `results/metrics.csv` (74 rows; 17 new `N-sweep` attempts).
- Experiment: `experiments/N-sweep/` (`README.md`, `run_n_sweep.pbs`,
  `outputs/N-sweep_*{.o,.e}`).
- Baseline reference: `baseline-sweep_v1` (metrics.csv), 1.4432e+06 GFLOP/s.
- PBS jobs: 51018–51024, 51031–51034, 51058–51061, 51064–51065.
- Analysis date: 2026-08-21.