---
task_id: TASK-004
title: Phase 2A — 2x8 GAAS Process-Grid Shape Screen
status: EXECUTED
current_owner: strategic-analyst
parent_task: TASK-003
analysis_id: 2x8-gaas-phase2a-grid-shape
created: 2026-09-27
last_updated: 2026-09-27
---

# TASK-004 — Phase 2A: 2×8 GAAS Process-Grid Shape Screen

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.11. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Execute the first **Phase-2A process-grid shape screen** for the established
**2 GAAS nodes × 8 H200 GPUs/node** NVIDIA HPL-MxP campaign.

Phase 1 is closed with the retained representative geometry:

```text
N  = 429056
NB = 3072
fill-device = 1
```

The current `4×4 column` grid is only a provisional control. TASK-004 varies
**only the process-grid shape** while holding rank order and all other scientific
controls fixed.

The purpose is to determine whether a different 16-rank decomposition changes:

- end-to-end HPL-MxP performance;
- LU efficiency;
- iterative-refinement cost;
- memory ownership/headroom;
- rank symmetry; and
- the inter-node structure of logical process rows/columns.

This task does **not** compare row versus column order, tune GPU affinity, tune
communication, change N/NB, or start any downstream host/runtime/scheduling
work.

One valid scored attempt per approved grid shape is sufficient.

### 1.2 Context

TASK-003 closed Phase 1 with:

```text
N = 429056
NB = 3072
4x4 column = provisional grid control
overall = 5.5381e+06 GFLOP/s in TASK-003
overall = 5.6091e+06 GFLOP/s in TASK-002
```

The retained NB region is `2048–3072`, with `NB=3072` carried forward as
the representative control.

The dependency graph marks grid/order as open because:

- E09: N materially changed the useful geometry/residency regime;
- E10: NB and process grid jointly affect block ownership, panel count,
  communication, and local update geometry;
- E12: grid shape changes panel communicator sizes/fan-out;
- E24: grid/NB jointly affect U-panel chunk validity/usefulness;
- E29 and placement-related edges become relevant once a grid candidate is
  retained.

The blueprint requires **shape screening first**, with one fixed explicit order
and mapping, before row/column order comparison.

### 1.3 Strategic Question / Hypotheses

Primary question:

> At fixed N=429056, NB=3072, column order, and identity GPU affinity, which
> non-extreme 16-rank process-grid shapes provide the strongest valid
> end-to-end behavior on the 2×8 GAAS topology?

Working hypotheses:

1. `2×8`, `4×4`, and `8×2` create materially different panel/update
   communicator shapes while keeping rank count constant.
2. With 8 ranks per node and fixed column order, these grids map logical
   process rows/columns differently across the two-node boundary; this may
   materially affect panel traffic and synchronization.
3. A more balanced-looking grid is not assumed to win; the correct result is
   whatever gives the best combined LU+IR path with valid correctness.
4. Grid shape may also change worst-rank local matrix ownership and memory
   headroom even at fixed N/NB.
5. Skinny extremes (`1×16`, `16×1`) are diagnostic rather than mandatory
   and are intentionally excluded from this first bounded screen.
6. Numerical winners from prior single-node or old 2×8 experiments are prior
   hypotheses only and must not be transferred.

TASK-004 produces evidence only. Shape retention and any later row-vs-column
order comparison require explicit `ANALYSE_RESULTS`.

### 1.4 Required Evidence / Deliverables

#### A. Fixed process-grid candidate set

Run exactly these three shapes:

```text
2 × 8
4 × 4
8 × 2
```

with:

```text
--nporder column
```

for all three.

Roles:

- `4×4 column`: same-protocol retained Phase-1 control;
- `2×8 column`: wider process-column count / smaller process-row count;
- `8×2 column`: larger process-row count / narrower process-column count.

Do not add `1×16`, `16×1`, row-order variants, adaptive shapes, or any other
grid candidate inside TASK-004.

Preferred candidate order:

```text
4x4 column
2x8 column
8x2 column
```

so the same-protocol control runs first.

#### B. Fixed scientific controls

Vary only:

```text
--nprow
--npcol
```

Use exactly:

