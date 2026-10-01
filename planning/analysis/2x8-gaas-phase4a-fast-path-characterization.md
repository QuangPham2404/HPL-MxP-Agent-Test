---
task_id: TASK-2X8-013
title: 2x8 GAAS Phase 4A Communication Fast-Path Characterization
analysis_id: 2x8-gaas-phase4a-fast-path-characterization
status: COMPLETE
parent_task: TASK-2X8-012
created: 2026-10-01
last_updated: 2026-10-01
---

# Analysis — 2x8 GAAS Phase 4A Communication Fast-Path Characterization

## 1. Summary

TASK-2X8-013 successfully characterizes the retained 2x8 communication fast
path without tuning it.

The main conclusion is:

> The retained automatic communication stack is already using the intended
> high-performance GPU-direct paths. Phase 4B is therefore a policy/critical-
> path optimization problem, not a broken-transport repair problem.

The clean A0 reference is:

```text
overall = 6.5324e+06 GFLOP/s
LU      = 7.77 s / 6.7741e+06 GFLOP/s
IR      = 0.29 s
IR/LU   = 0.037
PASSED
```

This is +35.99% over the immutable 2x8 baseline (4.8037e+06 GFLOP/s) and is
consistent with the retained Phase-3 control band.

The diagnostic A1 clone is effectively identical:

```text
A0 = 6.5324e+06
A1 = 6.5354e+06
difference = +0.046%

LU = 7.77 s in both
IR = 0.29 s in both
```

The per-HCA traffic shape is also effectively identical between A0 and A1.
Therefore the info-level UCX/NCCL instrumentation did not materially perturb
the communication behavior and A1 is representative for path diagnosis.

A1 establishes:

- MPI uses the UCX PML.
- `UCX_TLS` and `UCX_NET_DEVICES` are unset/automatic.
- Inter-node UCX selects `rc_mlx5`, not TCP.
- Large GPU-buffer transfers expose rendezvous zero-copy protocol rows.
- Small-message protocol rows include `cuda_copy`; there are no frag-host
  staging rows.
- NCCL uses `IBext_v11`, not Socket.
- All 128 observed inter-node NCCL channel lines are tagged `GDRDMA`:
  GDRDMA fraction = 128/128 = 1.00.
- The RoCE bond is visible as a read-only/OOB device but is not used by the
  measured NCCL data channels.
- All eight physical 400-Gb HCAs are active; there are no new
  error/discard/recovery counters.

A2-U and A2-N were correctly skipped: the transfer-level evidence is already
conclusive.

Phase 4A is therefore closed.

## 2. Execution validity and Phase-4 reference

Both arms ran sequentially in PBS job `76519.gaas` on the same pristine
`hpc-gaas-g14 + hpc-gaas-g15` allocation.

| Arm | Role | Overall GFLOP/s | LU s | LU GFLOP/s | IR s | IR/LU | Residual |
|---|---|---:|---:|---:|---:|---:|---:|
| A0 | clean reference | 6.5324e+06 | 7.77 | 6.7741e+06 | 0.29 | 0.037 | 1.416310E-05 |
| A1 | diagnostic clone | 6.5354e+06 | 7.77 | 6.7803e+06 | 0.29 | 0.037 | 1.416310E-05 |

Both arms:

- exited 0;
- PASSED correctness;
- used 16 ranks, 8/node;
- verified `OMP_NUM_THREADS=4` on every rank;
- retained N=429056, NB=3072, 4x4 row;
- retained identity GPU mapping;
- retained automatic UCX device policy;
- retained panel-broadcast=0 and U-panel chunk=8;
- retained the full Phase-3 memory/runtime stack.

A0 is only 0.02% above the earlier TASK-2X8-012 R0a control and remains within
about 0.4% of the Phase-3D retained-control range. There is no sign that moving
into Phase 4 changed the upstream operating regime.

The large constructor difference (A0 1.18 s versus A1 0.20 s) is not reflected
in LU, IR, score, memory, or fabric traffic and is most consistent with
first-arm initialization/warm-up. It is not evidence that diagnostic logging
improves performance.

## 3. MPI/UCX — AUTO is already on the fast path

A1's effective UCX environment is intentionally unconstrained:

```text
UCX_TLS         = unset
UCX_NET_DEVICES = unset
UCX_LOG_LEVEL   = info
UCX_PROTO_INFO  = y
```

The important observation is what AUTO selected:

