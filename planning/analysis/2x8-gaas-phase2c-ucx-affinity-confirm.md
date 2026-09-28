# Analysis — 2x8 GAAS Phase 2C UCX-Affinity Confirmation

Analysis ID: `2x8-gaas-phase2c-ucx-affinity-confirm`

This analysis covers **TASK-008** and closes the unresolved UCX device-affinity
question left by TASK-007.

Source evidence:

- `tasks/TASK-008.md`
- `experiments/2x8-GAAS/phase2c-ucx-affinity-confirm/`
- `planning/analysis/2x8-gaas-phase2bc-placement-locality.md`
- `planning/dependency-graph/README.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `results/metrics.csv`

All three arms ran sequentially in one allocation, PBS job `73068.gaas`, on
`hpc-gaas-g13 + hpc-gaas-g15`. Both hosts passed the same required topology
gate. All arms passed correctness with normalized residual
`1.416310E-05` and three refinement iterations.

## 1. Results

| Arm | UCX device policy | Overall GFLOP/s | LU s | LU GFLOP/s | IR s | IR/LU |
|---|---|---:|---:|---:|---:|---:|
| C0a | automatic/default | **5.6421e+06** | 7.76 | 6.7818e+06 | **1.57** | 0.202 |
| C1 | explicit PIX-paired HCA | 5.5794e+06 | **7.75** | 6.7936e+06 | **1.69** | 0.218 |
| C0b | automatic/default repeat | **5.6285e+06** | **7.75** | **6.7967e+06** | **1.61** | 0.208 |

Bracket deltas:

```text
C1 vs C0a overall = -1.11%
C1 vs C0b overall = -0.87%
C1 vs mean(C0a,C0b) = -0.99%

C0b vs C0a = -0.24%
```

The two automatic controls are tightly bracketed: only 0.24% apart. The PIX
arm lies below both controls.

IR behavior is also directionally consistent:

```text
C0a IR = 1.57 s
C1  IR = 1.69 s
C0b IR = 1.61 s

