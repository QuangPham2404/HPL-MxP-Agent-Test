# 2x8-GAAS phase2a-grid-shape

TASK-004 Phase-2A bounded process-grid shape screen for the 2 GAAS nodes x 8
H200 GPUs HPL-MxP campaign: the three approved grid shapes run sequentially
inside one 2x8 allocation at the retained Phase-1 geometry `N=429056`,
`NB=3072`, and ONLY `nprow x npcol` varies. Every other scientific control
is fixed (tasks/TASK-004.md Section 1.4B) and is identical to the validated
TASK-003 controls. The `4x4` column grid is the same-protocol retained
Phase-1 control and runs first; one valid scored attempt per approved shape
is sufficient (tasks/TASK-004.md Sections 1.4A, 1.7.10).

**Status (2026-09-27): prepared — NOT yet submitted; no run has occurred
(no Run summary section exists yet).** Any submission must use a new
`ATTEMPT_TAG` and pass `-q gpu_as` or `-q gpu_ded` (the only authorized
queues).

## Structure

- `scripts/run_phase2a_grid_shape.pbs` — single reusable sweep PBS script
  (three candidates sequentially in one allocation; allocation-level
  rank-map probe before scored work; per-candidate evidence files; attempt
  tag comes from the `ATTEMPT_TAG` environment at submission)
- `outputs/` — per-candidate application `.out`/`.err`/`.status` evidence,
  the allocation-level rank-map log, and PBS `.o`/`.e` job evidence
  (tracked, never overwritten; every rerun gets a new attempt tag)

## Approved candidate set (TASK-004 Section 1.4A)

Execution order: `4x4` first as the same-protocol retained Phase-1 control,
then `2x8`, then `8x2`.

| order | grid (nprow x npcol) | role |
|---|---|---|
| 1 | 4x4 | same-protocol retained Phase-1 control |
| 2 | 2x8 | wider process-column count / smaller process-row count |
| 3 | 8x2 | larger process-row count / narrower process-column count |

All run with `--nporder column`. These three shapes are the complete
scientific candidate set for TASK-004; no `1x16`, `16x1`, row-order
variants, adaptive shapes, or any other grid candidate inside TASK-004
(Section 1.4A). Historical grid results under `experiments/2Nodes-8GPUs/`
and single-node grid analyses are context only; their numerical winners are
not transferred.

## Fixed scientific controls (only nprow x npcol varies)

```
N = 429056
NB = 3072
OMP_NUM_THREADS=8
--nporder column
--gpu-affinity 0:1:2:3:4:5:6:7
--sloppy-type FP16
--use-mpi-panel-broadcast 0
--use-separate-stream-for-gemm 1
--prioritize-trsm 0
--prioritize-factorization 0
--fill-device 1
--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Configuration supplied by the Strategic Analyst and approved by the Human
Leader in tasks/TASK-004.md Section 1.4B; Codex/workers did not derive,
optimize, or modify it. All controls not listed above (e.g.
`--fill-device-buffer-size`, `--Anq-device`, U-panel chunking, DGEMV
partitioning, CPU/memory affinity, OpenMP placement beyond the thread count,
communication policy, precision, GEMM kernel) retain the same installed
package/default behavior used in TASK-003, consistently for all three
candidates.

## Rank-map probe (TASK-004 Section 1.4C)

One lightweight 16-rank MPI mapping probe runs before the scored candidates
in each allocation, using the same 16 ranks, shared de-duplicated
`slots=8` hostfile, container MPI, `pbsdsh` bridge, and launcher daemon
flags as the scored launch; it emits, per rank, the global rank, hostname,
and local rank in the form `rank=<global>/<size> host=<hostname> local_rank=<local>/<local_size>`.
Evidence: `outputs/2x8-GAAS-phase2a-grid-shape_rankmap_<ATTEMPT_TAG>.log`.
The probe is diagnostic only and must not alter scientific controls; no
topology profiling or communication tracing is added. The script aborts
before scored work if the probe fails its mechanical check (nonzero exit,
not 16 rank lines, not 2 distinct hosts, or not 8 ranks per host) — a rerun
then needs a new `ATTEMPT_TAG`. Purpose: the later Strategic Analyst must
be able to reconstruct which logical grid rows/columns cross the node
boundary for each candidate under `nporder=column`. A `GRID_SUBSET` split
allocation includes its own probe (each allocation has its own rank-map
evidence).

## Per-candidate command

Identical for every candidate except `--nprow <NPROW> --npcol <NPCOL>`, at
fixed `--n 429056 --nb 3072`, launched inside the PBS job through the
validated Approach-1 container launcher (same contract as
TASK-001/TASK-002/TASK-003):

```bash
apptainer exec --nv \
  -B /opt/pbs:/opt/pbs \
  -B /var/spool/pbs:/var/spool/pbs \
  -B "$REPO_ROOT":"$REPO_ROOT" \
  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif \
  /usr/local/mpi/bin/mpirun -np 16 \
    --hostfile "$PWD/hostfile" \
    --mca plm_rsh_agent "$BRIDGE" \
    --mca plm_rsh_no_tree_spawn 1 \
    --mca plm_rsh_num_concurrent 1 \
    --mca routed direct \
    -x PATH -x LD_LIBRARY_PATH \
    --bind-to none \
    /workspace/hpl-mxp.sh \
      --n 429056 --nb 3072 --nprow <NPROW> --npcol <NPCOL> --nporder column \
      --gpu-affinity 0:1:2:3:4:5:6:7 --sloppy-type FP16 \
      --use-mpi-panel-broadcast 0 --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

