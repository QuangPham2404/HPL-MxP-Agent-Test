# Analysis: Basic parameter sweep 2

## 1. Concise summary

This is a fresh Step 6 analysis of all experiments currently recorded in
`results/metrics.csv`. It compares the baseline, matrix-size (`N`) sweep,
panel-size (`NB`) sweep, and process-grid/order sweep. The baseline is the
explicit `baseline-sweep_v1` run: `N=370000`, `NB=1024`, `2x4` row, and
`1.4432e+06` GFLOP/s.

The best recorded configuration is `N=399360`, `NB=3072`, `4x2` column at
`1.8441e+06` GFLOP/s, which is 27.78% above the baseline. All 38 rows pass the
recorded verification gate. The repeated N reruns now separate the severe
402423/403423 outlier from the broader, smaller deterioration at larger N.

## 2. Scope and evaluation criteria

- Analysis ID: `basic_param_sweep2`
- Analysis date: 2026-08-20
- Source: [`results/metrics.csv`](../../results/metrics.csv)
- Included: all 38 rows from `baseline-sweep`, `N-sweep`, `nb-sweep`, and
  `np-sweep`; no attempts were excluded.
- Workload/runtime: NVIDIA HPL-MxP container `26.02`, GAAS `gpu_as` queue,
  eight MPI processes/GPUs, GPU affinity `0:1:2:3:4:5:6:7`, and FP16 sloppy
  type as shown in the raw benchmark output.
- Baseline: `baseline-sweep_v1`, `N=370000`, `NB=1024`, grid setup `2x4 row`,
  `1.4432e+06` GFLOP/s, `PASSED`.
- Correctness gate: a row is rankable only when `verification=PASSED` and
  `gflops` is finite. Every included row satisfies this gate. The gate does
  not make a large performance outlier representative.
- Metric: reported HPL-MxP performance (`gflops`, GFLOP/s). Increase is
  `(reported result / 1.4432e+06 - 1) * 100`.
- Limitations: most rows have unknown retained runtime and exit status, and
  runs use different GAAS nodes. There is only one measurement at most
  configurations, so parameter effects and transient/node variation are not
  fully separable.

## 3. Data and analysis

The tables below copy the selected numeric fields from `results/metrics.csv`.
The `grid setup` column combines `nprow`, `npcol`, and `nporder` as
`nprow x npcol order`. Every percentage uses the baseline above.

### Baseline

| Attempt | N | NB | Grid setup | Reported result (GFLOP/s) | Increase vs baseline |
|---|---:|---:|---|---:|---:|
| `baseline-sweep_v1` | 370000 | 1024 | 2x4 row | 1.4432e+06 | 0.00% |

### Sweep N

The N sweep holds `NB=1024` and `2x4 row` fixed.

| Attempt | N | NB | Grid setup | Reported result (GFLOP/s) | Increase vs baseline |
|---|---:|---:|---|---:|---:|
| `N-sweep_399k` | 399360 | 1024 | 2x4 row | 1.4918e+06 | 3.37% |
| `N-sweep_v1` | 400000 | 1024 | 2x4 row | 1.5569e+06 | 7.88% |
| `N-sweep_400k` | 400384 | 1024 | 2x4 row | 1.5751e+06 | 9.14% |
| `N-sweep_401k` | 401408 | 1024 | 2x4 row | 1.5821e+06 | 9.62% |
| `N-sweep_402k` | 402423 | 1024 | 2x4 row | 7.6797e+05 | -46.79% |
| `N-sweep_402_re1..3` | 403423 | 1024 | 2x4 row | 7.2526e+05, 7.3508e+05, 7.3884e+05 | -49.77% to -48.80% |
| `N-sweep_402432_1..3` | 402432 | 1024 | 2x4 row | 1.4748e+06, 1.5521e+06, 1.5990e+06 | 2.19% to 10.79% |
| `N-sweep_403432_1..3` | 403432 | 1024 | 2x4 row | 1.5635e+06, 1.6098e+06, 1.6022e+06 | 8.34% to 11.54% |
| `N-sweep_403k` | 403456 | 1024 | 2x4 row | 1.5818e+06 | 9.61% |
| `N-sweep_404k` | 404480 | 1024 | 2x4 row | 1.5540e+06 | 7.68% |

*Manual analysis*

