# Analysis: Effect of a smaller U-panel chunk during panel factorization

## 1. Concise summary

This analysis evaluates `--u-panel-chunk-nbs 4` against the previous profiled
best configuration, which used `--u-panel-chunk-nbs 8`. The workload and all
other recorded HPL-MxP controls were held fixed. A smaller chunk changes the
granularity of U-panel work from roughly eight `NB` blocks per group to four;
at this workload the guide's derived constraint changes from `5` to `10`, so
both values are valid and non-pathological.

The trace shows a real scheduling change: chunk 4 launches many more small
instances of the dominant `nvjet` kernel, increases NCCL broadcast-kernel
launches, and reduces the recorded MPI collective synchronization time. It
does not reduce the dominant kernel's cumulative execution time, however, and
the clean end-to-end runs show no reproducible performance gain. The practical
conclusion is to retain chunk 8 as the default for this single-node H200
workload; chunk 4 changes the pipeline shape but does not improve the measured
HPL-MxP score.

## 2. Scope and evaluation criteria

- Application: NVIDIA HPL-MxP v26.02 (`hpc-benchmarks_26.02.sif`).
- Profile source revision: `c7d0056`.
- Workload: `N=491520`, `NB=3072`, `2x4` row grid, eight MPI ranks/eight H200
  GPUs, GPU affinity `0:1:2:3:4:5:6:7`.
- Fixed controls: `--preset-gemm-kernel 90`, FP16, `--fill-device 1`,
  fill buffer `2048`, CUDA host-register step `2048`, separate GEMM stream,
  `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`, and
  `--skip-tests 1`.
- Profile control: `--use-mpi-panel-broadcast 50`, chunk `8`, job `53452`,
  node `hpc-gaas-g13`, reported `1.9668e+06` GFLOP/s.
- Chunk profile: `--use-mpi-panel-broadcast 50`, chunk `4`, job `55234`,
  node `hpc-gaas-g15`, reported `2.1824e+06` GFLOP/s.
- Additional profiled context: broadcast-100, chunk `8`, job `55233`, node
  `hpc-gaas-g12`, reported `2.1585e+06` GFLOP/s.
- Clean current-control reference from the optimization plan:
  `2.3920e+06` GFLOP/s. Original project baseline:
  `baseline-sweep_v1 = 1.4432e+06` GFLOP/s.
- Acceptance criteria: finite residual, `PASSED` verification, and a
  repeatable improvement in clean end-to-end GFLOP/s. Cumulative times in the
  SQLite tables are rank-local event time; they are not wall time and must not
  be summed as an application runtime.

## 3. Data and analysis

### 3.1 HPL-MxP output and phase-level comparison

| Run | Chunk | Broadcast | GFLOP/s | % vs original baseline | % vs clean control | LU s | LU GFLOP/s | Solver s | Residual marker |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Previous profiled control | 8 | 50 | 1.9668e+06 | +36.28% | -17.78% | 20.76 | 3.8133e+06 | 19.49 | `4.836718e-14`, PASSED |
| Profiled broadcast comparison | 8 | 100 | 2.1585e+06 | +49.56% | -9.76% | 20.88 | 3.7914e+06 | 15.80 | `4.836718e-14`, PASSED |
| Profiled chunk comparison | 4 | 50 | 2.1824e+06 | +51.22% | -8.76% | 20.52 | 3.8572e+06 | 15.75 | `4.553931e-14`, PASSED |

The chunk-4 profile is `+10.96%` above the older profiled control and only
`+1.11%` above the broadcast-100 profile. These are not clean optimization
comparisons: the control was profiled on 27 August on `g13`, while both
variant profiles were collected on 31 August on different nodes. More
importantly, both variant profiles—not only chunk 4—show a solver time near
`15.8 s`, versus `19.49 s` for the older profile. That common shift makes the
apparent chunk-4 score gain unsuitable for attribution to U-panel chunk size.

