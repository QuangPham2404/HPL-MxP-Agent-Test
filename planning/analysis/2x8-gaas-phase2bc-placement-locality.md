# Analysis — 2x8 GAAS Phase 2B/2C Placement and Locality

Analysis ID: `2x8-gaas-phase2bc-placement-locality`

This analysis covers **TASK-007** only and interprets the physical-placement
experiment after verified execution.

Source evidence:

- `tasks/TASK-007.md`
- `experiments/2x8-GAAS/phase2bc-placement-locality/`
- `planning/analysis/2x8-gaas-phase2a-grid-order-matrix.md`
- `planning/dependency-graph/README.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `results/metrics.csv`

All ten arms ran sequentially in one PBS allocation, job `72879.gaas`, on
`hpc-gaas-g12 + hpc-gaas-g15`. Every arm passed correctness with the same
normalized residual and three iterative-refinement iterations.

Fixed controls:

```text
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row
OMP_NUM_THREADS = 8

sloppy-type = FP16
use-mpi-panel-broadcast = 0
use-separate-stream-for-gemm = 1
prioritize-trsm = 0
prioritize-factorization = 0
fill-device = 1
skip-tests = 0
monitor-gpu = 0
```

The experiment changes only GPU, memory, CPU, and UCX-device placement.

## 1. Results

| Arm | Placement change | Overall GFLOP/s | LU s | LU GFLOP/s | IR s | IR/LU |
|---|---|---:|---:|---:|---:|---:|
| A0 | G0 identity GPU, mem omitted | **5.7363e+06** | 7.79 | 6.7609e+06 | **1.39** | 0.178 |
| A1 | G0 + matching mem affinity | 5.6984e+06 | 7.79 | 6.7561e+06 | 1.45 | 0.186 |
| A2 | G1 column-local GPU, mem omitted | 5.5378e+06 | 7.78 | 6.7713e+06 | 1.73 | 0.222 |
| A3 | G1 + matching mem affinity | 5.6699e+06 | 7.78 | 6.7675e+06 | 1.51 | 0.194 |
| B0 | G0 / no mem / CPU free | 5.6247e+06 | 7.81 | 6.7453e+06 | 1.56 | 0.200 |
| B1 | CPU loose | 5.5530e+06 | 7.77 | 6.7781e+06 | 1.72 | 0.221 |
| B2 | CPU medium, 10 CPUs/rank | **5.6912e+06** | 7.78 | 6.7686e+06 | **1.48** | 0.190 |
| B3 | CPU strict, 8 CPUs/rank | 5.3783e+06 | 7.77 | 6.7728e+06 | **2.02** | 0.260 |
| C0 | UCX automatic | 5.5828e+06 | 7.80 | 6.7515e+06 | 1.64 | 0.210 |
| C1 | GPU-PIX-paired UCX HCA | **5.6949e+06** | 7.78 | 6.7658e+06 | **1.47** | 0.189 |

All arms report the same matrix-memory regime:

```text
host consumption MAX ~= 0.004 GB/process
device consumption MAX = 135.254 GB/process
after-matgen device headroom ~= 2.767 GB/process
```

Therefore no candidate crossed a new N/residency or memory-capacity regime.

### Important control drift

The exact same physical configuration appears three times:

```text
A0 = 5.7363e+06
B0 = 5.6247e+06   (-1.95% vs A0)
C0 = 5.5828e+06   (-2.68% vs A0)
```

This is the most important uncertainty bound in TASK-007.

It does not invalidate same-stage comparisons, but it means a one-shot
1-2% gain should not automatically be promoted as a stable tuning result.
Effects clearly larger than this span or supported by a strong phase-level
mechanism carry more confidence.

## 2. Global mechanism: placement changes IR, not LU

Across all ten candidates:

```text
LU time range = 7.77-7.81 s
LU-rate range ~= 6.745-6.778e+06 GFLOP/s
IR time range = 1.39-2.02 s
```

The LU path is essentially flat while iterative refinement moves by more than
40% between the fastest and slowest IR observations.

This is the central finding of TASK-007:

> The tested placement controls do not materially change the H200 LU compute
> path at this geometry. Their performance effect is primarily on the
> solver/refinement side, where CPU, NUMA, MPI/UCX progress, and host-device
> locality matter.

That interpretation also explains why apparently small locality choices can
move the final HPL-MxP score even though LU GFLOP/s barely changes.

## 3. GPU affinity — G0 identity versus G1 column-local

The GPU-only comparison is A0 versus A2:

```text
A0 G0 identity:      5.7363e+06, LU 7.79 s, IR 1.39 s
A2 G1 column-local:  5.5378e+06, LU 7.78 s, IR 1.73 s