- The trend is clear: pushing N increase throughput until ~402k where the performance starts to plateau.
- The significant drop in the case `402423` as the sole outlier is likely due to it being a non-NB multiple of N. Results of the following experiements suggest that choosing N so that `N mod NB = 0` can either have no affect at all or completely stumps the result. Therefore, to be safe,  `N` should be set as a multiple of `NB`
- REMAINING ISSUE: Why the plateu of performance is yet to be define accurately --> likely its due to larger N hitting a limit of CPU (host) RAM.

*Agent analysis*

The valid N results are non-monotonic. The original `402423` result is a
repeatable outlier: the original was `7.6797e+05`, followed by
`7.2526e+05`, `7.3508e+05`, and `7.3884e+05`. The corrected divisible case
`N=402432` instead produces `1.4748e+06`, `1.5521e+06`, and `1.5990e+06`.
Thus, the catastrophic result is associated with the non-divisible N rather
than ordinary node noise. The renamed `403432` files are retained as a
separate provenance group and also produce normal performance.

After removing the non-divisible outlier, the larger-N trend is still visible:
`N=403456` reports `1.5818e+06`, while `N=404480` reports `1.5540e+06` (the
previous `404k` record was `1.4871e+06`). This supports a smaller deterioration
above the alignment pathology. It does not by itself demonstrate CPU-RAM
overload. A roughly 50% loss at 402423 is more consistent with a block/grid
alignment path, while the gradual high-N decline could still involve workspace,
NUMA placement, memory traffic, or communication.

To verify the CPU-RAM hypothesis, repeat aligned N values around 401408–404480
with the same NB, grid, affinity, and comparable nodes while recording PBS
`resources_used.mem`/`resources_used.vmem`, process RSS/high-water mark, NUMA
placement, free memory, and swap activity. Compare those measurements with the
GFLOP/s trend. If memory pressure rises with the gradual decline, RAM/workspace
pressure remains plausible; if memory telemetry is stable while divisibility
predicts the severe drop, alignment is the stronger explanation.

### Sweep NB

The main NB sweep holds `N=401408` and `2x4 row` fixed. The two N re-sweep
rows retain `NB=3072` and the same grid while changing N.

| Attempt | N | NB | Grid setup | Reported result (GFLOP/s) | Increase vs baseline |
|---|---:|---:|---|---:|---:|
| `nb-sweep_1024` | 401408 | 1024 | 2x4 row | 1.5782e+06 | 9.35% |
| `nb-sweep_2048` | 401408 | 2048 | 2x4 row | 1.7879e+06 | 23.88% |
| `nb-sweep_3072` | 401408 | 3072 | 2x4 row | 1.8209e+06 | 26.17% |
| `nb-sweep_4096` | 401408 | 4096 | 2x4 row | 1.8040e+06 | 25.00% |
| `nb-sweep_5120` | 401408 | 5120 | 2x4 row | 1.7569e+06 | 21.74% |
| `nb-sweep_8192` | 401408 | 8192 | 2x4 row | 1.7445e+06 | 20.88% |
| `n-resweep_399k` | 399360 | 3072 | 2x4 row | 1.8177e+06 | 25.95% |
| `n-resweep_399_1..3` | 399360 | 3072 | 2x4 row | 1.7624e+06, 1.8038e+06, 1.7933e+06 | 22.11% to 24.93% |
| `n-resweep_402k` | 402432 | 3072 | 2x4 row | 1.6981e+06 | 17.66% |

*Manual Analysis*

- Pushing `NB` yeilds the biggest gain in the basic param sweeps, jumping from ~9% to ~23%.
- However, after 4096, the results starts to deteriorate.
- REMAINING ISSUES:
  - The increase in performance is likely do to the fact that pushing `NB` pushes the VRAM usage while keeping the CPU RAM usage under the limit. However, we still need to verify specifically.
  - We also need to verify what causes the decrease after `NB` reaches 4096.

*Agent Analysis*

At fixed `N=401408`, increasing NB from 1024 to 2048 improves performance by
13.29% relative to the NB=1024 point; NB=3072 adds a further 1.85% over
NB=2048. Performance then falls 0.93% at NB=4096 and 4.20% by NB=8192
relative to NB=3072. Thus `NB=3072` is a clear local peak in this sampled
range, although nearby values were not tested.