C1 vs C0a IR = +7.64%
C1 vs C0b IR = +4.97%
C1 vs mean automatic IR = +6.29%
```

LU is effectively identical across all three arms:

```text
7.75-7.76 s
6.782-6.797e+06 GFLOP/s
```

Memory/residency behavior is unchanged:

```text
host consumption MAX = 0.004 GB/process
device consumption MAX = 135.254 GB/process
post-matgen device headroom = 2.767 GB/process
```

## 2. Analysis

### 2.1 TASK-008 rejects the apparent TASK-007 PIX-affinity gain

TASK-007 had measured:

```text
automatic = 5.5828e+06, IR 1.64 s
PIX       = 5.6949e+06, IR 1.47 s
PIX gain  = +2.01%
```

but the identical TASK-007 control itself drifted by as much as about 2.68%
over the allocation. That is why TASK-008 used an immediate bracket.

TASK-008 produces the opposite result:

```text
auto before = 5.6421e+06
PIX         = 5.5794e+06
auto after  = 5.6285e+06
```

The two controls differ by only 0.24%, while PIX is about 1% below their mean.
Therefore the earlier +2.01% result does not reproduce when local drift is
controlled.

The important conclusion is not that PIX pinning is strongly harmful. Its
roughly 1% loss is still small. The stronger conclusion is:

> There is no repeatable performance evidence that explicit PIX-paired UCX
> device affinity improves this operating point.

Because the automatic policy is simpler and the explicit policy has not shown
a robust gain, automatic UCX should be retained.

### 2.2 The earlier IR improvement also fails to reproduce

The previous rationale for PIX affinity was especially interesting because the
TASK-007 gain came almost entirely from IR:

```text
TASK-007:
auto IR = 1.64 s
PIX IR  = 1.47 s
```

TASK-008 reverses that:

```text
auto IR bracket = 1.57 / 1.61 s
PIX IR          = 1.69 s
```

So the proposed mechanism — deterministic rank-to-PIX-HCA routing improving
refinement-side locality/progress — is not supported as a stable effect.

This strengthens the decision to close the flag rather than continuing to
repeat it.

### 2.3 LU confirms UCX device affinity is not an LU-critical control here

LU remains essentially unchanged:

```text
C0a 7.76 s
C1  7.75 s
C0b 7.75 s
```

That is consistent with the TASK-007 observation that UCX device affinity did
not materially affect the main LU path under the current
`--use-mpi-panel-broadcast 0` policy.

The current UCX-affinity knob is therefore not a productive standalone tuning
dimension for this geometry.

### 2.4 HCA traffic evidence remains consistent with automatic multi-rail use

TASK-007 already showed automatic UCX using all eight HCAs with balanced
aggregate transmitted volume.

TASK-008 again records substantial traffic growth on all eight HCAs for every
arm. Nothing in the counter evidence suggests that explicit PIX affinity is
unlocking otherwise-idle rails.

The counters are aggregate and cannot prove rank-specific routing quality, but
combined with the bracketed performance result there is no remaining evidence
that explicit HCA pinning is worth retaining.

### 2.5 Cross-job score movement is not used for the decision

TASK-008 used g13+g15 rather than g12+g15, and available host-memory readings
also differ materially from TASK-007 even though actual HPL-MxP host
consumption stays at 0.004 GB/process.

Therefore TASK-007 versus TASK-008 absolute score movement is not treated as a
UCX effect.

The closure decision relies only on the within-TASK-008 bracket.

## 3. Phase-2C closure

**Phase 2C is closed.**

Retain:

```text
UCX device affinity = automatic/default
--ucx-affinity omitted
```

Do not carry the explicit PIX HCA string into the retained configuration.

Retained physical-placement state is now:

```text
GPU affinity = 0:1:2:3:4:5:6:7
memory affinity = omitted
CPU affinity = omitted/free   # still provisional pending E19 host-runtime work
UCX affinity = omitted/automatic
```

TASK-007's B2 medium CPU mask remains a hypothesis, not a retained setting.

## 4. Dependency checkpoint

- **E03 — topology/resources -> placement:** satisfied for the current
  topology family. Exact topology strings remain machine-specific and must be
  remapped on materially different hardware.
- **E11 — grid/order -> rank/GPU/NIC placement:** satisfied. Physical
  placement work triggered by retained 4x4 row is now closed.
- **E12 — grid/order -> panel transport:** remains open. Phase 4 must
  revalidate communication policy for retained 4x4 row.
- **E13 — placement -> panel transport:** now ready downstream because the
  retained placement is established. Phase 4 must use automatic UCX device
  selection as the placement control unless a transport experiment itself
  requires an explicit device constraint for diagnostic reasons.
- **E18 — N/refinement work -> host runtime/locality:** active. The retained
  N/IR regime requires host-runtime validation.
- **E19 — CPU/memory affinity -> OpenMP policy:** **the next active strong
  dependency.** TASK-007 showed CPU-mask sensitivity under OMP=8, so
  CPU-affinity and OMP thread/place/bind must be tuned as one coordinated
  host-runtime group rather than independently.
- **E20 — host runtime/locality -> DGEMV partition:** defer until the
  OpenMP/CPU host-runtime group is closed.
- **E25/E26/E29:** remain downstream of Phase-4 transport and later scheduling
  work.
- **N/NB/grid/residency:** remain closed; TASK-008 changed none of them and
  preserved the same device-memory regime.

## 5. Proposed next step

**Next action: begin the coordinated Phase-3A/3B host-runtime revalidation
required by E19.**

Do not simply set TASK-007 B2 medium and then sweep OpenMP independently.

Use a staged bounded design:

### Stage A — establish the OpenMP thread-count region with CPU affinity free

Keep:

```text
CPU affinity = omitted
memory affinity = omitted
UCX affinity = omitted
```

Sweep a small set of thread counts spanning underprovisioning to the current
8-thread point and the available per-rank CPU budget. The allocated cpuset is
96 CPUs/node for 8 ranks/node, i.e. an average budget of 12 CPUs/rank before
runtime/helper headroom is considered.

The goal is to identify a useful OMP-count plateau, not a single noisy winner.

### Stage B — re-test explicit CPU isolation jointly with retained OMP counts

For the one or two useful OMP counts from Stage A, compare:

```text
CPU free
TASK-007-style medium non-overlapping rank-local masks
```

The medium masks should be recalculated if the chosen OMP count changes. They
must leave deliberate headroom for MPI/UCX/runtime activity; do not reuse the
8-CPU strict policy.

### Stage C — only then test OMP_PLACES / OMP_PROC_BIND

Test only legal place/bind combinations whose effective place lists have been
verified under the retained CPU policy. Do not transfer the old single-node
socket/cores winner blindly.

This staging directly answers the E19 question:

> Is the apparent benefit of medium CPU affinity due to private rank-local
> cores, to spare progress capacity relative to OMP_NUM_THREADS, or to the
> interaction between CPU masks and OpenMP binding?

Do not move to DGEMV or Phase-4 communication tuning until this host-runtime
group is closed.

**Human decision state:** Phase 2C closed; coordinated host-runtime tuning is
proposed only and requires a new approved task before execution.