with `<NPROW> x <NPCOL>` one of the three approved shapes (4x4, 2x8, 8x2)
and the only thing that changes between candidates; application stdout/stderr
is redirected to that candidate's `.out`/`.err` evidence file.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ngpus=8` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `01:30:00`, same validated request as the TASK-001/TASK-002/TASK-003 sweeps (TASK-003's six-candidate sequential sweep used `00:06:42` of `01:30:00`); may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by all candidates in the allocation |
| Process grid | varies per candidate — exactly {2x8, 4x4, 8x2}, `nporder=column` fixed (not auto-derived) |
| GPU affinity | `0:1:2:3:4:5:6:7` (node-local rank -> local GPU) |
| Rank-map probe | one lightweight 16-rank probe before scored work per allocation; see its section |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mechanically
mirrors `experiments/2x8-GAAS/phase1b-nb-screen/scripts/run_phase1b_nb_screen.pbs`
(TASK-003), which itself mirrors the TASK-002/TASK-001/TASK-000 scripts, for
container/MPI/orted/pbsdsh launcher, hostfile, resource request, accounting
project, bind mounts, daemon flags, module set, and pre/post health-snapshot
pattern. Only the approved grid-shape candidate set (at fixed N=429056,
NB=3072), the candidate order, the added allocation-level rank-map probe,
experiment/attempt identifiers, and task-section references differ.

## Sequential-sweep behavior

- The candidates run one at a time inside the single 2x8 allocation (same
  nodes for all candidates; reduces node/allocation variation and scheduler
  overhead, TASK-004 Section 1.4D).
- `4x4` runs first as the same-allocation same-protocol control before any
  new grid territory is entered; then `2x8`, then `8x2`.
- A candidate with a nonzero exit is recorded and the sweep continues with
  the next candidate (job exits nonzero overall if any failed).
- The script always attempts every candidate in the submitted set.
- Evidence guard: abort if any target `.out`/`.err`/`.status`/rankmap
  `.log` exists — reruns need a new `ATTEMPT_TAG`; existing evidence is
  never overwritten.
- Mid-run kill (e.g. walltime): that candidate keeps its `.out`/`.err` but
  has no `.status`, and later candidates were not run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query) are
  taken once around the whole sweep; per-candidate host/device memory
  evidence comes from the application's own memory-report lines in each
  `.out`.
- Rank-map probe before scored work (see its section); the script aborts
  before any scored candidate if the probe fails its mechanical check.
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-candidate attempt ID:
`2x8-GAAS-phase2a-grid-shape_grid<NPROW>x<NPCOL>_<ATTEMPT_TAG>` (e.g.
`2x8-GAAS-phase2a-grid-shape_grid4x4_v1`).

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| candidate status | `outputs/<attempt>.status` (attempt, experiment, PBS job ID, queue, nodes, N, NB, nprow, npcol, nporder, fixed-controls line, start/end timestamps, exit status, evidence paths) |
| rank-map log | `outputs/2x8-GAAS-phase2a-grid-shape_rankmap_<ATTEMPT_TAG>.log` |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase2a-grid-shape_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase2a-grid-shape_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names. `GRID_SUBSET` splits do not change the per-candidate ID
scheme; each submitted allocation is a separate sweep tag.

## Submission (from this directory; requires TASK-004 execution authorization)

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase2a-grid-shape_v1.o \
     -e outputs/2x8-GAAS-phase2a-grid-shape_v1.e \
     scripts/run_phase2a_grid_shape.pbs
