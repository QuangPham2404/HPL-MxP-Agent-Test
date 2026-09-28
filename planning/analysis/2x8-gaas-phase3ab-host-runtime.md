# Analysis — 2x8 GAAS Phase 3A/3B Coordinated Host Runtime

Analysis ID: `2x8-gaas-phase3ab-host-runtime`  
Task: `TASK-009`  
Execution commit: `5a1391b31b5e61563848b90d218ef34b22b2635d`

## 1. Scope and execution basis

TASK-009 coordinated the host-runtime controls that dependency E19 required to
be treated together:

1. Step A — `OMP_NUM_THREADS`;
2. Step B — HPL `--cpu-affinity`;
3. Step C — `OMP_PLACES × OMP_PROC_BIND`.

All 21 scored v2 arms ran in one PBS allocation on `hpc-gaas-g13 +
hpc-gaas-g15`, job `73174.gaas`, queue `gpu_as`, project
`hpc_ebslee`. Every arm exited 0, reported `PASSED`, finite normalized
residual `1.416310E-05`, and 3 refinement iterations.

The fixed scientific point was:

```text
N = 429056
NB = 3072
grid = 4x4 row
gpu-affinity = 0:1:2:3:4:5:6:7
mem-affinity = omitted
ucx-affinity = omitted / automatic
sloppy-type = FP16
use-mpi-panel-broadcast = 0
use-separate-stream-for-gemm = 1
prioritize-trsm = 0
prioritize-factorization = 0
fill-device = 1
test-loop = 1
skip-tests = 0
monitor-gpu = 0
```

TASK-009 additionally fixed an important launcher-observability gap: every
scored arm explicitly forwarded `OMP_NUM_THREADS` through `mpirun -x` and
verified the requested OpenMP environment on all 16 ranks.

The immutable campaign baseline remains `4.8037e+06 GFLOP/s`. Percentage
improvements against that baseline are useful campaign context, but the clean
causal comparisons in this analysis are the same-allocation TASK-009
comparisons.

---

## 2. Step A — OpenMP thread-count sweep

### 2.1 Results

CPU/memory/UCX affinity remained omitted. `OMP_PLACES` and
`OMP_PROC_BIND` were omitted, leaving the installed launcher defaults
(effectively `sockets / TRUE`).

| OMP threads | Overall GFLOP/s | vs original baseline | LU s | LU GFLOP/s | IR s | IR/LU | Decision-region |
|---:|---:|---:|---:|---:|---:|---:|---|
| **4** | **6.5632e+06** | **+36.63%** | 7.74 | 6.8076e+06 | **0.29** | 0.037 | plateau leader |
| 6 | 6.5459e+06 | +36.27% | 7.75 | 6.7906e+06 | 0.29 | 0.037 | plateau |
| 8 | 6.5437e+06 | +36.22% | 7.76 | 6.7868e+06 | 0.29 | 0.037 | plateau |
| 10 | 6.4302e+06 | +33.86% | 7.78 | 6.7652e+06 | 0.41 | 0.053 | outside 2% plateau |
| 12 | 6.2635e+06 | +30.39% | 7.77 | 6.7742e+06 | 0.63 | 0.081 | degraded |

Relative to T=4:

```text
T=6:  -0.26%
T=8:  -0.30%
T=10: -2.03%
T=12: -4.57%
```

### 2.2 Analysis

The useful thread-count region is a broad **4–8-thread plateau**, not a sharp
single-thread-count optimum.

The key phase evidence is that LU is essentially unchanged:

```text
LU time = 7.74–7.78 s
LU rate = 6.765–6.808 PF/s
```

across the entire 4–12-thread sweep. The performance separation above eight
threads comes almost entirely from refinement:

```text
T=4–8: IR = 0.29 s
T=10:  IR = 0.41 s
T=12:  IR = 0.63 s
```

Thus more host threads do not feed the LU path faster at this operating point.
Once roughly four threads/rank are available, the useful host work is already
saturated. Raising concurrency beyond the plateau instead increases the
refinement-side cost, consistent with greater thread/runtime scheduling
overhead and/or competition with MPI/UCX/helper work.

The experiment does **not** prove that four threads is intrinsically faster
than six or eight: their 0.26–0.30% spread is far below the campaign's observed
1–2% class of run-to-run movement. The strategic conclusion is therefore:

> `OMP_NUM_THREADS=4,6,8` form one useful plateau. Retain **4** as the
> representative control because it is the numerical leader and uses the
> smallest host-thread budget, leaving the most spare host capacity without
> sacrificing measurable performance.

Retained Step-A representative:

```text
OMP_NUM_THREADS = 4
```

### 2.3 Important launcher-regime observation

TASK-009 also exposes a major cross-task bookkeeping issue.

