# Consolidation M2: Communication, LU Scheduling, and Host-Threading Results

## Purpose and evidence boundary

This document consolidates the second phase of the HPL-MxP optimization. It
explains what the tested flags control, why the measured phases responded as
they did, which settings should be retained, and which apparent differences
are too small to distinguish from run-to-run variation. It expands rather
than merely repeats these four analysis reports:

- [`mpi-nccl-coms-sweep.md`](analysis/mpi-nccl-coms-sweep.md);
- [`factorization-priority.md`](analysis/factorization-priority.md);
- [`separate-stream-for-gemm.md`](analysis/separate-stream-for-gemm.md);
- [`dgemv-with-multiple-threads.md`](analysis/dgemv-with-multiple-threads.md).

The numeric source of truth is [`results/metrics.csv`](../results/metrics.csv),
with correctness cross-checked against the raw outputs. The original project
baseline remains `baseline-sweep_v1`:

- `N=370000`, `NB=1024`, `2x4` row grid;
- 8 MPI ranks, one rank per H200 GPU;
- `1.4432e+06` reported GFLOP/s;
- finite residual and `PASSED` verification.

Every percentage labelled “vs original baseline” uses that `1.4432e+06`
GFLOP/s result, even though the phase-2 sweeps use a much stronger
same-configuration control near `2.3–2.4e+06`. This distinction matters:

- the **original baseline** shows cumulative project improvement;
- the **in-experiment control** isolates the flag being tested;
- the **best single measurement** is not automatically a repeatable baseline.

All phase-2 runs used NVIDIA HPL-MxP v26.02 on one GAAS node with eight H200
GPUs, `N=491520`, `NB=3072`, a `2x4` row grid, eight OpenMP threads with socket
placement/binding, and the established device-placement settings. All reported
attempts passed with finite residuals. The communication sweep ran on
`hpc-gaas-g13`; the three later scheduling/threading sweeps ran on
`hpc-gaas-g16`. Comparisons across those node groups are descriptive, not
controlled flag comparisons.

## The overall causal story

Phase 2 asked whether the remaining time could be reduced by changing four
different layers of the pipeline:

```text
panel factorization
        ↓
panel broadcast (MPI/NCCL policy)
        ↓
U-side TRSM and chunk readiness
        ↓
trailing GEMM updates (CUDA stream/dependency ordering)
        ↓
FP64 residual work and iterative refinement (including DGEMV)
```

The decisive result is not that “communication does not matter.” It is that,
on this single NVSwitch-connected node and at this workload, changing the
transport mix or panel chunk granularity did not shorten the measured critical
path beyond the noise floor. Reordering the dependency graph did: allowing
panel factorization to take precedence over otherwise-ready GEMMs shortened LU
from `20.38 s` to `19.12 s`. Keeping GEMM in a separate CUDA stream preserved
some of that concurrency. Trying to parallelize host DGEMV work then slowed the
solver without changing LU or convergence.

| Stage | Tested choice | Best measured result | % vs original baseline | Decision | Phase carrying the signal |
|---|---|---:|---:|---|---|
| Original baseline | `N=370000`, `NB=1024` | 1.4432e+06 | 0.00% | Historical reference | Whole run |
| MPI/NCCL broadcast | 0/25/50/75/100% MPI | 2.3570e+06 at 75 | +63.32% | Keep 50; winner is inside control drift | Small LU-side movement |
| U-panel chunk | 4/8/16 `NB` units | 2.3496e+06 control at 8 | +62.80% | Keep 8; no resolved effect | None |
| Dependency priority | factorization on, TRSM off | 2.4203e+06 | +67.70% | Retain factorization priority | LU |
| Separate GEMM stream | enabled | 2.4162e+06 | +67.42% | Keep enabled | LU overlap/scheduling |
| DGEMV host threading | 0, meaning one caller thread | 2.4252e+06 | +68.04% | Keep 0 | Iterative solver |

