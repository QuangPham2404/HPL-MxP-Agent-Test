# Consolidation M1: Interpreting the HPL-MxP Optimization Results

## Purpose and evidence boundary

This document is the expanded interpretation of the nine most recent analysis
reports listed in [`planning/PLANS.md`](PLANS.md). Its purpose is to explain
why the measurements changed, what the raw artifacts actually demonstrate,
and which conclusions remain hypotheses.

The numeric source of truth is [`results/metrics.csv`](../results/metrics.csv);
the validated-result summary is [`results/RESULTS.md`](../results/RESULTS.md).
The original project baseline is `baseline-sweep_v1`:

- `N=370000`, `NB=1024`, `2x4` row grid;
- 8 MPI ranks, one rank per H200 GPU;
- 1.4432e+06 reported GFLOP/s;
- finite residual and `PASSED` verification.

Unless stated otherwise, percentages in this document are relative to that
original baseline. A reported GFLOP/s value is the HPL-MxP end-to-end metric,
not GEMM-only throughput. The raw outputs also report `LU GFLOPS`, explicitly
described as performance excluding the iterative-solver portion. Those two
numbers must not be confused.

The experiments used an NVIDIA HPL-MxP v26.02 container on one GAAS node with
eight NVIDIA H200 GPUs. The hardware probe found two NUMA sockets, 56 physical
cores per socket, approximately 2 TB host memory, approximately 143 GB VRAM
per GPU, and NV18 GPU-to-GPU paths through an NVIDIA NVSwitch. GPUs 0–3 are
local to NUMA node 0 and GPUs 4–7 to NUMA node 1
([probe report](../scripts/probing_report.md)).

## The overall causal story

The gains are cumulative, but they improve different parts of the execution:

| Stage | Configuration change | Result | % vs original baseline | Main phase affected |
|---|---|---:|---:|---|
| Baseline | `N=370000`, `NB=1024`, `2x4` row | 1.4432e+06 | 0.00% | Reference |
| N sweep | Increase `N` to 490000 | 1.8293e+06 | +26.75% | Better amortization and LU efficiency |
| NB sweep | `NB=3072`, `N=490000` | 2.1726e+06 | +50.54% | LU/panel efficiency |
| Grid sweep | `2x4` row at `N=491520`, `NB=3072` | 2.2067e+06 | +52.90% | Grid-dependent communication/panel balance |
| OpenMP sweep | 8 threads, socket placement/binding | 2.3204e+06 | +60.79% | Host pipeline and iterative solver |
| Matrix placement | Fill device, buffer 1024–2048 MB | 2.3902–2.3920e+06 | +65.62–65.74% | Host/device staging and solver |
| Candidate only | Register step 1536 | 2.3974e+06 | +66.12% | Not separable from node noise |

The current evidence-based control is approximately:

```text
N=491520, NB=3072, 2x4 row
no explicit HPL CPU or memory affinity
OMP_NUM_THREADS=8
OMP_PLACES=sockets
OMP_PROC_BIND=TRUE
--fill-device 1
--fill-device-buffer-size 1024 or 2048
--cuda-host-register-step 2048 (default)
```

The 2.3974e+06 register-step result is a candidate, not a confirmed new
baseline. It was a single cross-node result, and all register-step values were
within the observed node variation.

## 1. N sweep — why increasing N helped

Report: [`n-sweep-370k-510k.md`](analysis/n-sweep-370k-510k.md), 2026-08-21.

### Interpretation

The basic intuition is correct, but the most precise explanation is not simply
“GEMM is O(N^3), therefore larger N is faster.” At fixed hardware:

- the algorithmic work grows approximately as (O(N^3));
- matrix storage and memory pressure grow approximately as (O(N^2));
- larger matrices improve arithmetic intensity and make GPU updates larger;
- fixed costs—startup, panel handling, synchronization, and communication—are
  amortized over more useful work.

The measured GFLOP/s therefore rises because the *rate* improves, even though
the total amount of work and runtime also increase.

The raw artifacts illustrate this. At `N=490000`, the baseline `NB=1024`
configuration took about 26.33 s in LU and 16.55 s in the iterative solver,
for approximately 42.88 s of benchmark phase time, and reported
1.8293e+06 GFLOP/s ([raw output](../experiments/N-sweep/outputs/N-sweep_490000.o:281)).
At `N=370000`, the corresponding phase times were 13.04 s and 9.86 s, about
22.90 s total, with 1.4747e+06 GFLOP/s
([raw output](../experiments/N-sweep/outputs/N-sweep_370000.o:272)). The larger
problem does more work, but its useful work grows faster than its overhead.

