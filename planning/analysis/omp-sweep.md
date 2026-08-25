# Analysis: OpenMP thread/placement sweep (N = 491520, nb = 3072, 2x4 row)

## 1. Concise summary

Swept OpenMP host-thread controls on the current best workload — N = 491520,
NB = 3072, 2x4 row grid, `--gpu-affinity 0:1:2:3:4:5:6:7`, 8 MPI ranks,
no CPU/memory affinity. A first phase swept `OMP_NUM_THREADS` (1 → 20), then a
second phase swept `OMP_PLACES × OMP_PROC_BIND` at the best thread count (8).
The sweep found two real gains: **(a)** `OMP_NUM_THREADS = 8` lifts the no-OMP
shipping config from ~2.21e+06 to 2.2859e+06 (+3.6%), and **(b)** setting
`OMP_PLACES=sockets` on top of that reaches **2.3204e+06** (`sockets` + `TRUE`),
the highest single result recorded for this workload family (+60.8% over the
original 1.4432e+06 baseline).

## 2. Scope and evaluation criteria

- **Workload**: N = 491520, NB = 3072, `--nprow 2 --npcol 4 --nporder row`,
  `--gpu-affinity 0:1:2:3:4:5:6:7`, 8 MPI ranks, `--bind-to none`,
  `--skip-tests 1` + GPU monitoring.
- **Fixed config**: no `--cpu-affinity`, no `--mem-affinity` (the 2026-08-24
  affinity finding).
