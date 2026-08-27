# Optimization Plan 1: Compute and Scheduling Controls

## Objective and scope

This plan uses the Nsight Systems SQLite exports from the best-configuration
profile to choose the next HPL-MxP experiments. The primary scope is limited to
the controls described in Section 6, **Compute and scheduling controls**, of
[`HPL_MxP_TuningParam_Guide.md`](../HPL_MxP_TuningParam_Guide.md):

```text
--preset-gemm-kernel
--u-panel-chunk-nbs
--call-dgemv-with-multiple-threads
--prioritize-trsm
--prioritize-factorization
--use-separate-stream-for-gemm
--use-mpi-panel-broadcast
--mpi-use-mpi
--use-host-mpi
```

The purpose is not to retune `N`, `NB`, the process grid, affinity, precision,
or memory placement in this round. Those are held fixed so that a change can
be attributed to a compute, dependency, stream, or communication policy.
Ideas outside this boundary are collected at the end in a separate section.

The intended output is an experiment handoff: another agent should be able to
stage the runs from the fixed baseline, one-variable sweeps, acceptance rules,
and result-recording requirements below.

## Evidence sources and limitations

The trace files were exported on GAAS from:

```text
/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test/
  experiments/nsight-systems/outputs/nsys-sqlite/
```

There are eight SQLite databases, one per MPI rank. They contain
`CUPTI_ACTIVITY_KIND_KERNEL`, CUDA runtime and synchronization events, memory
copies, MPI collectives and point-to-point events, NVTX annotations, and CPU
scheduling events. The profile's stdout is available locally at
[`hpl_stdout.log`](../experiments/nsight-systems/outputs/nsys-trace/hpl_stdout.log).

Important interpretation rules:

1. The SQLite values are event data, not an automatically aggregated HPL
   performance report. Durations summed across eight ranks are **cumulative
   rank time**, not wall time.
2. The rank traces should not be aligned by absolute timestamp without an
   explicit clock-synchronization check. The analysis therefore uses each
   rank's own main-phase duration and compares rank-level distributions.
3. The Nsight profile reports `1.9668e+06` GFLOP/s, while the clean best runs
   reached about `2.3920e+06` GFLOP/s. Profiling changes execution, so the
   profile is used to identify mechanisms, not as the clean score baseline.
4. The trace includes a long setup/matrix-generation region. It must not be
   mistaken for the timed LU-plus-refinement score.

## Current control to preserve

The profile stdout records this effective configuration:

| Control | Current value |
|---|---|
| `N`, `NB` | `491520`, `3072` |
| Process grid | `2x4`, row order |
| GPU affinity | `0:1:2:3:4:5:6:7` |
| OpenMP | `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE` |
| `--preset-gemm-kernel` | `90` |
| `--u-panel-chunk-nbs` | `8` |
| `--call-dgemv-with-multiple-threads` | `0` |
| `--prioritize-trsm` | `0` |
| `--prioritize-factorization` | `0` |
| `--use-separate-stream-for-gemm` | `1` |
| `--use-mpi-panel-broadcast` | `50` |
| `--mpi-use-mpi` | `0` |
| `--use-host-mpi` | `0` |
| Precision/residency held fixed | `FP16`, `--fill-device 1`, buffer `2048`, host-register step `2048` |

The profile output is the authoritative record for this run: in particular,
it reports preset `90`, even though the guide's explanatory text describes
the older/default-looking `0` and `80` choices. The staging agent must query
`/workspace/hpl-mxp.sh --help` inside the exact v26.02 container and record the
supported preset values before changing this flag. Do not assume that `80`
is valid or appropriate for an H200/SM90 GPU.

The clean comparison point should be the established M1 control near
`2.3920e+06` GFLOP/s, approximately `+65.74%` relative to the original
`1.4432e+06` baseline. Use the clean control for performance decisions; use
the Nsight profile for bottleneck evidence.