overall: -3.46%
LU time: -0.13%  (effectively unchanged)
IR time: +24.46%
```

G1 was designed to put each same-node pair belonging to an inter-node process
column into one NUMA domain. If process-column locality were directly
accelerating the dominant LU communication path, a LU improvement would be
expected. That does not happen: LU is essentially identical.

Instead, G1 without corresponding host-memory placement makes refinement much
slower. The likely reason is that GPU remapping changes each rank's GPU/NUMA
relationship while host-side runtime placement remains unchanged/default. The
solver/refinement path is more sensitive to that CPU/NUMA/GPU relationship
than the NV18-connected LU path.

Because all eight GPUs are connected through the same NV18 fabric, there is
little GPU-fabric penalty for either permutation. The observable cost comes
from the host side.

However, the strategic conclusion should be weaker than "G1 is definitively
3.46% worse." A0 is the first run, and the repeated unchanged control drifts
downward by 1.95-2.68% later in the allocation. After G1 receives matching
memory placement, the gap to A0 shrinks to only 1.16%, inside this control
span.

**Decision:** retain **G0 identity** as the representative GPU mapping because
it is at least as fast, simpler, and does not require compensating explicit
memory placement. Do not claim that G1+memory is conclusively slower; rather,
there is no evidence that it is better enough to justify the more complex
mapping.

## 4. Memory affinity — useful only as compensation for G1

Memory affinity behaves differently under the two GPU maps.

### Under G0 identity

```text
A1 vs A0:
overall = -0.66%
LU      = unchanged
IR      = 1.39 -> 1.45 s (+4.32%)
```

Explicit NUMA memory binding does not help the already-natural identity layout.
The default placement is evidently adequate, and forcing memory policy removes
runtime/OS flexibility without exposing a measurable gain.

### Under G1 column-local

```text
A3 vs A2:
overall = +2.39%
LU      = unchanged
IR      = 1.73 -> 1.51 s (-12.72%)
```

This is a much clearer interaction. Matching memory affinity repairs most of
the solver penalty introduced by the G1 GPU permutation.

The important interpretation is therefore **not** "memory affinity is good."
It is:

> Memory affinity matters when the GPU map creates a different rank-to-NUMA
> relationship. In that case, explicit memory locality can repair host-side
> solver/refinement locality. Under the natural G0 map, the same control is
> unnecessary.

A3 still does not beat A0:

```text
A3 vs A0 overall = -1.16%
A3 IR = 1.51 s
A0 IR = 1.39 s
```

and the difference is within observed control drift.

**Decision:** with G0 retained, keep `--mem-affinity` **omitted**. Preserve
the A2/A3 result as evidence of a real GPU-map × memory-locality interaction.

## 5. CPU affinity — evidence for a host-progress headroom boundary

Stage B is especially informative because LU stays flat while IR responds
strongly to CPU-mask width.

Relative to B0 free:

```text
B1 loose:
  overall -1.27%
  LU 7.81 -> 7.77 s
  IR 1.56 -> 1.72 s (+10.26%)

B2 medium, 10 CPUs/rank:
  overall +1.18%
  LU 7.81 -> 7.78 s
  IR 1.56 -> 1.48 s (-5.13%)

B3 strict, 8 CPUs/rank:
  overall -4.38%
  LU 7.81 -> 7.77 s
  IR 1.56 -> 2.02 s (+29.49%)
