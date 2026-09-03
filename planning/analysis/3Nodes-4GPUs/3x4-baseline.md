# Analysis: 3x4 Baseline

## 1. Concise summary

The first valid HPL-MxP run on the 3-node × 4-GPU topology is established as
the **new-system original baseline**: `3x4-baseline_v1` (N=480000, NB=1024,
`3×4` row grid, 12 ranks). It passed verification with a finite residual, but
its performance is exceptionally low — the timed phases are dominated by
inter-node communication not present on the previous single-node 8×H200
topology.

## 2. Scope and evaluation criteria

- Config: `N=480000`, `NB=1024`, `nprow=3 × npcol=4`, `nporder=row`,
  `--gpu-affinity 0:1:2:3`, `--skip-tests 1`.
- Environment: `hpc-benchmarks_26.02.sif`, container `mpirun` +
  `rsh_pbsdsh_container.sh` pbsdsh bridge (Approach-1), 3 nodes × 4 H200 GPUs.
- Correctness: `PASSED` with residual `3.402630E-04` (finite).
- Comparison reference: prior single-node 8×H200 campaign (original baseline
  `baseline-sweep_v1` = `1.4432e+06` GFLOPS; later N≈480k/NB=1024 points
  ≈ `1.76–1.83e+06` GFLOPS).
- Note: `N` and `NB` are baseline *inputs*, not tuned values; this analysis
  records the run and its anomaly, not a ranking.

## 3. Data and analysis

Result for `3x4-baseline_v1` (job `57232.gaas`):

| Metric | Value |
|---|---|
| Verification | PASSED (`3.402630E-04`) |
| Overall GFLOPS | `4.0092e+04` |
| LU-only GFLOPS | `4.5117e+04` |
| Nodes | `hpc-gaas-g09 g13 g15` |

Phase breakdown (HPL-MxP internal timers):

| Phase | AVG seconds |
|---|---:|
| Constructor | 0.36 |
| RNG | 282.28 (MAX 421 on g09) |
| Sp | 128.92 |
| matgen (total) | 551.81 |
| **LU** | **1634.20** |
| Iterative solver | 205.11 |

The **LU phase accounts for ~27 min** of the ~40 min runtime. At comparable
`N`/`NB`, the single-node 8×H200 campaign reached ~`1.76–1.83e+06` GFLOPS
(≈44× higher) with LU on the order of seconds, not minutes.

## 4. Insights gained

- The baseline is **~44× slower** than the single-node 8×H200 at comparable
  `N`/`NB`, and the deficit is concentrated in the **LU phase** (1634 s),
  consistent with an inter-node communication bottleneck rather than compute.
- GPU utilization observed during the run was very low (0–26%), supporting a
  communication/launch-wall explanation rather than saturated Tensor Cores.
- RNG/matgen also shows rank imbalance (`MAX 421 s` vs `AVG 282 s`, skewed to
  `hpc-gaas-g09`), but it is not the dominant cost.
- This is consistent with the known multinode launch path (pbsdsh/container
  bridge transport): the validated spawn works, but inter-node panel
  collectives on this transport are far slower than NVSwitch-connected
  single-node (cross-node NVLink/IB).

## 5. Suggested next section

Investigate the multinode communication path (blueprint Phase 4) before any
tuning: confirm the actual inter-node transport (UCX/NIC, CUDA-aware MPI /
GPU-direct), measure per-rank imbalance and panel/collective time, and compare
the container pbsdsh bridge against any faster site-supported transport. This
is a recommendation for review, not an authorization to execute.

## 6. Provenance

- Source: `results/metrics.csv` (`3x4-baseline` / `3x4-baseline_v1`).
- Raw outputs: `experiments/3x4-baseline/outputs/3x4-baseline_v1.{o,e}`.
- Analysis date: 2026-09-03.