## 1. What the SQLite traces show

### 1.1 Timed HPL work is separate from setup

The profile stdout reports:

```text
matgen seconds: AVG = 158.81
GFLOPS = 1.9668e+06
LU GFLOPS = 3.8133e+06
... PASSED
```

The per-rank trace has a local main HPL window of approximately `44.0–44.5 s`
from the first sustained `MPI_Wait` activity through the final reduction. This
is consistent with the reported HPL score. Matrix generation and residency
preparation happen before this window and dominate elapsed setup time, but
they are not the objective reported by HPL-MxP.

This distinction matters for this plan. A large `cudaHostRegister` total is
not automatically a reason to change a compute/scheduling flag, because the
registration activity is outside the timed HPL phase and is controlled by a
memory/staging flag that is out of scope here.

### 1.2 The dominant GPU compute path is an SM90 `nvjet` kernel

Across all eight rank databases, the main kernel categories were:

| Kernel category | Calls | Cumulative kernel time | Interpretation |
|---|---:|---:|---|
| Main `nvjet_sm90_hss_192x192_64x3_2x1_v_badd_coopB_NNN` | 3,981 | `118.45 s` | Dominant low-precision compute path |
| All `nvjet` kernels | 5,285 | `118.79 s` | Main HPL-MxP compute family |
| NCCL broadcast kernels | 12,244 | `27.15 s` | GPU-side collective/broadcast work |
| cuBLAS `sm90_xmma_gemm...` kernels | 3,787 | `5.00 s` | Additional GEMM path |
| DGEMV/GEMV kernels | 2,257 | `0.85 s` | Small auxiliary/vector path |
| TRSM kernels | 9,600 | `0.30 s` | Small raw execution time, potentially critical dependency |
| Factorization `getrf` kernels | 160 | `0.25 s` | Small raw execution time, potentially critical dependency |

The largest `nvjet` kernel contributes roughly `14.6–15.3 s` of device kernel
time per rank. The timed HPL window is about `44 s`, so this is a substantial
compute phase, but it does not occupy the GPU for the entire wall interval.
The union of recorded kernel intervals is approximately `16.7–17.4 s` per
rank, or only about `38–39%` of the local main-phase window. This is not a
direct SM-utilization measurement, but it does show that the remaining time is
not simply one continuously running GEMM. Dependency waits, communication,
host-side synchronization, and gaps between launches are all plausible
targets.

**Implication for the scoped flags:**

- `--preset-gemm-kernel` is the only direct compute-kernel selector in scope.
  The trace proves that the current path is already SM90-specific; it does not
  prove that another preset is available or faster on H200.
- The large non-kernel portion makes scheduling and communication controls
  credible next targets rather than assuming that only GEMM arithmetic needs
  tuning.
- The small raw TRSM/getrf times do not close the priority flags. A short
  operation can still delay a long dependent GEMM pipeline if it is on the
  critical path.

### 1.3 Panel communication and waits are substantial

The trace contains both MPI point-to-point activity and NCCL activity while the
current panel-broadcast policy is `50`:

| Evidence | Per-rank observation | Why it matters |
|---|---:|---|
| `MPI_Wait` calls | `42,780–43,430` | Very frequent dependency/completion waits |
| `MPI_Wait` cumulative duration | `7.16–13.20 s` | Large host-visible wait budget; not all ranks behave alike |
| `MPI_Wait` events over 100 ms | `24–52` per rank | A small number of long waits dominate part of the total |
| Longest `MPI_Wait` | up to `656 ms` | Indicates bursty readiness/arrival delays |
| `ncclBroadcast` NVTX calls | about `1,525–1,535` | Repeated collective path |
| NCCL broadcast kernel time | `1.87–4.94 s` per rank | Collective work occupies GPU time |
| MPI point-to-point payload | `0.755–1.510 GB` per rank in main phase | Communication is not only control traffic |