The phase split is consistent with this caution. Relative to the old profile,
chunk 4 reduces LU time by `1.16%` and solver time by `19.19%`; broadcast 100
reduces solver time by `18.93%` while slightly increasing LU time by `0.58%`.
The large solver change is therefore primarily a run/node/profiling-state
difference, not evidence that chunk 4 improved refinement.

### 3.2 Nsight kernel and synchronization evidence

The new SQLite exports were queried across all eight ranks. The previous
profile values below are the corresponding all-rank values reported in
`optimization_plan_1.md`; rank-0 values from the old `.nsys-rep` were also
checked directly with `nsys stats`.

| Evidence, per rank mean unless stated | Previous profile, chunk 8 / broadcast 50 | Chunk 4 / broadcast 50 | Change |
|---|---:|---:|---:|
| Dominant `nvjet_sm90_hss_192x192...` calls | ~497.6 | 878.1 | +76.5% |
| Dominant `nvjet` kernel time | ~14.806 s | 14.818 s | +0.08% |
| NCCL broadcast kernel calls | ~1,530.5 | 1,621.5 | +5.9% |
| NCCL broadcast kernel time | ~3.394 s | 3.445 s | +1.5% |
| Rank-0 `MPI_Wait` calls | 540 | 540 | 0.0% |
| Rank-0 `MPI_Wait` cumulative time | 3.781 s | 3.791 s | +0.3% |
| Rank-0 `cudaStreamSynchronize` time | 17.964 s | 17.459 s | -2.8% |

Chunk 4 therefore exposes finer-grained kernel scheduling without shortening
the dominant compute path. The larger number of `nvjet` launches is the
expected consequence of subdividing U-panel work; the nearly unchanged
cumulative kernel time says that the extra launch granularity did not produce
more useful low-precision throughput.

The comparison with the broadcast-100 profile helps identify what is and is
not a chunk effect:

| Trace evidence, eight-rank distribution | Broadcast 100 / chunk 8 | Broadcast 50 / chunk 4 | Interpretation |
|---|---:|---:|---|
| `MPI_Wait` calls per rank | 1,080 | 540 | Mostly a broadcast-policy difference; not a clean chunk comparison |
| `MPI_Wait` cumulative time mean | 6.508 s | 5.473 s | Chunk trace has less wait time than broadcast-100, but policies differ |
| Long `MPI_Wait` calls (>100 ms), mean/rank | 26.8 | 26.6 | Long-tail count is unchanged |
| `MPI_Allreduce` cumulative time mean | 11.853 s | 5.345 s | Arrival/collective timing is much better in the chunk trace, but is not isolated from node/run effects |
| NCCL broadcast calls per rank | 1,195.5 | 1,621.5 | Chunk 4 creates a finer collective schedule |
| NCCL broadcast kernel time mean | 1.928 s | 3.445 s | More GPU-side collective work accompanies finer chunking |
| `cudaStreamSynchronize` time mean | 18.372 s | 16.475 s | Some host-visible synchronization is reduced |

The chunk-4 trace also has a `cudaEventSynchronize` total of `2.446 s` on
rank 0, with a longest event of about `430 ms`; the corresponding broadcast-100
trace has negligible event-synchronization time on that rank. This is another
sign that chunk 4 changes where synchronization is paid rather than removing
the dependency cost altogether.

### 3.3 Clean same-node controls

The clean `mpi-nccl-coms-sweep` records provide the decisive performance
control. They all use the same `N`, `NB`, grid, placement, fill settings, and
node `hpc-gaas-g13`; chunk 4 and chunk 8 are compared at the same broadcast
policy where possible.

| Clean attempt | Broadcast | Chunk | GFLOP/s | % vs original baseline | LU s | Solver s | Verification |
|---|---:|---:|---:|---:|---:|---:|---|
| `chunk_baseline_a` | 50 | 8 | 2.3118e+06 | +60.19% | 20.53 | 13.71 | PASSED |
| `chunk4_b` | 50 | 4 | 2.3391e+06 | +62.08% | 20.58 | 13.26 | PASSED |
| `chunk8_b` | 50 | 8 | 2.3430e+06 | +62.35% | 20.43 | 13.36 | PASSED |
| `chunk_baseline_b` | 50 | 8 | 2.3496e+06 | +62.80% | 20.50 | 13.20 | PASSED |

