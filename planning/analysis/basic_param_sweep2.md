# Analysis: Basic parameter sweep 2

## 1. Concise summary

This update incorporates the reruns in `results/metrics.csv` and revisits the
N, NB, and process-grid questions. The baseline remains
`baseline-sweep_v1`: `N=370000`, `NB=1024`, `2x4` row, and
`1.4432e+06` GFLOP/s.

The strongest measured configuration remains `N=399360`, `NB=3072`, `4x2`
column at `1.8441e+06` GFLOP/s, 27.78% above baseline. The new evidence
resolves the original 402k performance anomaly as an N/block-alignment issue,
but exposes an important filename/input discrepancy: files labeled
`402432` report `--n = 403432` in their captured HPL-MxP settings. That value
must be corrected or explicitly reconciled before calling the result a clean
402432 comparison.

The new repeats also show that the earlier grid-order difference was partly
node/run noise. The 4x2 shape remains faster than 2x4, while column versus
row is now a weaker effect, especially for 4x2.

## 2. Scope and evaluation criteria

- Analysis ID: `basic_param_sweep2`
- Analysis date: 2026-08-20
- Source: [`results/metrics.csv`](../../results/metrics.csv)
- Included: all 35 recorded rows from `baseline-sweep`, `N-sweep`,
  `nb-sweep`, and `np-sweep`, including the new reruns.
- Workload/runtime: NVIDIA HPL-MxP container `26.02`, GAAS `gpu_as` queue,
  eight MPI processes/GPUs, GPU affinity `0:1:2:3:4:5:6:7`.
- Correctness gate: `verification=PASSED` and finite GFLOP/s. All 35 rows
  pass this gate. A passed verification does not make an anomalous
  performance result representative.
- Metric: reported HPL-MxP performance in GFLOP/s. Percentage changes use
  `1.4432e+06` GFLOP/s as the baseline.
- Important limitation: most retained PBS runtime and exit-status fields are
  unknown, and attempts use different GAAS nodes. The reruns therefore help
  separate parameter effects from transient noise but do not eliminate it.

## 3. Data and analysis

### Baseline

| Attempt | N | NB | Grid setup | GFLOP/s |
|---|---:|---:|---|---:|
| `baseline-sweep_v1` | 370000 | 1024 | 2x4 row | 1.4432e+06 |

### Issue 1 — N sweep and deterioration above 402k

The normal N sweep rises from 399k through 401k, then deteriorates at the
larger tested sizes. The raw settings emitted by HPL-MxP are shown below;
these are the values used in the CSV.

| Attempt | Captured N | GFLOP/s | Note |
|---|---:|---:|---|
| `N-sweep_399k` | 399360 | 1.4918e+06 | original point |
| `N-sweep_400k` | 400384 | 1.5751e+06 | original point |
| `N-sweep_401k` | 401408 | 1.5821e+06 | original point |
| `N-sweep_402k` | 402423 | 7.6797e+05 | original outlier |
| `N-sweep_402_re1` | 403423 | 7.2526e+05 | repeat; still outlier |
| `N-sweep_402_re2` | 403423 | 7.3508e+05 | repeat; still outlier |
| `N-sweep_402_re3` | 403423 | 7.3884e+05 | repeat; still outlier |
| `N-sweep_402432_{1,2,3}` | 403432 | 1.5635e+06, 1.6098e+06, 1.6022e+06 | files labeled 402432; captured N is 403432 |
| `N-sweep_403k` | 403456 | 1.5818e+06 | normal-sized result |
| `N-sweep_404k` | 404480 | 1.5540e+06 | below the 401k/403k region |

The repeated `402423`/`403423` runs establish that the low value is not a
one-off node failure. The aligned-size reruns are around `1.56–1.61e+06`,
which is a large recovery relative to `7.25–7.39e+05`. The likely mechanism
is N/block alignment: the outlier values are not divisible by `NB=1024`,
while the intended aligned values are divisible by 1024. This is a strong
working explanation, not a proof of the exact internal bottleneck.

The broader deterioration is still visible after removing the outlier:
`403456` reaches `1.5818e+06`, while `404480` falls to `1.5540e+06`.
Therefore the alignment issue explains the catastrophic 402k-class anomaly,
but not necessarily the gradual performance decline at larger N.

The CPU-RAM-overload hypothesis is possible but currently weak. A one-percent
change in N changes matrix storage only slightly; it would not by itself
explain a roughly 50% drop that repeats at the misaligned size. Larger N can
still change workspace, paging, NUMA placement, or memory traffic enough to
explain a gradual decline, so it should be tested rather than dismissed.