### What the wall means

`N=500000` still passed at 1.8152e+06 GFLOP/s, while `N=510000` was OOM-killed.
The `N=510000` output recorded approximately 243.234 GB maximum host memory
per process and 128.197 GB maximum device memory per process before the final
failure ([raw output](../experiments/N-sweep/outputs/N-sweep_510000.o:110)).
This is a hard resource boundary, not evidence of a smooth compute optimum.

The two apparent dips at `N=390000` and `N=450000` were caused by
`hpc-gaas-g13` having unusually low free host memory. Their re-runs recovered
the expected trend. This is why a single low GFLOP/s value cannot automatically
be interpreted as an N-dependent regression.

### Remaining questions

- How does the memory wall move when NB, fill-device, and scheduling settings
  change? The later `NB=3072` sweep moved the observed OOM boundary to about
  `N=506880`.
- Can a scheduling or residency change improve the work rate at the same
  `N=491520`, without trying to push N further?
- How much of the N gain comes from larger GEMM efficiency versus improved
  amortization of panel and communication overhead? The current outputs expose
  LU and solver phases but not a complete communication-only timer.

## 2. NB sweep — what NB actually changes

Report: [`nb-sweep.md`](analysis/nb-sweep.md), 2026-08-24.

### Correction to the initial interpretation

The trade-off is directionally right, but “higher NB means more computation” is
not the best explanation. At fixed N, increasing NB does not fundamentally
increase the leading-order LU work. `NB` is the blocking constant/panel size;
it changes the organization of the work.

Increasing NB generally gives:

- fewer panel steps;
- larger trailing-matrix GEMM updates;
- better use of high-throughput GEMM kernels;
- fewer synchronization or communication startups around panels.

But it also gives:

- larger panels and more workspace;
- potentially less parallelism in panel factorization and triangular solves;
- greater device-memory pressure;
- less favorable behavior when the panel becomes too large.

Thus the real trade-off is between panel overhead, GEMM efficiency,
communication/synchronization frequency, parallelism, and memory—not simply
between “more versus less computation.” NVIDIA documents `NB` as the blocking
constant or panel size in the HPL-MxP launcher
([NVIDIA documentation](https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html)).

### Raw artifact showing the mechanism

At fixed `N=490000`, the raw phase measurements were:

| NB | LU time | Iterative solver time | Approx. phase sum | GFLOP/s | Device headroom |
|---:|---:|---:|---:|---:|---:|
| 1024 | 26.61 s | 16.05 s | 42.66 s | 1.8387e+06 | 19.868 GB |
| 3072 | 20.22 s | 15.88 s | 36.10 s | 2.1726e+06 | 14.423 GB |
| 6144 | 21.03 s | 15.80 s | 36.83 s | 2.1303e+06 | 6.478 GB |
| 8192 | 23.87 s | 15.77 s | 39.64 s | 1.9785e+06 | 1.103 GB |

The `NB=1024` and `NB=3072` values are directly visible in the raw outputs
([1024](../experiments/nb-sweep/outputs/nb-sweep_1024_490k.o:282),
[3072](../experiments/nb-sweep/outputs/nb-sweep_3072_490k.o:273)). The key
observation is that the solver is almost unchanged while LU falls by about
6.4 s. That is why NB=3072 wins.

At `NB=8192`, the solver remains about 15.8 s, but LU rises to 23.87 s while
device headroom shrinks to about 1.1 GB
([raw output](../experiments/nb-sweep/outputs/nb-sweep_8192_490k.o:228)). The
decline is therefore consistent with oversized panels, reduced efficiency,
and memory pressure.

### What is established and what is not

`NB=3072` is the best measured point, but it is not a mathematically unique
optimum. `NB=3072`–`6144` form a broad plateau, and the experiment did not
resolve every value inside that interval. The gain from moving from 1024 to
3072 is real; the difference between 3072 and nearby plateau values may not be.

### Remaining questions

- Does the broad NB plateau change after all final controls are enabled?
- Would a finer scan around 3072–4096 produce a repeatable gain larger than
  node noise?
- Can scheduling settings recover the LU efficiency lost at large NB without
  consuming the remaining VRAM?

## 3. N-NB resweep — exact alignment is not the reason N=491520 works