The effective phase-2 configuration is therefore:

```text
--use-mpi-panel-broadcast 50
--u-panel-chunk-nbs 8
--prioritize-trsm 0
--prioritize-factorization 1
--use-separate-stream-for-gemm 1
--call-dgemv-with-multiple-threads 0
```

Only `--prioritize-factorization 1` is a retained change from the phase-1
configuration. The repeat measurements `2.4162e+06`, `2.4203e+06`, and
`2.4252e+06` indicate a practical performance plateau near `2.42e+06`
GFLOP/s—about `+68%` over the original baseline—rather than three meaningfully
different records.

## 1. MPI/NCCL panel-broadcast policy

Report: [`mpi-nccl-coms-sweep.md`](analysis/mpi-nccl-coms-sweep.md),
2026-08-27.

### What the flag actually changes

`--use-mpi-panel-broadcast <percent>` selects the percentage of panel steps
assigned to the CUDA-aware MPI path. NVIDIA's example states that `30` means
the first 30 percent of steps use MPI; `0` selects NCCL for the panel-broadcast
path. It is therefore a schedule policy, not a continuous bandwidth dial and
not a statement that the entire application contains no MPI or NCCL work.
The trace with value `100` still contains NCCL broadcasts outside or alongside
the selected panel path.

The two transports pay for communication differently:

- NCCL performs GPU-oriented collectives and consumes GPU-side execution
  resources for its broadcast kernels;
- CUDA-aware MPI can carry device buffers through the MPI stack, shifting more
  work and waiting into MPI progress and synchronization;
- changing the percentage trades one form of overhead for the other; it does
  not change the arithmetic performed by the dominant `nvjet_sm90` kernel.