```text
PML = ucx
inter-node transport = rc_mlx5
TCP inter-node lanes = 0
large GPU-buffer protocol = rendezvous zero-copy
frag-host staging rows = 0
```

The captured configuration contains 388 inter-node UCX configuration lines and
2001 `rc_mlx5` references. Transfer-level protocol evidence contains 625
zero-copy rows and 48 small-message `cuda_copy` rows.

### Interpretation

This closes the basic fast-path question.

The automatic UCX policy is not accidentally choosing TCP or a host-staged
large-message path. It already resolves large inter-node GPU communication to
mlx5 RDMA with zero-copy rendezvous.

The `cuda_copy` rows should not be interpreted as evidence that the main
large-message path is host-staged. They are small-message/eager CUDA-memory
protocol components; critically, there are no `frag host` rows and the
large-message rendezvous rows are zero-copy.

Therefore:

> Phase 4B should not treat explicit `UCX_TLS` as a way to "enable" the fast
> path. The fast path is already active under AUTO.

An explicit transport restriction can still change protocol/lane selection,
progress behavior, or eliminate alternatives, so a small controlled transport
comparison remains reasonable. But its expected role is refinement, not
repair.

## 4. NCCL — GPUDirect RDMA is fully engaged in the observed data channels

A1 shows:

```text
network backend = IBext_v11
Socket channels = 0
inter-node IBext channel lines = 128
GDRDMA-tagged lines = 128
GDRDMA fraction = 1.00
```

The data-channel lines explicitly use forms such as:

```text
via NET/IBext_v11/<device>/GDRDMA
```

This is stronger evidence than the separate capability messages saying that an
HCA supports GPUDirect RDMA.

The plugin enumerates the eight physical IB HCAs:

```text
mlx5_0
mlx5_1
mlx5_2
mlx5_3
mlx5_4
mlx5_5
mlx5_8
mlx5_9
```

It also sees `mlx5_bond_0` as a RoCE read-only/OOB device, but the observed
data-channel lines use the physical IB devices; there are no bond/RoCE mixed-
link warnings and no Socket fallback.

### Interpretation

With retained `--use-mpi-panel-broadcast=0`, the incumbent NCCL-oriented
panel path is not suffering from a missing-GDR or Socket-fallback problem.

This materially changes how Phase 4B should be framed:

> The next experiment compares two healthy communication mechanisms/policies.
> It is not testing NCCL against a known-broken MPI path or trying to rescue a
> broken NCCL path.

The current NCCL control is therefore a strong reference that any MPI-heavy
panel policy must beat through better latency/readiness/overlap, not merely by
turning on GPUDirect.

## 5. Fabric behavior — all rails work; the asymmetry is structured

### 5.1 Global accounting is coherent

For A0, summed across both nodes:

```text
total TX raw = 141,830,747,015
total RX raw = 141,857,358,949
difference   < 0.02%
```

Per-HCA transmit counters on one node closely mirror the corresponding receive
counters on the other node.

This is strong evidence that the snapshots are capturing the two-node
application traffic coherently.

### 5.2 g14 is balanced

A0 g14 TX shares:

```text
12.44 / 12.54 / 12.43 / 12.54 /
12.44 / 12.54 / 12.64 / 12.42 %
```

```text
CV = 0.58%
max / mean = 1.011
```

So all eight rails are carrying essentially equal outgoing volume from g14.

### 5.3 g15 TX is asymmetric, but this is not evidence of four failed rails

A0 g15 TX shares:

```text
mlx5_0-3     = 7.23 / 7.53 / 7.67 / 7.67 %
mlx5_4/5/8/9 = 17.44 / 17.28 / 17.58 / 17.58 %
```

The second four HCAs carry about 2.32x the outgoing volume of the first group
in aggregate.

However, the receive side mirrors this pattern exactly across the opposite
node, all links remain ACTIVE at 400 Gb/s, and no error/discard/recovery
counters move. A1 reproduces the same shares essentially byte-for-byte.

Therefore the correct interpretation is:

> This is deterministic application/rank/communicator traffic direction or
> ownership, not evidence that AUTO failed to use half the fabric.

All eight physical rails are active and carry data. The asymmetry alone does
not justify reopening `--ucx-affinity`.

### 5.4 `port_xmit_wait` is a useful Phase-4 diagnostic signal

Every physical HCA records a nonzero `port_xmit_wait` delta.

The higher group is consistently `mlx5_4/5/8/9` on both nodes, roughly
0.31-0.33M raw counter increments per arm, while several `mlx5_0-3` values
are lower.

