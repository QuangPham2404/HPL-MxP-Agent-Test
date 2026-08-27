# Consolidation 1: What the Nine Recent Reports Mean

## How to read this consolidation

This document consolidates the nine most recent entries in
[`planning/PLANS.md`](PLANS.md). It is intended to explain the reasoning behind
the results, not just repeat the fastest numbers.

Unless another comparison is stated, percentages are relative to the original
project baseline: `baseline-sweep_v1`, with `N=370000`, `NB=1024`, a `2x4` row
grid, and **1.4432e+06 GFLOP/s**. All retained successful runs passed the
HPL-MxP verification check with a finite residual. OOM runs and the low-buffer
matrix-placement runs are treated as failures, not performance wins.

The overall story is a sequence of increasingly better controls:

| Stage | Main configuration change | Best/representative result | % vs original baseline | What it established |
|---|---|---:|---:|---|
| Original baseline | `N=370000`, `NB=1024`, `2x4` row | 1.4432e+06 | 0.00% | Reference point |
| N sweep | Increase `N` to 490000 | 1.8293e+06 | +26.75% | More matrix work helps until a hard memory wall |
| NB sweep | `NB=3072` at `N=490000` | 2.1726e+06 | +50.54% | Block size is a stronger lever than N alone |
| Grid sweep | `2x4` row at `N=491520`, `NB=3072` | 2.2067e+06 | +52.90% | `2x4` row is the best tested grid at this N |
| OpenMP sweep | 8 threads, sockets placement/binding | 2.3204e+06 | +60.79% | Host-thread placement is a real bottleneck |
| Matrix placement | `--fill-device 1`, buffer 1024–2048 | 2.3902–2.3920e+06 | +65.62–65.74% | Device filling gives a real gain; buffer has a safe plateau |
| Unconfirmed single-run maximum | Register step 1536 | 2.3974e+06 | +66.12% | Not enough evidence to call register step 1536 a real improvement |

The current evidence-based working configuration is therefore approximately:
`N=491520`, `NB=3072`, `2x4` row, no explicit CPU or memory affinity,
`OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`,
`--fill-device 1`, and a buffer of 1024 or 2048 MB. The register-step default
of 2048 should be retained until a matched repetition proves otherwise.

## 1. N sweep — finding the usable matrix-size boundary

Report: [`n-sweep-370k-510k.md`](analysis/n-sweep-370k-510k.md), 2026-08-21.

### What was tested

`N` was increased from 370000 to 510000 while leaving the original `NB=1024`,
`2x4` row configuration unchanged. This separates the effect of giving the
GPUs a larger matrix from the effects of later tuning.

### Crucial insight

Performance rose almost monotonically from 1.4747e+06 at `N=370000` to
1.8293e+06 at `N=490000` (**+26.75%**). This is not evidence of a narrow
computational optimum at 490000. It shows that, on this configuration, larger
N provides more useful work and better amortization until the memory system
becomes the limiting factor.

At `N=500000`, performance was still high at 1.8152e+06 (+25.78%), and
`N=510000` was OOM-killed. The limiting behavior is therefore a hard memory
boundary, not a smooth performance roll-off. Both system RAM and GPU memory
were nearly exhausted at the boundary.

Two apparent dips, at `N=390000` and `N=450000`, were caused by
`hpc-gaas-g13` having unusually little free system memory. Re-running those
points on healthier nodes restored the expected trend. This is an important
lesson for every later single-run comparison: a low number can be a node
condition, not a bad parameter.

### Remaining questions

- How does the memory wall move when `NB=3072`, `--fill-device 1`, and the
  OpenMP settings are enabled? Later reports answer this partially: the wall
  occurs around `N=506880` with `NB=3072`, and the final fine sweep closes the
  search below `N=491520`.
- Can a different algorithmic or scheduling setting make use of a larger N
  without crossing the memory limit? This remains distinct from merely
  searching for another N value.
- How much of the N gain is true GPU utilization improvement versus changes in
  host/device staging? The later phase timing shows that staging is important,
  but larger N still wins overall because the LU work is better amortized.

## 2. NB sweep — discovering the strongest basic lever

Report: [`nb-sweep.md`](analysis/nb-sweep.md), 2026-08-24.

### What was tested

