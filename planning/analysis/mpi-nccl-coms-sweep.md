# Analysis: MPI/NCCL panel-broadcast and U-panel chunk study

## 1. Concise summary

This is a **communication-behavior study**, not an optimization sweep. Two
orthogonal controls that shape panel traffic — the MPI-versus-NCCL broadcast
mix (`--use-mpi-panel-broadcast`) and the U-panel chunk granularity
(`--u-panel-chunk-nbs`) — were each varied in isolation to observe how the
benchmark's end-to-end GFLOP/s and its LU / iterative-solver phase split
respond to changing panel-communication load.

Phase 1 swept `--use-mpi-panel-broadcast` over `0, 25, 50, 75, 100` (chunk held
at `8`). Phase 2 swept `--u-panel-chunk-nbs` over `4, 8, 16` at the two
Phase-1 winners (`75` and `50`). All runs used the fixed best config
(`N=491520`, `NB=3072`, `2x4` row, fill-device-on with buffer and register-step
both `2048`).

The headline result is that **both parameters are effectively flat**: the full
15-run study spans a ~2.6% band whose width is dominated by same-node drift,
not by either swept parameter. The MPI-NCCL mix binds only the LU phase by a
fraction of a percent (at the low-NCCL end `0` loses a little; `75` is a minor
peak), and the U-panel chunk size has no resolvable effect at all inside this
HVSwitch-connected single node.

## 2. Scope and evaluation criteria

- Source revision: commit `8fbccd2` (study) and its successors; NVIDIA HPL-MxP
  v26.02 container (`hpc-benchmarks_26.02.sif`).
- Environment: one GAAS node (`hpc-gaas-g13` for all 15 runs), 8× H200 GPUs,
  8 MPI ranks (`mpirun -np 8 --bind-to none`), `OMP_NUM_THREADS=8`,
  `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`.
- Workload (fixed): `--n 491520 --nb 3072 --nprow 2 --npcol 4 --nporder row`,
  `--gpu-affinity 0:1:2:3:4:5:6:7`, `--fill-device 1
  --fill-device-buffer-size 2048 --cuda-host-register-step 2048`, `--skip-tests
  1`, GPU monitoring enabled.
- Swept variables: Phase 1 `--use-mpi-panel-broadcast ∈ {0,25,50,75,100}`
  (chunk 8); Phase 2 `--u-panel-chunk-nbs ∈ {4,8,16}` at broadcast 75 and 50.
- Performance metric: reported end-to-end HPL-MxP GFLOP/s, plus the LU and
  iterative-solver phase seconds exposed in the raw output.
- Correctness requirement: `PASSED` verification and finite residual within the
  fixed `1e-12` tolerance. All 15 runs passed with residual `1.609604E-04`.
- Baseline for percentages: the original project baseline `baseline-sweep_v1`
  at `1.4432e+06` GFLOP/s.

## 3. Data and analysis

### 3.1 Phase 1 — broadcast policy (chunk 8)

| broadcast | GFLOP/s | LU s | Solver s | % vs baseline (1.4432e+06) | attempt |
|---:|---:|---:|---:|---:|---|
| 50 (control a) | 2.2771e+06 | 20.43 | 14.33 | +57.78% | `bc_baseline_a` |
| 0 (NCCL) | 2.3045e+06 | 21.05 | 13.30 | +59.68% | `bc_0` |
| 25 | 2.3179e+06 | 20.63 | 13.53 | +60.61% | `bc_25` |
| 50 | 2.3291e+06 | 20.60 | 13.39 | +61.38% | `bc_50` |
| 75 | 2.3570e+06 | 20.35 | 13.23 | +63.32% | `bc_75` |
| 100 (MPI) | 2.3251e+06 | 20.57 | 13.48 | +61.11% | `bc_100` |
| 50 (control b) | 2.3372e+06 | 20.50 | 13.37 | +61.95% | `bc_baseline_b` |

The two bracketing controls (`2.2771e+06` → `2.3372e+06`) already drift by
**+2.6%** across the single node-matched job, so the sweep must be read against
that floor. Within that band, GFLOP/s rises gently from NCCL (`0` = 2.3045e+06)
to a soft peak at `75` (2.3570e+06) and eases off at `100` (2.3251e+06). The
LU phase is the only phase that moves: it shortens from ~21.05 s at `0` to
~20.35 s at `75`, while the iterative solver is essentially fixed
(~13.2–13.5 s). The solver is insensitive to the broadcast mix; the whole
signal is a small LU-side effect.

### 3.2 Phase 2 — U-panel chunk (broadcast 75 and 50)