```

### Why loose binding does not help

B1 keeps each rank in the correct NUMA domain, but four ranks in that NUMA
domain share the same broad 50-core mask. This improves locality without
creating private CPU ownership. The small LU improvement therefore does not
translate into end-to-end improvement; refinement becomes slower.

A plausible mechanism is rank/thread contention or less deterministic host
progress inside the shared broad mask. The experiment did not capture
per-thread CPU traces, so this remains a mechanism hypothesis rather than a
proved scheduler event.

### Why medium is interesting

B2 gives each rank ten private CPUs for eight OpenMP threads. It has the best
Stage-B refinement time and the highest Stage-B end-to-end score.

This is exactly the behavior expected if HPL-MxP benefits from:

```text
private rank-local cores
+
some spare capacity beyond the eight OpenMP worker threads
```

The extra two CPUs/rank can plausibly provide room for the MPI/UCX/runtime
progress and helper activity that must coexist with OpenMP work.

But the +1.18% end-to-end gain over B0 is smaller than the observed repeated
control drift. Therefore B2 is **promising, not proven**.

### Why strict 8-core binding is bad

B3 is the strongest CPU result because its loss is much larger than the
control drift:

```text
overall -4.38%
IR +29.49%
LU essentially unchanged
```

Eight CPUs/rank for eight OMP threads leaves essentially no spare CPU capacity.
The result strongly suggests that "OMP threads == available CPUs" is too tight
for this workload. MPI/UCX progress, runtime/helper activity, refinement, or
other host-side work needs headroom beyond the eight OpenMP threads.

This is consistent with the historical single-node observation that very
narrow CPU masks eventually collapse performance, but TASK-007 establishes the
effect independently on the current 2x8 topology.

**Decision:** keep CPU affinity **free** as the current representative control,
but retain B2 medium as a serious candidate for the mandatory coordinated
OpenMP/CPU revalidation. Drop B3 strict from further optimization unless used
as a diagnostic boundary.

## 6. UCX affinity — plausible locality gain, but not yet statistically closed

Stage C compares automatic UCX device selection with exact rank-to-PIX-HCA
pinning:

```text
C0 auto: 5.5828e+06, LU 7.80 s, IR 1.64 s
C1 PIX:  5.6949e+06, LU 7.78 s, IR 1.47 s

overall = +2.008%
LU time = -0.26%
IR time = -10.37%
```

Again, the signal is almost entirely in refinement rather than LU.

That is consistent with the current fixed:

```text
--use-mpi-panel-broadcast 0
```

where the principal LU panel path is NCCL-heavy. UCX device affinity therefore
has more opportunity to affect MPI/control/refinement communication than the
main LU panel path.

### What the HCA counters tell us

On g12, both C0 and C1 moved nearly the same amount of data over **all eight
IB HCAs**.

Approximate per-HCA `port_xmit_data` deltas:

```text
C0 automatic:
  mean ~= 1.03494e10 counter units/HCA
  across-HCA spread ~= 1.73%

C1 PIX-pinned:
  mean ~= 1.03511e10 counter units/HCA
  across-HCA spread ~= 1.73%