NVIDIA documents both the percentage semantics and the requirement for a
CUDA-aware MPI path when the value is greater than zero
([HPL-MxP options](https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html),
[CUDA-aware MPI notes](https://docs.nvidia.com/nvidia-hpc-benchmarks/overview.html#cuda-aware-mpi-for-cray-mpich)).
The current online page lists a default of `1`, whereas the v26.02 GAAS run
output used by this project reports `50` when the experiment treats the flag
as its established control. The captured package output is authoritative for
reproducing these results; future package upgrades must re-check the effective
value rather than assuming either default.

### Clean sweep result

| MPI percentage | GFLOP/s | LU s | Solver s | % vs original baseline | Attempt |
|---:|---:|---:|---:|---:|---|
| 50, opening control | 2.2771e+06 | 20.43 | 14.33 | +57.78% | `bc_baseline_a` |
| 0, NCCL panel path | 2.3045e+06 | 21.05 | 13.30 | +59.68% | `bc_0` |
| 25 | 2.3179e+06 | 20.63 | 13.53 | +60.61% | `bc_25` |
| 50 | 2.3291e+06 | 20.60 | 13.39 | +61.38% | `bc_50` |
| 75 | 2.3570e+06 | 20.35 | 13.23 | +63.32% | `bc_75` |
| 100, MPI panel path | 2.3251e+06 | 20.57 | 13.48 | +61.11% | `bc_100` |
| 50, closing control | 2.3372e+06 | 20.50 | 13.37 | +61.95% | `bc_baseline_b` |

The sequence superficially suggests that 75% MPI is best. The bracketing
control invalidates that simple reading: the unchanged `50/8` configuration
rose from `2.2771e+06` to `2.3372e+06`, a `+2.6%` drift during the same job.
The apparent 75-versus-50 advantage is smaller than that control movement.
Across all six measurements of `50/8` in both communication phases, the score
spans `2.2771e+06–2.3496e+06`, about `3.2%`.

The small parameter-correlated movement is on the LU side: all-NCCL has the
longest LU time (`21.05 s`), while the soft 75% peak has the shortest
(`20.35 s`). The solver remains in a narrow range and is not logically part of
panel broadcast. This makes a minor LU transport effect plausible, but the
clean runs do not resolve its size.

### What the Nsight trace adds

The profiled 50-versus-100 comparison shows that the flag works as intended.
At 100%, mean NCCL broadcast-kernel time falls about 43%, while MPI wait time
rises about 23%, CUDA stream-wait time rises about 19%, and rank-0 MPI
point-to-point records and payload double. Dominant `nvjet` kernel time is
flat. These are cumulative per-rank trace quantities, not additive wall-clock
times, but together they show transport substitution rather than eliminated
communication.

The trace also explains why the clean sweep is flat: less NCCL GPU work is
exchanged for more MPI and synchronization pressure. On one H200 NVSwitch
node, neither side wins decisively. This conclusion must not be generalized to
multi-node runs, where network topology, NIC affinity, MPI progress, and
inter-node NCCL behavior can change the balance.

### Personal notes

*The ineffectiveness of the MPI-NCCL coms flag and the U-chunk granularity flag also indicates that it is not only the communication that acts as a bottleneck - it is also dependency of TRSM --> factorization --> GEMM. The results from the NSIGHT trace of the first phase's optimized run support this.*

### Remaining questions

- A repeated, interleaved 50-versus-75 test could resolve whether the small LU
  difference is real, but its likely upside is below the phase-2 priority win.
- The result says nothing conclusive about multi-node HPL-MxP.
- A different process grid, `NB`, or matrix size changes panel count and
  message sizes and can reopen this choice as a new interaction study.

## 2. U-panel chunk size

Report: the second phase of
[`mpi-nccl-coms-sweep.md`](analysis/mpi-nccl-coms-sweep.md), with mechanism
detail in [`panel_u_chunk_effect.md`](panel_u_chunk_effect.md).

### What the flag changes

`--u-panel-chunk-nbs <int>` controls the U-panel work granularity in units of
`NB`. Smaller values expose smaller pieces earlier, which can give dependent
work more opportunities to overlap, but also create more launches,
communication events, and scheduling decisions. Larger values amortize those
overheads but can delay readiness of consumers.

This is a granularity trade-off, not a change to the mathematical LU work. All
tested values satisfy NVIDIA's documented constraint:

```text
((N / NB) / npcol) / u-panel-chunk-nbs < 20
```

For `N=491520`, `NB=3072`, and `npcol=4`, the left side is `10`, `5`, and
`2.5` for chunks 4, 8, and 16 respectively.

### Clean sweep result

| MPI percentage | Chunk | GFLOP/s | LU s | Solver s | % vs original baseline | Attempt |
|---:|---:|---:|---:|---:|---:|---|
| 50, opening control | 8 | 2.3118e+06 | 20.53 | 13.71 | +60.19% | `chunk_baseline_a` |
| 75 | 4 | 2.3259e+06 | 20.59 | 13.45 | +61.16% | `chunk4_a` |
| 75 | 8 | 2.3403e+06 | 20.46 | 13.37 | +62.16% | `chunk8_a` |
| 75 | 16 | 2.3390e+06 | 20.33 | 13.51 | +62.07% | `chunk16_a` |
| 50 | 4 | 2.3391e+06 | 20.58 | 13.26 | +62.08% | `chunk4_b` |
| 50 | 8 | 2.3430e+06 | 20.43 | 13.36 | +62.35% | `chunk8_b` |
| 50 | 16 | 2.3113e+06 | 20.62 | 13.63 | +60.15% | `chunk16_b` |
| 50, closing control | 8 | 2.3496e+06 | 20.50 | 13.20 | +62.80% | `chunk_baseline_b` |

There is no monotonic chunk trend. At 75% MPI, chunks 8 and 16 are almost
identical and chunk 4 is slightly lower. At 50%, chunk 8 is nominally best
among the adjacent candidates, but the opening-to-closing controls drift by
`+1.6%`, larger than most candidate separations.

### Why changing granularity did not change throughput

Nsight confirms that chunk 4 really changes scheduling: the dominant `nvjet`
launch count rises about 76.5% relative to the earlier chunk-8 profile. Yet
the cumulative time in that kernel changes by only about `+0.08%`.
NCCL-broadcast launches also increase, and synchronization moves between MPI,
CUDA stream, and CUDA event waits rather than disappearing.

The smaller chunks therefore create more pieces of approximately the same
total compute. They may expose theoretical concurrency, but the existing
pipeline and H200 resources do not turn it into a shorter critical path. Chunk
4 is useful as a scheduling diagnostic, not as a measured optimization.

### Personal notes

A trade-off is seen here: smaller chunks allow more compute kernel calls, however it is hindered by the added time for organization, communication, and syncronization.

### Remaining questions

- A chunk value could matter after a major change to `NB`, process grid, or
  multi-node topology; the phase-2 result closes only this configuration.
- Further fine scanning is not justified without a trace showing that U-panel
  readiness has again become the critical bottleneck.

## 3. Factorization and TRSM priority

Report: [`factorization-priority.md`](analysis/factorization-priority.md),
2026-08-31.

### What the two flags change

NVIDIA defines the controls as:

- `--prioritize-trsm 1`: GEMMs wait for U-side TRSM work;
- `--prioritize-factorization 1`: GEMMs wait for panel factorizations.

The wording is important. These flags do not request a faster arithmetic
kernel and they do not prove that more work overlaps. They add ordering so a
short dependency-producing operation can run before large, otherwise-ready
GEMMs. This can improve the pipeline when advancing the next panel shortens
the global critical path, even if some local GEMM concurrency is temporarily
sacrificed. CUDA stream scheduling is opportunistic and already-running work
is not generally preempted merely because another stream has priority
([CUDA stream guidance](https://docs.nvidia.com/cuda/cuda-programming-guide/02-basics/asynchronous-execution.html)).

Factorization priority covers the broader panel-readiness chain. TRSM priority
targets only the U-side triangular solve within that chain. The earlier trace
showed short factorization kernels accompanied by long wait tails, which is
exactly the situation where total kernel time understates critical-path
importance.

### Four-way controlled result

| Attempt | TRSM priority | Factorization priority | GFLOP/s | LU s | LU GFLOP/s | Solver s | % vs original baseline | % vs `fp_0_0` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `fp_0_0` | 0 | 0 | 2.3375e+06 | 20.38 | 3.8849e+06 | 13.49 | +61.97% | 0.00% |
| `fp_0_1` | 0 | 1 | 2.4203e+06 | 19.12 | 4.1396e+06 | 13.58 | +67.70% | +3.54% |
| `fp_1_0` | 1 | 0 | 2.3352e+06 | 20.32 | 3.8964e+06 | 13.58 | +61.81% | -0.10% |
| `fp_1_1` | 1 | 1 | 2.4121e+06 | 19.16 | 4.1316e+06 | 13.66 | +67.14% | +3.19% |

The two factorization-off rows have essentially identical LU time
(`20.38/20.32 s`), regardless of TRSM priority. The two factorization-on rows
also match (`19.12/19.16 s`). This 2x2 pattern is stronger evidence than simply
selecting the maximum: factorization priority, not TRSM priority, explains the
change.

The factorization setting saves about `1.26 s` in LU and raises LU GFLOP/s by
about `6.6%`. Solver time and the three solver residuals do not improve. The
end-to-end gain is consequently smaller, `+3.54%`, because the unchanged
solver accounts for about 13.5 seconds of the measured path. The raw control
and winning outputs show this phase split directly
([control](../experiments/factorization-priority-test/outputs/fp_0_0.o:285),
[factorization priority](../experiments/factorization-priority-test/outputs/fp_0_1.o:285)).

### Why the broad priority wins but TRSM-only does not

The most defensible inference is that readiness of the complete next panel is
on the LU critical path, whereas prioritizing only its U-TRSM portion is too
narrow or that work is already adequately hidden. The experiment does not
expose enough internal timestamps to claim which exact factorization substep
was delayed. What it does establish is the causal grouping: both runs with
factorization priority are faster, and neither run gains from TRSM priority.

Combining both flags is not additive because the broader factorization order
already encompasses the useful dependency. `fp_1_1` is `0.34%` below
`fp_0_1`, well inside a small-noise interpretation, so it should not be called
a meaningful regression; it simply provides no additional benefit.

### Confidence and remaining questions

All four combinations ran sequentially in one job on `hpc-gaas-g16`, all
passed, and the factorization effect repeats across both TRSM states. That
makes the `+3.5%` same-job result materially stronger than the communication
sweep's soft peak. However, each combination was measured only once. A
bracketed repeat of `0/0` and `0/1` would quantify temporal drift and confirm
the retained setting across another allocation.

## 4. Separate CUDA stream for GEMM

Report: [`separate-stream-for-gemm.md`](analysis/separate-stream-for-gemm.md),
2026-08-31.

### What the flag changes

A CUDA stream is an in-order work queue: operations within one stream execute
in issue order. Independent work submitted to different streams is eligible
to execute concurrently, subject to dependencies, synchronization, and
available GPU resources. Multiple streams permit overlap; they do not
guarantee it ([CUDA Programming Guide](https://docs.nvidia.com/cuda/cuda-programming-guide/02-basics/asynchronous-execution.html)).

`--use-separate-stream-for-gemm 1` puts GEMM updates on their own stream. This
lets the implementation express independence between trailing updates and
panel/TRSM/communication work where the dependency graph permits. Setting it
to 0 removes that opportunity and forces more work through shared ordering.

This flag complements factorization priority:

- separate streams create the *opportunity* for useful concurrency;
- dependency priority prevents that concurrency from starving the next
  critical panel;
- events and stream waits preserve correctness between dependent operations.

### Toggle result

| Attempt | Separate GEMM stream | GFLOP/s | LU s | LU GFLOP/s | Solver s | % vs original baseline | % vs enabled control |
|---|---:|---:|---:|---:|---:|---:|---:|
| `ss_1` | 1 | 2.4162e+06 | 19.18 | 4.1275e+06 | 13.58 | +67.42% | 0.00% |
| `ss_0` | 0 | 2.3705e+06 | 19.92 | 3.9734e+06 | 13.47 | +64.25% | -1.89% |

Disabling the stream adds `0.74 s` to LU and reduces LU GFLOP/s by `3.73%`.
Solver time changes by only `-0.11 s`, so the end-to-end `-1.89%` loss is an
LU scheduling effect. The raw outputs preserve the exact settings and phase
times ([enabled](../experiments/separate-stream-for-gemm/outputs/ss_1.o:285),
[disabled](../experiments/separate-stream-for-gemm/outputs/ss_0.o:285)).

The result does not prove that GEMM and factorization overlap for every step,
nor does it measure a stream's isolated occupancy. It shows that the
implementation performs better when allowed to schedule GEMMs separately.
Because enabled is also the package default, this experiment validates rather
than changes the retained configuration.

## 5. Host-threaded DGEMV

Report:
[`dgemv-with-multiple-threads.md`](analysis/dgemv-with-multiple-threads.md),
2026-09-01.

### What the flag does—and does not mean

`--call-dgemv-with-multiple-threads <rows>` specifies how many matrix rows each
host thread handles when HPL-MxP invokes DGEMV. Value `0` means one thread
calls DGEMV. Values 128, 256, and so on are **rows per thread**, not requested
thread counts.

DGEMV is matrix-vector work. It has much lower arithmetic intensity and less
parallel work than the matrix-matrix GEMMs dominating low-precision LU. In
this benchmark it appears in the correction/refinement path, so this flag can
change solver latency without changing LU throughput. Dividing it among host
threads may help when the call is large enough and thread resources are idle,
but it also adds partitioning, synchronization, cache/NUMA traffic, and
competition with MPI progress. The exact split is internal to the binary, so
the results show the net cost, not which overhead alone dominates.

### Sweep result

| Attempt | Rows per host thread | GFLOP/s | LU s | LU GFLOP/s | Solver s | % vs original baseline | % vs single-thread control |
|---|---:|---:|---:|---:|---:|---:|---:|
| `dgemv_0` | 0, one caller thread | 2.4252e+06 | 19.12 | 4.1394e+06 | 13.52 | +68.04% | 0.00% |
| `dgemv_128` | 128 | 2.1552e+06 | 19.15 | 4.1350e+06 | 17.59 | +49.33% | -11.13% |
| `dgemv_256` | 256 | 2.1166e+06 | 19.18 | 4.1280e+06 | 18.22 | +46.66% | -12.72% |
| `dgemv_384` | 384 | 2.1940e+06 | 19.15 | 4.1333e+06 | 16.93 | +52.02% | -9.53% |
| `dgemv_512` | 512 | 2.3435e+06 | 19.21 | 4.1210e+06 | 14.57 | +62.38% | -3.37% |
| `dgemv_640` | 640 | 2.2940e+06 | 19.17 | 4.1299e+06 | 15.34 | +58.95% | -5.41% |

LU is exceptionally stable: `19.12–19.21 s`, with LU GFLOP/s inside about
`0.45%`. Solver time is minimized by the one-thread control and increases by
`1.05–4.70 s` for every nonzero setting. The three solver iterations and their
residuals are identical in every run, followed by the same finite verification
residual and `PASSED`. The slowdown therefore comes from executing the same
numerical refinement work less efficiently, not from taking more iterations
or producing a worse preconditioner.

The non-monotonic shape also matters. If DGEMV scaled cleanly with added host
parallelism, at least one partition would beat the control or form a stable
trend. Instead, 512 rows is merely the least harmful nonzero value. The 128–384
partitions pay the largest penalty, while 640 becomes slower again after the
partial recovery at 512. This is consistent with a workload/partition and
synchronization trade-off, not a useful thread-count optimum.

The raw control and worst case make the separation especially clear:
`dgemv_0` reports `19.12 s` LU and `13.52 s` solver, while `dgemv_256` reports
`19.18 s` LU and `18.22 s` solver
([control](../experiments/dgemv-with-multiple-threads/outputs/dgemv_0.o:286),
[256 rows](../experiments/dgemv-with-multiple-threads/outputs/dgemv_256.o:286)).

## Cross-report conclusions

### What is genuinely established

1. **The panel transport is being changed, but the trade is balanced here.**
   More MPI reduces NCCL broadcast work while increasing MPI traffic and
   synchronization. The clean end-to-end effect is below same-node drift.
2. **U-panel granularity changes launch structure, not the critical-path
   duration.** Chunk 4 creates many more kernel launches without shortening
   dominant-kernel time or the clean HPL result.
3. **Whole-factorization readiness is a real LU bottleneck.** Factorization
   priority reduces LU time by about `1.26 s` and raises end-to-end GFLOP/s by
   `3.54%` against the same-job control.
4. **TRSM readiness alone is not the bottleneck resolved by this sweep.** The
   TRSM flag is neutral both with and without factorization priority.
5. **Separate GEMM scheduling is useful.** Removing the dedicated stream costs
   `0.74 s` in LU and `1.89%` end to end.
6. **Host-threaded DGEMV is counterproductive under this launch.** It leaves
   LU and convergence unchanged but adds `1.05–4.70 s` to the solver.
7. **Phase attribution is essential.** Similar-looking total-score changes
   arise from different mechanisms: communication and priority act in LU;
   DGEMV threading acts in refinement.

### What should be treated as closed for the current workload

- fine tuning `--use-mpi-panel-broadcast` without matched repetitions;
- further `--u-panel-chunk-nbs` scanning at the current N/NB/grid;
- `--prioritize-trsm 1`;
- disabling the separate GEMM stream;
- any tested nonzero `--call-dgemv-with-multiple-threads` value.

These findings are conditional on one node, eight H200 GPUs, the current
matrix/block/grid, FP16, and the established placement controls. A multi-node
run or a major N/NB/grid/precision change can alter communication and scheduling
balance and would justify fresh controls rather than blindly carrying every
negative result forward.

### The retained phase-2 configuration

Use the following as the evidence-based control for the next optimization
direction:

```text
N=491520, NB=3072, 2x4 row
OMP_NUM_THREADS=8, OMP_PLACES=sockets, OMP_PROC_BIND=TRUE
--fill-device 1
--fill-device-buffer-size 2048
--cuda-host-register-step 2048
--use-mpi-panel-broadcast 50
--u-panel-chunk-nbs 8
--prioritize-trsm 0
--prioritize-factorization 1
--use-separate-stream-for-gemm 1
--call-dgemv-with-multiple-threads 0
```

The best observed score is `2.4252e+06` GFLOP/s (`+68.04%` versus the original
baseline), but the reproducible statement is “approximately `2.42e+06`.” A
confirmation pair with factorization priority off/on remains worthwhile before
treating the `+3.5%` isolated gain as fully reproduced across allocations.

## Direction forward

The second phase largely optimized ordering around the dominant compute work;
it did not make the dominant `nvjet_sm90` arithmetic kernel itself faster.
The highest-value next questions therefore move from scheduling to the compute
and numerical path:

1. **Sloppy precision (`FP4`/`FP8` versus FP16).** This can change tensor-core
   throughput and data volume, but must be judged by LU time, refinement time,
   iteration count, finite residual, and `PASSED` verification together.
2. **Supported H200 GEMM-kernel selection.** The trace already shows an SM90
   `nvjet` kernel. Test only presets explicitly supported by the installed
   v26.02 package; a preset number should not be inferred solely from the GPU
   architecture.
3. **Conditional `--Anq-device` residency.** Test only with `--fill-device 0`,
   because fill-device overrides it. Any solver improvement must exceed the
   LU/end-to-end cost and preserve safe VRAM headroom.

For each direction, preserve the original-baseline percentage column, add
bracketing controls or repeated loops, record LU and solver times separately,
and do not rank an invalid or non-finite run by GFLOP/s.

## Provenance

- Original baseline and structured results:
  [`results/metrics.csv`](../results/metrics.csv)
- Validated summary: [`results/RESULTS.md`](../results/RESULTS.md)
- Communication and chunk analysis:
  [`analysis/mpi-nccl-coms-sweep.md`](analysis/mpi-nccl-coms-sweep.md)
- MPI/NCCL trace interpretation:
  [`mpi_panel_broadcast_effect.md`](mpi_panel_broadcast_effect.md)
- U-panel trace interpretation:
  [`panel_u_chunk_effect.md`](panel_u_chunk_effect.md)
- Factorization/TRSM analysis:
  [`analysis/factorization-priority.md`](analysis/factorization-priority.md)
- Separate-stream analysis:
  [`analysis/separate-stream-for-gemm.md`](analysis/separate-stream-for-gemm.md)
- DGEMV-threading analysis:
  [`analysis/dgemv-with-multiple-threads.md`](analysis/dgemv-with-multiple-threads.md)
- Flag definitions: [NVIDIA HPL-MxP documentation](https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html)
- CUDA stream semantics: [CUDA Programming Guide](https://docs.nvidia.com/cuda/cuda-programming-guide/02-basics/asynchronous-execution.html)
- Raw outputs are linked beside the relevant phase-level claims above.