The closest historical control is TASK-008 automatic UCX on the same
g13+g15 node pair:

```text
TASK-008 C0a:
  OMP intended = 8
  overall = 5.6421e+06
  LU = 7.76 s
  IR = 1.57 s

TASK-009 A8:
  OMP_NUM_THREADS=8 explicitly forwarded + verified on all 16 ranks
  overall = 6.5437e+06
  LU = 7.76 s
  IR = 0.29 s
```

The cross-task score rises about 15.98%, while LU is unchanged and IR falls
about 81.5%.

This is not a clean same-allocation causal experiment, so the full improvement
must **not** be attributed numerically to `mpirun -x OMP_NUM_THREADS`.
However, the repository cannot prove that older remote ranks received the
job-shell OpenMP value, while TASK-009 explicitly verifies that they do.
The combination of a concrete launcher-contract difference, unchanged LU, and
a very large refinement-only shift is strong evidence that the campaign has
entered a **materially different host-runtime / IR regime**.

Accordingly, older TASK-001–008 *within-task relative comparisons* remain
valuable because each task used one consistent launcher convention, but their
absolute IR behavior must not be assumed to transfer unchanged to the new
verified host-runtime contract.

---

## 3. Step B — CPU-affinity matrix

### 3.1 Results

Step A carried T=4 and T=6. For each T, the free Step-A arm is the matched B0
control.

#### T = 4

| CPU policy | CPU territory | Overall GFLOP/s | vs free | LU s | IR s | IR/LU |
|---|---|---:|---:|---:|---:|---:|
| **free** | affinity omitted | **6.5632e+06** | control | 7.74 | **0.29** | 0.037 |
| loose | shared whole local NUMA domain | 6.5433e+06 | -0.30% | 7.76 | 0.29 | 0.037 |
| medium | 6 CPUs/rank | 6.2703e+06 | -4.46% | 7.81 | 0.60 | 0.077 |
| strict | 4 CPUs/rank | 6.1713e+06 | -5.97% | 7.76 | 0.77 | 0.099 |

#### T = 6

| CPU policy | CPU territory | Overall GFLOP/s | vs free | LU s | IR s | IR/LU |
|---|---|---:|---:|---:|---:|---:|
| **free** | affinity omitted | **6.5459e+06** | control | 7.75 | **0.29** | 0.037 |
| loose | shared whole local NUMA domain | 6.5505e+06 | +0.07% | 7.75 | 0.29 | 0.037 |
| medium | 8 CPUs/rank | 6.2819e+06 | -4.03% | 7.81 | 0.58 | 0.074 |
| strict | 6 CPUs/rank | 6.3429e+06 | -3.10% | 7.75 | 0.56 | 0.072 |

### 3.2 Analysis

The Step-B result is stronger than TASK-007 because the CPU policies are now
tested jointly with the retained OpenMP plateau.

**Free and loose are effectively equivalent.** Restricting each rank to the
broad NUMA domain local to its GPU does not improve performance, but it also
does not hurt. This shows that ranks do not require cross-NUMA CPU freedom to
reach the current fast IR path; broad same-NUMA CPU territory is sufficient.

The harmful transition occurs when the rank is divided into **small private,
non-overlapping CPU slices**.

At T=4:

```text
medium: IR 0.29 -> 0.60 s  (+107%), score -4.46%
strict: IR 0.29 -> 0.77 s  (+166%), score -5.97%
```

At T=6:

```text
medium: IR 0.29 -> 0.58 s  (+100%), score -4.03%
strict: IR 0.29 -> 0.56 s  (+93%),  score -3.10%
```

LU remains almost flat throughout. Therefore the earlier TASK-007 finding was
real in mechanism but should be refined:

> The problem is not simply “OMP threads need exactly two spare cores.”
> Rather, **narrow private CPU territories themselves are harmful to the
> refinement/progress path**. Broad free/shared territory preserves the CPU
> flexibility required by OpenMP, MPI/UCX progress, helper/runtime work, and
> refinement. The non-monotonic medium-vs-strict ordering at T=6 is additional
> evidence against a simplistic “more spare cores always wins” interpretation.

The T=6 loose arm (+0.07%) does not establish a benefit over free placement,
and free is simpler.

Retained Step-B policy:

```text
--cpu-affinity omitted
```

This also means the final host configuration does **not** introduce a new CPU
NUMA restriction that would by itself force a memory-affinity remap.

---

## 4. Step C — OpenMP place/bind matrix

### 4.1 Results

Step B carried T=4/free and T=6/free. Their existing omitted-policy arms are
the C0 controls, corresponding to the installed launcher defaults
`OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`.

#### T = 4 / CPU free