Report: [`N-NB-resweep.md`](analysis/N-NB-resweep.md), 2026-08-24.

### Interpretation

The experiment tested whether making `N % NB == 0` would eliminate remainder
work or improve panel regularity. It did not. Passing aligned points scattered
between 2.1520e+06 and 2.1974e+06 GFLOP/s, with no monotonic trend. The best
aligned point, `N=491520`, reached 2.1974e+06 (**+52.26%**), only 1.14% above
the unaligned `N=490000`, `NB=3072` result.

The practical meaning is that `N=491520` is a good large, feasible operating
point, not that divisibility itself gives a gain.

The memory wall was also measured: `N=503808` passed, while `N=506880` and
`N=509952` were OOM-killed during matrix generation. Increasing NB slightly
reduces the maximum feasible N because the blocked implementation needs more
workspace.

### Remaining questions

- Would alignment matter after changing the scheduler or residency behavior?
  It is not justified to search alignment first; memory headroom and measured
  end-to-end performance should remain the criteria.
- Can a scheduling change reduce workspace or improve the near-wall operating
  point? That would be a new hypothesis, not an alignment result.

## 4. Process-grid sweep — what the 2x4 row result really says

Report: [`np-sweep.md`](analysis/np-sweep.md), 2026-08-24.

### Interpretation

`2x4` row is the best observed layout at `N=491520`, `NB=3072`:

| Grid/order | GFLOP/s | % vs original baseline |
|---|---:|---:|
| `2x4` row | 2.2067e+06 | +52.90% |
| `2x4` column | 2.1865e+06 | +51.50% |
| `4x2` column | 2.1732e+06 | +50.58% |
| `4x2` row | 2.1683e+06 | +50.24% |

However, the entire spread is only about 1.8%, so `2x4` row is the best
single observation, not an incontrovertibly proven optimum. The 2x4-versus-4x2
shape effect is somewhat more credible because it appears in both orders; the
row-versus-column effect is especially small.

Your NVLink intuition is useful but should be stated more cautiously. The
hardware probe found NV18 paths between every GPU pair and an NVSwitch
([probe report](../scripts/probing_report.md:60)). That makes coarse GPU-rank
ordering less dominant than it might be on a PCIe-only system, but it does not
make communication irrelevant. The probe also found two NUMA domains, a local
NUMA distance of 10 versus remote distance 21, and different NIC locality for
GPU groups ([probe report](../scripts/probing_report.md:38)). These are still
possible sources of cost.

The correct conclusion is:

> Coarse process-grid and ordering choices are now a modest residual lever on
> this NVSwitch-connected single node. Lower-level communication, panel
> scheduling, and overlap controls are reasonable next hypotheses, but the
> current data do not prove that communication is the dominant remaining cost.

All four raw runs used the same major application controls. In particular, the
raw output shows `--use-mpi-panel-broadcast = 50`, `--use-separate-stream-for-
gemm = 1`, and `--sloppy-type = FP16`; the grid was not tested together with
every later OpenMP and fill-device setting. NVIDIA documents the panel-broadcast
option as a percentage of steps using MPI, with `0` selecting NCCL
([NVIDIA documentation](https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html)).

### Remaining questions

- Does `2x4` row remain best after OpenMP socket placement and fill-device are
  enabled? This interaction was not directly re-swept.
- Is the 0.9% row-versus-column difference real? It needs matched repetition.
- Does changing panel broadcast or scheduling change the preferred grid?

## 5. Affinity sweep — no explicit binding is best, but this is not “the OS solves everything”

Report: [`affinity-491k.md`](analysis/affinity-491k.md), 2026-08-24.

### Interpretation

The affinity results show two different facts:

1. Explicit HPL CPU/memory affinity did not help this workload.
2. The host-side pipeline still benefits from a deliberate OpenMP placement
   policy, as the later OpenMP experiment demonstrated.

The best affinity control had no CPU or memory affinity: 2.1980e+06 GFLOP/s
(**+52.30%**). Memory affinity was -1.45%, within node variation. Eight or
twelve cores per rank were approximately neutral, four cores per rank cost
18%, and two cores per rank caused an 87% collapse.

This is not evidence that the OS has discovered the application’s optimal
placement. It is evidence that broad default scheduling is safer than
over-constraining ranks, while a later OpenMP policy can still improve the
host-side work. The GAAS container exposes only CPU ranges 0–49 and 56–101 to
the relevant application, even though the physical node has 0–111. Affinity
strings must respect that cpuset.

