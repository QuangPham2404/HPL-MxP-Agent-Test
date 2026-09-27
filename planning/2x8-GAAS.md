# 2×8 GAAS HPL-MxP Analysis

This file is the persistent analysis record for HPL-MxP tuning on the **2 GAAS nodes × 8 H200 GPUs/node** topology.

## 1. Phase-0 Baseline

The immutable original baseline is `2x8-GAAS-baseline_n700k_v1` from TASK-000.

### Baseline result

| Field | Value |
|---|---|
| Attempt | `2x8-GAAS-baseline_n700k_v1` |
| PBS job | `72602.gaas` |
| Nodes | `hpc-gaas-g12` + `hpc-gaas-g15` |
| Queue / project | `gpu_as` / `hpc_ebslee` |
| Topology | 2 nodes × 8 H200 GPUs = 16 MPI ranks |
| N | 700000 |
| NB | 3072 |
| Process grid | 4 × 4 |
| Process order | column |
| OMP threads | 8 |
| Sloppy type | FP16 |
| MPI panel broadcast | 0 |
| Separate GEMM stream | 1 |
| Prioritize TRSM | 0 |
| Prioritize factorization | 0 |
| Correctness | **PASSED** |
| Normalized residual | `2.520608E-04` |
| Iterative-refinement iterations | 3 |
| LU time | 29.17 s |
| Iterative-refinement time | 18.44 s |
| LU performance | `7.8390e+06` GFLOP/s |
| Overall performance | **`4.8037e+06` GFLOP/s** |
| Per-GPU overall performance | `300228.24` GFLOP/s |
| Host memory available MIN before matrix generation | 219.944 GB/process |
| Host memory available MIN after matrix generation | 4.168 GB/process |
| Device memory available MIN after matrix generation | 14.005 GB/process |
| PBS exit status | 0 |
| Baseline status | **Immutable 2×8-GAAS original baseline** |

Primary evidence:

- `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.o`
- `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.e`
- `experiments/2x8-GAAS/baseline/README.md`
- `results/metrics.csv`

### Initial observations

#### LU versus iterative-refinement balance

The baseline has a substantial gap between LU-only performance and the final end-to-end score:

- LU: `7.8390e+06` GFLOP/s
- Overall: `4.8037e+06` GFLOP/s
- `T_IR / T_LU = 18.44 / 29.17 ≈ 0.632`

Using the campaign approximation

```text
R_MxP ≈ P_LU / (1 + T_IR / T_LU)
```

gives approximately `4.803e+06` GFLOP/s, essentially matching the reported `4.8037e+06` GFLOP/s.

This makes the Phase-0 decomposition clean: future improvements must be evaluated against both **LU throughput** and **iterative-refinement cost**. Improving LU alone can be cancelled by a slower refinement phase.

#### Memory boundary

`N=700000` is valid, but it is already close to the host-memory boundary. After Matrix Generation, the minimum reported system-memory headroom fell to only **4.168 GB/process**. Device-memory headroom remained larger at **14.005 GB/process**.

The previous `N=737280` attempt was killed by host-memory exhaustion, so the current baseline establishes that the practical N boundary for this resource shape lies above 700000 but below 737280. Any future upward N exploration should therefore be treated as a memory-boundary experiment rather than assumed safe tuning headroom.

### Baseline denominator

All future percentage improvements for the new 2×8-GAAS campaign should use:

```text
Baseline overall performance = 4.8037e+06 GFLOP/s
```

unless a later human-approved workflow explicitly replaces the campaign baseline.