At `N=490000`, the panel/block size `NB` was swept from 1024 through 8192.
The N-sweep's 490000 result was retained as the secondary control, so this
experiment isolates block-size effects.

### Crucial insight

Increasing `NB` from 1024 to 3072 raised performance from 1.8387e+06 to
2.1726e+06 GFLOP/s: an additional **+18.77% over the N=490000 control**, and
**+50.54% over the original baseline**. This is why `NB` is considered a
stronger lever than N alone.

The result is a broad plateau rather than a sharply defined optimum:
`NB=3072` through `NB=6144` remain in roughly the same performance region.
The two clear declines at 7168 and 8192 show where the block becomes too large,
but the data do not prove that 3072 is intrinsically better than every value
between 3072 and 6144.

The 1024 control reproduced the earlier N-sweep point within 0.51%, which is
good evidence that the comparison is meaningful despite different nodes.

### Remaining questions

- Is `NB=3072` still best after adding `--fill-device 1` and the finalized
  OpenMP placement? No later report re-sweeps NB under every final setting.
- Could a finer scan inside the 3072–6144 plateau produce a repeatable gain?
  The likely upside is small compared with the untested compute and scheduling
  flags, so it should not outrank those directions.
- Does changing NB change the memory wall enough to permit or forbid a larger
  N? The aligned-N resweep shows a small reduction in the maximum feasible N
  with NB=3072.

## 3. N-NB resweep — testing exact block alignment

Report: [`N-NB-resweep.md`](analysis/N-NB-resweep.md), 2026-08-24.

### What was tested

With `NB=3072` fixed, N values that were exact multiples of 3072 were tested
from 488448 through 509952. The hypothesis was that `N % NB == 0` might remove
remainder work or improve panel regularity.

### Crucial insight

Alignment did not produce a measurable benefit. The six passing values ranged
from 2.1520e+06 to 2.1974e+06 GFLOP/s, with no trend. The best aligned point,
`N=491520`, reached 2.1974e+06 (**+52.26%**), only 1.14% above the unaligned
`N=490000`/`NB=3072` result. Other aligned points were below that unaligned
reference, so the apparent peak is consistent with normal node/run noise.

This is a useful negative result: the choice of `N=491520` is operationally
convenient and near the top of the feasible region, but exact divisibility is
not the reason it performs well.

The resweep also located the `NB=3072` memory wall more precisely: `N=503808`
passed, while `N=506880` and `N=509952` were OOM-killed during matrix
generation. A larger NB consumes enough additional workspace to move the wall
slightly lower than the NB=1024 wall.

### Remaining questions

- Is the apparent advantage of `N=491520` still present after all later
  settings are applied? The node-matched fine sweep answers the local question:
  no narrower peak was found immediately below it.
- Would a non-aligned N just below the memory wall be preferable if a future
  setting changes workspace usage? Alignment should not be used as the search
  criterion; available memory and measured performance should be.
- Can scheduling or residency changes reduce workspace enough to expand the
  usable N range? This is a future systems question, not an alignment question.

## 4. Process-grid and order sweep — selecting the communication layout

Report: [`np-sweep.md`](analysis/np-sweep.md), 2026-08-24.

### What was tested

All four combinations of `2x4` versus `4x2` and row versus column order were
tested at `N=491520`, `NB=3072`.

### Crucial insight

`2x4` row was the best tested layout at 2.2067e+06 GFLOP/s (**+52.90%**).
The full spread across the four layouts was only about 1.8%, so grid shape is
a modest refinement compared with N and NB. Still, the `2x4` advantage over
`4x2` appeared in both orders, making the shape difference more credible than
the smaller row-versus-column difference.

The earlier `N=399360` sweep favored `4x2` column, while this larger N favored
`2x4` row. That reversal suggests grid choice interacts with matrix size and
memory/communication balance. It is not proof of a universal rule because the
two sweeps were not fully node-matched and did not use identical later-stage
settings.

### Remaining questions

- Does `2x4` row remain best after `OMP_PLACES=sockets` and
  `--fill-device 1` are enabled? This interaction has not been directly
  re-tested.
- Is the 0.9% row-versus-column difference real? It is within the observed
  noise, so a matched repetition is needed before treating order as a strong
  optimization.
- Could a scheduling or panel-broadcast option change the preferred grid by
  changing communication or panel overlap? This is plausible and should be
  considered when testing those flags.

