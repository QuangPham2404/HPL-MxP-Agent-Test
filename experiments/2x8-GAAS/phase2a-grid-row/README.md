# 2x8-GAAS phase2a-grid-row

TASK-005 Phase-2A row-order complement for the 2 GAAS nodes x 8 H200 GPUs
HPL-MxP campaign: the three TASK-004 grid shapes run sequentially inside one
2x8 allocation at the retained Phase-1 geometry `N=429056`, `NB=3072`, with
`--nporder row` fixed and ONLY `nprow x npcol` varying. Every other
scientific control is fixed (tasks/TASK-005.md Section 1.4B) and is identical
to the validated TASK-004 controls except for the rank order. Preferred
execution order `4x4`, `2x8`, `8x2` mirrors TASK-004 and simplifies paired
comparison (tasks/TASK-005.md Sections 1.4A, 1.7); one valid scored attempt
per approved shape is sufficient (tasks/TASK-005.md Sections 1.4A, 1.7.10).

**Status (2026-09-27): v1 sweep complete — all three approved row-order
grid shapes ran sequentially in PBS job `72802.gaas` (queue `gpu_as`,
project `hpc_ebslee`) with candidate `exit_status=0` and `PASSED`
verification; see Run summary.** Any rerun must use a new `ATTEMPT_TAG`,
pass `-q gpu_as` or `-q gpu_ded` (the only authorized queues), and never
overwrite existing evidence.

## Structure

- `scripts/run_phase2a_grid_row.pbs` — single reusable sweep PBS script
  (three candidates sequentially in one allocation; allocation-level
  rank-map probe before scored work; per-candidate evidence files; attempt
  tag comes from the `ATTEMPT_TAG` environment at submission)
- `outputs/` — per-candidate application `.out`/`.err`/`.status` evidence,
  the allocation-level rank-map log, and PBS `.o`/`.e` job evidence
  (tracked, never overwritten; every rerun gets a new attempt tag)

## Approved candidate set (TASK-005 Section 1.4A)

Execution order: `4x4` first (mirrors TASK-004's execution order for paired
comparison), then `2x8`, then `8x2`.

| order | grid (nprow x npcol) | role |
|---|---|---|
| 1 | 4x4 | square grid; mirrors TASK-004's first candidate |
| 2 | 2x8 | wider process-column count / smaller process-row count |
| 3 | 8x2 | larger process-row count / narrower process-column count |

All run with `--nporder row`. These three shapes are the complete
scientific candidate set for TASK-005; no column-order scored reruns,
`1x16`, `16x1`, additional grid shapes, adaptive variants, or any other
grid/order candidate inside TASK-005 (Section 1.4A). TASK-005 is the
row-order half of the intended 3x2 grid/order matrix; no Phase-2A retention
decision is made from TASK-005 in isolation (Sections 1.1, 1.10).

## Fixed scientific controls (only nprow x npcol varies)