| OMP policy | Overall GFLOP/s | vs default control | LU s | IR s | IR/LU |
|---|---:|---:|---:|---:|---:|
| **default omitted -> sockets/TRUE** | **6.5632e+06** | control | 7.74 | 0.29 | 0.037 |
| sockets/CLOSE | 6.5431e+06 | -0.31% | 7.76 | 0.29 | 0.037 |
| sockets/SPREAD | 6.5355e+06 | -0.42% | 7.77 | 0.29 | 0.037 |
| cores/TRUE | 1.8504e+06 | -71.81% | 12.93 | 15.59 | 1.206 |
| cores/CLOSE | 1.8637e+06 | -71.60% | 12.74 | 15.53 | 1.219 |
| cores/SPREAD | 1.8350e+06 | -72.04% | 12.99 | 15.74 | 1.212 |

#### T = 6 / CPU free

| OMP policy | Overall GFLOP/s | vs default control | LU s | IR s | IR/LU |
|---|---:|---:|---:|---:|---:|
| **default omitted -> sockets/TRUE** | **6.5459e+06** | control | 7.75 | 0.29 | 0.037 |
| sockets/CLOSE | 6.5575e+06 | +0.18% | 7.74 | 0.29 | 0.037 |
| sockets/SPREAD | 6.5575e+06 | +0.18% | 7.74 | 0.29 | 0.037 |
| cores/TRUE | 1.8395e+06 | -71.90% | 13.06 | 15.57 | 1.192 |
| cores/CLOSE | 1.8484e+06 | -71.76% | 13.00 | 15.50 | 1.192 |
| cores/SPREAD | 1.8404e+06 | -71.88% | 12.69 | 15.99 | 1.260 |

### 4.2 Analysis

The socket-level policies form one clear plateau. Changing TRUE/CLOSE/SPREAD
with `OMP_PLACES=sockets` moves end-to-end performance by less than 0.5% and
leaves both LU and IR essentially unchanged.

Therefore there is no evidence that an explicit socket bind policy is better
than the installed package default. Retain omission for simplicity and to
avoid unnecessary launcher coupling.

The `OMP_PLACES=cores` result is qualitatively different and decisive.
Every core-level binding policy collapses performance by about 72%.

Unlike Step A/B, the failure now damages **both** major phases:

```text
normal socket policy:
  LU ~= 7.75 s
  IR ~= 0.29 s

core policy:
  LU ~= 12.7–13.1 s
  IR ~= 15.5–16.0 s
```

So core-level placement is not merely a refinement-side penalty; it creates a
system-wide host-placement failure.

The likely mechanism is rank crowding / excessive core-level restriction:
with CPU affinity free, all eight local MPI ranks see the same broad scheduled
cpuset. A core-place policy plus binding can make independent rank-local
OpenMP runtimes choose overlapping physical core places, producing severe
cross-rank contention. This is consistent with the historical single-node
failure mode.

However, TASK-009 did **not** capture an actual runtime enumeration of Intel
OpenMP's instantiated place list, so that exact crowding pattern remains a
mechanistic explanation rather than directly observed placement proof. What is
directly established is:

> `OMP_PLACES=cores` is catastrophically unsafe under the current free-rank
> launcher/cpuset contract, regardless of TRUE/CLOSE/SPREAD.

Retained Step-C policy:

```text
OMP_PLACES = omitted
OMP_PROC_BIND = omitted

effective installed-launcher policy:
OMP_PLACES = sockets
OMP_PROC_BIND = TRUE
```

---

## 5. Retained host-runtime configuration

TASK-009 closes the coordinated CPU/OpenMP portion of Phase 3A/3B for the
current geometry with:

```text
OMP_NUM_THREADS = 4

--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted

OMP_PLACES omitted
OMP_PROC_BIND omitted

effective launcher defaults:
  OMP_PLACES=sockets
  OMP_PROC_BIND=TRUE
```

Interpretation boundaries:

- T=4 is the retained representative of a 4–8-thread plateau, not a uniquely
  proven optimum.
- CPU free and broad loose placement are effectively tied; free is retained
  because it is simpler.
- socket TRUE/CLOSE/SPREAD are effectively tied; package-default omission is
  retained because it is simpler.
- `OMP_PLACES=cores` is strongly rejected under this launcher/cpuset.

---

## 6. Dependency checkpoint

### E18 — N / refinement work -> host runtime/locality

**Host-runtime validation is complete at N=429056, but the N operating point
must now be reopened.**

The reason is not a small OMP winner. The material result is the new verified
IR regime:

```text
TASK-008 C0a at N=429056: IR = 1.57 s
TASK-009 A8 at N=429056:  IR = 0.29 s
LU remains 7.76 s
```