The raw two-core artifact shows the scale of the failure: LU expanded to
242.30 s and the solver to 40.70 s, producing only 2.7974e+05 GFLOP/s while
still eventually passing ([raw output](../experiments/affinity-sweep/outputs/cpu_strict2_491k.o:420)).
This is host-thread starvation, not numerical failure.

### Remaining questions

- Would explicit HPL CPU affinity help if it were coordinated with, rather
  than competing against, OpenMP socket placement? It was not tested in that
  combined form.
- Would a different allocation or node type change the result? Affinity is
  closed for this current workload, not universally disproved.
- Can a future launcher change the visible cpuset? Every new affinity test
  must rediscover it.

## 6. OpenMP sweep — the host-side pipeline is a real bottleneck

Report: [`omp-sweep.md`](analysis/omp-sweep.md), 2026-08-26.

### Interpretation

The conclusion is mostly correct, but “at least 8 threads/cores” combines two
different experiments:

- `OMP_NUM_THREADS` below about 8 starved the host-side pipeline;
- explicit HPL CPU affinity below about 8 cores per rank starved the same
  pipeline in a different way.

Eight is the observed threshold under this GAAS allocation and launch. It is
not a universal HPL-MxP minimum for every node.

The raw phase timings show what improved:

| Configuration | LU time | Solver time | GFLOP/s | % vs baseline |
|---|---:|---:|---:|---:|
| `OMP_NUM_THREADS=8`, placement unset | 20.22 s | 14.41 s | 2.2859e+06 | +58.39% |
| 8 threads, `sockets + TRUE` | 20.28 s | 13.84 s | 2.3204e+06 | +60.79% |
| 8 threads, `cores + TRUE` | 46.57 s | 39.97 s | 9.1505e+05 | -36.60% |

The socket placement gain came primarily from reducing solver/host-pipeline
time; LU was essentially unchanged ([socket output](../experiments/omp-sweep/outputs/omp_t8_sockets_true.o:280),
[cores output](../experiments/omp-sweep/outputs/omp_t8_cores_true.o:302)).
`OMP_PLACES=cores` plus binding is catastrophic because, with the MPI launcher
using `--bind-to none`, the ranks can oversubscribe the same low-numbered CPU
places. `cores + FALSE` avoids that particular failure, so the issue is the
mapping interaction, not that physical cores are inherently bad.

The best interpretation of the OS result is:

> Do not impose narrow HPL CPU or memory ranges. Let the runtime access the
> available cpuset, while explicitly using socket-level OpenMP placement to
> avoid pathological thread placement.

### Remaining questions

- Are `sockets + TRUE`, `sockets + SPREAD`, and `sockets + FALSE` genuinely
  different? Their roughly 1% spread requires matched repetitions.
- Does the best OpenMP placement change when fill-device or LU scheduling
  changes the CPU/GPU overlap?
- Is eight optimal because of this allocation, or would a different rank/core
  arrangement shift the threshold?

## 7. Matrix-placement control — why the gain was modest

Report: [`matrix-placement-491k.md`](analysis/matrix-placement-491k.md),
2026-08-26.

### What the flags mean

NVIDIA documents `--fill-device` as filling the device with the FP64 matrix;
`--fill-device-buffer-size` controls the buffer zone left on the device; and
`--Anq-device` controls the number of FP64-matrix columns placed on the device.
The documentation states that `--fill-device` overrides `--Anq-device`
([NVIDIA options](https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html)).
Therefore, Anq and fill-device are not independent knobs when fill-device is
enabled.

### Interpretation

The “little gain” conclusion is directionally right, but the reason is not
that only a negligible amount of the matrix moved. Fill-on increased measured
device usage from about 124 GB to about 136 GB, leaving only a few GB of
headroom. The incremental buffer change from 3048 MB to 1024 MB then used about
2 GB more VRAM and improved the end-to-end result by less than 1%.

The raw artifacts show the distinction:

| Configuration | Device max/free | LU time | Solver time | GFLOP/s | Correctness |
|---|---:|---:|---:|---:|---|
| Fill on, buffer 3048 | 135.668 / 2.847 GB | 20.20 s | 13.14 s | 2.3745e+06 | PASSED |
| Fill on, buffer 1024 | 137.644 / 0.870 GB | 20.24 s | 12.88 s | 2.3902e+06 | PASSED |
| Fill on, buffer 2048 | 136.644 / 1.870 GB | 20.04 s | 13.06 s | 2.3920e+06 | PASSED |
| Fill on, buffer 512 | 138.146 / 0.368 GB | 19.24 s | 56.24 s | 1.0488e+06 | FAILED |