The MPI nonblocking calls themselves are short, but their completion is not.
Across the rank files, the trace contains about `172,600` `MPI_Isend` and
`172,600` `MPI_Irecv` records in the captured workload. This pattern is
consistent with a pipeline that posts communication quickly and later waits
for readiness or completion.

The strongest in-scope hypothesis is therefore not “MPI is bad” or “NCCL is
bad.” It is that the current `50` policy may not match this H200/NVSwitch
topology and this process-grid schedule. The direct experiment is
`--use-mpi-panel-broadcast`, holding all other controls fixed.

*Note: NCCL is designed for high-throughput communications while MPI can better support smaller and more latency sensitive communcation. And why they allow to mix is because as the factorization is because there are some drawbacks for NCCL: (1) If the communication is small, the latency due to set up >> communication, and also NCCL takes up GPU resource to organize. Also recall that as GEMM goes on, the matrix gets smaller, meaning that the comms gets smaller (meaning MPI is more and more prefereable)*

*Note: Furthermore, from the data, it shows that the comms are a lot of small and short burst with high latency (delay due to syncing), there for MPI may be more prefereable. We should sweep this.*

### 1.4 Rank asymmetry indicates arrival skew, not just average bandwidth

Four ranks (`0`, `2`, `5`, and `7`) show roughly `12.7–13.2 s` of cumulative
main-phase `MPI_Wait` time, while ranks `1`, `3`, `4`, and `6` show roughly
`7.0–7.9 s`. The exact rank-to-topology cause is not proven by separate
SQLite files, but the asymmetry is important: a mean communication time would
hide the ranks that arrive late and hold up dependent work.

There is also a conspicuous small-control collective event. On ranks `4–7`,
one `MPI_Allreduce` with message size `16` takes about `4.56 s`, followed by
roughly `165–365 ms` events; corresponding allreduces on other ranks are
mostly sub-millisecond. This looks like arrival skew in a small synchronization
collective rather than a bandwidth limit. It may be in iterative refinement or
another control path, so it is not automatically controlled by panel-broadcast
policy. It should be treated as a diagnostic clue for scheduling/arrival
experiments, not as proof that a particular flag will fix it.

### 1.5 Two CUDA streams are active, but overlap is uneven

The profile uses `--use-separate-stream-for-gemm=1` and records two active CUDA
streams per rank. Stream `19` carries the long-running main compute kernels;
stream `18` carries many auxiliary kernels and the collective path. The
recorded stream overlap between streams `18` and `19` is approximately:

| Rank group | Stream 18/19 overlap |
|---|---:|
| Ranks `0`, `2`, `5`, `7` | `0.82–0.93 s` |
| Ranks `1`, `3`, `4`, `6` | `3.59–3.71 s` |

This proves that the separate-stream mechanism is active and sometimes allows
concurrency. It also shows that the amount of overlap is rank-dependent. The
profile cannot determine whether the overlap reduces total wall time without
a matched `0` comparison, because overlap can help one dependency while
increasing synchronization or contention elsewhere.

The corresponding host-side evidence is strong: `cudaStreamSynchronize`
accounts for approximately `5.5–9.1 s` per rank in the local main window,
with `11–19` calls over `100 ms` per rank. These durations are not additive to
MPI waits—the events can nest or overlap—but they justify testing the stream
policy and priority flags together in a controlled sequence.

*Note: This rank assymetry is worth exploring to improve algorithm (point 1.4 and point 1.5)*

### 1.6 DGEMV is visible but not a first-order target

The main-phase DGEMV/GEMV kernel time is only about `0.10–0.12 s` per rank,
compared with about `44 s` of HPL wall time. The current
`--call-dgemv-with-multiple-threads=0` setting therefore has weak evidence as
a high-gain first experiment.

