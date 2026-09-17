# 2Nodes-8GPUs experiment area

HPL-MxP full-node N sweep on 2 GAAS nodes x 8 H200 GPUs (16 ranks, one rank
per GPU, process grid 4x4, row order). Single experiment family, small number
of arms: find the maximum N before the memory wall (OOM) and record
performance along the way.

**Status (2026-09-17):** N-sweep COMPLETE (wall found, see below). The
follow-up basic parameter sweep (NB + grid/order) is **planned and
user-approved but ON HOLD** — see "Planned next experiment" below for the
hand-off.

## Structure

- `scripts/run_hplmxp_n_sweep.pbs` — parametrized PBS run script
- `outputs/` — attempt-specific PBS `.o`/`.e` evidence (tracked, never
  overwritten; every retry gets a new attempt label)

## Protocol (user-authorized 2026-09-17)

1. Smoke test at `N=500000`. If it does not succeed, stop and report.
2. On success, step `N` by `+100000` per run (600000, 700000, ...) until OOM.
   The run that OOMs is recorded as the memory wall; the series ends there.
3. Any non-OOM failure stops the series for manual inspection (Track 2).

## Fixed parameters

- `NB=3072` (user decision 2026-09-17), `nporder=row`
- Grid auto-derived: 16 ranks -> `nprow=4 npcol=4`
- `--gpu-affinity 0:1:2:3:4:5:6:7` (node-local rank -> local GPU)
- `--skip-tests 1` plus GPU monitoring flags (project convention)
- Project `hpc_ebslee`; queue `gpu_ded` by default, `gpu_as` allowed (both
  approved for this campaign; chosen per submission based on node
  availability and recorded per attempt)
- Resources: `select=2:ngpus=8`, `place=scatter`, `walltime=00:45:00`

## Launch contract

Validated Approach-1 multinode launch (see
`multi-node-test/GAAS_MULTINODE_SETUP.md`): container `mpirun` +
`multi-node-test/rsh_pbsdsh_container.sh` bridge, `/opt/pbs` and
`/var/spool/pbs` bound into the container, de-duplicated hostfile with
`slots=8`, fixed daemon flags (`plm_rsh_no_tree_spawn=1`,
`plm_rsh_num_concurrent=1`, `routed=direct`, `--bind-to none`), and
`-x PATH -x LD_LIBRARY_PATH` so remote ranks resolve NVML. One job at a
time; no concurrent multinode submissions.

## Submission (from this directory)

```bash
qsub -q gpu_ded -v "N=500000,ATTEMPT=2x8-n-sweep_n500k_v1" \
     -o outputs/2x8-n-sweep_n500k_v1.o -e outputs/2x8-n-sweep_n500k_v1.e \
     scripts/run_hplmxp_n_sweep.pbs
```

## Validation

A run is valid only when PBS completes, the raw outputs exist, HPL-MxP
reports `PASSED` with a finite residual within tolerance, and a finite
`GFLOPS` value is present. OOM evidence: exit 137 / cgroup OOM kill /
CUDA out-of-memory / `bad_alloc`. Expected wall (host-RAM cgroup ~2000 GB
per node, FP64 matrix in host RAM, N^2*8/2 bytes per node): ~700000-800000.

## Run summary

| attempt | N | job id | queue | nodes | result | GFLOPS | per-GPU GFLOPS |
|---|---|---|---|---|---|---|---|
| 2x8-n-sweep_n500k_v1 | 500000 | 67383.gaas | gpu_ded | g01+g22 | PASSED (residual 3.06e-04), exit 0, walltime 00:02:04, mem ~996 GB/node | 2.9133e+06 | 1.8208e+05 |
| 2x8-n-sweep_n600k_v1 | 600000 | 67393.gaas | gpu_ded | g01+g22 | PASSED (residual 3.13e-04), exit 0, walltime 00:02:40, mem ~1360 GB/node | 3.4441e+06 | 2.1525e+05 |
| 2x8-n-sweep_n700k_v1 | 700000 | 67397.gaas | gpu_ded | g01+g22 | PASSED (residual 2.73e-04), exit 0, walltime 00:03:19, mem ~1845 GB/node | 4.1061e+06 | 2.5663e+05 |
| 2x8-n-sweep_n800k_v1 | 800000 | 67404.gaas | gpu_ded | g01+g22 | FAILED: device CUDA OOM (exit 102, 36 s) | - | - |

**Series complete (2026-09-17).** Memory wall for 2x8 is between N=700000 and
N=800000, and it is the **GPU HBM**, not host RAM: at N=800000 every rank
aborts with `cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory)`
(matrix.cpp:298) — per-process device consumption MAX 161.7 GB vs 138.7 GB
available on each H200, while host RAM still had ~238 GB headroom per process.
Implied device-matrix ceiling: N ≈ sqrt(139.8 GB x 16 GPUs / 4 B) ≈ 747000.
Peak performance: N=700000, GFLOPS = 4.1061e+06 (2.5663e+05 per GPU).

## Runtime error-patching history