```text
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

Only `nprow × npcol` changes between scored candidates.

Do not explicitly change or tune:

- N or NB;
- row/column order;
- GPU affinity;
- `--fill-device-buffer-size`;
- `--Anq-device`;
- U-panel chunking;
- DGEMV partitioning;
- CPU/memory affinity;
- OpenMP placement/binding beyond `OMP_NUM_THREADS=8`;
- MPI/NCCL broadcast policy;
- communication/NIC controls;
- precision;
- GEMM kernel/preset;
- host-register step;
- scheduling priorities;
- any other downstream control.

All unspecified controls must retain the same installed package/default
behavior used in TASK-003.

#### C. Rank-map evidence

Before the first scored candidate in each allocation, record one lightweight
MPI mapping probe using the same:

- 16 ranks;
- shared de-duplicated `slots=8` hostfile;
- container MPI;
- `pbsdsh` bridge;
- launcher daemon flags.

The probe must emit, for all 16 ranks when available:

```text
global_rank
local_rank
hostname
```

or an equivalent unambiguous mapping.

This probe is diagnostic only and must not alter scientific controls.

Preserve the rank-map output as raw evidence. The later Strategic Analyst must
be able to reconstruct which logical grid rows/columns cross the node boundary
for each candidate under `nporder=column`.

Do not add topology profiling or communication tracing.

#### D. Execution logistics

Create a dedicated experiment area, preferably:

```text
experiments/2x8-GAAS/phase2a-grid-shape/
```

with:

```text
README.md
scripts/
outputs/
```

Reuse/adapt the TASK-003 sequential-sweep pattern and the same validated
multinode launcher contract.

Preferred execution:

- one PBS allocation;
- 2 nodes × 8 H200 GPUs;
- 16 MPI ranks;
- one rank/GPU;
- all three shapes sequentially inside one allocation;
- shared de-duplicated hostfile with `slots=8` per node;
- validated NVIDIA container MPI + `pbsdsh` bridge;
- `place=scatter`;
- no `mpiprocs`;
- same module/container stack as TASK-003;
- one rank-map probe before the scored sweep;
- one pre/post hardware-health snapshot around the whole sweep;
- per-candidate stdout/stderr/status evidence;
- unique `ATTEMPT_TAG` evidence naming;
- never overwrite previous evidence;
- no concurrent multinode submissions.

If one allocation is operationally impractical, Codex may split approved
shapes across equivalent 2×8 allocations without additional approval, but each
allocation must preserve the exact scientific controls and include its own
rank-map evidence.

#### E. Minimal pre-submit validation

Reuse accepted Phase-0 through TASK-003 evidence.

Before submission, perform only lightweight checks sufficient to catch
mistakes:

- syntax-check new/modified PBS/shell script;
- verify fixed `N=429056`, `NB=3072`;
- verify candidate set is exactly `2×8`, `4×4`, `8×2`;
- verify all shapes multiply to 16 ranks;
- verify `nporder=column` for every candidate;
- verify fixed controls from Section 1.4B;
- verify validated TASK-003 container/launcher contract;
- verify 2 nodes × 8 GPUs, 16 ranks, one rank/GPU;
- verify project `hpc_ebslee`;
- verify queue is `gpu_as` or `gpu_ded`;
- perform lightweight live queue/node eligibility check.

Do not redo comprehensive topology/software/GDR/NCCL/UCX characterization
unless execution reveals a concrete contradiction.

#### F. Per-candidate evidence

For every grid shape preserve, when emitted:

- attempt ID;
- PBS job ID;
- queue and nodes;
- N, NB, nprow, npcol, nporder;
- fixed scientific controls;
- exit status;
- correctness verdict;
- finite normalized residual;
- overall HPL-MxP GFLOP/s;
- LU time / LU GFLOP/s;
- iterative-refinement time;
- iterative-refinement iteration count;
- host/device memory consumption and headroom;
- any ordinary per-rank timing/imbalance markers present in benchmark output;
- stdout/stderr.

Also preserve the allocation-level rank-map probe from Section 1.4C.

Normal HPL-MxP output is sufficient scientific evidence. No profiling,
hardware counters, or extra tracing is required.

#### G. Result logging

Append factual rows to:

```text
results/metrics.csv
results/RESULTS.md
```

Update the experiment README with factual provenance, candidate order, rank-map
evidence location, and raw result table.

Codex must not:

- rank/promote a final grid shape;
- decide which shapes proceed to row/column order comparison;
- launch row-order variants;
- change affinity;
- update strategic conclusions in `planning/2x8-GAAS.md`;
- begin Phase 2B;
- perform campaign-level interpretation.

Those actions require explicit `ANALYSE_RESULTS`.

### 1.5 Relevant Inputs and References

Primary repository:

`QuangPham2404/HPL-MxP-Agent-Test`

Primary references:

- `tasks/TASK-003.md`
- `planning/analysis/2x8-gaas-phase1b-nb-screen.md`
- `planning/2x8-GAAS.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `experiments/2x8-GAAS/phase1b-nb-screen/README.md`
- `experiments/2x8-GAAS/phase1b-nb-screen/scripts/run_phase1b_nb_screen.pbs`
- `multi-node-test/GAAS_MULTINODE_SETUP.md`
- `workflow/07-Workflow.md`
- `workflow/08-Workflow-Multinode-Tuning.md`
- active root `AGENTS.md` and `APPLICATION.md`
- `results/metrics.csv`

