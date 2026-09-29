# 3×4 GAAS HPL-MxP Analysis

This file is the persistent analysis record for HPL-MxP tuning on the **3 GAAS nodes × 4 H200 GPUs/node** topology.

## 1. Phase-0 Baseline

The immutable original baseline is `3x4-GAAS-baseline_v1` from `TASK-3X4-000`.

### 1.1 Result

| Field | Value |
|---|---|
| Attempt | `3x4-GAAS-baseline_v1` |
| PBS job | `73926.gaas` |
| Queue / project | `gpu_as` / `hpc_ebslee` |
| Nodes | `hpc-gaas-g14` + `hpc-gaas-g10` + `hpc-gaas-g09` |
| Node condition | No pristine trio available; selected least-contended eligible trio, all with light-active co-tenants |
| Topology | 3 nodes × 4 H200 GPUs = 12 MPI ranks |
| Resource shape | 4 GPUs + 48 CPUs + 1000 GB per node |
| N | 480000 |
| NB | 3072 |
| Process grid | 4 × 3 |
| Process order | column |
| GPU affinity | `0:1:2:3` |
| Effective OMP threads | 48/rank, inherited from PBS; not tuned |
| Effective OMP placement | rank environment unset; wrapper defaults `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE` |
| Sloppy type | FP16 |
| MPI panel broadcast | 0 |
| Separate GEMM stream | 1 |
| Prioritize TRSM | 0 |
| Prioritize factorization | 0 |
| Correctness | **PASSED** |
| Normalized residual | `3.784553E-04` |
| IR iterations | 3 |
| LU time | 16.52 s |
| IR time | 19.99 s |
| IR/LU | **1.210** |
| LU performance | `4.4619e+06` GFLOP/s |
| Overall performance | **`2.0193e+06` GFLOP/s** |
| Per-GPU overall performance | `168271.05` GFLOP/s |
| Host memory consumption MAX | 144.203 GB/process |
| Device memory consumption MAX | 79.561 GB/process |
| Device headroom during solve | ~58.608 GB/process |
| Minimum host headroom observed around matrix generation | ~2.097 GB/process |
| PBS exit status | 0 |
| Baseline status | **Immutable 3×4-GAAS original baseline** |

Primary evidence:

- `experiments/3x4-GAAS/baseline/outputs/3x4-GAAS-baseline_v1.o`
- `experiments/3x4-GAAS/baseline/outputs/3x4-GAAS-baseline_v1.e`
- `experiments/3x4-GAAS/baseline/outputs/3x4-GAAS-baseline_v1.rankmap.log`
- `experiments/3x4-GAAS/baseline/outputs/3x4-GAAS-baseline_v1.presubmit_pbsnodes.log`
- `experiments/3x4-GAAS/baseline/README.md`
- `results/metrics.csv`

### 1.2 Analysis

#### The baseline is healthy and is not in the historical catastrophic 3×4 regime

The run completed normally, the residual converged cleanly, the final normalized residual passed, rank mapping was correct, and the validated bond-excluded NCCL HCA policy reached all 12 ranks.

The new score (`2.0193e+06` GFLOP/s) is also close to the historical clean-node diagnostic result at `N=480000` (`1.9842e+06` GFLOP/s, about +1.77% difference). This is **not** a controlled performance comparison because the old run used different NB/grid/order, test/monitor protocol, communication state, and node conditions. It is useful only as a sanity check: the new campaign baseline is in the expected clean-performance order of magnitude and is not suffering the old ~50× collapse.

The historical contaminated `3x4-baseline_v1` remains mechanism evidence only and is not a campaign denominator.

#### End-to-end performance is strongly limited by iterative refinement

The Phase-0 decomposition is:

```text
LU time = 16.52 s
IR time = 19.99 s
IR/LU   = 1.210
```

The iterative-refinement phase is therefore **longer than LU itself**.

Using the same campaign approximation used in the 2×8 analysis,

```text
R_MxP ≈ P_LU / (1 + T_IR / T_LU)
```