## 5. CPU and memory affinity sweep — learning what not to bind

Report: [`affinity-491k.md`](analysis/affinity-491k.md), 2026-08-24.

### What was tested

Memory affinity was compared first, then CPU affinity was tested with free
placement, 2/4/8/12 cores per rank, and full-socket ranges at
`N=491520`, `NB=3072`, `2x4` row.

### Crucial insight

The best result was the unbound configuration at 2.1980e+06 (**+52.30%**).
Memory affinity was slightly slower by 1.45%, but that difference was within
node noise. CPU affinity with 8 or more cores per rank was roughly neutral to
slightly negative; restricting ranks to 4 cores cost 18%, and 2 cores caused
an 87% collapse.

The reason is structural: HPL-MxP uses host threads to drive the GPU pipeline.
Binding a rank to too few CPUs starves the pipeline. Therefore, “more explicit
binding” is not automatically better. The container exposes only CPUs 0–49
and 56–101, not the full host ranges, which also explains the corrected launch
errors in this experiment.

### Remaining questions

- How should explicit CPU affinity interact with the later OpenMP socket
  placement? The OpenMP sweep found a good placement without explicit HPL CPU
  affinity; adding both could either reinforce or conflict with the runtime.
- Does affinity become useful on a different node type, GPU count, or matrix
  size? It is closed for the current workload, not universally disproved.
- Can a future scheduler or launcher change alter the visible cpuset? Any new
  affinity test must rediscover the allowed CPU ranges first.

## 6. OpenMP thread and placement sweep — exposing the host-side bottleneck

Report: [`omp-sweep.md`](analysis/omp-sweep.md), 2026-08-26.

### What was tested

The number of OpenMP host threads was swept from 1 to 20. At the best thread
count, 8, all combinations of `OMP_PLACES={cores,sockets}` and
`OMP_PROC_BIND={TRUE,FALSE,CLOSE,SPREAD}` were tested.

### Crucial insight

The host pipeline needs enough threads: one thread produced only 1.1606e+06
GFLOP/s and two produced 1.7369e+06, while eight reached 2.2859e+06
(**+58.39%**). Above eight, results formed a noise-dominated plateau; the
thread sweep did not establish that 16 or 20 is better than 8.

Placement was even more informative. `OMP_PLACES=sockets` was consistently
strong, and `sockets + TRUE` reached 2.3204e+06 (**+60.79%**), the highest
single result at that point. In contrast, `OMP_PLACES=cores` combined with a
binding mode collapsed to roughly 0.9e+06 because the ranks oversubscribed a
small set of low-numbered CPUs. `cores + FALSE` avoided that specific failure.

This explains why the later matrix-placement results should be compared with
the OpenMP socket configuration, not with the original no-OMP baseline.

### Remaining questions

- Are `sockets + TRUE`, `sockets + SPREAD`, and `sockets + FALSE` genuinely
  different? Their single-run spread is about 1%, so node-matched repetitions
  are required.
- Does the best OpenMP placement change when the matrix is filled on the GPU
  or when a scheduling flag changes the CPU/GPU overlap?
- Is eight threads best because of a fixed host-thread budget, or because of
  this particular node and MPI launch? A different allocation could change the
  answer.

## 7. Matrix-placement rerun — converting memory placement into a gain

Report: [`matrix-placement-491k.md`](analysis/matrix-placement-491k.md),
2026-08-26.

### What was tested

On top of the OpenMP socket configuration, the experiment tested
`--fill-device`, `--fill-device-buffer-size`, and
`--cuda-host-register-step` at `N=491520`, `NB=3072`, `2x4` row.

### Crucial insight

`--fill-device 1` is the important result. The fill-on run reached 2.3745e+06
(**+64.53%**), about 2.3% above the earlier 2.3204e+06 fill-off reference
after accounting for the fact that the fill-off control landed on a slow
node. The raw comparison against that slow node was +10.4%, but that is not a
valid estimate of the optimization gain.

The fill-device buffer is a safety and residency control more than a precise
performance knob. Buffers of 1024 and 2048 MB were the strongest valid region,
at 2.3902e+06 (+65.62%) and 2.3920e+06 (+65.74%). Buffers of 512 and 256 MB
caused the FP64 matrix to overflow device memory; the solver stalled with a
residual near 1.0 and verification failed. Those low numbers must not be
ranked as performance regressions alone—they are correctness failures.