Chunk 4 is `-0.17%` against the adjacent chunk-8 run and `+0.36%` against
the mean of the two bracket controls (`2.3307e+06`). At broadcast 75, the
corresponding clean comparison is also slightly negative: chunk 4 is
`2.3259e+06` versus `2.3403e+06` for chunk 8 (`-0.62%`). These differences
are below the observed same-node control spread, so there is no clean score
evidence of a chunk-4 win.

## 4. Insights gained

1. Smaller U-panel chunks do change execution granularity. At chunk 4, the
   dominant `nvjet` launch count rises by about `76%`, while its cumulative
   execution time stays essentially constant. NCCL broadcast launches also
   rise by about `6%` and their cumulative kernel time by about `1.5%` relative
   to the prior chunk-8 profile.
2. The trace suggests reduced average collective/synchronization time in the
   chunk-4 run, especially for `MPI_Allreduce`, but the profile runs are on
   different nodes and dates. The unchanged count of long MPI waits and the
   new rank-0 event-synchronization tail show that this is a redistribution of
   synchronization, not proof of a shorter critical path.
3. The profiled HPL score improvement cannot be assigned to chunk 4. The
   broadcast-100 profile has the same unusually shorter solver phase, and the
   clean chunk study shows chunk 4 and chunk 8 within measurement drift.
4. Correctness is preserved. All profiled and clean comparison runs report
   `PASSED`, finite residuals, and two solver correction steps. The residual
   values differ slightly between profiling runs but remain valid.
5. For the current single-node NVSwitch/H200 workload, chunk 4 is a
   scheduling diagnostic rather than a performance optimization. It should
   not replace chunk 8 in the shipping configuration based on this evidence.

## 5. Suggested next section

Close `--u-panel-chunk-nbs` as a first-order lever for this workload and keep
the established value `8`. If the mechanism must be isolated further, use a
matched repeated profile with the same node class and the same
`--use-mpi-panel-broadcast` value for chunk 4 and chunk 8, then compare the
critical-path wall window, MPI wait tails, `MPI_Allreduce` arrival skew,
stream/event synchronization, and dominant-kernel launch counts.

The next optimization direction recommended by the prior plan remains the
dependency-priority sweep (`--prioritize-factorization` and
`--prioritize-trsm`). Those flags target panel readiness directly and avoid
reopening a chunk-size direction that has already shown no clean end-to-end
gain. This is a recommendation only; no new experiment is authorized by this
analysis.

## 6. Provenance

- Prior mechanism analysis and baseline profile: [`optimization_plan_1.md`](optimization_plan_1.md).
- Chunk-4 profile stdout: [`hpl_stdout.log`](../experiments/nsight-systems/outputs/nsys-trace-chunk-4/hpl_stdout.log).
- Broadcast-100 profile stdout: [`hpl_stdout.log`](../experiments/nsight-systems/outputs/nsys-trace-broadcast-100/hpl_stdout.log).
- Prior profile stdout: [`hpl_stdout.log`](../experiments/nsight-systems/outputs/nsys-trace/hpl_stdout.log).
- Remote SQLite traces: `experiments/nsight-systems/outputs/nsys-trace-chunk-4/hpl_mxp_rank_0.sqlite` … `hpl_mxp_rank_7.sqlite` and the corresponding `nsys-trace-broadcast-100` files on GAAS.
- Profile experiment metadata and jobs: [`experiments/nsight-systems/README.md`](../experiments/nsight-systems/README.md), jobs `53452`, `55233`, and `55234`.
- Clean structured source: [`results/metrics.csv`](../results/metrics.csv), attempts `chunk_baseline_a/b`, `chunk4_a/b`, and `chunk8_a/b`.
- Clean detailed comparison: [`mpi-nccl-coms-sweep.md`](analysis/mpi-nccl-coms-sweep.md).
- Analysis date: 2026-08-31.