Historical grid results under `experiments/2Nodes-8GPUs/` and single-node
grid analyses may be read as mechanism/context only. Their numerical winners
must not be transferred.

No OpenMxP access is required or authorized.

### 1.6 Execution Scope

#### Allowed

Codex may:

- create `experiments/2x8-GAAS/phase2a-grid-shape/`;
- reuse/adapt the TASK-003 sweep script and launcher;
- execute exactly the three approved grid shapes at fixed N/NB/order;
- run all three sequentially in one 2×8 allocation when practical;
- split them across equivalent 2×8 allocations only when operationally needed;
- choose `gpu_as` or `gpu_ded` based on live eligibility;
- use scheduler-selected eligible nodes or host-pin an eligible pair;
- run the lightweight allocation-level MPI rank-map probe;
- perform lightweight syntax/configuration checks;
- submit and boundedly monitor approved jobs;
- preserve all attempt-specific evidence;
- automatically handle Track-1 synchronization, scheduler, output-path,
  worktree, transfer, or submission failures;
- retry an interrupted candidate/allocation with a new attempt tag when no
  meaningful scientific result was produced;
- continue remaining shapes after an isolated scientifically meaningful
  candidate failure when safe and under unchanged controls;
- update experiment/results/task/progress bookkeeping;
- commit/push approved execution artifacts.

Reasonable scheduler-only changes such as attempt tags, output paths, eligible
host pinning, or sufficient walltime are allowed if scientific controls and
resource shape remain unchanged.

#### Prohibited

Codex and workers must not:

- use any queue other than `gpu_as` or `gpu_ded`;
- use another accounting project;
- change the 2-node × 8-GPU resource shape;
- change N or NB;
- add/remove/replace the approved grid shapes;
- run `1×16` or `16×1`;
- run any `nporder=row` candidate;
- tune or permute GPU affinity;
- start Phase 2B;
- change fill-device buffer/Anq-device;
- tune OpenMP, CPU/memory affinity, DGEMV, communication, U-panel chunking,
  precision, GEMM kernel, host registration, or scheduling controls;
- perform a grid×order×affinity Cartesian sweep;
- rerun the immutable original baseline;
- perform a targeted N/NB resweep;
- repeat comprehensive accepted characterization without concrete reason;
- require extra statistical repeats;
- access or depend on OpenMxP;
- perform strategic analysis or select retained shapes.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and active Workflow v2.
2. Substantive execution remains delegated through the approved OpenCode worker
   workflow.
3. Use PBS compute-node execution only.
4. Resource shape remains:

   ```text
   2 nodes × 8 H200 GPUs
   16 MPI ranks
   one rank/GPU
   place=scatter
   no mpiprocs
   ```

5. Use project:

   ```text
   hpc_ebslee
   ```

6. Only:

   ```text
   gpu_as
   gpu_ded
   ```

   are authorized queues.

7. `free` node state alone does not prove queue eligibility; verify live
   queue eligibility before host-pinning.

8. Preserve the validated TASK-003 container-MPI / `pbsdsh` launcher.

9. Preserve fixed N, NB, column order, GPU affinity, and all Section 1.4B
   controls.

10. One valid scored attempt per grid shape is sufficient.

11. Preserve unique evidence names and never overwrite prior outputs.

12. A genuine candidate OOM/correctness/runtime failure must be preserved as
    scientific evidence, not silently converted into a different grid/control.