The guide's parameter is also easy to misread: its nonzero value describes
the rows handled per host thread; it is not simply “the number of threads.” A
smaller rows-per-thread value can imply more host-thread parallelism and can
steal CPU time from MPI progress or other host work. Test this only after the
higher-value scheduling/communication sweeps, or if CPU-side DGEMV overhead is
isolated by a later trace.

### 1.7 Large registration time is setup evidence, not this round's target

Across the rank files, `cudaHostRegister` appears `928` times with about
`1010.5 s` cumulative duration, and `cudaHostUnregister` contributes about
`136.2 s` cumulative duration. These large totals are spread across ranks and
are primarily associated with the setup/matrix-generation region; the
main-phase overlap of host registration is effectively zero.

Likewise, the profile stdout reports `158.81 s` for matrix generation. The
main-phase asynchronous copy activity is tiny (`about 0.001–0.006 s` per
rank), so the trace does not support making host-MPI a performance target for
the timed score. These observations are retained as context, but host
registration and FP64 residency are outside this optimization plan.

## 2. What M1 changes about the interpretation

[`planning/consolidate_m1.md`](consolidate_m1.md) establishes the following
constraints for this round:

1. `N=491520` is already at a safe large operating point. The fine N sweep
   stayed within a roughly 1% noise band, so another N search is not justified
   unless a new control changes the memory or phase balance.
2. `NB=3072` reduced LU time from about `26.61 s` at `NB=1024` to `20.22 s`
   at `N=490000`, while the iterative solver remained almost unchanged. The
   next plan should not interpret every LU change as a solver improvement.
3. `2x4` row is the best measured grid, but its approximately 1.8% spread over
   nearby layouts is small. Keep it fixed while testing compute/scheduling
   flags.
4. Explicit narrow HPL CPU/memory affinity damaged the run; broad default
   placement plus `OMP_NUM_THREADS=8`, socket placement, and binding was the
   safer host policy. Do not combine a new flag sweep with an affinity change.
5. Fill-device and buffer tuning produced only a modest safe gain. The current
   fill/buffer configuration must stay fixed so that a scheduler result is not
   confused with a residency result.
6. Lowering N reduced solver time but also reduced LU efficiency, leaving the
   end-to-end rate flat. This is direct evidence that phase-level gains must be
   judged by complete HPL time and GFLOP/s.

The M1 phase evidence points at the same question as the trace: can the
critical path be shortened by changing dependency priority, panel granularity,
stream overlap, or the MPI/NCCL panel policy while preserving the large-N LU
rate and successful refinement?

## 3. In-scope controls: hypotheses and expected evidence

| Control | Current | Trace/M1 signal | Hypothesis | Priority |
|---|---:|---|---|---:|
| `--use-mpi-panel-broadcast` | `50` | Long MPI waits plus substantial NCCL kernels | A different MPI/NCCL mix reduces panel wait or GPU collective interference | 1 |
| `--u-panel-chunk-nbs` | `8` | Many waits and a sparse kernel timeline | Chunk granularity is delaying readiness or adding scheduler overhead | 2 |
| `--prioritize-factorization` | `0` | Panel/getrf kernels are short but critical-path dependent | Advancing the whole panel process may reduce downstream stalls | 3 |
| `--prioritize-trsm` | `0` | TRSM kernels are short but repeated; wait tails are long | Advancing U-side TRSM may make GEMM dependencies ready sooner | 3 |
| `--use-separate-stream-for-gemm` | `1` | Two streams overlap unevenly; stream sync is costly | Disabling or preserving the separate stream changes useful overlap versus synchronization | 4 |
| `--preset-gemm-kernel` | `90` in profile | `nvjet_sm90` dominates compute | A supported H200-specific preset/path may improve the dominant compute family | 5, gated |
| `--call-dgemv-with-multiple-threads` | `0` | DGEMV kernel time is only ~0.1 s/rank | More host parallelism is unlikely to be a first-order gain; test only if host overhead is found | 6 |
| `--mpi-use-mpi` | `0` | Normal MPI Bcast is tiny; panel path is mixed | Fallback MPI may diagnose a collective path issue, but is not a primary optimization hypothesis | Diagnostic |
| `--use-host-mpi` | `0` | Main-phase device copies are tiny; GPU-aware path is active | Host MPI likely adds staging; use only as a transport diagnostic or regression control | Diagnostic |