```

Optional operational split across equivalent 2x8 allocations (TASK-004
Section 1.4D fallback; unchanged controls, new tag, only approved shapes):

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v2,GRID_SUBSET=2x8 8x2" \
     -o outputs/2x8-GAAS-phase2a-grid-shape_v2.o \
     -e outputs/2x8-GAAS-phase2a-grid-shape_v2.e \
     scripts/run_phase2a_grid_shape.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (as validated
for the Phase-0 probe, job 72591.gaas, and used by the TASK-001/TASK-002/
TASK-003 sweeps):

```bash
qsub -l select=host=<n1>:ngpus=8:ncpus=96:mem=2000GB+host=<n2>:ngpus=8:ncpus=96:mem=2000GB ...
```

`GRID_SUBSET` values outside the three approved shapes (and duplicates) are
rejected by the script; the candidate set cannot silently change.

## Mechanical feasibility context (arithmetic only)

The per-GPU FP64 device-matrix footprint under `--fill-device 1` is
`N^2 * 8 / 16` bytes, i.e. approximately 92.0 GB per GPU at `N=429056` —
identical for every candidate because N is fixed; the grid shape changes
logical block ownership, panel communicator geometry, and possibly
worst-rank local ownership/headroom, not the stored-matrix footprint; those
effects are observed from each candidate's application memory-report lines,
not predicted here. TASK-003 measured device memory available MIN 138.739
GB with post-matrix-generation headroom 2.767 GB at this N/NB with the 4x4
column grid. Mechanical derived values, not predictions or recommendations.

## Available baseline provenance (context only; no analysis)

| item | value |
|---|---|
| Retained Phase-1 operating point (TASK-003) | `2x8-GAAS-phase1b-nb-screen_nb3072_v1` (N=429056, NB=3072, 4x4 column), PBS job 72712.gaas, queue gpu_as, hpc-gaas-g12 + hpc-gaas-g15, PASSED, exit 0; overall `5.5381e+06` GFLOP/s; LU 7.98 s / `6.5950e+06` GFLOP/s; IR 1.53 s / 3 iterations; device headroom after matrix generation 2.767 GB; host consumption MAX 0.004 GB — this is the same-protocol 4x4 column control for TASK-004 |
| TASK-002 evidence | `2x8-GAAS-phase1a-n-refine_n429056_v1`, PBS job 72688.gaas, overall `5.6091e+06` GFLOP/s, PASSED; evidence `experiments/2x8-GAAS/phase1a-n-refine/` |
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, overall `4.8037e+06` GFLOP/s, PASSED; evidence `experiments/2x8-GAAS/baseline/` |
| Phase-0 topology evidence | `experiments/2x8-GAAS/baseline/scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated, per TASK-004 Section 1.4E |

Both the retained operating point and the original baseline used the same
scored-run protocol as this sweep (`--skip-tests 0 --monitor-gpu 0`); the
original baseline is the campaign percentage denominator for 2x8-GAAS
comparisons. TASK-004 does not rerun it. Ranking, baseline-percentage
tables, and retention decisions are reserved for the authorized
`ANALYSE_RESULTS` step (tasks/TASK-004.md Sections 1.4G, 1.10).

## Expected output markers and validation criteria

A candidate is valid only when its `outputs/<attempt>.out` contains:

- normal HPL-MxP output: internal tests completed (`--skip-tests 0`: GEMM /
  MPI / NCCL broadcast / pdgemv sections), `****** Matrix Generation ******`,
  `LU seconds: AVG = ...`, `Solver iteration <k>, L-infinite residual = ...`
  lines, and a measured performance result (not a stop during
  initialization or internal tests);
- the normalized-residual line
  `||Ax-b||_oo / (EPS * (||A||_oo * ||x||_oo + ||b||_oo) * N) = <finite value> ...... PASSED`
  (`FAILED` or a non-finite value is invalid);
- `GFLOPS = <value>, per GPU = <value>` (the overall score to report) and
  `LU GFLOPS = <value>` (excluding iterative refinement);
- the memory lines `Per process host memory consumption MAX = ..., available MIN = ...`
  and the device equivalent.

Job-level: PBS completes, the `.o`/`.e` files exist, and `.status` records
`exit_status=0`. With `--monitor-gpu 0`, GPU-monitoring output is
unavailable by design. A candidate with an OOM, `FAILED`, or invalid result
is preserved as evidence, is not ranked as a valid performance point, and
should have its phase of failure identified when possible (TASK-004
Sections 1.4F, 1.7.12-13). Do not classify success from exit status alone.

## Evidence paths

- `outputs/` — per-candidate `.out`/`.err`/`.status`, the allocation-level
  rank-map log, and PBS `.o`/`.e`
- `scripts/run_phase2a_grid_shape.pbs` — the sweep script (header documents
  purpose, working directory, inputs, outputs, and assumptions)