Register step was weak: all tested values were within about 1.5% of the 2048
default. The 1536 result, 2.3974e+06 (**+66.12%**), is the numerical maximum
but was measured on a different node and is not separated from noise. The
correct interpretation is “1536 is a candidate to repeat,” not “1536 is
proven optimal.”

### Remaining questions

- What is the repeatable gain from fill-on when fill-on and fill-off are run on
  the same node or in alternating order?
- Is buffer 1024, 2048, or the 3048 default best after node matching? The
  current data support 1024–2048 as a plateau, not a unique winner.
- Can `--Anq-device` keep the iterative-solver data device-resident without
  crossing the VRAM or host-memory limits?
- Do register-step values near 1024–2048 matter once node effects are removed?
  Current evidence says probably not.

## 8. Matrix-placement N resweep — explaining why smaller N did not win

Report: [`matrix-placement-N-resweep.md`](analysis/matrix-placement-N-resweep.md),
coarse section dated 2026-08-26.

### What was tested

With fill-device enabled and the OpenMP socket configuration held fixed, N was
reduced from 491520 to 368640. The hypothesis was that a smaller N might make
the full FP64 matrix device-resident, reduce host/device staging, and improve
overall GFLOP/s.

### Crucial insight

The mechanism was real but the optimization failed at the application level.
Solver time fell from 13.07 seconds at `N=491520` to 4.09 seconds at
`N=368640`, and solver share fell from 39.2% to 29.1%. However, smaller N also
made the LU phase less efficient: panel and communication overhead were less
well amortized. That LU penalty cancelled the solver improvement, leaving
GFLOP/s flat within node noise.

This distinction is central: improving one phase does not guarantee improving
the end-to-end metric. At the large-N end, the solver is still about 39% of
the measured runtime, while at the small-N end the LU penalty becomes the
dominant counterforce. The right next question is therefore how to improve the
phases or overlap, not whether to keep lowering N.

### Remaining questions

- Can LU scheduling reduce the panel/communication penalty while retaining
  the large-N throughput?
- Can the solver be made cheaper at `N=491520` without sacrificing the LU
  efficiency gained from the larger matrix?
- Are the phase timings stable enough across nodes to quantify a scheduling
  gain smaller than the current 3–7% node variation?

## 9. Fine N resweep — closing the N dimension

Report: the follow-up section in
[`matrix-placement-N-resweep.md`](analysis/matrix-placement-N-resweep.md),
dated 2026-08-27.

### What was tested

Eight N values from 490496 down to 483328 were run in 1024-step increments,
with a `491520` control both before and after the sequence. All ten runs were
on the same node, `hpc-gaas-g18`, using fill-device, OpenMP socket placement,
`NB=3072`, and the `2x4` row grid.

### Crucial insight

The eight fine values formed a 2.3573e+06–2.3820e+06 band, roughly 1% wide,
with no trend. The nominal best, `N=484352` at 2.3820e+06 (**+65.05%**), was
only 0.12% above the first control. The control declined from 2.3792e+06 to
2.3706e+06 over the job, a -0.36% drift. Thus the apparent 484352 peak is
smaller than the measured intra-node drift and cannot be treated as real.

This is stronger evidence than the earlier cross-node sweeps because the
control design measures the changing node condition directly. The practical
conclusion is that `N=491520` remains the best large-N choice and the N
dimension should now be considered closed for this workload.

### Remaining questions

- None that justify further N refinement under the current configuration. The
  next useful questions are orthogonal: compute/precision, LU scheduling, and
  panel communication.
- If a future flag changes memory use or phase balance substantially, the
  memory boundary may need to be checked again, but that would be a new
  experiment with a new hypothesis.

## Cross-report conclusions

### What is genuinely established

1. **The large gains are cumulative and understandable.** N supplies more
   useful work (+26.75%), NB improves blocking (+18.77% over the N-only peak),
   and the final host/device placement controls add further gains.
2. **The current usable operating point is near the memory ceiling.**
   `N=491520` is high enough to amortize LU work but below the observed
   `NB=3072` OOM boundary near 506880.
3. **The major host-side bottleneck is now controlled.** Eight OpenMP threads
   placed on sockets are materially better than the unset/default configuration
   used by earlier sweeps.