13. An isolated candidate failure does not automatically stop the remaining
    shapes if they remain safe to run under unchanged controls.

14. Track-1 operational recovery is permitted without human intervention when
    it stays within approved scope.

### 1.8 Success Criteria

TASK-004 is operationally complete when:

- the dedicated Phase-2A grid-shape experiment exists;
- the three approved shapes `2×8`, `4×4`, `8×2` have each been attempted,
  except where a documented systemic blocker prevents further execution;
- N=429056 and NB=3072 remain fixed;
- `nporder=column` remains fixed;
- only nprow/npcol vary;
- the rank-map probe proves the allocation's global/local rank-to-node mapping;
- 2×8 / 16-rank resource mapping is preserved;
- only approved queues/project are used;
- every valid scored point has normal benchmark output, finite residual, and
  `PASSED`;
- overall/LU/IR/memory evidence is preserved;
- raw stdout/stderr/status and rank-map evidence are preserved;
- factual rows are added to project results;
- the Execution Report records factual completion/scope compliance only;
- artifacts are committed/pushed;
- task handoff is:

  ```text
  status: EXECUTED
  current_owner: strategic-analyst
  ```

No row-order comparison, affinity tuning, profiling, baseline rerun, strategic
selection, or Phase-2B work is required.

### 1.9 Stop / Escalation Conditions

Stop and return for Strategic Analyst / Human direction only when:

- validated launcher/container behavior materially changed and accepted
  evidence cannot reasonably be reused;
- rank/GPU mapping is materially wrong and Track-1 recovery cannot restore it;
- the rank-map probe reveals unexpected launcher placement that makes the
  approved shape comparison scientifically ambiguous and cannot be resolved
  without changing launcher semantics;
- execution requires changing N, NB, order, affinity, or another scientific
  control;
- execution requires a grid outside the approved three;
- execution requires another resource shape, queue, or accounting project;
- multiple shapes exhibit a common correctness/runtime failure suggesting a
  systemic platform/scientific issue;
- a necessary diagnostic would exceed Section 1.11 authorization.

Do **not** escalate merely because:

- a preferred node pair is unavailable;
- one approved queue lacks an eligible pair;
- the other approved queue must be used;
- a normal worktree/scheduler/output/transfer issue occurs;
- shapes must be split across equivalent allocations;
- one shape is valid but slower;
- one isolated shape fails scientifically while remaining approved shapes are
  still safe to attempt.

### 1.10 Strategic Analyst Notes

TASK-004 is **Phase 2A shape screening only**.

Later analysis must compare:

```text
grid shape
overall GFLOP/s
LU time / LU GFLOP/s
IR time / IR-LU
IR iterations
correctness / residual
host/device headroom
per-rank timing or imbalance markers if emitted
global/local rank-to-node mapping
logical row/column node-crossing pattern under column order
same-protocol 4x4 column control
```

Expected workflow:

```text
TASK-004 execution
        ↓
ANALYSE_RESULTS
        ↓
retain useful grid shapes
        ↓
dependency checkpoint
        ↓
row vs column comparison only for retained shapes
        ↓
refine/repeat leading shape-order pairs
        ↓
then Phase 2B GPU-affinity / physical placement
```

Do not automatically launch row-order candidates after TASK-004.

### 1.11 Authorization

status: APPROVED

approved_scope: Execute TASK-004 as the bounded Phase-2A process-grid shape screen on the established 2x8 GAAS NVIDIA HPL-MxP topology. Fix N=429056, NB=3072, nporder=column, OMP_NUM_THREADS=8, identity GPU affinity, FP16, MPI panel broadcast=0, separate GEMM stream=1, TRSM/factorization priorities=0, --fill-device 1, --test-loop 1, --skip-tests 0, and --monitor-gpu 0, with all unspecified controls retaining the same package/default behavior as TASK-003. Vary only nprow/npcol across exactly {2x8,4x4,8x2}, preferably running 4x4 first as the same-protocol control, then 2x8 and 8x2. Use the same validated execution logistics as TASK-003: preferably one 2-node x 8-H200 allocation, 16 ranks/one rank per GPU, place=scatter, no mpiprocs, validated container MPI plus pbsdsh bridge, shared de-duplicated slots=8 hostfile, attempt-tag-specific evidence, pre/post sweep health snapshots, project hpc_ebslee, and only queues gpu_as or gpu_ded. Before scored candidates, run one lightweight MPI rank-map probe using the same allocation/hostfile/launcher to preserve global_rank/local_rank/hostname evidence sufficient to reconstruct node placement. Codex may choose between approved queues, select or host-pin eligible nodes, split approved shapes across equivalent 2x8 allocations when operationally necessary, make scheduler-only adjustments, and perform Track-1 recovery without new approval. Preserve correctness, overall/LU/IR, iteration, memory/headroom, job/node, rank-map, stdout/stderr evidence and update factual experiment/results/task/progress artifacts. One valid scored attempt per grid shape is sufficient. No 1x16/16x1 shapes, row-order variants, N/NB changes, affinity permutations, buffer/residency/host-runtime/DGEMV/communication/chunk/precision/kernel/scheduling tuning, grid×order×affinity Cartesian sweep, comprehensive reprobe, profiling, OpenMxP access, Phase-2B work, or strategic interpretation is authorized.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