```
N = 429056
NB = 3072
OMP_NUM_THREADS=8
--nporder row
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
Leader in tasks/TASK-005.md Section 1.4B; Codex/workers did not derive,
optimize, or modify it. All controls not listed above (e.g.
`--fill-device-buffer-size`, `--Anq-device`, U-panel chunking, DGEMV
partitioning, CPU/memory affinity, OpenMP placement beyond the thread count,
communication policy, precision, GEMM kernel) retain the same installed
package/default behavior used in TASK-004, consistently for all three
candidates.

## Rank-map probe (TASK-005 Section 1.4C)

One lightweight 16-rank MPI mapping probe runs before the scored candidates
in each allocation, using the same 16 ranks, shared de-duplicated
`slots=8` hostfile, container MPI, `pbsdsh` bridge, and launcher daemon
flags as the scored launch; it emits, per rank, the global rank, hostname,
and local rank in the form `rank=<global>/<size> host=<hostname> local_rank=<local>/<local_size>`.
Evidence: `outputs/2x8-GAAS-phase2a-grid-row_rankmap_<ATTEMPT_TAG>.log`.
The probe is diagnostic only and must not alter scientific controls; no
topology profiling or communication tracing is added. The script aborts
before scored work if the probe fails its mechanical check (nonzero exit,
not 16 rank lines, not 2 distinct hosts, or not 8 ranks per host) — a rerun
then needs a new `ATTEMPT_TAG`. Purpose: the later Strategic Analyst must
be able to reconstruct which logical grid rows/columns cross the node
boundary for each candidate under `nporder=row`, jointly with the TASK-004
column-order evidence. A `GRID_SUBSET` split allocation includes its own
probe (each allocation has its own rank-map evidence).

## Per-candidate command

Identical for every candidate except `--nprow <NPROW> --npcol <NPCOL>`, at
fixed `--n 429056 --nb 3072`, launched inside the PBS job through the
validated Approach-1 container launcher (same contract as
TASK-001/TASK-002/TASK-003/TASK-004):

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
      --n 429056 --nb 3072 --nprow <NPROW> --npcol <NPCOL> --nporder row \
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
| Walltime | `01:30:00`, same validated request as the TASK-001/TASK-002/TASK-003/TASK-004 sweeps (TASK-004's three-candidate sequential sweep used `00:03:35` of `01:30:00`); may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by all candidates in the allocation |
| Process grid | varies per candidate — exactly {4x4, 2x8, 8x2}, `nporder=row` fixed (not auto-derived) |
| GPU affinity | `0:1:2:3:4:5:6:7` (node-local rank -> local GPU) |
| Rank-map probe | one lightweight 16-rank probe before scored work per allocation; see its section |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mechanically
mirrors `experiments/2x8-GAAS/phase2a-grid-shape/scripts/run_phase2a_grid_shape.pbs`
(TASK-004), which itself mirrors the TASK-003/TASK-002/TASK-001/TASK-000
scripts, for container/MPI/orted/pbsdsh launcher, hostfile, resource
request, accounting project, bind mounts, daemon flags, module set, and
pre/post health-snapshot pattern. Only the rank order (`--nporder row`
instead of `column`), the experiment/attempt identifiers, and the
task-section references differ.

## Sequential-sweep behavior

- The candidates run one at a time inside the single 2x8 allocation (same
  nodes for all candidates; reduces node/allocation variation and scheduler
  overhead, TASK-005 Section 1.4D).
- `4x4` runs first, mirroring TASK-004's execution order so later paired
  row-vs-column comparison is straightforward; then `2x8`, then `8x2`.
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
`2x8-GAAS-phase2a-grid-row_grid<NPROW>x<NPCOL>_<ATTEMPT_TAG>` (e.g.
`2x8-GAAS-phase2a-grid-row_grid4x4_v1`).

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| candidate status | `outputs/<attempt>.status` (attempt, experiment, PBS job ID, queue, nodes, N, NB, nprow, npcol, nporder, fixed-controls line, start/end timestamps, exit status, evidence paths) |
| rank-map log | `outputs/2x8-GAAS-phase2a-grid-row_rankmap_<ATTEMPT_TAG>.log` |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase2a-grid-row_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase2a-grid-row_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names. `GRID_SUBSET` splits do not change the per-candidate ID
scheme; each submitted allocation is a separate sweep tag.

## Submission (from this directory; requires TASK-005 execution authorization)

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase2a-grid-row_v1.o \
     -e outputs/2x8-GAAS-phase2a-grid-row_v1.e \
     scripts/run_phase2a_grid_row.pbs
```

Optional operational split across equivalent 2x8 allocations (TASK-005
Section 1.4D fallback; unchanged controls, new tag, only approved shapes):

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v2,GRID_SUBSET=2x8 8x2" \
     -o outputs/2x8-GAAS-phase2a-grid-row_v2.o \
     -e outputs/2x8-GAAS-phase2a-grid-row_v2.e \
     scripts/run_phase2a_grid_row.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (as validated
for the Phase-0 probe, job 72591.gaas, and used by the TASK-001 through
TASK-004 sweeps):

```bash
qsub -l select=host=<n1>:ngpus=8:ncpus=96:mem=2000GB+host=<n2>:ngpus=8:ncpus=96:mem=2000GB ...
```

`GRID_SUBSET` values outside the three approved shapes (and duplicates) are
rejected by the script; the candidate set cannot silently change. `free`
alone does not establish queue eligibility; verify live Qlist/queue
eligibility before host-pinning (TASK-005 Section 1.7.7).

## Mechanical feasibility context (arithmetic only)