- **Container**: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`,
  `apptainer exec --nv`, `mpirun -np 8`, modules apptainer/1.4.1, nvhpc/26.3,
  squashfuse/0.5.2, gocryptfs/2.5.0.
- **Baseline**: `baseline-sweep_v1` = 1.4432e+06 GFLOP/s (PASSED).
- **Previous best (pre-OMP reference)**: `np-sweep` `2x4_row_491k` = 2.2067e+06
  GFLOP/s — the N = 491520, NB = 3072, `--nprow 2 --npcol 4 --nporder row` run
  immediately before this experiment. Every data table below includes a column
  that reports each run relative to this reference.
- **Correctness**: every run below is `PASSED` with finite residual.
- **Phase 1 range**: `OMP_NUM_THREADS` ∈ {1, 2, 4, 8, 10, 12, 14, 16, 18, 20},
  stopping after two consecutive declines (t18, t20).
- **Phase 2 range**: `OMP_PLACES ∈ {cores, sockets}` × `OMP_PROC_BIND ∈
  {TRUE, FALSE, CLOSE, SPREAD}` at `OMP_NUM_THREADS = 8` (8 runs).
- **Metric**: the reported `GFLOPS = <x>, per GPU` marker (first match).

## 3. Data and analysis

### 3.1 Phase 1 — `OMP_NUM_THREADS` sweep

| Threads | GFLOP/s | vs baseline (1.4432e6) | vs prev best (2.2067e6) | node |
|---|---:|---:|---:|---|
| 1  | 1.1606e+06 | −19.58% | −47.41% | g16 |
| 2  | 1.7369e+06 | +20.35% | −21.29% | g17 |
| 4  | 2.1323e+06 | +47.75% | −3.37% | g18 |
| 8  | 2.2859e+06 | +58.39% | +3.59% | g19 |
| 10 | 2.2455e+06 | +55.59% | +1.76% | g19 |
| 12 | 2.2529e+06 | +56.11% | +2.09% | g16 |
| 14 | 2.2754e+06 | +57.67% | +3.11% | g17 |
| 16 | 2.2840e+06 | +58.26% | +3.50% | g16 |
| 18 | 2.2671e+06 | +57.09% | +2.74% | g17 |
| 20 | 2.2624e+06 | +56.76% | +2.52% | g18 |

The thread count is a real lever with a sharp low-end collapse: 1 thread
(−47.4% vs the pre-OMP reference) and 2 threads (−21.3%) starve the host
threads that drive the GPU pipeline, and the sweep climbs steeply to a peak at
**8 threads**. Below 8 threads the config is at or below the pre-OMP reference
(4 threads −3.4%); only 8 and above clear it. Above 8 the curve does not climb
further: 10–20 sit in a noise-dominated plateau between 2.2455e+06 and
2.2840e+06. Two consecutive declines at t18 (2.2671e+06) and t20 (2.2624e+06)
triggered the stop rule. **t8 = 2.2859e+06 (+3.59% vs the pre-OMP reference) is
the phase-1 peak**, with t16 = 2.2840e+06 (+3.50%) an essentially tied second
(0.08% apart, well inside the observed node noise of ±~1%).

### 3.2 Phase 2 — `OMP_PLACES × OMP_PROC_BIND` at 8 threads

| PLACES | BIND | GFLOP/s | vs baseline (1.4432e6) | vs prev best (2.2067e6) | node |
|---|---|---:|---:|---:|---|
| cores   | TRUE   | 9.1505e+05 | −36.60% | −58.53% | g16 |
| cores   | FALSE  | 2.3032e+06 | +59.59% | +4.37% | g18 |
| cores   | CLOSE  | 9.0139e+05 | −37.55% | −59.15% | g17 |
| cores   | SPREAD | 8.1662e+05 | −43.42% | −62.99% | g18 |
| sockets | TRUE   | 2.3204e+06 | +60.79% | +5.15% | g17 |
| sockets | FALSE  | 2.3026e+06 | +59.55% | +4.35% | g19 |
| sockets | CLOSE  | 2.2987e+06 | +59.28% | +4.17% | g19 |
| sockets | SPREAD | 2.3152e+06 | +60.43% | +4.92% | g16 |

Two clean groups emerge:

- **`cores` + a binding mode (TRUE/CLOSE/SPREAD) is catastrophic** — ~0.9e+06,
  a −59% to −63% collapse below the pre-OMP reference. With `--bind-to none`,
  every rank's 8 threads `OMP_PLACES=cores` + bind collapse onto the same
  low-numbered cores, so all 8 ranks oversubscribe a handful of CPUs. `cores` +
  `FALSE` (no binding) avoids this and is healthy (+4.37% vs the reference).
- **`sockets` is uniformly strong** (+4.17% to +5.15% vs the reference)
  regardless of bind mode, and is the best family. `sockets` + `TRUE` =
  **2.3204e+06** is the highest recorded result; `sockets` + `SPREAD`
  (2.3152e+06, +4.92%) is second, and `sockets` + `FALSE`/`CLOSE` are ~2.30e+06.
  Binding to sockets distributes the 8×8 = 64 host threads across both NUMA
  nodes instead of squeezing them, which is a consistent net win.

### 3.3 Position versus the shipping config

The best result, `sockets` + `TRUE` at 8 threads (2.3204e+06), is **+5.15% over
the previous best single result** (`np-sweep` `2x4_row_491k` = 2.2067e+06) and
**+5.57% over the no-affinity reference** (2.1980e+06). The gain is real and
concentrated in `OMP_PLACES=sockets`; the `OMP_NUM_THREADS=8` portion by itself
accounts for roughly +3.6% over the no-OMP config.

## 4. Insights gained

- **Confirmed win**: `OMP_NUM_THREADS = 8` (+3.59% over the pre-OMP reference,
  2.2067e+06) and `OMP_PLACES = sockets` (+~1.5% further at 8 threads). Together
  they reach 2.3204e+06, +5.15% over the pre-OMP reference and +60.8% over the
  original 1.4432e+06 baseline.
- **Sharp low-end penalty**: 1–4 threads/rank starve host threads
  (1 thread −19.6%).
- **Catastrophic mis-bind**: `OMP_PLACES=cores` with any bind mode oversubscribes
  the low cores and collapses to ~0.9e+06. This matches the invalid 96-thread
  run's preliminary observation and is now reproduced cleanly at 8 threads.
- **Noise**: phase-1 points above 8 threads scatter ±~1.5% with no clean trend;
  the t8 vs t16 peak is within noise. g19 appears slightly slower in the phase-2
  `sockets FALSE/CLOSE` points (both on g19), consistent with earlier sessions,
  but `sockets` + `TRUE` (g17) still leads comfortably.
- **Reproducibility limit**: single-run per config cell; the 1–2% spreads between
  near-equal candidates (e.g. sockets TRUE vs SPREAD) are not resolvable without
  repetition.

## 5. Suggested next section

Adopt `OMP_NUM_THREADS=8` + `OMP_PLACES=sockets` + `OMP_PROC_BIND=TRUE` as part
of the recommended configuration (candidate: 2.3204e+06). Before shipping,
repeat the top two or three candidates — `sockets TRUE`, `sockets SPREAD`,
`sockets FALSE` — on comparable nodes to separate the ~1% ordering from node
noise, since all three sit within ~1% of each other. Then fold the confirmed
OpenMP setting into the workload and revisit the one remaining untested lever at
N = 491520: the matrix-placement controls (`--fill-device-buffer-size` /
register step), which previously reached ~2.20e+06 at N = 399360.

## 6. Provenance

- Source: `results/metrics.csv` (experiment `omp-sweep`, attempts `omp_t1` …
  `omp_t20`, `omp_t8_{cores,sockets}_{true,false,close,spread}`).
- Raw evidence: `experiments/omp-sweep/outputs/*.o` / `*.e`.
- PBS jobs: phase 1 52401–52407, 52877–52879; phase 2 52880–52887.
- Analysis date: 2026-08-26.