<!-- Codex completes this section after execution; do not rewrite section 1. -->

### 2.1 Execution Status

status: COMPLETE

All three approved grid shapes (4x4, 2x8, 8x2) completed in one PBS
allocation (job `72783.gaas`, state `F`, `Exit_status=0`) with `PASSED`
verification, finite residuals, and full evidence preservation. The
preparation was pushed before remote use, and the post-run evidence and
bookkeeping were committed and pushed in
`882c6ba2e7fceb4befe5f3bb995ac4771d24312a`.

### 2.2 Orchestration Summary

Six sequential OpenCode worker assignments handled substantive phases of
TASK-004; Codex performed startup and scope verification, local review,
worktree/commit verification, live eligibility orchestration, independent
spot-check validation against raw local evidence, and this report:

- Worker A (preparation): created the local experiment README, PBS sweep
  script, and output directory. The initial handoff returned empty; the
  same session was resumed and the files were independently validated.
- Worker B (remote synchronization/eligibility): fetched `origin`, created
  a clean detached TASK-004 worktree at the exact pushed preparation commit,
  verified task/script hashes and unchanged authorization, and checked only
  the approved queues and eligible-node Qlists. The dirty primary clone
  remained untouched.
- Worker C (submission): rechecked the selected g12+g15 pair and submitted
  exactly one host-pinned `gpu_as` job, `72783.gaas`, with attempt tag `v1`.
- Worker D (bounded monitoring): read-only `qstat` monitoring of
  `72783.gaas` — 3 of the maximum 12 checks at >=60 s spacing; terminal
  state detected; exactly one `qstat -x -f` record captured afterward. No
  submit/retry/cancel and no launcher/resource alteration.
- Worker E (retrieval + validation): individual `scp -o BatchMode=yes`
  retrieval of all 12 v1 evidence files into the local experiment
  `outputs/` directory (no overwrites; none pre-existed locally);
  SHA-256 comparison remote vs local; rank-map and per-candidate marker
  validation with verbatim extraction.
- Worker F (bookkeeping): experiment README run summary and status update;
  three appended `results/metrics.csv` rows; `results/RESULTS.md`
  regeneration with the existing generator; CSV/diff validation checks.
- Worker assignments were sequential (preparation -> remote sync/eligibility
  -> submission -> monitor -> retrieve/validate -> bookkeeping); no
  per-worker task or report files were created.

### 2.3 Work Executed

- Startup: read workflow files 00-08, `APPLICATION.md`, explicitly
  identified `tasks/TASK-004.md` (front matter `EXECUTING / codex`;
  Section 1.11 `APPROVED / approved_by: user` with unchanged approved
  scope — valid resume), latest progress `progress/2026-09-27-progress_s11.md`,
  and Git state. Local `main` = `origin/main` =
  `2332d8fece53b6e42d6a28f4599fdb16488ae82f`; pre-existing untracked
  `hpl-mxp-runs-on-gaas/` preserved untouched.
- Verified the remote execution worktree
  `.codex-worktrees/TASK-004-2332d8f-phase2a-v1` at the exact commit
  `2332d8fece53b6e42d6a28f4599fdb16488ae82f`; v1 evidence files were
  accumulating (rank-map log + grid4x4 in progress) at first inspection.