gives approximately:

```text
4.4619e6 / (1 + 19.99/16.52) ≈ 2.019e6 GFLOP/s
```

which matches the reported `2.0193e+06` score. The final score is therefore almost completely explained by the LU-versus-IR balance.

This is an important starting condition for the 3×4 campaign: **a tuning change that improves LU but increases IR can easily be a net loss**, and reducing IR has unusually high leverage on this baseline.

#### Phase 0 shows a clear reason to test FP64 device residency

The baseline uses `fill-device=0`. At `N=480000` it reports:

```text
device consumption MAX ≈ 79.561 GB/process
device headroom during solve ≈ 58.608 GB/process
host consumption MAX ≈ 144.203 GB/process
minimum host headroom around matgen ≈ 2.097 GB/process
```

So the baseline simultaneously has:

- substantial unused HBM during the solve; and
- very tight host-memory headroom during matrix generation.

That is exactly the regime in which the blueprint's Phase-1A `N + fill-device` experiment is informative. The current run does **not** establish that more residency will improve performance, but it shows that the residency choice is materially active rather than irrelevant.

For 12 ranks and approximately 139.8 GiB usable HBM/GPU, the blueprint heuristic gives:

```text
N_pivot = sqrt(ranks × GPU_memory_bytes × 0.85 / 8)
        ≈ 437,480
```

The Phase-0 `N=480000` point is therefore about **110% of the heuristic pivot**. A 70–120% coarse Phase-1A sweep naturally spans both sides of the expected residency transition.

#### The 4×3 column geometry is a good control, not yet an optimum

The observed global rank layout is node-contiguous:

```text
g14: ranks 0-3
g10: ranks 4-7
g09: ranks 8-11
```

With `NPROW=4, NPCOL=3, nporder=column`, each four-rank process column maps cleanly onto one physical four-GPU node. Process rows therefore span the three nodes.

That makes `4×3 column` a mechanically clean Phase-0 control, but there is no comparative evidence yet that this row/column communication pattern is best. E09/E10 keep grid/order fully open after Phase 1 geometry is established.

#### The inherited OMP=48 state is a major provisional caveat

PBS supplied `OMP_NUM_THREADS=48` to every rank. Four MPI ranks share a 48-CPU node allocation, so the environment permits far more OpenMP threads than the simple 12-CPU/rank resource share would suggest.

This is **not evidence that OMP=48 is bad on 3×4**; no controlled 3×4 OMP comparison has been run. However, the combination of:

- IR/LU = 1.210;
- four ranks sharing 48 allocated CPUs/node; and
- strong prior evidence that host runtime can materially alter refinement cost

means the host-runtime state must remain explicitly provisional.

For the immediate Phase-1A N/residency sweep, keep this effective host-runtime state fixed so the experiment does not change N, residency, and OMP simultaneously. E18 remains open, and host runtime must be revalidated later after the N/NB operating regime is bounded.

#### Node contention must be treated as a comparison covariate

No pristine eligible trio existed. The immutable baseline was therefore measured on g14+g10+g09 with light-active co-tenants.

The baseline remains immutable by campaign design, but future percentage gains can be affected by cleaner or dirtier node conditions. Therefore future 3×4 experiments should:

- record live `pbsnodes -aSj` / co-tenant state;
- prefer one fixed allocation for all candidates in a sweep; and
- include an in-sweep control when practical.

The immutable baseline column remains required, but causal decisions should primarily use same-allocation candidate/control differences when node conditions differ.

### 1.3 Baseline denominator

All future 3×4 campaign percentage columns use:

```text
Original baseline = 2.0193e+06 GFLOP/s
```

unless a later human-approved workflow explicitly changes campaign policy. The baseline itself is not recreated simply because a cleaner node trio becomes available.

## 2. Dependency checkpoint

The checkpoint is **performed**.

