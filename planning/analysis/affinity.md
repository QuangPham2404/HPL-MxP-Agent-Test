# Analysis: Affinity and OpenMP thread flags

## 1. Concise summary

This analysis evaluates the authorized affinity and OpenMP sweep results from
`affinity-sweep`. The tests held the HPL-MxP workload at `N=399360`,
`NB=3072`, an eight-process `4x2` column-major grid, and GPU affinity
`0:1:2:3:4:5:6:7`. All five selected attempts passed the numerical
verification gate and reported finite performance.

The memory-affinity control was effectively equal to the prior matched
`4x2`-column result, the best CPU-affinity variant was only 0.84% higher, and
the strict CPU-affinity variant was 8.25% lower. The single OpenMP run with
10 threads was 52.80% below the matched control. These are single
measurements per configuration, so they indicate candidates and regressions,
not reproducible final rankings.

## 2. Scope and evaluation criteria

- Analysis ID: `affinity`
- Analysis date: 2026-08-20
- Source: [`results/metrics.csv`](../../results/metrics.csv)
- Source revision: repository commit `2ff2c7d`
- Included rows: the five `affinity-sweep` attempts
  `mem_aff`, `cpu_aff_free`, `cpu_aff_neutral`, `cpu_aff_strict`, and
  `thread_10`.
- Grouping: CPU/memory affinity flags and OpenMP thread flags, as requested.
- Matched control: `np-sweep/4x2_col`, `N=399360`, `NB=3072`, `4x2` column,
  `1.8441e+06` GFLOP/s, `PASSED`.
- Project baseline: `baseline-sweep_v1`, `N=370000`, `NB=1024`, `2x4` row,
  `1.4432e+06` GFLOP/s, `PASSED`.
- Correctness gate: `verification=PASSED`, finite residual, and finite
  reported `gflops`. All five included rows pass.
- Performance metric: reported HPL-MxP GFLOP/s from the `gflops` CSV field.
- Runtime, completion time, and PBS exit status were not available in the
  retained CSV records and were not used for ranking.
- Provenance limitation: the raw stdout files retain the HPL-MxP settings
  but do not echo the exact CPU-affinity launch strings for `cpu_aff_free` or
  `cpu_aff_strict`; their labels and output paths are retained as submitted.

## 3. Data and analysis

### Affinity flags

| Attempt | Affinity configuration recorded | Node | GFLOP/s | vs matched control |
|---|---|---|---:|---:|
| `mem_aff` | Memory affinity `0:0:0:0:1:1:1:1`; no explicit CPU affinity | `hpc-gaas-g11` | `1.8428e+06` | `-0.07%` |
| `cpu_aff_free` | CPU-affinity variant label; exact launch string not retained | `hpc-gaas-g11` | `1.8596e+06` | `+0.84%` |
| `cpu_aff_neutral` | CPU affinity `0-11:12-23:24-35:36-49:56-66:67-77:78-89:90-101` plus memory affinity | `hpc-gaas-g14` | `1.8077e+06` | `-1.97%` |
| `cpu_aff_strict` | CPU-affinity variant label; exact launch string not retained | `hpc-gaas-g11` | `1.6919e+06` | `-8.25%` |

The three CPU-affinity results span `1.6919e+06` to `1.8596e+06` GFLOP/s;
their simple mean is `1.7864e+06`, 3.06% below the memory-affinity control.
The spread is too large to attribute confidently to the affinity labels from
one run each, especially because node and runtime metadata are incomplete.
The `mem_aff` result is nearly identical to the matched control. Relative to
the project baseline, the four affinity attempts range from +17.23% to
+28.85%, but that comparison includes the workload/grid changes already
present in the matched control.

### OpenMP thread flags

| Attempt | OpenMP configuration | Node | GFLOP/s | vs matched control |
|---|---|---|---:|---:|
| `thread_10` | `OMP_NUM_THREADS=10`, `OMP_PLACES=cores`, exported through MPI/container; CPU affinity as documented in the experiment README | `hpc-gaas-g11` | `8.7049e+05` | `-52.80%` |

The one `thread_10` run is a large regression relative to the matched control
and is also below the project baseline by 39.68%. It passed verification, so
this is a performance result rather than a correctness failure. Because no
thread-count control or repetition is included, the result does not establish
whether the regression is caused by 10 threads specifically or by an
interaction between OpenMP placement, MPI process binding, and the selected
CPU-affinity layout.

## 4. Insights gained

- All selected configurations were numerically valid; no correctness
  regression or non-finite performance value was observed.
- Memory affinity appears neutral relative to the prior `4x2` column control
  in this single comparison (`-0.07%`).
- The CPU-affinity measurements are inconclusive as a ranking: `free` is the
  highest at `1.8596e+06`, while `strict` is `8.25%` below the control, but
  the exact free/strict launch strings are not present in retained stdout and
  each configuration has only one attempt.
- `OMP_NUM_THREADS=10` is a strong negative signal in the recorded attempt,
  but it needs a matched thread-count control and repetitions before treating
  it as a stable effect.
- Node placement is a confounder: four selected attempts ran on `hpc-gaas-g11`
  and `cpu_aff_neutral` ran on `hpc-gaas-g14`; retained runtime and PBS exit
  fields are unknown.

## 5. Suggested next section

For user review, repeat the matched `4x2` column workload with the memory
affinity control and the best labeled CPU-affinity variant, preserving exact
launch strings, node/runtime metadata, and at least two comparable attempts
per configuration. Add an explicit OpenMP control at the same CPU affinity
with the default thread setting before testing a small thread-count set; this
will separate thread-count effects from MPI/container placement effects.

Require `PASSED` verification and a repeatable performance improvement over
the matched `4x2` column control before selecting an affinity configuration.
This recommendation does not authorize a new experiment or configuration
change.

## 6. Provenance

- Structured source: [`results/metrics.csv`](../../results/metrics.csv)
- Validated report: [`results/RESULTS.md`](../../results/RESULTS.md)
- Experiment metadata: [`experiments/affinity-sweep/README.md`](../../experiments/affinity-sweep/README.md)
- Raw evidence:
  - [`cpu_aff_free.o`](../../experiments/affinity-sweep/outputs/cpu_aff_free.o)
  - [`cpu_aff_neutral.o`](../../experiments/affinity-sweep/outputs/cpu_aff_neutral.o)
  - [`cpu_aff_strict.o`](../../experiments/affinity-sweep/outputs/cpu_aff_strict.o)
  - [`mem_aff.o`](../../experiments/affinity-sweep/outputs/mem_aff.o)
  - [`thread_10.o`](../../experiments/affinity-sweep/outputs/thread_10.o)
- Raw residual marker: each selected stdout contains `PASSED` with a finite
  residual and a finite GFLOP/s marker matching the CSV.