- Created and pushed preparation commit `2332d8fece53b6e42d6a28f4599fdb16488ae82f`
  before remote use; it contains the experiment README, PBS sweep script,
  output placeholder, and the TASK-004 lifecycle transition to
  `EXECUTING / codex`.
- Live pre-submit eligibility check found `gpu_as` enabled/started and
  `hpc-gaas-g12` plus `hpc-gaas-g15` fully free, each with 8 GPUs,
  zero assigned GPUs, and `resources_available.Qlist=gpu_as,gpu_ppu`;
  `gpu_ded` had only one fully-free eligible node, so the approved
  `gpu_as` pair was selected. The later immediate pre-submit recheck
  confirmed the same pair.
- Bounded monitoring (3 checks: 2026-09-27T11:34:04Z state R,
  11:35:06Z state R, 11:36:08Z job finished): terminal `job_state=F`,
  `Exit_status=0`, `resources_used.walltime` 00:03:35, `run_count=1`,
  queue `gpu_as`, project `hpc_ebslee`, exec hosts `hpc-gaas-g12/0*96 +
  hpc-gaas-g15/0*96`, qtime 2026-09-27 19:32:19 +08:00 (equal to
  stime/etime — no queue wait), mtime/obittime 19:35:55 +08:00. One
  `qstat -x -f 72783.gaas` record captured after terminal state.
- Evidence retrieval: all 12 files transferred individually (rank-map log;
  three candidate `.out`/`.err`/`.status` triplets; PBS `.o`/`.e`); all 12
  SHA-256 values match the remote copies byte-for-byte.
- Rank-map validation: `2x8-GAAS-phase2a-grid-shape_rankmap_v1.log`
  contains 16/16 rank lines, exactly 2 distinct hosts, exactly 8 ranks per
  host — global ranks 0-7 -> `hpc-gaas-g12` (local_rank 0-7/8), global
  ranks 8-15 -> `hpc-gaas-g15` (local_rank 0-7/8). PBS `.o` probe gate
  line records `rc=0 rank_lines=16 hosts=2 ranks_per_host=8`.
- Per-candidate validation (execution order 4x4, 2x8, 8x2): each
  `.status` records `exit_status=0`, job `72783.gaas`, queue `gpu_as`,
  nodes g12+g15, `n=429056`, `nb=3072`, its `nprow x npcol`, and the
  identical `fixed_controls` line; each `.out` contains normal benchmark
  output (internal tests, Matrix Generation, LU seconds, 3 solver
  iterations, HPL MxP Result, test loop done), a finite normalized
  residual with `PASSED` (4x4 `1.263430E-05`, 2x8 `4.910973E-05`, 8x2
  `7.375562E-05`), overall and LU GFLOPS lines, and host/device memory
  markers; no `NaN`/`Inf`/`FAILED` markers anywhere.
- Bookkeeping: README status paragraph updated and factual Run summary
  section added (job metadata, rank-map evidence, per-grid factual table,
  memory/IR facts, warnings, integrity note); three unique rows appended
  to `results/metrics.csv` (214 data rows total; no duplicate
  `(experiment_id, attempt)` keys); `results/RESULTS.md` regenerated with
  the existing generator (exactly 3 new rows; all pre-existing rows
  unchanged).

### 2.4 Operational Validation

- Scheduler: single job `72783.gaas`, final state `F`, `Exit_status=0`,
  `run_count=1`; only approved queue `gpu_as` and project `hpc_ebslee`
  used; host-pinned select
  `host=hpc-gaas-g12:ngpus=8:ncpus=96:mem=2000GB+host=hpc-gaas-g15:ngpus=8:ncpus=96:mem=2000GB`,
  `place=scatter`, no `mpiprocs`.
- Resource mapping preserved: exec_vnode 2 x (8 GPUs), de-duplicated
  hostfile `slots=8` per node (echoed in the PBS `.o`), 16 ranks one per
  GPU, rank-map probe confirms 16 ranks / 2 hosts / 8 ranks per host.
- Scientific controls: N=429056 and NB=3072 fixed (result line of every
  `.out` and every `.status`), `nporder=column` fixed, identical
  `fixed_controls` line across all three candidates; only `nprow x npcol`
  varied (4x4, 2x8, 8x2 — exactly the approved set, approved order);
  echoed package defaults identical across candidates
  (`--fill-device-buffer-size = 3048`, `--u-panel-chunk-nbs = 8`,
  `--preset-gemm-kernel = 90`,
  `--call-dgemv-with-multiple-threads = 0`,
  `--cuda-host-register-step = 2048`).