The priority is based on evidence and expected opportunity, not a claim that
the gain has already been measured.

## 4. Experiment sequence for the staging agent

### Stage 0 — establish a clean control

Run the current control without Nsight Systems to obtain a comparable score.
Use at least three repetitions if the queue budget permits, preferably
interleaved with candidate runs on the same node class. Record the median and
spread. The exact command must explicitly include every in-scope current value
so that a package default cannot silently change the experiment:

```text
--n 491520
--nb 3072
--nprow 2
--npcol 4
--nporder row
--gpu-affinity 0:1:2:3:4:5:6:7
--preset-gemm-kernel 90
--u-panel-chunk-nbs 8
--call-dgemv-with-multiple-threads 0
--prioritize-trsm 0
--prioritize-factorization 0
--use-separate-stream-for-gemm 1
--use-mpi-panel-broadcast 50
--mpi-use-mpi 0
--use-host-mpi 0
```

Keep the established OpenMP, FP16, fill-device, buffer, and host-registration
settings unchanged. Use `--skip-tests 1` for the optimization runs and include
the project-required monitoring parameters:

```text
--monitor-gpu 1
--monitor-gpu-interval 10
--monitor-gpu-pcie-width-warning 16
--monitor-gpu-pcie-gen-warning 5
```

Monitoring is for diagnosing clocks, power, temperature, and PCIe anomalies;
it is not itself an optimization variable. The final clean score should use
the same measurement procedure for every configuration.

### Stage 1 — sweep the MPI/NCCL panel policy

Test one variable with:

```text
--use-mpi-panel-broadcast 0
--use-mpi-panel-broadcast 25
--use-mpi-panel-broadcast 50
--use-mpi-panel-broadcast 75
--use-mpi-panel-broadcast 100
```

The guide explains that `0` selects NCCL and positive values select an MPI
percentage policy. Keep `50` as the existing control. The purpose is to learn
whether the observed `MPI_Wait`/NCCL balance is appropriate for this node, not
to assume that all-NCCL or all-MPI is universally best.

For each run, record:

- end-to-end GFLOP/s and LU GFLOP/s;
- LU time, iterative-solver time, and refinement iteration count if printed;
- `PASSED`, finite residual, and residual value;
- GPU headroom and monitoring warnings;
- whether the preferred process-grid behavior changes;
- if a candidate wins, a follow-up Nsight trace of only the best policy and
  the `50` control.

**Decision rule:** retain a policy only if it improves clean end-to-end
GFLOP/s over the matched control with repeatable evidence. A reduction in
NCCL kernel time alone is insufficient if MPI waits or LU time increase.

### Stage 2 — sweep U-panel chunk granularity

Test:

```text
--u-panel-chunk-nbs 4
--u-panel-chunk-nbs 8
--u-panel-chunk-nbs 16
```

The current release constraint from the guide is:

```text
((N / NB) / npcol) / u-panel-chunk-nbs < 20
```

At `N=491520`, `NB=3072`, `npcol=4`, the numerator before division by the
chunk is `40`; the current chunk `8` gives `5`, chunk `4` gives `10`, and
chunk `16` gives `2.5`. All three are inside the stated constraint.

The expected trade-off is:

- `4`: finer readiness and potentially more overlap, at the cost of more
  scheduling/communication bookkeeping;
- `8`: current reference;
- `16`: coarser bulk work and less scheduling overhead, at the risk of delaying
  consumers that need only part of the U panel.

This is a high-value follow-up to Stage 1 because the trace shows both long
wait tails and non-continuous kernel activity. Do not call a winner from a
single run.