The NB=3072 N re-sweep repeats remain above baseline. The recorded
`N=399360` repeats range from `1.7624e+06` to `1.8040e+06`, while
`N=402432` gives `1.6981e+06`; this indicates sensitivity to N near 400k but
does not establish a global N optimum. In particular, not every N that is not
divisible by NB is catastrophic: the NB=3072 resweep is valid and performant.
The special 402423/403423 case demonstrates that misalignment can nevertheless
cause a severe failure mode. The operational rule remains: always align N to
NB.

The rise through NB=3072 is plausibly due to larger panel/work granularity and
better amortization of panel and communication overhead. The decline beyond
3072 may result from larger workspace, reduced occupancy/cache efficiency,
more synchronization, or less favorable communication granularity. To verify
the VRAM explanation in batch jobs, sample per-GPU `memory.used` and
`memory.total` with `nvidia-smi` throughout each job and retain peak values;
also record HPL-MxP allocation messages and host RAM separately. A smooth peak
supports a tuning/occupancy tradeoff, while an abrupt change near available
VRAM supports workspace pressure. (`NB=3072`, rather than 3073, is the tested
point.)

### Sweep grid (nprow, npcol, nporder)

The grid sweep holds `N=399360` and `NB=3072` fixed.

| Attempt | N | NB | Grid setup | Reported result (GFLOP/s) | Increase vs baseline |
|---|---:|---:|---|---:|---:|
| `2x4_row` | 399360 | 3072 | 2x4 row | 1.7302e+06 | 19.89% |
| `2x4_col` | 399360 | 3072 | 2x4 column | 1.7625e+06 | 22.12% |
| `4x2_row` | 399360 | 3072 | 4x2 row | 1.8126e+06 | 25.60% |
| `4x2_col` | 399360 | 3072 | 4x2 column | 1.8441e+06 | 27.78% |
| `2x4_col_re` | 399360 | 3072 | 2x4 column | 1.7837e+06 | 23.60% |
| `2x4_row_re1..2` | 399360 | 3072 | 2x4 row | 1.7550e+06, 1.7954e+06 | 21.61% to 24.42% |
| `4x2_col_re` | 399360 | 3072 | 4x2 column | 1.8370e+06 | 27.27% |
| `4x2_row_re` | 399360 | 3072 | 4x2 row | 1.8304e+06 | 26.82% |

*Manual Analysis*

- A clear trend: 4x2 > 2x4
- However, row-major vs col-major shows little difference.
- A note: due to the jobs being ran on different nodes, the expected difference in performance is around 5%.
- REMAINING ISSUE
  - Explain why 4x2 > 2x4: Intuition is that 4x2 have more communication for panel factorization compared to 2x4? is it because this his H200 mxp connectied by 8-way NVLink?

*Agent Analysis*

At fixed N and NB, the original single runs showed 4x2 ahead of 2x4 by about
4.6–4.8%, but the reruns reduce the estimated shape effect to about 3%:
2x4 row averages `1.7752e+06` across its two reruns versus `1.8304e+06` for
4x2 row, and 2x4 column is `1.7837e+06` versus `1.8370e+06` for 4x2 column.
Thus 4x2 remains the better tested shape, but the effect should be validated
with matched-node repetitions.

Column ordering is no longer a clear universal winner. In the reruns, 2x4
column is only about 0.5% above the 2x4 row mean, and 4x2 column is about
0.36% above 4x2 row. The earlier 1.7–1.9% differences were comparable to
node/run variation. A favorable 4x2 result may reflect communication and panel
factorization mapping, but the intuition that it must communicate more does
not predict performance by itself. H200 8-way NVLink is a plausible topology
factor, not a confirmed cause; verify with `nvidia-smi topo -m`, GPU affinity,
MPI transport mapping, and available NCCL/UCX diagnostics.

The earlier `n-resweep_399k` versus `2x4_row` comparison was not a like-for-like
repeat: the old values `1.8177e+06` and `1.7302e+06` differed by about 5%.
The new NB-sweep repeats (`1.7624e+06`, `1.8038e+06`, `1.7933e+06`) and grid
reruns (`1.7550e+06`, `1.7954e+06`) overlap substantially. The discrepancy is
therefore best explained by node/run noise, with the earlier 5% difference
likely a one-time outlier rather than a persistent experiment-definition
effect. One recorded rerun is `1.7624e+06`; this is the CSV value used here.

## 4. Insights gained

- **Best measured result:** `4x2 column`, `N=399360`, `NB=3072`, at
  `1.8441e+06` GFLOP/s, *27.78%* above baseline. It passed verification.