The old Phase-1 N decision was driven heavily by the rise in IR above
N=429056. Because host runtime now changes that exact scoring term
dramatically, the previous N optimum cannot be assumed invariant.

This is the reverse consequence of E18: once host runtime materially changes
IR/LU, the useful N balance must be rechecked.

### E19 — CPU/memory affinity <-> OpenMP policy

**CPU/OpenMP portion: resolved with direct coordinated evidence.**

TASK-009 establishes:

- broad free/loose CPU territory is safe;
- narrow private CPU slices are harmful primarily through IR;
- socket-level OpenMP placement is safe;
- core-level placement is catastrophic.

E19 should therefore be promoted from `UNCERTAIN` to
`OBSERVED + MECHANISTIC` for the CPU/OpenMP interaction.

**Memory-affinity checkpoint:** no immediate memory-affinity task is required.

The retained host policy remains CPU-free and socket-level, i.e. it does not
introduce a new NUMA pinning structure. TASK-007 already found no benefit from
explicit memory affinity under the retained identity GPU map, and TASK-009
shows that broad same-NUMA CPU territory itself provides no advantage over
free placement. There is no new locality mechanism strong enough to justify a
memory-affinity resweep now.

Retain:

```text
--mem-affinity omitted
```

Reopen only if a later CPU/GPU mapping, N/residency regime, or grid change
materially changes host-memory locality.

### E20 / E21 — host runtime and N/residency -> DGEMV

**Technically reopened, but not the next experiment.**

The host-runtime contract changed materially, so the old DGEMV result is no
longer universally transferable. However, at the current point:

```text
IR = 0.29 s
IR/LU = 0.037
```

Refinement is now only a very small fraction of runtime. A DGEMV optimization
has little available end-to-end upside here.

More importantly, N itself must be revalidated first. If the new host runtime
allows a larger N and IR becomes material again, DGEMV economics will change
with that new refinement workload.

Decision:

> Keep E20/E21 open but defer DGEMV until the N/residency operating point is
> reclosed.

### E07 / E09 / E14 / E15 — consequences if N moves

A material new N winner will trigger:

- **E07:** NB revalidation;
- **E09:** process grid/order revalidation if local geometry/regime changes
  materially;
- **E14/E15:** residency/headroom re-evaluation;
- **E18:** light OMP revalidation at the new N if refinement workload becomes
  materially different;
- **E37:** LU scheduling reopening if LU geometry changes materially.

Do not execute those in the same next task. First determine whether N actually
moves.

### E12 / E13 / Phase 4 communication

Still deferred. The current grid/placement remain the controls until the
upstream N operating point is reclosed. Starting transport tuning before that
would risk optimizing communication for a geometry that immediately changes.

---

## 7. Proposed next step

### Reopen N under the verified retained host-runtime contract

The next experiment should be a **bounded N re-sweep**, not DGEMV and not
Phase-4 communication.

Fix:

```text
NB = 3072
grid = 4x4 row
gpu-affinity = identity
cpu-affinity = omitted
mem-affinity = omitted
ucx-affinity = omitted / automatic

OMP_NUM_THREADS = 4
OMP_PLACES = omitted
OMP_PROC_BIND = omitted
# explicitly forward/verify OMP_NUM_THREADS on all 16 ranks

all current residency / precision / scheduling / communication controls fixed
```

Recommended first-pass N candidates:

```text
429056   # current control / high-device-residency edge
454656   # first historical host-residency transition point
504832   # moderate host-resident FP64 region
556032   # larger-N / higher-LU region
606208   # upper previously-valid coarse point
```

Why this range:

1. The prior N optimum was selected because increasing N improved LU but made
   IR grow quickly.
2. TASK-009 has changed the IR regime without changing LU at N=429056.
3. Therefore the old tradeoff may shift toward larger N.
4. These five points deliberately span the known FP64 residency transition and
   previously valid larger-N region without approaching the historical
   host-memory cliff near N=700k.
5. Running the old anchors again under the **verified** host-runtime contract
   directly answers whether larger credited work can now exploit the higher LU
   throughput without paying the former IR penalty.

Run all five sequentially in one allocation. Monitor correctness, LU, IR,
IR/LU, host memory, device headroom, and the exact verified OpenMP environment.

Do not extend beyond 606208 adaptively in the same task. If performance is
still clearly rising at 606208 with safe headroom, use the analysis to approve
a separate upper extension.

After this N re-sweep:

- if N remains near 429056, host runtime can be considered closed and E20/DGEMV
  can be judged against the now-small IR budget;
- if N moves materially upward, apply E07/E09/E14/E15/E18 before proceeding
  downstream.

**Human decision state:** TASK-009 analysis complete. N re-sweep proposed only;
no execution is authorized by this analysis.