### Stage 3 — test dependency priorities

Use the current communication policy and stream setting, then test the
factorization/TRSM priority controls in isolation and combination:

| Run | `--prioritize-trsm` | `--prioritize-factorization` |
|---|---:|---:|
| Control | `0` | `0` |
| TRSM only | `1` | `0` |
| Factorization only | `0` | `1` |
| Both | `1` | `1` |

The guide distinguishes these controls: TRSM priority changes the relationship
between U-side triangular solves and GEMMs, while factorization priority gives
the whole panel-factorization process priority. Test factorization-only first
if queue budget is limited, because the trace's central problem is readiness
of the panel pipeline rather than raw TRSM arithmetic throughput.

Measure both phases. A successful candidate should reduce the long HPL wall
time or improve total GFLOP/s; a candidate that raises LU GFLOP/s but increases
iterative refinement time is not an end-to-end win.

### Stage 4 — test the separate GEMM stream

Compare:

```text
--use-separate-stream-for-gemm 0
--use-separate-stream-for-gemm 1
```

The current `1` setting is not merely a nominal flag: two streams are visible,
and their overlap ranges from about `0.8 s` to `3.7 s` per rank. The `0`
experiment is therefore a meaningful control for whether that concurrency is
helping or whether it is generating synchronization overhead.

Use clean runs for the score. If the result is ambiguous, profile only the
matched `0` and `1` cases and compare:

- union of kernel activity;
- stream-to-stream overlap;
- `cudaStreamSynchronize` duration and long-call count;
- MPI wait tails;
- total HPL phase time.

Do not choose based on more streams or higher individual GEMM activity alone.

### Stage 5 — investigate the GEMM preset, only after validating support

The dominant compute kernel is already `nvjet_sm90...`, and the profile
stdout reports preset `90`. This is strong evidence that the run is using an
H200/SM90-aware path. It is not evidence that preset `80` should be tried.

Before staging any preset sweep:

1. Run the exact v26.02 container's launcher help and inspect its package
   `README`, `RUNNING`, or `TUNING` documentation.
2. Enumerate values accepted for H200/SM90. Preserve explicit `90` as the
   reference because that is what the profile actually used.
3. If the package documents an alternative H200-compatible value, compare it
   with explicit `90`; if not, close this flag for the current release.
4. If `0` is accepted, treat it as a separate “no preset” path, not as an
   assumed equivalent to preset `90`.

Keep FP16 fixed while testing this flag. Record the dominant kernel names and
durations in any follow-up profile, but accept only a clean end-to-end gain
with `PASSED` verification.

### Stage 6 — conditional DGEMV and MPI fallback diagnostics

These are lower-priority controls because the trace does not show a large
first-order opportunity.

For DGEMV, consult the exact package help for valid values, then test the
default `0` against one or two documented nonzero values only if CPU-side
DGEMV time or host scheduling shows a real cost. Do not describe the parameter
as a thread count; use the guide's rows-per-thread meaning.

For transport diagnostics:

- `--mpi-use-mpi 1` can be tested against `0` if Stage 1 exposes a collective
  path problem or if a controlled MPI fallback is needed;
- `--use-host-mpi` should be a last diagnostic/regression control, not a gain
  hypothesis, because the main phase already uses very little explicit
  device-host copy time and host MPI can add staging.

Do not combine these fallback controls with the main Stage 1–4 sweep. Their
purpose is to explain a transport issue, not to create an uncontrolled set of
confounded runs.

## 5. Required result table and acceptance criteria

The staging/analysis agent should maintain a table with at least:

| Run | Changed flag(s) | GFLOP/s | % vs original baseline | % vs clean current control | LU time | Solver time | Iterations | Residual | PASSED | Node |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| Clean control | none | `2.3920e+06` reference | `+65.74%` | `0.00%` | record | record | record | record | yes | record |