The buffer-1024 and buffer-512 artifacts are especially instructive. At 1024,
the solver still converged in three iterations and the final residual was
5.22e-14 ([valid output](../experiments/matrix-placement-control/outputs/491k_buf_1024.o:283)).
At 512, the solver took ten iterations, stalled around residual 1.001, and
the final verification failed ([invalid output](../experiments/matrix-placement-control/outputs/491k_buf_512.o:285)).
The low-buffer result is not merely a slow performance point; it is a broken
residency/correctness point.

The fill-on versus fill-off comparison is also node-confounded. Fill-on on
`hpc-gaas-g16` reached 2.3745e+06, while fill-off on slower `hpc-gaas-g10`
reached 2.1512e+06. The raw fill-off solver time was 16.66 s versus 13.14 s
for fill-on, but the raw comparison cannot assign all of that difference to
the flag because the nodes differ. The defensible fill-on gain is about 2–3%,
not the raw +10.4% comparison against the slow node.

### Register-step interpretation

The 2.3974e+06 result at register step 1536 is the numerical maximum, but all
register-step results were within approximately 1.5% of the default and were
distributed across nodes. The correct conclusion is “1536 merits matched
repetition,” not “1536 is optimal.”

### Remaining questions

- What is the repeatable fill-on gain with fill-on and fill-off interleaved on
  the same node?
- Is buffer 1024 or 2048 preferable once node variation is controlled?
- Can `--Anq-device` improve partial residency when tested with
  `--fill-device 0`, without causing the low-buffer failure mode?
- Do register steps near 1024–2048 matter after matched repetition?

## 8. Matrix-placement N resweep — faster solver, unchanged end-to-end rate

Report: [`matrix-placement-N-resweep.md`](analysis/matrix-placement-N-resweep.md),
coarse section dated 2026-08-26.

### Interpretation

The mechanism is real, but the net optimization failed. Lowering N under
fill-device reduced the iterative-solver time substantially, consistent with
less staging or better residency. However, it also reduced LU efficiency by
making panel and communication overhead a larger fraction of the smaller
problem.

The raw phase evidence is:

| N | LU time | Solver time | Approx. phase sum | LU GFLOP/s | Total GFLOP/s | Final result |
|---:|---:|---:|---:|---:|---:|---|
| 491520 | 20.29 s | 13.07 s | 33.36 s | 3.9023e+06 | 2.3731e+06 | PASSED |
| 368640 | 9.95 s | 4.09 s | 14.04 s | 3.3570e+06 | 2.3792e+06 | PASSED |

The raw files show both the timing and the final finite residuals
([N=491520](../experiments/matrix-placement-N-resweep/outputs/n_491520.o:283),
[N=368640](../experiments/matrix-placement-N-resweep/outputs/n_368640.o:275)).
The smaller problem does not fail; it simply loses LU efficiency. This is the
important performance lesson:

> A phase-level improvement is not automatically an end-to-end improvement.
> The opposing phase can absorb the gain.

The successful runs still converged in three iterations. The improvement is
primarily in solver time and data movement, not a dramatic reduction in the
number of refinement iterations.

### Why the expected large gain did not appear

At `N=491520`, fill-on/buffer-1024 had approximately 20.24 s of LU and 12.88 s
of solver time, or 33.12 s total. If matrix placement could make the entire
solver free—which it cannot—the theoretical speedup from changing only that
phase would be:

```text
33.12 / 20.24 = approximately 1.64x
```

That is already below 2x because LU alone exceeds half of the total time. A
2x end-to-end gain would require substantial improvement to LU as well as the
solver, or a different metric such as GEMM-only throughput.

### Remaining questions

- Can LU scheduling reduce the panel/communication penalty while preserving
  the large-N LU efficiency?
- Can solver staging be reduced at `N=491520` without lowering N?
- Can phase timings be made sufficiently repeatable to resolve a scheduling
  gain smaller than the observed node variation?

## 9. Fine N resweep — closing the N dimension

Report: follow-up section in [`matrix-placement-N-resweep.md`](analysis/matrix-placement-N-resweep.md),
2026-08-27.

### Interpretation