- Correctness: every candidate has normal output, three finite L-infinite
  iteration residuals, finite normalized residual below threshold with
  `PASSED`, and no `NaN`/`Inf`/`FAILED` markers; success was not classified
  from exit status alone.
- Provenance: execution worktree at the exact approved commit verified;
  all 12 evidence files SHA-256-identical between the remote worktree and
  the canonical local `outputs/` directory; no evidence file was
  overwritten (local directory contained only `.gitkeep` before
  retrieval); the remote worktree and its generated `hostfile` were left
  intact.
- Results consistency: `results/metrics.csv` parses with 214 data rows,
  consistent schema, and no duplicate keys; `results/RESULTS.md` diff is
  exactly the 3 new rows; `git diff --check` clean for the edited text
  artifacts. Running `git diff --cached --check` over all staged files also
  reports trailing spaces and blank EOF lines emitted by the benchmark in
  the raw candidate `.out` and PBS `.o` files; these byte-exact evidence
  files were preserved unchanged.
- Codex independently spot-checked the worker-extracted values against the
  local raw `.out`/`.status`/rank-map files (GFLOPS, residual, LU/IR
  seconds, iterations, memory lines, rank distribution, hashes); all
  matched.

### 2.5 Evidence and Artifacts

- Experiment area: `experiments/2x8-GAAS/phase2a-grid-shape/` (README with
  Run summary; 12 raw evidence files under `outputs/`:
  `2x8-GAAS-phase2a-grid-shape_v1.o`/`.e`,
  `2x8-GAAS-phase2a-grid-shape_rankmap_v1.log`, and
  `2x8-GAAS-phase2a-grid-shape_grid{4x4,2x8,8x2}_v1.{out,err,status}`)
- Structured results: `results/metrics.csv` (rows
  `2x8-GAAS-phase2a-grid-shape_grid4x4_v1`, `..._grid2x8_v1`,
  `..._grid8x2_v1`) and `results/RESULTS.md`
- Job record: `qstat -x -f 72783.gaas` (key fields recorded in the
  experiment README Run summary)
- Remote execution worktree:
  `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test/.codex-worktrees/TASK-004-2332d8f-phase2a-v1`
  at commit `2332d8fece53b6e42d6a28f4599fdb16488ae82f` (originals
  preserved in place)
- PBS job: `72783.gaas` (queue `gpu_as`, project `hpc_ebslee`,
  2026-09-27 19:32:19 - 19:35:55 +08:00)
- Approved specification and unchanged authorization:
  `tasks/TASK-004.md` Section 1 (Section 1.11 `APPROVED / approved_by:
  user`)

### 2.6 Files Changed

Files changed during TASK-004 execution:

- `experiments/2x8-GAAS/phase2a-grid-shape/README.md` — prepared before
  remote use and updated with status + factual Run summary
- `experiments/2x8-GAAS/phase2a-grid-shape/scripts/run_phase2a_grid_shape.pbs`
  — approved three-shape sweep script
- `experiments/2x8-GAAS/phase2a-grid-shape/outputs/.gitkeep` — output
  directory placeholder
- `experiments/2x8-GAAS/phase2a-grid-shape/outputs/` — 12 new raw evidence
  files (listed in 2.5)
- `results/metrics.csv` — 3 appended rows
- `results/RESULTS.md` — regenerated (3 new rows)
- `tasks/TASK-004.md` — this Section 2 execution report + front matter
  `EXECUTED / strategic-analyst`
- `progress/2026-09-27-progress_s12.md` — new dated progress handoff

No other files were modified. Pre-existing untracked `hpl-mxp-runs-on-gaas/`
preserved untouched.

### 2.7 Missing / Unavailable Evidence

- Benchmark continuous GPU-monitoring output is unavailable by design
  (`--monitor-gpu 0`); ordinary PBS `resources_used.gpu_usage` accounting
  for all 16 GPUs is recorded in the `qstat -x -f` job record instead.
- No per-candidate wall-clock timing exists beyond the `.status`
  start/end timestamps and the application's own LU/IR AVG/MAX/MIN lines
  (ordinary for this benchmark).
- Otherwise none: all Section 1.4F per-candidate evidence items that the
  benchmark emits are preserved.