mean C1 vs C0 traffic difference ~= +0.016%
```

Therefore automatic UCX was **already using all eight rails evenly**. C1 did
not win by activating dormant HCAs or moving materially more aggregate data.

If the performance gain is real, the more plausible mechanism is:

- deterministic rank -> local PIX HCA routing;
- fewer remote/less favorable PCIe/NUMA paths for a given rank;
- less device-selection/path-selection ambiguity or progress overhead;

rather than greater aggregate rail utilization.

The counters are only transmit-volume snapshots on the mother node, so they do
not prove path latency or GPU-direct locality.

### Why C1 is not yet a closed winner

The pre-authorized mechanical rule correctly promoted C1 because +2.008% is
strictly above the 2% gate.

Strategically, however:

```text
A0 -> B0 identical-control drift = -1.95%
A0 -> C0 identical-control drift = -2.68%
C1 -> C0 measured gain          = +2.01%
```

The C1 gain is therefore smaller than the full same-allocation control span.
There is no bracketed C0/C1 repeat to separate a real UCX-affinity effect from
time/order drift.

**Decision:** keep C1 PIX affinity as the **leading provisional UCX candidate**,
but do not close Phase 2C on one unbracketed +2.01% result.

## 7. Retained state after TASK-007

Strong enough to retain now:

```text
GPU affinity = 0:1:2:3:4:5:6:7  (G0 identity)
mem affinity = omitted
CPU affinity = omitted/free      (B2 medium remains open for OMP interaction)
```

UCX device policy remains unresolved:

```text
automatic = stable/simple control
PIX-paired = leading provisional candidate
```

The execution-time mechanical carry-forward selected PIX-paired UCX affinity,
which was correct under TASK-007's rule. Strategic closure requires one small
confirmation because the measured effect is at the control-drift scale.

N/NB/grid/residency remain closed:

```text
N = 429056
NB = 3072
4x4 row
fill-device = 1
```

No TASK-007 candidate changed device/host memory behavior.

## 8. Dependency checkpoint

| Earlier / downstream decision | Edge(s) | Material change? | Action | Reason |
|---|---|---:|---|---|
| Physical topology -> placement | E03 | No topology change | Keep mapped for g12/g15; remap on different hardware | TASK-007 directly validated the current GPU/NUMA/HCA map. |
| Grid/order -> placement | E11 | Yes, now resolved | **Satisfied for 4x4 row** | TASK-007 explicitly remapped placement after Phase 2A. |
| Grid/order -> panel transport | E12 | Yes | Keep Phase 4 fully open | 4x4 row changes which communicators cross nodes. |
| Rank/GPU/NIC placement -> panel transport | E13 | Yes | **Fully revalidate transport later** | Final NIC policy is not yet closed, and transport depends on physical routes. |
| N/refinement work -> host runtime | E18 | Already open | Revalidate host runtime after placement closes | Current IR remains placement-sensitive. |
| CPU/memory affinity -> OpenMP | E19 | **Yes** | **Fully revalidate as a coordinated host-runtime group** | B2 is promising while B3 is strongly negative under OMP=8/socket defaults. CPU masks cannot be finalized independently of OMP thread/place/bind. |
| Host runtime/locality -> DGEMV | E20 | Not yet finalized | Defer DGEMV until host runtime closes | Any retained OMP/CPU change alters solver host resources. |
| Panel transport -> chunk | E25 | Downstream | Revalidate selectively in Phase 4 | Chunk usefulness depends on retained transport. |
| Panel transport/readiness -> scheduling | E26 | Downstream | Keep scheduling open | Communication changes can alter the critical readiness path. |
| Grid/order -> scheduling | E29 | Already triggered | Revalidate later | 4x4 row materially changed ownership/node crossings. |

### Dependency interpretation

The graph produces two distinct obligations:

1. **Current-phase obligation:** Phase 2C cannot be considered robustly closed
   until automatic versus PIX-paired UCX affinity is separated from the
   observed control drift.
2. **Next-phase obligation:** once placement is closed, E19 requires a
   coordinated OpenMP + CPU-affinity revalidation. B2 must not simply be
   stacked with a separately selected OMP policy.

## 9. Proposed next step

**Recommended next action: run a minimal bracketed UCX-affinity confirmation
before moving to host-runtime tuning.**

Keep the established placement fixed:

```text
N = 429056
NB = 3072
4x4 row
GPU = G0 identity
mem affinity = omitted
CPU affinity = free
OMP_NUM_THREADS = 8
use-mpi-panel-broadcast = 0
```

Run a same-allocation bracket such as:

```text
C0 automatic
C1 PIX-paired
C0 automatic repeat
```

or the symmetric reverse bracket if operationally preferable.

Purpose:

- estimate drift immediately around C1;
- determine whether the ~10% IR-time reduction repeats;
- close Phase 2C without expanding into `UCX_TLS` or communication-policy
  tuning.

Decision logic for the later analysis:

- if C1 remains clearly above the local C0 bracket and preserves the IR
  reduction, retain PIX affinity and close Phase 2C;
- if C1 falls inside the bracket movement, retain automatic UCX as the simpler
  policy and close Phase 2C.

After Phase 2C closes, the next planned subgroup should be the **coordinated
OpenMP/CPU host-runtime revalidation required by E19**, with B2 medium retained
as the main explicit-CPU hypothesis.

Do **not** start `UCX_TLS × use-mpi-panel-broadcast` yet. That remains Phase 4
after physical placement and host runtime are established.

**Human decision state:** analysis complete; the UCX confirmation is proposed
only and requires a new approved task before execution.