Because the raw counter time/unit interpretation is not resolved in the
evidence, do not convert these values into a stall-time percentage.

Still, the relative pattern is useful:

- it is stable across A0 and A1;
- it occurs without link errors;
- on g14 the higher-wait group exists even though TX bytes are balanced.

That suggests real, repeatable flow-control/backpressure asymmetry somewhere in
the communication path rather than simple traffic-volume imbalance.

This is **not enough to change HCA affinity now**. It is, however, an excellent
secondary metric for Phase 4B: if a panel/transport policy materially improves
LU and simultaneously changes/reduces the relevant `port_xmit_wait`
pattern, that would strengthen the communication-path explanation.

## 6. Important timing limitation

The application emits:

```text
MPI U broadcast seconds
NCCL U broadcast seconds
MPI L2 broadcast seconds
NCCL L2 broadcast seconds
```

but these lines appear under:

```text
****** Testing HPL MxP components ******
```

before matrix generation.

They validate that the component paths run and expose rank imbalance, but they
are **not a direct decomposition of the 7.77-s LU phase**.

Therefore Phase 4B must make decisions primarily from:

1. LU time / LU GFLOP/s;
2. end-to-end GFLOP/s;
3. rank-level timing/skew when the main run exposes it;
4. HCA traffic/wait/error changes;
5. transport/channel evidence.

Do not add the component-test broadcast times together and interpret the sum as
the communication fraction of LU.

## 7. Dependency checkpoint

| Dependency | 4A result | State after 4A |
|---|---|---|
| E06 topology/resources -> panel transport | Both stacks proven healthy on the actual 2-node fabric | Still open for policy optimization in 4B |
| E12 grid/order -> panel transport | 4x4-row application path characterized; traffic is structured/deterministic | Still open until panel policy is swept |
| E13 rank/GPU/NIC placement -> panel transport | Automatic placement uses all eight physical rails; no fabric fault; no need to reopen UCX affinity | Characterization satisfied; transport policy still open |
| E22 NB -> panel transport | Fast path characterized at retained NB=3072 | 4B must stay at NB=3072 |
| E23/E24 -> U-panel chunk | No chunk change in 4A | Keep Phase 4C downstream |
| E25 panel transport -> chunk interpretation | Not triggered yet | Revisit only after 4B selects/retains transport policies |
| E26/E29 transport/readiness/grid -> scheduling | No scheduling change in 4A | Keep Phase 5 downstream |

No new dependency edge is required from TASK-2X8-013.

The g15 directional rail asymmetry and the HCA-group `port_xmit_wait`
pattern are observations to track, not reasons to reopen upstream placement.

## 8. Phase-4A closure and proposed next step

Phase 4A is complete.

Retain as the Phase-4 control:

```text
UCX affinity = omitted / automatic
UCX_TLS = automatic / unset
use-mpi-panel-broadcast = 0
u-panel-chunk-nbs = 8
```

The strongest new information for Phase 4B is that AUTO UCX already selects
`rc_mlx5` zero-copy for relevant large GPU-buffer traffic and NCCL already
uses GDRDMA on all observed inter-node channel lines.

Therefore the next experiment should prioritize **panel-broadcast policy**.

Recommended Phase-4B structure:

1. Keep the entire Phase-3 stack fixed.
2. Keep AUTO UCX as the principal control.
3. Screen the bounded, mechanism-distinct
   `--use-mpi-panel-broadcast` policies first / as the main interaction axis.
4. Include at most one explicitly constrained rc_mlx5-based UCX transport
   family where it provides a real comparison to AUTO; validate the exact
   installed-release syntax before execution.
5. Do not perform a broad `UCX_TLS` search. AUTO already reaches the intended
   mlx5 zero-copy path, so a large transport sweep has weak expected value.
6. Retain multiple policies only if they differ in LU time, scaling/rank
   balance, or fabric behavior, even when overall score ties.
7. Record the same per-HCA TX/RX/`port_xmit_wait` metrics in 4B.
8. Stop before U-panel chunk tuning; Phase 4C should use only the retained 4B
   policies.

The key Phase-4B question is now:

> Can changing the panel mechanism/cadence improve LU readiness or overlap
> compared with the already-healthy NCCL/GDR control?

That is a much narrower and cleaner problem than the pre-4A uncertainty about
whether the stack was on the correct transport at all.

**Human decision state:** TASK-2X8-013 analysis complete. Phase 4A is closed.
A bounded Phase-4B panel-policy / minimal-transport interaction experiment is
recommended only; no new execution is authorized.