| broadcast | chunk | GFLOP/s | LU s | Solver s | % vs baseline | attempt |
|---:|---:|---:|---:|---:|---:|---|
| 50 (control a) | 8 | 2.3118e+06 | 20.53 | 13.71 | +60.19% | `chunk_baseline_a` |
| 75 | 4 | 2.3259e+06 | 20.59 | 13.45 | +61.16% | `chunk4_a` |
| 75 | 8 | 2.3403e+06 | 20.46 | 13.37 | +62.16% | `chunk8_a` |
| 75 | 16 | 2.3390e+06 | 20.33 | 13.51 | +62.07% | `chunk16_a` |
| 50 | 4 | 2.3391e+06 | 20.58 | 13.26 | +62.08% | `chunk4_b` |
| 50 | 8 | 2.3430e+06 | 20.43 | 13.36 | +62.35% | `chunk8_b` |
| 50 | 16 | 2.3113e+06 | 20.62 | 13.63 | +60.15% | `chunk16_b` |
| 50 (control b) | 8 | 2.3496e+06 | 20.50 | 13.20 | +62.80% | `chunk_baseline_b` |

The Phase-2 controls again drift `+2.6%` (`2.3118e+06` → `2.3496e+06`). All
eight runs sit in a `2.3113e+06 … 2.3496e+06` (~1.6%) band with no monotonic
chunk trend: at broadcast `75` the chunk values are 2.3259 / 2.3403 / 2.3390
(4/8/16) and at `50` they are 2.3391 / 2.3430 / 2.3113. LU time is flat at
~20.3–20.6 s and solver time ~13.2–13.7 s regardless of chunk. Chunk granularity
does not move the critical path on this node.

### 3.3 Cross-phase control spread

The same `50/8` configuration was measured six times across both phases
(`bc_baseline_a`, `bc_50`, `bc_baseline_b`, `chunk_baseline_a`, `chunk8_b`,
`chunk_baseline_b`): 2.2771, 2.3291, 2.3372, 2.3118, 2.3430, 2.3496 e+06 (a
~3.2% spread, mean ≈ 2.325e+06). This is the noise floor against which every
single-run difference above must be judged, and it explains why the swept
parameters register as flat.

## 4. Insights gained

1. **The MPI↔NCCL mix is a minor, LU-only lever on this single node.** Moving
   from all-NCCL (`0`) toward MPI-inclusive policies improves GFLOP/s by only
   ~2.3% at most (`0` = 2.3045e+06 vs `75` = 2.3570e+06), and the effect is
   carried entirely by the LU phase (21.05 s → 20.35 s). The iterative solver
   is indifferent to the transport mix.
2. **`--u-panel-chunk-nbs` is effectively inert here.** Across `4, 8, 16` at two
   broadcast values, GFLOP/s, LU time, and solver time are all flat to within
   the same-node control drift. The documented chunk constraint
   `((N/NB)/npcol)/chunk < 20` is satisfied by all three values (5, 10, 2.5),
   so none is in a pathological regime — which may be why the difference vanishes.
3. **Same-node drift (~2.6%) exceeds the effect size of both parameters.** The
   NVSwitch-connected 8-GPU node makes panel/collective latency a small
   residual cost, so neither a finer nor a coarser communication granularity
   changes the end-to-end rate observably.
4. **The best single point (`2.3570e+06`, broadcast 75) is not separable** from
   the bracketing `50/8` controls (`2.3372e+06`, `2.3496e+06`) given the drift;
   it must not be treated as an optimization win.
5. All 15 runs passed with a constant finite residual (`1.609604E-04`), so none
   of these communication settings destabilizes the refinement stage.

## 5. Suggested next section

Because the panel-broadcast and U-panel-chunk levers are flat on the current
single-node NVSwitch setup, further tuning of these two flags at `N=491520` is
not justified by this data. Remaining study/optimization directions that the
trace evidence (`optimization_plan_1.md`) and M1 synthesis still point to, in
priority order:

1. **Dependency priorities** (`--prioritize-trsm`, `--prioritize-factorization`):
   the trace's longest waits are panel-readiness stalls, a different mechanism
   from transport mix — a more targeted next experiment for the LU critical
   path.
2. **A matched re-run of the single broadcast winner (`75`) vs `50`** with
   repetitions, if isolating a sub-noise transport effect is still desired; a
   follow-up Nsight trace of `75` vs `50` would show whether the LU-side gain
   is a lower collective-latency tail or noise.
3. **Sloppy precision (`--sloppy-type` FP8/FP4)** remains the largest
   unexplored throughput lever, but is a correctness-sensitive direction
   outside this communication study.

The recommended concrete step is to leave these two flags at their defaults
(effectively `50`/`8`) and move to the dependency-priority experiment, since the
communication mix and chunk granularity have been shown to be non-first-order on
this platform.

## 6. Provenance

- Structured source of truth: `results/metrics.csv` (experiment
  `mpi-nccl-coms-sweep`, 15 attempts).
- Experiment README and per-attempt tables:
  `experiments/mpi-nccl-coms-sweep/README.md`.
- Raw outputs: `experiments/mpi-nccl-coms-sweep/outputs/*.{o,e}`.
- Run scripts: `run_broadcast_sweep.pbs` (job 53508),
  `run_chunk_sweep.pbs` (job 53546), node `hpc-gaas-g13`.
- Tuning definitions: `HPL_MxP_TuningParam_Guide.md`.
- Prior communication/priority plan: `planning/optimization_plan_1.md`.
- Analysis date: 2026-08-27.