Use the original project baseline `1.4432e+06` GFLOP/s for the required
percentage column:

```text
percent_vs_original = 100 * (candidate_gflops / 1.4432e6 - 1)
```

Use the clean current control—not the profiled `1.9668e+06` score—for the
candidate comparison:

```text
percent_vs_clean_control = 100 * (candidate_gflops / clean_control_gflops - 1)
```

A run is acceptable only when all of the following hold:

- final verification is `PASSED`;
- residuals are finite and within the fixed tolerance;
- no OOM, allocation failure, or convergence stall occurs;
- the exact container, executable, CUDA/MPI environment, and launch shape are
  recorded;
- the clean end-to-end score improves repeatably, not just a phase metric;
- LU and iterative-solver times explain the direction of the change;
- GPU monitoring does not reveal a confounding clock, thermal, power, or PCIe
  event;
- the result is compared against a matched node/control where possible.

If a candidate is faster but changes refinement iterations, residual behavior,
or correctness, classify it as an invalid performance result until the cause
is understood.

## 6. Recommended decision tree

```text
Clean control
    |
    v
MPI/NCCL panel policy (0/25/50/75/100)
    |
    v
U-panel chunk (4/8/16)
    |
    v
Factorization/TRSM priority (00/10/01/11)
    |
    v
Separate GEMM stream (0/1)
    |
    v
Supported H200 GEMM preset (gated)
    |
    v
Conditional DGEMV or transport diagnostics
```

At each stage, carry forward only the best validated configuration and retain
the original clean control as a reference. After the one-variable stages, a
small confirmation matrix may combine the two strongest independently
validated controls. Do not immediately test every cross-product: with five
communication values, three chunk values, four priority combinations, and two
stream choices, a full factorial would obscure causality and consume the
allocation budget.

## 7. Out-of-scope ideas to consider later

The following may be valuable, but they are deliberately **not** part of the
compute/scheduling experiment set above:

- `--sloppy-type` FP8 or FP4: potentially the largest compute-throughput
  opportunity, but it changes numerical behavior and must be validated by
  refinement convergence.
- `--Anq-device`, `--fill-device`, and `--fill-device-buffer-size`: FP64
  residency and VRAM-buffer controls. M1 already found a safe fill-on region
  around 1024–2048 MB and correctness failure below it.
- `--cuda-host-register-step`: host-pinning/staging control. The trace shows
  large setup registration time, but that activity is outside the timed HPL
  phase and should be analyzed separately.
- `N`, `NB`, `nprow`, `npcol`, and `nporder`: problem/block/grid controls.
  M1 found `N=491520`, `NB=3072`, and `2x4` row to be strong fixed choices;
  further sweeps should wait for evidence that a compute/scheduling change
  moves the balance.
- `--gpu-affinity`, `--cpu-affinity`, and `--mem-affinity`: placement controls.
  M1 found narrow explicit CPU/memory affinity harmful and socket-level
  OpenMP placement useful; mixing placement changes into this plan would
  confound attribution.
- `--ucx-affinity`, `--ucx-tls`, and multi-node transport settings: relevant
  for a multi-node study, not the current single-node NVSwitch experiment.

These ideas remain visible so that a later plan can pick them up, but they
must not be added to the present experiment scripts unless the scope is
explicitly changed.

## Provenance

- Tuning definitions: [`HPL_MxP_TuningParam_Guide.md`](../HPL_MxP_TuningParam_Guide.md)
- Prior-run synthesis: [`consolidate_m1.md`](consolidate_m1.md)
- Profile stdout: [`hpl_stdout.log`](../experiments/nsight-systems/outputs/nsys-trace/hpl_stdout.log)
- Raw SQLite directory on GAAS:
  `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test/experiments/nsight-systems/outputs/nsys-sqlite/`
- Nsight Systems profile directory on GAAS:
  `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test/experiments/nsight-systems/outputs/nsys-trace/`