### 2.8 Execution Errors / Exceptions

None blocking. No job failure, retry, cancellation, Track-1 recovery, or
Track-2 condition occurred; all 12 SCP transfers succeeded on the first
attempt (5 s spacing; no connection resets). Factual non-blocking
observations, recorded without interpretation:

- Recurring `WARNING: group: unknown groupid 1304617061` (one line per
  candidate `.err`, four in the PBS `.e`, one in the rank-map log) — same
  known non-blocking pattern as TASK-001/002/003 evidence; each `.err`
  also preserves the validated bridge diagnostic and the PBS `.e` the
  `cuda/13.1` module note.
- `Stageout_status = 1` in the `qstat -x -f 72783.gaas` record.
- Per-GPU `powerViolationTime` values (13,293-14,079 s, all 16 GPUs,
  `overallHealth=10`, `thermalViolationTime=0.000s`) exceed the 215 s job
  walltime — PBS accounting fields recorded as observed.
- Candidate `.out`/`.o` files contain benchmark-emitted ANSI color escape
  sequences (raw bytes preserved unchanged).
- `git diff --cached --check` reports benchmark-generated trailing
  whitespace/blank EOF lines in raw `.out`/PBS `.o` evidence; raw files were
  preserved byte-for-byte and were not normalized.

No further execution action is required. The approved post-run artifacts
are committed and pushed in
`882c6ba2e7fceb4befe5f3bb995ac4771d24312a`.

### 2.9 Scope Compliance

Work stayed within the approved task scope:

- Monitored and finished only the one already-submitted job `72783.gaas`;
  no submit/retry/cancel; no launcher, resource, or queue alteration;
  monitoring stayed within the bounded plan (3 of max 12 checks at >=60 s
  spacing; one `qstat -x -f` record after terminal state).
- Exactly the three approved shapes ran at fixed N=429056, NB=3072,
  `nporder=column`, identity GPU affinity, and the Section 1.4B controls;
  only `nprow`/`npcol` varied; approved queue (`gpu_as`) and project
  (`hpc_ebslee`) only; 2x8/16-rank/one-rank-per-GPU mapping preserved and
  proven by the rank-map probe.
- No ranking, retention decision, baseline-percentage comparison, row-order
  variant, affinity change, Phase-2B work, planning update, OpenMxP access,
  or strategic interpretation was performed. No per-worker report files
  were created. Existing progress files and raw evidence were left
  untouched.

### 2.10 Handoff to Strategic Analyst

Factual reading guidance (no interpretation included):

- Start with the experiment README Run summary
  (`experiments/2x8-GAAS/phase2a-grid-shape/README.md`) for job metadata,
  the per-grid factual table (normalized residual, overall GFLOP/s and per
  GPU, LU seconds / LU GFLOP/s, IR seconds / iterations, IR/LU mechanical
  ratio, host/device memory consumption/headroom), and the rank-map
  evidence.
- Raw per-candidate evidence: the `.out`/`.err`/`.status` triplets under
  `experiments/2x8-GAAS/phase2a-grid-shape/outputs/`; the rank-map log
  gives the global/local rank-to-node mapping needed to reconstruct which
  logical grid rows/columns cross the node boundary for each candidate
  under `nporder=column` (global ranks 0-7 on g12, 8-15 on g15).
- Same-protocol control context: TASK-003 `2x8-GAAS-phase1b-nb-screen_nb3072_v1`
  (4x4 column, job `72712.gaas`) and TASK-002
  `2x8-GAAS-phase1a-n-refine_n429056_v1` (job `72688.gaas`); immutable
  2x8-GAAS original baseline `2x8-GAAS-baseline_n700k_v1` (job `72602.gaas`,
  `4.8037e+06` GFLOP/s) is the campaign percentage denominator for this
  topology, with the protocol mismatch disclosure required by Workflow 08.
- Structured rows: `results/metrics.csv` /
  `results/RESULTS.md` (experiment `2x8-GAAS-phase2a-grid-shape`).
- Relevant dependency-graph context per Section 1.2: E09, E10, E12, E24,
  E29 and placement edges.
- Analysis, shape retention, row-vs-column comparison, and any Phase-2B
  work require explicit `ANALYSE_RESULTS` and human decisions; per project
  policy, authorized analysis tables must include the immutable original
  baseline and a percentage-increase column against it.