How to verify the remaining RAM hypothesis:

1. Repeat aligned N values around 401k–405k with the same NB, grid, node
   controls, and at least two attempts per point.
2. Record PBS memory accounting (`resources_used.mem`, and job-level
   `resources_used.vmem` where available) with `qstat -f`/accounting data.
3. Record host memory pressure and NUMA placement during the job, including
   per-node free memory, swap activity, and the process RSS/high-water mark.
4. Compare aligned and misaligned runs at nearly identical N. If memory
   usage and paging are unchanged while performance follows divisibility, the
   alignment explanation is favored; if memory pressure rises at the larger
   sizes, RAM/workspace pressure remains plausible.

### Issue 1.1 — 402k anomaly resolved, with a data caveat

The original `402423` result (`7.6797e+05`) is reproduced by three reruns
(`7.2526e+05`, `7.3508e+05`, `7.3884e+05`). It is therefore a stable
performance pathology for that input, not random noise. The intended aligned
case produces `1.5635e+06`, `1.6098e+06`, and `1.6022e+06`.

The practical conclusion is to always align N to NB when comparing N values.
However, the captured settings must be checked: the files named
`N-sweep_402432_*` contain `--n = 403432`, not `402432`. The analysis can
confidently conclude that the aligned/revised input avoids the catastrophic
behavior, but it should not claim that the exact 402432 input was measured
until the run script or captured settings are corrected.

### Issue 2 — NB sweep

The fixed-N NB sweep is:

| NB | N | Grid | GFLOP/s |
|---:|---:|---|---:|
| 1024 | 401408 | 2x4 row | 1.5782e+06 |
| 2048 | 401408 | 2x4 row | 1.7879e+06 |
| 3072 | 401408 | 2x4 row | 1.8209e+06 |
| 4096 | 401408 | 2x4 row | 1.8040e+06 |
| 5120 | 401408 | 2x4 row | 1.7569e+06 |
| 8192 | 401408 | 2x4 row | 1.7445e+06 |

(`3072`, not 3073, is the tested point.) Increasing NB improves performance
strongly through 2048 and 3072, then performance declines. The most likely
explanation for the increase is improved panel/work granularity and fewer
panel-level overheads, with better amortization of communication and GPU
work. The decline may reflect larger panel workspace, reduced occupancy or
cache efficiency, more synchronization, or a less favorable communication
granularity. The current data cannot distinguish these mechanisms.

The N resweep with `NB=3072` does not show a universal rule that every
non-multiple is catastrophic: `N=399360` gives `1.8040e+06` in the rerun and
`N=402432` gives `1.6981e+06`, both valid and performant. Nevertheless, the
`402423`/`403423` versus aligned/revised case demonstrates that misalignment
can cause a severe failure mode. The operational rule remains: always align N
to NB.

How to verify the NB mechanism and VRAM limit:

- Capture `nvidia-smi` memory-used and memory-total per GPU throughout each
  batch job, not only at startup; retain peak values with the result.
- Record HPL-MxP workspace/allocation messages if emitted, and correlate peak
  VRAM with the NB transition from 3072 to 4096 and above.
- Repeat nearby values around 3072 (for example 2560, 2816, 3072, 3328,
  3584, 4096) with the same N and grid. A smooth peak suggests tuning/occupancy
  effects; an abrupt change near available memory suggests workspace pressure.
- Record host RAM and GPU VRAM separately. GPU VRAM exhaustion or allocator
  pressure is not equivalent to CPU RAM overload.

### Issue 3 — process-grid shape and ordering

The original grid sweep suggested both 4x2 and column ordering were clear
winners. The reruns are:

| Attempt | Grid | GFLOP/s |
|---|---|---:|
| `2x4_col_re` | 2x4 column | 1.7837e+06 |
| `2x4_row_re1` | 2x4 row | 1.7550e+06 |
| `2x4_row_re2` | 2x4 row | 1.7954e+06 |
| `4x2_col_re` | 4x2 column | 1.8370e+06 |
| `4x2_row_re` | 4x2 row | 1.8304e+06 |

The rerun mean for 2x4 row is `1.7752e+06`; 4x2 row is `1.8304e+06`,
approximately 3.1% higher. The column comparison is `1.7837e+06` versus
`1.8370e+06`, approximately 3.0% higher for 4x2. This supports 4x2 as the
better shape in this workload.