The fine sweep tested eight values from 490496 down to 483328 in 1024-step
increments, with a `491520` control before and after the sequence. All ten
runs were on `hpc-gaas-g18`, which made the control drift measurable.

The best-looking fine point was `N=484352` at 2.3820e+06 (**+65.05%**), but it
was only 0.12% above the first control. The same-node control fell from
2.3792e+06 to 2.3706e+06, a -0.36% drift over the job
([start control](../experiments/matrix-placement-N-fine/outputs/ctrl_491520_a.o:283),
[fine point](../experiments/matrix-placement-N-fine/outputs/n_484352.o:283),
[end control](../experiments/matrix-placement-N-fine/outputs/ctrl_491520_b.o:283)).

The fine values therefore form a noise band, not a hidden N optimum. More N
searching below 491520 is not justified under the current configuration.

### Important qualification

The raw output proves the timing and memory behavior, but it does not expose
an exact byte-level breakdown of which FP64 columns are resident. It is safer
to say that the phase-timing pattern is consistent with reduced staging and
that the mechanism is supported by the experiment—not to claim that the raw
memory line alone proves complete FP64 residency.

### Remaining questions

There are no remaining N questions that justify another refinement sweep. If a
future scheduling, precision, or residency change materially changes memory
use or phase balance, checking the new memory boundary would be a new
hypothesis.

## Cross-report conclusions

### What is genuinely established

1. **N is a work/amortization lever until memory stops the run.** The memory
   wall is hard and approximately 506–510k for the tested configurations.
2. **NB improves blocking and LU efficiency, not the fundamental amount of
   computation.** `NB=3072` reduces LU time substantially while solver time is
   nearly unchanged.
3. **The process grid is a modest refinement.** `2x4` row is the best observed
   layout, but its advantage is near the noise scale and it was not re-tested
   with every later control.
4. **Host execution matters.** The OpenMP thread/placement controls improved
   the host pipeline and solver phase; explicit narrow CPU affinity damaged it.
5. **Device placement has diminishing returns.** Fill-on is a real small gain;
   the safe buffer region is 1024–2048 MB; below that, correctness fails.
6. **Smaller N improves a phase but not the objective.** Solver time falls,
   but LU efficiency also falls, leaving end-to-end GFLOP/s flat.
7. **Node variation is a first-class experimental variable.** Differences of
   1–2% are often not resolvable from single runs, and some cross-node effects
   are much larger.

### What should be treated as closed

- More N searching below 491520 under the current controls.
- Exact N/NB divisibility as an optimization lever.
- Explicit CPU or memory affinity for this workload.
- Register-step micro-tuning without matched repetition.
- Fill buffers below 1024 MB.
- Claims that a single 2.3974e+06 result is a confirmed new baseline.

## Direction forward: highest-value optimization questions

This ranking is based on potential upside and the phase evidence; it is not a
claim that the gains have already been measured. Every experiment should keep
the current control fixed:

```text
N=491520, NB=3072, 2x4 row
OMP_NUM_THREADS=8, OMP_PLACES=sockets, OMP_PROC_BIND=TRUE
--fill-device 1, buffer 1024 or 2048
register-step 2048 unless specifically being repeated
```

Every candidate must produce normal output, finite residuals, and `PASSED`
verification. Record LU time, iterative-solver time, device headroom, and the
reported end-to-end GFLOP/s.

### 1. Sloppy precision: FP4/FP8/FP16