- **NB has the clearest isolated effect:** at `N=401408`, `2x4 row`, the
  result rises from `1.5782e+06` at NB=1024 to `1.8209e+06` at NB=3072,
  then declines through NB=8192. The sampled peak is broad enough to justify
  local refinement, but not enough to claim the exact optimum.
- **Grid shape is more credible than ordering:** reruns preserve roughly a 3%
  4x2 advantage over 2x4, while column-over-row falls to a weak difference.
  The topology explanation remains a hypothesis.
- **N alignment is mandatory:** repeated `402423`/`403423` runs remain near
  half performance, while the corrected divisible `402432` runs recover to
  `1.4748e+06`–`1.5990e+06`. This is a performance pathology, not a
  correctness failure.
- **A smaller high-N deterioration remains:** `403456` reaches `1.5818e+06`
  and `404480` reaches `1.5540e+06`; CPU RAM overload is not established and
  requires memory/NUMA telemetry.
- **Cross-check evidence:** the N=401408, NB=1024, 2x4-row result is
  `1.5821e+06` in the N sweep and `1.5782e+06` in the NB sweep, only 0.25%
  apart. This supports the broad level of the result, while still leaving
  ordinary run-to-run noise unresolved.
- **No invalid rows:** all 38 rows have `PASSED` verification and finite
  reported GFLOP/s. The analysis therefore ranks all rows numerically, while
  flagging the anomalous performance value rather than discarding it.
- **Reproducibility constraint:** node placement differs across attempts and
  most retained runtime/exit-status fields are unknown. The measurements do
  not support attributing every difference solely to the requested parameter.

## 5. Suggested next section

**Manual ideation**

We proceed with `Precision and memory-placement controls` flags. The report of memory usage from our best run:

```txt
The current best run is:

  experiments/np-sweep/outputs/4x2_col.o

  It reports 1.8441e+06 GFLOP/s for N=399360, NB=3072, 4x2, column order.

  Reported memory usage:

  - Host memory per process: maximum 150.826 GB
  - Host memory available initially: minimum 191.953 GB
  - Device/VRAM per process: maximum 82.813 GB
  - Device memory available initially: minimum 138.646 GB
  - Later during matrix generation:
      - Host memory available minimum: 43.104 GB
      - VRAM available minimum: 55.700 GB

  The output reports total device memory of 139.80 GB. No host or VRAM exhaustion is shown in this run.
```

With VRAM unused fully after we push n and nb, i think we can ultilize it for this "Precision and memory-placement controls" with these flags:

- `--sloppy-type <value>`

- `--Anq-device <int>`

- `--fill-device <0|1>`

- `--fill-device-buffer-size <int>`

- `--cuda-host-register-step <int>`

Since

**Agent ideation**

For user review, the next direction should be controlled confirmation and local
refinement at the `4x2 column` grid: test aligned N values around 401408–404480,
refine NB around 3072 with peak VRAM telemetry, and repeat the 2x4/4x2 grid
comparison on comparable nodes with topology diagnostics. Use the same
container, eight-GPU allocation, launcher, affinity, correctness settings, and
monitoring controls. Prefer at least two comparable attempts per shortlisted
configuration, retaining node and runtime metadata.

Selection should require `PASSED` verification and a repeatable improvement
over the baseline; a single peak should remain provisional. This suggestion
does not authorize a new experiment.

## 6. Provenance

- Structured source: [`results/metrics.csv`](../../results/metrics.csv)
- Validated summary: [`results/RESULTS.md`](../../results/RESULTS.md)
- Experiment IDs: `baseline-sweep`, `N-sweep`, `nb-sweep`, `np-sweep`
- Attempts: all 38 `(experiment_id, attempt)` rows in the CSV
- Raw evidence directories:
  - [`experiments/baseline-sweep/outputs/`](../../experiments/baseline-sweep/outputs/)
  - [`experiments/N-sweep/outputs/`](../../experiments/N-sweep/outputs/)
  - [`experiments/nb-sweep/outputs/`](../../experiments/nb-sweep/outputs/)
  - [`experiments/np-sweep/outputs/`](../../experiments/np-sweep/outputs/)
- Extraction script: [`results/scripts/extract_sweeps.py`](../../results/scripts/extract_sweeps.py)
- Raw marker check: each included stdout contains a `PASSED` residual marker
  and a finite `GFLOPS` report matching the CSV row.
- Analysis date: 2026-08-20