4. **The main device-placement win is fill-on, not register-step selection.**
   Buffer 1024–2048 is a safe plateau; lower values fail correctness.
5. **Node noise is large enough to invalidate small single-run differences.**
   The practical resolution is often around 1–2% for ordinary comparisons and
   can be worse across particularly noisy nodes. Matched controls and repeated
   candidates are necessary before declaring a small win.

### What should no longer consume optimization effort

- More N searching below 491520: the coarse and node-matched fine sweeps found
  no repeatable peak.
- Exact `N % NB == 0` alignment: no measurable benefit.
- Explicit CPU or memory affinity for this workload: no gain, and small CPU
  budgets are disastrous.
- Register-step micro-tuning: currently sub-noise.
- Fill-device buffers below 1024 MB: they compromise device residency and fail
  verification.

## Top five next optimization ideas, ranked by potential upside

This ranking is an upside ranking, not a claim that the gains have already been
measured. Every candidate must be tested from the same control configuration
and must pass the finite-residual and `PASSED` correctness gates. Keep
`N=491520`, `NB=3072`, `2x4` row, OpenMP socket placement, fill-device on, and
buffer 1024 or 2048 as the control while testing one direction at a time.

| Rank | Optimization idea | Why it ranks here | Concrete question to answer |
|---:|---|---|---|
| 1 | **GEMM-kernel preset** — `--preset-gemm-kernel` | HPL-MxP is dominated by GPU matrix operations, and this is an untested direct compute-path lever. It could improve the largest phase without changing N or memory pressure. | Which supported preset improves GFLOP/s repeatably, and does it preserve finite residuals? |
| 2 | **Sloppy precision selection** — `--sloppy-type` (`FP4`, `FP8`, `FP16`) | Lower-precision Tensor Core paths may offer the largest raw throughput upside, but the gain is conditional on verification and residual quality. | Which precision gives a real end-to-end gain at the configured tolerance, rather than only a faster but invalid run? |
| 3 | **LU scheduling and overlap** — `--use-separate-stream-for-gemm`, `--prioritize-trsm`, `--prioritize-factorization`, and `--u-panel-chunk-nbs` | The N resweep shows LU efficiency is the reason solver gains did not improve end-to-end GFLOP/s. Scheduling directly targets that counteracting cost and may also overlap GPU work. | Which individual scheduling flag reduces LU/panel time or improves overlap, and do combinations help without creating instability? |
| 4 | **MPI panel broadcast** — `--use-mpi-panel-broadcast` | Panel communication and synchronization are plausible contributors to the LU penalty and may explain why grid shape changes with N. This is untested at the final large-N control. | Does the broadcast path reduce communication/panel overhead on the `2x4` row layout, and does it change the best grid? |
| 5 | **Auxiliary-vector/device residency** — `--Anq-device` | The solver still consumes about 39% of runtime at large N, and the fill-device experiments show that residency affects this phase. This could reduce staging, but it is conditional because VRAM is already tight. | Can `--Anq-device` reduce solver time at `N=491520` without triggering the same VRAM/correctness cliff seen with small fill buffers? |

### Recommended order inside the top five

Start with the GEMM-kernel preset and sloppy-precision direction as separate,
small experiments because they have the largest potential throughput impact.
Then test LU scheduling, measuring both total GFLOP/s and the LU/solver phase
split. Test panel broadcast after that, because it may interact with the grid
and scheduling choices. Treat `--Anq-device` as a carefully monitored,
conditional residency experiment rather than assuming that faster solver time
will improve end-to-end performance—the N resweep demonstrated why that
assumption can fail.

## Provenance and evidence boundary

- Numeric source of truth: [`results/metrics.csv`](../results/metrics.csv).
- Validated result summary: [`results/RESULTS.md`](../results/RESULTS.md).
- Original baseline: `baseline-sweep_v1`, 1.4432e+06 GFLOP/s.
- Nine report entries consolidated: N sweep, NB sweep, N-NB resweep, process
  grid/order sweep, affinity re-sweep, OpenMP sweep, matrix-placement rerun,
  matrix-placement N resweep, and its 2026-08-27 fine-N follow-up.
- The numerical maximum of 2.3974e+06 GFLOP/s is retained as a candidate, not
  a confirmed optimization, because register-step differences were within
  node noise and the peak was not node-matched.