This has the largest potential throughput upside because HPL-MxP is designed
to use lower-precision Tensor Core work with higher-precision correction. The
current raw outputs use `SLOPPY-TYPE = FP16`; FP4 and FP8 have not been tested
in this project. NVIDIA’s release notes identify FP4 support in the HPL-MxP
package and the documentation lists FP4, FP8, and FP16 as accepted sloppy
types ([release notes](https://docs.nvidia.com/nvidia-hpc-benchmarks/release_notes.html),
[launcher options](https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html)).

The key risk is correctness: a faster sloppy path is not a win if refinement
fails or the residual becomes non-finite. Test each precision separately and
compare both phase timing and residual trajectory.

### 2. LU scheduling and overlap

The N resweep identifies LU efficiency as the counterforce that erased the
smaller-N solver gain. The most direct flags are:

- `--prioritize-trsm`;
- `--prioritize-factorization`;
- `--use-separate-stream-for-gemm` (already `1` in current runs, so test the
  opposite only if there is a reason to do so);
- `--u-panel-chunk-nbs` around its default of 8.

The first two flags are currently `0` and are more promising unexplored
controls. Test them one at a time before combinations, and measure LU and
solver phases separately. NVIDIA documents the U-panel chunk constraint

```text
((N / NB) / npcol) / u-panel-chunk-nbs < 20
```

For the current `N=491520`, `NB=3072`, `npcol=4`, and default chunk size 8,
the left side is 5, so the current run is comfortably inside the documented
constraint ([release notes](https://docs.nvidia.com/nvidia-hpc-benchmarks/release_notes.html)).

### 3. Panel communication path

The current raw runs already use `--use-mpi-panel-broadcast=50`, so this is
not an untouched default-versus-optimized comparison. Sweep the communication
mix deliberately, for example comparing the current 50% setting with a
NCCL-oriented setting (`0`) and selected MPI percentages, while recording
whether the preferred grid changes.

This direction is motivated by the two-NUMA/NVSwitch/NIC topology and by the
LU penalty seen when the problem becomes smaller. It is a hypothesis about
panel synchronization and communication, not a conclusion that NVLink has
stopped communication from mattering.

### 4. GEMM-kernel selection and CUDA/cuBLAS path

The application’s largest compute phase remains a plausible source of gain.
NVIDIA explicitly notes that HPL-MxP performance depends heavily on cuBLAS and
documents `--preset-gemm-kernel` as a kernel-selection option
([NVIDIA documentation](https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html)).
The current raw runs use the default preset value 0. Before testing a preset,
confirm that the documented preset is appropriate for GAAS’s H200/SM90 GPUs;
the documentation describes preset 80 as an SM80 preset, so it must not be
assumed to help H200.

A useful experiment should compare the preset against the same control, keep
sloppy precision fixed at FP16 initially, and check whether LU GFLOP/s rises
without changing solver correctness.

### 5. Partial FP64 residency with `--Anq-device`

The iterative solver still accounts for a large fraction of the large-N
runtime, and fill-device demonstrates that residency affects it. However,
`--Anq-device` must be tested with `--fill-device 0`, because fill-device
overrides it. Sweep a small number of safe column counts and watch VRAM
headroom and residual convergence.

This is ranked fifth because it is conditional and memory-constrained. The
N-resweep warns us not to optimize solver time in isolation: any solver gain
must survive the LU and end-to-end GFLOP/s measurement.

## What the “performance should double” expectation misses

A doubling expectation is not supported by the current end-to-end evidence.
At the best measured large-N control, the raw phase split is approximately
20.24 s LU and 12.88 s iterative solver. Even making the solver free would
only yield about 1.64x speedup. To approach 2x, LU, GEMM, communication, and
overlap would also need to improve.

The expectation may be based on a different quantity:

- GEMM-only or Tensor Core peak throughput;
- `LU GFLOPS`, which explicitly excludes the iterative solver;
- a workload whose entire relevant working set fits in GPU memory;
- a different HPL-MxP version, CUDA/cuBLAS stack, or hardware platform.

The current experiments did not miss an obvious 2x matrix-placement gain. They
show that matrix placement is only one component of the end-to-end runtime,
and that its safe incremental gain is modest once the GPU is already near
capacity.

## Provenance

- Baseline and structured results: [`results/metrics.csv`](../results/metrics.csv)
- Validated summary: [`results/RESULTS.md`](../results/RESULTS.md)
- Hardware probe: [`scripts/probing_report.md`](../scripts/probing_report.md)
- N analysis: [`analysis/n-sweep-370k-510k.md`](analysis/n-sweep-370k-510k.md)
- NB analysis: [`analysis/nb-sweep.md`](analysis/nb-sweep.md)
- Alignment analysis: [`analysis/N-NB-resweep.md`](analysis/N-NB-resweep.md)
- Grid analysis: [`analysis/np-sweep.md`](analysis/np-sweep.md)
- Affinity analysis: [`analysis/affinity-491k.md`](analysis/affinity-491k.md)
- OpenMP analysis: [`analysis/omp-sweep.md`](analysis/omp-sweep.md)
- Matrix-placement analysis: [`analysis/matrix-placement-491k.md`](analysis/matrix-placement-491k.md)
- N-resweep and fine follow-up: [`analysis/matrix-placement-N-resweep.md`](analysis/matrix-placement-N-resweep.md)
- Raw examples are linked beside the claims in each section.