- `2x8-n-sweep_n800k_v1` (job 67404.gaas, g01+g22): definitive memory wall,
  not a defect. All 16 ranks aborted with device `cudaMalloc ... = 2 (out of
  memory)` at matrix.cpp:298 during startup (exit 102, 36 s). No patch
  attempted; recorded as the series terminal condition per the authorized
  protocol. Raw evidence: `outputs/2x8-n-sweep_n800k_v1.{o,e}`.

## Planned next experiment (ON HOLD): basic parameter sweep

Approved plan, put on hold by the user on 2026-09-17 before any submission.
Nothing has been run for this sweep; `scripts/run_hplmxp_basic_sweep.pbs`
does not exist yet and must be created first.

Fixed config (same as the N sweep): `N=700000` (2x8 peak), 16 ranks,
`--gpu-affinity 0:...:7`, package defaults elsewhere (broadcast 50, chunk 8),
`--skip-tests 1` + GPU monitoring, project `hpc_ebslee`, queue `gpu_ded`
(fallback `gpu_as`), `walltime=00:45:00`. Control = existing
`2x8-n-sweep_n700k_v1` (NB=3072, 4x4 row, 4.1061e+06 GFLOPS, g01+g22) —
user chose to reuse it instead of fresh control/repeat runs; record allocated
nodes per run to flag drift (cross-node noise 1-2.6%).

### Phase A — NB sweep, full bracket from 1024 (grid 4x4 row)

| attempt | NB | source |
|---|---|---|
| `2x8-nb-sweep_nb1024_v1` | 1024 | new |
| `2x8-nb-sweep_nb2048_v1` | 2048 | new |
| *(reference)* | 3072 | **existing** `n700k_v1` = 4.1061e+06 |
| `2x8-nb-sweep_nb4096_v1` | 4096 | new |
| `2x8-nb-sweep_nb5120_v1` | 5120 | new |
| `2x8-nb-sweep_nb6144_v1` | 6144 | new |
| `2x8-nb-sweep_nb7168_v1` | 7168 | new (device-OOM risk: ~17 GB HBM free/GPU at N=700k) |
| `2x8-nb-sweep_nb8192_v1` | 8192 | only if not already stopped |

Stop rule: two consecutive points clearly below the running peak (>~2%),
mirroring the 1x8 nb-sweep stop at 7168→8192; any OOM/FAILED is a definitive
axis stop (recorded as the wall, not retried).

### Phase B — grid/order sweep at the Phase-A-winning NB

| attempt | grid | order |
|---|---|---|
| `2x8-grid-sweep_2x8row_v1` | 2x8 | row |
| `2x8-grid-sweep_2x8col_v1` | 2x8 | col |
| `2x8-grid-sweep_8x2row_v1` | 8x2 | row |
| `2x8-grid-sweep_8x2col_v1` | 8x2 | col |
| *(reference if NB stays 3072)* | 4x4 | row |
| `2x8-grid-sweep_4x4col_v1` | 4x4 | col |

If Phase A picks NB != 3072, the 4x4-row point is run fresh too (6 new runs).
Node-mapping context: 2x8 row keeps process rows node-local; 2x8 col keeps
process columns node-local; 4x4 spans nodes on both communicators.

### Mechanics and rules for the resuming session

- New parametrized script `scripts/run_hplmxp_basic_sweep.pbs`: identical
  Approach-1 launch, but explicit `NB`, `NPROW`, `NPCOL`, `NPORDER` via
  `qsub -v` (do not modify the existing `run_hplmxp_n_sweep.pbs`). Submit
  from this experiment directory:
  `qsub -q gpu_ded -v "N=700000,NB=4096,NPROW=4,NPCOL=4,NPORDER=row,ATTEMPT=..." -o outputs/$ATTEMPT.o -e outputs/$ATTEMPT.e scripts/run_hplmxp_basic_sweep.pbs`
- One job at a time; PASSED + finite residual + GFLOPS gate per run; retrieve
  `.o/.e`; append `results/metrics.csv` (experiment ids `2x8-nb-sweep`,
  `2x8-grid-sweep`); update the run-summary table with % vs the 4.1061e+06
  control; pathspec-limited commit/push; remote pull with the move-aside
  pattern for untracked outputs (see progress/2026-09-17-progress_s3.md).
- Dependency checkpoint after each phase (E07/E10: NB<->grid coupling;
  E22/E23: NB moves reopen broadcast/chunk conclusions) — record it in this
  README.
- Do not submit anything without user confirmation of scope; the hold was
  user-initiated.

### Recorded follow-up direction (not yet authorized)

From the 1x8 campaign analysis (`planning/PLANS.md`, dependency graph), the
top unapplied 1x8 winners for 2x8, ranked by expected transfer, are:
(1) `OMP_NUM_THREADS=8` + `OMP_PLACES=sockets` + `OMP_PROC_BIND=TRUE`
(+5.15% on 1x8); (2) `--prioritize-factorization 1` (+3.5% e2e / +6.6% LU,
targets the 2x8 weak spot: per-GPU LU efficiency is -29% vs tuned 1x8);
(3) `--fill-device 1` with buffer 1024-2048 MB (~+2.3%, correctness-gate the
buffer). These are recommendations only; not execution permission.