The per-GPU FP64 device-matrix footprint under `--fill-device 1` is
`N^2 * 8 / 16` bytes, i.e. approximately 92.0 GB per GPU at `N=429056` —
identical for every candidate because N is fixed; the grid shape changes
logical block ownership, panel communicator geometry, and possibly
worst-rank local ownership/headroom, not the stored-matrix footprint; those
effects are observed from each candidate's application memory-report lines,
not predicted here. TASK-004 measured device memory available MIN 138.739
GB with post-matrix-generation headroom 2.163-2.767 GB across its three
column-order candidates at this N/NB. Mechanical derived values, not
predictions or recommendations.

## Available baseline provenance (context only; no analysis)

| item | value |
|---|---|
| TASK-004 column-half counterparts (same protocol, same controls except `nporder=column`) | PBS job 72783.gaas, queue gpu_as, hpc-gaas-g12 + hpc-gaas-g15, all PASSED, exit 0; factual overall GFLOP/s as recorded: 4x4 column `5.4505e+06`, 2x8 column `5.3746e+06`, 8x2 column `5.5487e+06`; evidence `experiments/2x8-GAAS/phase2a-grid-shape/` |
| Retained Phase-1 operating point (TASK-003) | `2x8-GAAS-phase1b-nb-screen_nb3072_v1` (N=429056, NB=3072, 4x4 column), PBS job 72712.gaas, queue gpu_as, PASSED, exit 0; overall `5.5381e+06` GFLOP/s |
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, overall `4.8037e+06` GFLOP/s, PASSED; evidence `experiments/2x8-GAAS/baseline/` — the campaign percentage denominator for 2x8-GAAS comparisons |
| Phase-0 topology evidence | `experiments/2x8-GAAS/baseline/scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated, per TASK-005 Section 1.4E |

TASK-004, TASK-003, and TASK-000 all used the same scored-run protocol as
this sweep (`--skip-tests 0 --monitor-gpu 0`). TASK-005 does not rerun the
baseline. Ranking, baseline-percentage tables, row-vs-column comparison,
and retention decisions are reserved for the authorized `ANALYSE_RESULTS`
step over TASK-004 and TASK-005 jointly (tasks/TASK-005.md Sections 1.4G,
1.10).

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
should have its phase of failure identified when possible (TASK-005
Sections 1.4F, 1.7.12-13). Do not classify success from exit status alone.

## Run summary

One submitted attempt family (tag `v1`, PBS job `72802.gaas`, queue `gpu_as`,
project `hpc_ebslee`), executed on the host pair `hpc-gaas-g12` +
`hpc-gaas-g15` (2 nodes x 8 H200 GPUs, 16 MPI ranks, one rank/GPU). Script
start (first PBS `.o` timestamp): 2026-09-27T20:14:24+08:00. Execution tree:
the remote worktree referenced by every `.status` stdout/stderr path and by
the bridge path in the PBS `.o`,
`.codex-worktrees/TASK-005-bc312e6-phase2a-v1` (the short SHA in the
worktree name matches the local preparation commit `bc312e6`, "Prepare
TASK-005 row-order grid sweep"). Container:
`/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`;
launcher, bridge, daemon flags, hostfile, and module set unchanged from the
validated TASK-004 contract (see Resource metadata and launch contract
above).

All three approved candidates ran sequentially in the documented order
`4x4` first (mirroring TASK-004's execution order for paired comparison),
then `2x8`, then `8x2` — on the same node pair with identical fixed
controls; each `.status` records `exit_status=0`, and the PBS `.o` ends with
`=== HPL-MxP 2x8-GAAS phase2a-grid-row sweep complete: all 3 candidate(s) exited 0 (tag v1) ===`.
Factual per-candidate data as emitted by the application output (no
interpretation, no ranking, no baseline-percentage comparison):

| order | grid (nprow x npcol) | attempt | normalized residual | verdict | overall GFLOP/s (per GPU) | LU s / LU GFLOP/s (per GPU) | IR s / iterations | IR/LU | host mem cons. MAX / avail. MIN | device mem cons. MAX / avail. MIN | device mem avail. MIN after matrix gen |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 4x4 | `..._grid4x4_v1` | 1.416310E-05 | PASSED | 5.6347e+06 (352171.51) | 7.77 / 6.7803e+06 (423771.85) | 1.58 / 3 | 0.203 | 0.004 GB / 228.294 GB | 135.254 GB / 138.739 GB | 2.767 GB |
| 2 | 2x8 | `..._grid2x8_v1` | 5.149082E-05 | PASSED | 5.0562e+06 (316010.67) | 8.14 / 6.4670e+06 (404185.65) | 2.27 / 3 | 0.279 | 6.292 GB / 228.251 GB | 135.866 GB / 138.843 GB | 2.304 GB |
| 3 | 8x2 | `..._grid8x2_v1` | 6.995029E-05 | PASSED | 5.4331e+06 (339566.95) | 8.08 / 6.5199e+06 (407493.78) | 1.62 / 3 | 0.200 | 3.040 GB / 228.226 GB | 135.763 GB / 138.739 GB | 2.161 GB |

Attempt IDs are the full `2x8-GAAS-phase2a-grid-row_grid<NPROW>x<NPCOL>_v1`
stems. Per-candidate `.status` start/end (+08:00): grid4x4 20:14:47→20:15:45,
grid2x8 20:15:45→20:16:51, grid8x2 20:16:51→20:17:55 (per-candidate elapsed
58 s / 66 s / 64 s; the job-level evidence span from `.o` script start to
the last candidate end is 00:03:31, followed by the untimed post-sweep
health snapshot).

Allocation-level rank-map probe (TASK-005 Section 1.4C),
`outputs/2x8-GAAS-phase2a-grid-row_rankmap_v1.log`: 16/16 rank lines,
exactly 2 distinct hosts, exactly 8 ranks per host — global ranks 0–7 →
`hpc-gaas-g12` (local_rank 0–7/8), global ranks 8–15 → `hpc-gaas-g15`
(local_rank 0–7/8); local_rank = global_rank − 8×host_index. The probe gate
line in the PBS `.o` records `rc=0 rank_lines=16 hosts=2 ranks_per_host=8`.
The mapping is sufficient to reconstruct which logical grid rows/columns
cross the node boundary for each candidate under `nporder=row`, jointly
with the TASK-004 column-order rank-map evidence.

Facts not representable in the current `results/metrics.csv` schema,
recorded here for Codex review (schema/extractor unchanged):

- IR/LU is the mechanical ratio `Iterative Solver seconds (AVG) / LU
  seconds (AVG)` computed from each `.out` (rounded to 3 decimals).
- `--fill-device 1` was active for all three candidates (settings block of
  every `.out`); the binary additionally echoed `--order = row` plus the
  same package defaults as TASK-004: `--fill-device-buffer-size = 3048`,
  `--u-panel-chunk-nbs = 8`, `--preset-gemm-kernel = 90`,
  `--call-dgemv-with-multiple-threads = 0`, and
  `--cuda-host-register-step = 2048` (package defaults, not tuned;
  identical across all three candidates).
- Iterative refinement emitted 3 solver iterations (iterations 0, 1, 2) for
  every candidate; L-infinite residuals per iteration are in each `.out`
  (grid4x4 4.88341694e-04 → 9.15421072e-10 → 3.66373598e-15; grid2x8
  4.67920592e-04 → 8.70649116e-10 → 1.33226763e-14; grid8x2 4.82485206e-04
  → 9.27003299e-10 → 1.80966353e-14).
- The two `Per process memory available MIN system/device` lines per
  candidate: grid4x4 228.078/2.767 then 228.075/2.767 GB; grid2x8
  228.035/2.304 then 225.171/2.304 GB; grid8x2 227.996/2.161 then
  225.891/2.161 GB.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query)
  were taken once around the whole sweep on the job's mother node
  (`hpc-gaas-g12`, where the script, rank 0, and the container `mpirun`
  ran; each snapshot lists that node's GPUs 0–7): all NVIDIA H200, driver
  580.126.20, 143771 MiB total, pre-sweep 0 MiB used at 345 MHz (29–31 °C,
  75.02–78.63 W), post-sweep 0 MiB used at 1980 MHz (31–34 °C,
  118.47–135.67 W). The pre- and post-sweep topology tables in the `.o` are
  identical (NV18 all-pairs GPU mesh; NICs mlx5_0–mlx5_5, mlx5_8, mlx5_9,
  mlx5_bond_0 as listed in the `.o` legend).
- Raw PBS `.e` warnings (factual, non-blocking, same pattern as
  TASK-001/TASK-002/TASK-003/TASK-004 evidence): module-load note
  `cuda/13.1: compile with -arch=sm_XX (e.g. sm_90 on H200); default builds
  fail to launch on the 580 driver.` emitted while loading `nvhpc/26.3`
  (with requirement `gnu/gcc-12.3 cuda/13.1`), plus four `WARNING: group:
  unknown groupid 1304617061` lines. Each candidate `.err` contains one
  `WARNING: group: unknown groupid 1304617061` plus the bridge
  `rsh_pbsdsh_container` orted-spawn diagnostic line for `hpc-gaas-g15`
  (expected bridge output). The rank-map log carries the same group-ID
  warning plus one bridge diagnostic line. No `FAILED`, `NaN`, or `Inf`
  markers appear in any candidate `.out`.
- Job record for `72802.gaas`: the terminal `qstat -x -f` output was
  retrieved and captured in the operational transcript during TASK-005
  execution, but was not retained as a standalone raw evidence file. Key
  fields from that record: `qtime` = Sun Sep 27 20:14:24 2026 and
  `stime` = 20:14:24 (equal — the job launched at task submission, no
  queue wait); `mtime` = `obittime` = 20:17:57 (terminal);
  `job_state = F`; `Exit_status = 0`; `run_count = 1`;
  `resources_used.walltime = 00:03:32`; `queue = gpu_as`;
  `project = hpc_ebslee`;
  `exec_host = hpc-gaas-g12/0*96+hpc-gaas-g15/0*96`;
  `resources_used.ngpus = 16`, `resources_used.ncpus = 192`,
  `resources_used.mem = 85850128kb`,
  `resources_used.vmem = 6051911728kb`; `Stageout_status = 1`. The
  `pbs_state=F` and `exit_status=0` facts recorded in `metrics.csv` are
  established from this job record and from the complete PBS `.o` (the
  script ran to its final sweep-complete marker with all three candidates
  exited 0), the closed `.e`, and the three per-candidate `.status`
  files. As with the TASK-004 rows, the `metrics.csv`
  `submission_time`/`completion_time` for these rows carry the job-level
  `qtime`/`mtime` and `runtime` carries `resources_used.walltime`; the
  per-candidate `.status` start/end timestamps and elapsed durations
  remain recorded above in the Run summary.
- The exact qsub-time resource request is known from the retrieved qstat
  job record: `Resource_List.select` was the host-pinned request
  `host=hpc-gaas-g12:ngpus=8:ncpus=96:mem=2000GB+host=hpc-gaas-g15:ngpus=8:ncpus=96:mem=2000GB`
  with `place=scatter` and `walltime=01:30:00` — the documented
  host-pinned qsub form, not the script's generic `select=2:ngpus=8`
  default. The actual allocation evidenced by the hostfile and rank map
  was `hpc-gaas-g12` + `hpc-gaas-g15` with 8 GPUs and `slots=8` per node,
  16 ranks, one rank/GPU, matching the pinned hosts.
- The 12 evidence files for this attempt family (three candidate
  `.out`/`.err`/`.status` triplets, the rank-map log, and PBS `.o`/`.e`)
  are preserved in `outputs/`; their recorded `stdout`/`stderr` paths
  reference the remote execution worktree
  `.codex-worktrees/TASK-005-bc312e6-phase2a-v1`.
- With `--monitor-gpu 0`, benchmark GPU-monitoring output is unavailable
  by design; the PBS `gpu_usage` accounting fields were present in the
  retrieved `qstat -x -f` output (captured in the operational transcript,
  not retained as a standalone raw file).

Extracted rows for all three attempts are in `results/metrics.csv` /
`results/RESULTS.md` (experiment id `2x8-GAAS-phase2a-grid-row`, attempts
`2x8-GAAS-phase2a-grid-row_grid<NPROW>x<NPCOL>_v1`).

## Evidence paths

- `outputs/` — per-candidate `.out`/`.err`/`.status`, the allocation-level
  rank-map log, and PBS `.o`/`.e`
- `scripts/run_phase2a_grid_row.pbs` — the sweep script (header documents
  purpose, working directory, inputs, outputs, and assumptions)