| Dependency | State after Phase 0 | Decision |
|---|---|---|
| Physical topology → N/residency | Active | Proceed to Phase 1A; new 12-rank topology must establish its own residency regime. |
| E07: N → NB | Open | Keep `NB=3072` only as the provisional Phase-1A control; fully sweep NB after N/residency is bounded. |
| E08: NB → N/memory boundary | Pending | Mandatory checkpoint after Phase 1B if NB materially changes. |
| E09: N → grid/order | Open | Defer grid/order comparison until Phase 1 geometry is established. |
| E14/E15: N ↔ FP64 residency | **Directly relevant** | This is the immediate Phase-1A question. |
| E16: fill-device/Anq → fill buffer | Open downstream | Keep the package-default buffer fixed during N discovery; tune only after residency/N is understood. |
| E18: N/refinement work → host runtime | Open, high priority | Keep the baseline host runtime fixed during Phase 1A; revalidate OMP after the useful N/NB regime is established. |
| Communication / placement dependencies | Open downstream | The HCA exclusion is platform hygiene; MPI/NCCL policy, grid, affinity, and NIC placement are not yet optimized. |

Nothing in Phase 0 justifies jumping directly to NB, grid, placement, or communication tuning before the N/residency operating regime is measured.

## 3. Suggested next step

### Recommended next action: Phase 1A coarse N / FP64-residency sweep

Use `--fill-device 1` for the N-discovery arms and keep all other scientific controls fixed.

The heuristic pivot is approximately `N=437480`. A bounded 70–120% sweep, aligned approximately to 1024 where convenient, is:

| Arm | N | Approx. pivot fraction | Purpose |
|---|---:|---:|---|
| A | 306176 | 70.0% | Lower residency / LU-efficiency bound |
| B | 350208 | 80.1% | Lower-middle regime |
| C | 394240 | 90.1% | Approach residency transition |
| D | 437248 | 99.9% | Heuristic pivot |
| E | **480000** | 109.7% | Same N as immutable baseline; isolates the effect of enabling fill-device as much as node conditions permit |
| F | 525312 | 120.1% | Upper regime / headroom boundary probe |

In addition, if task walltime permits, run one **same-allocation in-sweep control** before the fill-device arms:

```text
N=480000
fill-device=0
```

with every other control identical to the immutable baseline. This does **not** replace or recreate the original baseline. Its purpose is to measure current allocation/node drift and give a same-allocation reference for the residency change.

Fixed provisional controls should remain:

```text
NB=3072
4×3 column
gpu-affinity=0:1:2:3
FP16
use-mpi-panel-broadcast=0
use-separate-stream-for-gemm=1
prioritize-trsm=0
prioritize-factorization=0
test-loop=1
skip-tests=0
monitor-gpu=0
NCCL_IB_HCA=mlx5_0,mlx5_1,mlx5_2,mlx5_3,mlx5_4,mlx5_5,mlx5_8,mlx5_9

effective provisional host runtime:
OMP_NUM_THREADS=48
OMP_PLACES / OMP_PROC_BIND left to the same wrapper defaults as Phase 0
```

Run all arms sequentially inside **one 3×4 allocation** on the least-contended eligible trio to minimize node-to-node variation. Preserve the live pre-submit contention snapshot and enough end-of-job node state to detect a major co-tenant change during the sweep.

For every N, collect:

- overall GFLOP/s and % vs immutable baseline;
- % vs the same-allocation control;
- LU GFLOP/s / LU time;
- IR time, iterations, residual trajectory, and IR/LU;
- device/host consumption and headroom;
- evidence of the FP64 residency transition;
- correctness;
- exact nodes and contention state.

Interpret the sweep through **end-to-end LU + IR balance**, not largest N or fastest LU alone. If the upper point becomes OOM/invalid, preserve it as the boundary and do not patch N automatically.

After this coarse sweep, refine around both the best end-to-end region and any distinct residency/IR transition at approximately 5% spacing. Only after Phase 1A closes should the 3×4 track proceed to NB tuning.

**Human decision state:** proposed only. No Phase-1A execution is authorized by this analysis.