Column versus row is no longer a strong universal effect. In the reruns,
2x4 column exceeds the 2x4 row mean by about 0.5%, while 4x2 column is only
about 0.36% above 4x2 row. The earlier single-run differences (1.7–1.9%)
were comparable to the observed node/run variation.

The 4x2 result is consistent with a favorable communication and panel
factorization mapping, but the intuition that 4x2 must communicate more is
not sufficient to predict performance: message count, message sizes, panel
broadcast direction, GPU affinity, and synchronization all matter. The H200
8-way NVLink topology is a plausible contributor, but it is not established
by these timings. Verify it with `nvidia-smi topo -m`, the MPI transport
mapping, GPU affinity, and (where available) NCCL/UCX topology diagnostics.
Compare panel-factorization and broadcast timings from the raw benchmark
output if they are available.

### Issue 3.1 — grid/NB resweep discrepancy resolved as node noise

The earlier comparison was not a like-for-like repeat: the NB-sweep
`n-resweep_399k` and grid-sweep `2x4_row` were different attempts and nodes.
The original values were `1.8177e+06` and `1.7302e+06` (about 5% apart).

The new NB-sweep reruns are `1.7624e+06`, `1.8038e+06`, and `1.7933e+06`,
and the new grid-sweep 2x4-row reruns are `1.7550e+06` and `1.7954e+06`.
Their ranges overlap substantially, and their means are close. This supports
the conclusion that the earlier 5% discrepancy was predominantly node/run
noise, likely a one-time outlier, rather than a persistent difference between
the experiment definitions.

## 4. Insights gained

- **N alignment is mandatory:** the repeated low result at 402423/403423
  demonstrates a severe non-aligned-N failure mode, while the revised aligned
  files recover to normal performance. The exact captured N for the files
  labeled 402432 is 403432 and needs correction or confirmation.
- **The gradual high-N decline remains open:** after removing the alignment
  pathology, 403456 is `1.5818e+06` and 404480 is `1.5540e+06`. This is a
  smaller deterioration than the outlier and may involve workspace, memory,
  or communication effects. Current evidence does not establish CPU RAM as
  the cause.
- **NB=3072 is a sampled local peak:** NB improves throughput substantially
  from 1024 through 3072 and then declines. The likely causes are panel
  granularity/overhead at low NB and workspace, occupancy, cache, or
  synchronization tradeoffs at high NB. VRAM and host-memory telemetry are
  required to identify which applies.
- **4x2 is the stronger grid shape:** reruns preserve an approximately 3%
  advantage over 2x4. This is consistent with a topology/mapping effect but
  does not by itself prove an H200 NVLink explanation.
- **Column ordering is a weak effect after replication:** the earlier clear
  column advantage is not reproduced consistently; it is near the scale of
  node noise in the new data.
- **The prior cross-experiment discrepancy is explained by node noise:** the
  repeated 399360/NB=3072/2x4-row results overlap across the two experiment
  families. The earlier 5% difference should not be treated as a stable
  experiment-definition effect.
- **All 35 runs pass correctness:** no result is numerically invalid, but
  correctness does not prevent performance-pathology cases from being
  identified and investigated.

## 5. Suggested next section

For further confirmation, use controlled repeats rather than a new broad
optimization direction:

1. Correct and verify the intended `N=402432` launch, then repeat aligned N
   values around 401408–404480 with `NB=1024`; capture host RAM, NUMA, paging,
   and PBS memory accounting.
2. Refine NB around 3072 at a fixed aligned N and fixed 4x2 grid, capturing
   peak per-GPU VRAM and host memory.
3. Repeat 2x4 and 4x2 row/column configurations on comparable nodes with
   identical GPU affinity; collect topology and communication diagnostics.

These are verification recommendations, not execution authorization.

## 6. Provenance

- Structured source: [`results/metrics.csv`](../../results/metrics.csv)
- Validated report: [`results/RESULTS.md`](../../results/RESULTS.md)
- Experiment IDs: `baseline-sweep`, `N-sweep`, `nb-sweep`, `np-sweep`
- Raw evidence directories:
  - [`experiments/N-sweep/outputs/`](../../experiments/N-sweep/outputs/)
  - [`experiments/nb-sweep/outputs/`](../../experiments/nb-sweep/outputs/)
  - [`experiments/np-sweep/outputs/`](../../experiments/np-sweep/outputs/)
- Extraction workflow: [`results/scripts/extract_sweeps.py`](../../results/scripts/extract_sweeps.py)
- Analysis date: 2026-08-20
