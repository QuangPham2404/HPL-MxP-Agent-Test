---
task_id: TASK-001
title: Phase 1A — 2x8 GAAS Coarse N / FP64-Residency Sweep
status: EXECUTED
current_owner: strategic-analyst
parent_task: TASK-000
analysis_id: 2x8-gaas-phase1a-n-coarse
created: 2026-09-27
last_updated: 2026-09-27
---

# TASK-001 — Phase 1A: 2×8 GAAS Coarse N / FP64-Residency Sweep

<!-- Lifecycle: APPROVED / codex = ready to begin; EXECUTING / codex =
     started and resumable across sessions under unchanged approved Section
     1.11. Recoverable Track 1 mechanics keep EXECUTING / codex. BLOCKED / user
     requires actual human/external action or new authority. -->

## 1. STRATEGIC SPECIFICATION

### 1.1 Objective

Execute the first bounded Phase-1A experiment for the **2 GAAS nodes × 8 H200 GPUs/node** NVIDIA HPL-MxP campaign.

The purpose is to perform a **coarse N sweep** around the hardware-derived FP64-residency pivot while holding the rest of the HPL-MxP configuration fixed.

This task is intended to produce the evidence needed to identify useful N / FP64-residency operating regimes for later Strategic Analyst review.

It does **not** select the final N, tune NB, perform the later ~5% refinement sweep, or choose the next optimization direction.

One valid scored attempt per approved N candidate is sufficient for TASK-001 completion. Mandatory repeats, noise studies, comprehensive reprobes, and duplicate validation are not required.

### 1.2 Context

TASK-000 established the immutable 2×8 GAAS original baseline:

```text
Attempt: 2x8-GAAS-baseline_n700k_v1
PBS job: 72602.gaas
N: 700000
NB: 3072
Grid: 4x4 column
Ranks: 16
Correctness: PASSED
LU time: 29.17 s
IR time: 18.44 s
IR/LU: ~0.632
LU performance: 7.8390e+06 GFLOP/s
Overall performance: 4.8037e+06 GFLOP/s
```

This run remains the immutable campaign percentage denominator.

The earlier `N=737280` attempt was killed by host-memory exhaustion and remains useful boundary evidence. It must not be retried as part of this task.

Phase 0 also established approximately:

```text
16 MPI ranks
8 H200 GPUs/node
143156 MiB initially free GPU memory/device
```

Using the Phase-1A blueprint heuristic:

```text
N_pivot = sqrt(ranks * usable_GPU_memory_bytes * 0.85 / 8)
```

gives approximately:

```text
N_pivot ≈ 505160
```

This is only a sweep-center heuristic. It is not an assumed optimum.

The scientific motivation is:

```text
R_MxP ≈ ((2/3) * N^3) / (T_LU + T_IR)

or

R_MxP ≈ P_LU / (1 + T_IR / T_LU)
```

Therefore the objective is not to maximize N or LU throughput independently. The sweep must preserve enough evidence to distinguish:

- credited N³ work;
- LU efficiency;
- iterative-refinement cost;
- FP64-residency / memory behavior; and
- final end-to-end HPL-MxP performance.

Existing Phase-0 topology, launcher, package-support, and provenance evidence is accepted and should be reused rather than regenerated.

### 1.3 Strategic Question / Hypotheses

Primary question:

> Across a broad range around the 2×8 FP64-residency pivot, which N regions provide the strongest end-to-end HPL-MxP behavior, and how does that behavior relate to LU efficiency, iterative-refinement cost, and memory residency?

Working hypotheses:

1. Increasing N may improve LU/GEMM efficiency and amortization because useful work grows approximately as N³.
2. Increasing N may also increase IR cost and FP64 staging pressure.
3. Smaller-N / higher-device-residency regimes may become competitive if their reduction in IR time outweighs lost LU efficiency and credited N³ work.
4. The best operating regime therefore does not necessarily occur at the largest N that fits.
5. `N % NB == 0` is not assumed to be a universal performance requirement.

TASK-001 does not resolve these hypotheses itself. It produces the raw evidence for subsequent Strategic Analyst analysis.

### 1.4 Required Evidence / Deliverables

#### A. Fixed coarse-N candidate set

Use the Phase-0 measured memory envelope and the Phase-1A pivot described above.

The approved coarse candidates are approximately 70%, 80%, 90%, 100%, 110%, and 120% of the pivot, rounded to convenient 1024-sized values:

```text
N = 353280
N = 404480
N = 454656
N = 504832
N = 556032
N = 606208
```

These six values are the complete scientific sweep for TASK-001.

Do not add a finer N sweep, additional boundary points, or NB combinations within this task.

The candidate generation intentionally does not require every N to be divisible by `NB=3072`.

#### B. Fixed scientific controls

Vary only `N`.

Use:

```text
OMP_NUM_THREADS=8

--nb 3072
--nprow 4
--npcol 4
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

`--fill-device 1` is intentionally enabled for the entire Phase-1A sweep so changes in N can expose the FP64-residency transition.

Do not explicitly tune `--fill-device-buffer-size`, `--Anq-device`, DGEMV partitioning, U-panel chunking, CPU/memory affinity, OpenMP placement, communication policy, precision, GEMM kernel, or other downstream controls.

Where such controls are not explicitly listed above, retain the installed package/default behavior consistently for all six candidates.

The fixed values inherited from TASK-000 are provisional controls for experimental isolation. They are not claimed to be optimal for the 2×8 topology.

#### C. Experiment preparation

Create a dedicated experiment area, preferably:

```text
experiments/2x8-GAAS/phase1a-n-coarse/
```

with:

```text
README.md
scripts/
outputs/
```

Prepare a reusable sweep script or equivalent execution mechanism.

Prefer executing the six N candidates sequentially within the same 2×8 allocation when practical, because this reduces node/allocation variation and scheduler overhead.

If operational constraints make a single allocation impractical, Codex may split the six approved candidates across multiple 2×8 allocations without additional human approval, provided:

- the scientific controls remain identical;
- the candidate set does not change;
- every attempt remains uniquely identified;
- queue/project/resource restrictions remain unchanged; and
- allocated nodes/jobs are recorded.

No baseline repeat or opening/closing control is mandatory for TASK-001.

#### D. Minimal pre-submit validation

Before submission, perform only the checks needed to catch obvious execution mistakes:

- syntax-check any newly written or modified shell/PBS script;
- verify the six approved N values;
- verify the fixed controls from Section 1.4B;
- verify 2 nodes × 8 GPUs, 16 ranks, one rank/GPU;
- verify 4×4 column grid;
- verify the existing validated NVIDIA container / multinode launcher is still being used;
- verify the requested queue is either `gpu_as` or `gpu_ded`;
- perform a lightweight queue-aware eligibility check sufficient to avoid selecting nodes that cannot actually execute under the chosen queue.

Do not repeat:

- the comprehensive Phase-0 topology probe;
- the complete software/provenance inventory;
- container hashing;
- full package documentation review;
- flag-by-flag support verification;
- GPUDirect/NCCL/UCX characterization;
- exhaustive node-health telemetry;

unless execution directly reveals a material contradiction with previously accepted evidence.

#### E. Per-candidate evidence

For each attempted N preserve, when emitted:

- experiment / attempt identifier;
- PBS job ID;
- queue;
- allocated nodes;
- N;
- fixed configuration;
- PBS/application completion state;
- correctness status;
- finite residual / normalized residual;
- overall HPL-MxP GFLOP/s;
- LU time;
- LU GFLOP/s;
- iterative-refinement time;
- iterative-refinement iteration count;
- host-memory usage/headroom;
- GPU-memory usage/headroom;
- stdout/stderr.

The normal HPL-MxP output is the primary scientific evidence.

Separate profiling, Nsight, continuous GPU monitoring, hardware counters, or additional diagnostic instrumentation are not required.

Failure of an auxiliary pre/post health snapshot alone does not invalidate an otherwise complete HPL-MxP scored run.

#### F. Result logging

Append factual attempt data to the normal project result structure:

```text
results/metrics.csv
results/RESULTS.md
```

Preserve raw stdout/stderr under the experiment directory.

Codex must report execution facts only.

Do not perform campaign-level interpretation, select a winning N, recommend the refinement region, or update strategic conclusions in `planning/`.

That analysis occurs only after explicit `ANALYSE_RESULTS` authorization.

### 1.5 Relevant Inputs and References

Primary repository:

`QuangPham2404/HPL-MxP-Agent-Test`

Relevant references:

- `tasks/TASK-000.md`
- `planning/blueprint/HPL_MxP_Sweep_Blueprint.md`
- `planning/dependency-graph/README.md`
- `planning/2x8-GAAS.md`
- `experiments/2x8-GAAS/baseline/README.md`
- `experiments/2x8-GAAS/baseline/scripts/run_2x8_baseline.pbs`
- `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.o`
- `multi-node-test/GAAS_MULTINODE_SETUP.md`
- `workflow/07-Workflow.md`
- `workflow/08-Workflow-Multinode-Tuning.md`
- active `AGENTS.md` and `APPLICATION.md`
- `results/metrics.csv`

Existing Phase-0 evidence should be referenced rather than reproduced.

No OpenMxP repository access is required or authorized.

### 1.6 Execution Scope

#### Allowed

Codex may:

- create the TASK-001 experiment directory and supporting README/scripts;
- reuse the validated TASK-000 NVIDIA container and multinode launcher;
- implement the approved six-point N sweep;
- set `--fill-device 1` for all six points;
- execute the six approved candidates sequentially in one allocation or split them across multiple equivalent 2×8 allocations when operationally useful;
- choose between `gpu_as` and `gpu_ded` based on actual scheduler/node eligibility;
- perform queue-aware node selection;
- use an eligible scheduler-selected pair or an explicitly host-pinned eligible pair;
- perform lightweight syntax/configuration checks;
- submit and boundedly monitor the approved jobs;
- preserve outputs and factual metrics;
- automatically recover/retry clearly non-scientific Track-1 scheduler, output-path, synchronization, or workflow failures;
- retry an interrupted candidate with a new attempt label when no meaningful scientific result was produced;
- continue with other approved candidates after one candidate produces scientifically meaningful failure evidence, when doing so remains safe and within scope;
- update experiment/results/task/progress bookkeeping;
- commit and push approved execution artifacts under normal repository policy.

Reasonable scheduler-only adjustments such as attempt names, output paths, host pinning, or sufficient walltime may be made without new authorization as long as they do not alter the scientific configuration or approved resource shape.

#### Prohibited

Codex and workers must not:

- use any queue other than `gpu_as` or `gpu_ded`;
- use another accounting project;
- change the 2-node × 8-GPU resource shape;
- add N candidates outside the six approved values;
- perform the later ~5% N refinement;
- change `NB=3072`;
- change the 4×4 process grid;
- change `nporder=column`;
- change rank/GPU mapping policy;
- tune OpenMP placement/thread count;
- tune CPU or memory affinity;
- tune DGEMV partitioning;
- tune MPI/NCCL broadcast policy;
- tune U-panel chunking;
- tune fill-device buffer size;
- tune Anq residency;
- tune precision, GEMM kernel, scheduling priorities, or communication controls;
- perform an N×NB Cartesian sweep;
- repeat Phase-0 characterization without a concrete contradiction;
- require mandatory repeat runs for statistical completeness;
- access or depend on OpenMxP;
- perform campaign-level strategic analysis;
- promote an N candidate as the winner;
- begin Phase 1B NB tuning.

### 1.7 Execution Constraints

1. Follow root `AGENTS.md` and the active Workflow v2.
2. Substantive execution remains delegated through the project-approved OpenCode worker workflow.
3. Use PBS compute-node execution.
4. Resource shape is fixed at:

   ```text
   2 nodes × 8 H200 GPUs
   16 MPI ranks
   one rank/GPU
   place=scatter
   no mpiprocs
   ```

5. Accounting project:

   ```text
   hpc_ebslee
   ```

6. **Only these queues are authorized:**

   ```text
   gpu_as
   gpu_ded
   ```

   Every other cluster queue is explicitly outside TASK-001 authorization.

7. A node reporting scheduler state `free` does **not** by itself establish that the node is eligible for the selected queue. Queue eligibility must be checked using the available scheduler/site information before host-pinning or relying on a node pair.

8. If a candidate/node combination cannot run in one approved queue because of eligibility, Codex may use the other approved queue without human escalation.

9. Do not submit to an unauthorized queue merely because suitable nodes appear idle or free.

10. Preserve the validated container-MPI / `pbsdsh` launcher contract from TASK-000.

11. Use the fixed scientific configuration in Section 1.4B.

12. Use:

   ```text
   --skip-tests 0
   --monitor-gpu 0
   ```

13. Preserve every actual submitted attempt using unique output/attempt names.

14. One valid scored run per N is sufficient. No mandatory second or third repetition is required.

15. A scientifically meaningful failed candidate must be preserved rather than silently retried with changed controls.

16. A single candidate OOM, correctness failure, or invalid result does not automatically terminate the whole task if the remaining approved candidates can still be executed safely without configuration changes.

17. Track-1 operational recovery does not require human intervention when it stays within this approved scope.

### 1.8 Success Criteria

TASK-001 is operationally complete when:

- a dedicated coarse-N experiment area exists;
- the six approved N candidates have each been attempted, except where a documented systemic blocker legitimately prevents further execution;
- all scored candidates use identical fixed scientific controls other than N;
- `--fill-device 1` is active for every candidate;
- only `gpu_as` and/or `gpu_ded` were used;
- 2×8 allocation and 16-rank mapping are preserved;
- every valid scored point reports normal HPL-MxP output, finite correctness data, and `PASSED`;
- overall HPL-MxP performance is captured for valid points;
- LU and IR timing/performance information is captured when emitted;
- memory/headroom information from normal application output is preserved when emitted;
- scientifically meaningful failed/invalid candidates are retained as evidence and not ranked as valid performance points;
- factual metrics are added to the project result structure;
- raw stdout/stderr is preserved;
- Codex completes the Execution Report without selecting a winning N or refinement direction;
- task/progress/result bookkeeping is committed/pushed;
- TASK-001 is handed back as:

  ```text
  status: EXECUTED
  current_owner: strategic-analyst
  ```

No comprehensive reprobe, repeated package audit, profiling run, mandatory repeatability study, or strategic interpretation is required for completion.

### 1.9 Stop / Escalation Conditions

Codex should stop the affected work and return for Strategic Analyst / Human direction only when:

- the validated container or multinode launcher has materially changed and existing evidence can no longer reasonably be reused;
- rank/GPU mapping is materially incorrect and cannot be restored through normal Track-1 recovery;
- execution requires a scientific-control change outside Section 1.4B;
- execution requires a resource shape other than 2×8;
- execution requires a queue other than `gpu_as` or `gpu_ded`;
- execution requires another accounting project;
- several candidates exhibit a common correctness/runtime failure suggesting a systemic scientific or platform issue rather than an isolated N boundary;
- the approved experiment cannot proceed without adding/changing N candidates;
- another required action would exceed Section 1.11 authorization.

Do **not** escalate merely because:

- a `free` node is not eligible for the chosen queue;
- one approved queue cannot currently provide an eligible pair;
- the other approved queue must be used;
- scheduler placement differs from a preferred node pair;
- a normal Track-1 synchronization/output/scheduler issue occurs;
- a single N candidate produces a genuine OOM or correctness failure while other approved candidates remain safe to execute;
- comprehensive Phase-0 evidence was not regenerated.

Queue eligibility and ordinary scheduler placement are operational concerns. Use `gpu_as` or `gpu_ded` as appropriate and continue within scope.

### 1.10 Strategic Analyst Notes

This task deliberately implements only the **coarse discovery stage** of Phase 1A.

The intended campaign sequence remains:

```text
TASK-001:
coarse N sweep
        ↓
ANALYSE_RESULTS
        ↓
identify best-performing region(s)
and any distinct residency/IR transition
        ↓
new human-approved task:
~5% local N refinement
        ↓
analysis / verification
        ↓
Phase 1B NB tuning
```

Do not let TASK-001 expand into the refinement stage.

The pivot and candidate values are mechanisms for constructing a broad search. They are not expected winners.

Interpretation after execution must consider at minimum:

```text
overall GFLOP/s
LU time / LU GFLOP/s
IR time
IR/LU
IR iterations
correctness
host/device memory headroom
candidate N / N_pivot
```

The final analysis should distinguish end-to-end gain from LU-only gain.

The immutable TASK-000 baseline remains:

```text
N = 700000
overall = 4.8037e+06 GFLOP/s
```

for campaign-wide percentage reporting.

TASK-001 does not require rerunning that baseline.

### 1.11 Authorization

status: APPROVED

approved_scope: Execute TASK-001 Phase-1A coarse N / FP64-residency discovery on the established 2x8 GAAS NVIDIA HPL-MxP topology. Create a dedicated experiment using exactly N={353280,404480,454656,504832,556032,606208}; vary only N while enabling --fill-device 1 and keeping NB=3072, 4x4 column grid, OMP_NUM_THREADS=8, GPU mapping, precision, MPI-panel policy, scheduling controls, test behavior, and all other scientific controls fixed/default as specified. Use only 2 nodes x 8 H200 GPUs, 16 ranks, project hpc_ebslee, and queues gpu_as or gpu_ded; all other queues are unauthorized. Queue/node eligibility must be checked rather than inferred from a node's free state. Codex may choose between the two approved queues, host-pin eligible nodes, split the candidate set across equivalent allocations, make reasonable scheduler-only adjustments, and perform Track-1 operational retries without new approval. Preserve normal correctness, LU, IR, overall-performance, memory, job, node, and stdout/stderr evidence and update factual results/task/progress artifacts. One valid scored attempt per N is sufficient; no mandatory repeats, comprehensive Phase-0 reprobe, repeated flag/provenance audit, profiling, extra telemetry, baseline repeat, ~5% N refinement, NB tuning, additional N candidates, OpenMxP access, scientific-control changes, or strategic interpretation are authorized.

approved_by: user

---

## 2. CODEX EXECUTION REPORT

<!-- Codex completes this section after execution; do not rewrite section 1. -->

### 2.1 Execution Status

status: COMPLETE

### 2.2 Orchestration Summary

Four NTU-HPC-Large OpenCode worker assignments covered preparation, initial
synchronization and eligibility checks, resumed submission/monitoring, and
output retrieval/factual extraction. The resolved runtime completed the
previously blocked submission step. Codex reviewed the raw evidence and
updated the Execution Report. No analysis authorization was used.

### 2.3 Work Executed

- Created `experiments/2x8-GAAS/phase1a-n-coarse/README.md`,
  `scripts/run_phase1a_n_coarse.pbs`, and `outputs/.gitkeep`.
- Prepared the six approved N candidates to run sequentially in one 2×8
  allocation, with fixed controls and attempt-specific candidate evidence.
- Committed and pushed the reviewed preparation as
  `70c56a1b90643631dc9e89d1f77018b46ab76983`.
- On resume, fetched `origin` without modifying the dirty primary clone and
  created a new clean detached worktree at
  `.codex-worktrees/TASK-001-f9e3a5a-phase1a-v1`, commit
  `f9e3a5aa2cc3faf840a19a5c311e6857a8f16f6c`. The prior
  `.codex-worktrees/TASK-001-70c56a1-phase1a` worktree was preserved.
- Immediately before submission at 2026-09-27 11:33:06 +08:00, verified
  `hpc-gaas-g12` and `hpc-gaas-g15` had state `free`, Qlist
  `gpu_as,gpu_ppu`, and zero assigned CPU/GPU/memory resources. `gpu_as` was
  enabled and started. The other fully free nodes observed were either
  `gpu_aisg`-only or did not form an eligible pair in `gpu_ded`.
- Submitted exactly one job, `72624.gaas`, at 11:33:07 +08:00 using `gpu_as`,
  project `hpc_ebslee`, host-pinned `g12` + `g15`, `select` with 8 GPUs per
  node and no `mpiprocs`, `place=scatter`, and `ATTEMPT_TAG=v1`.
- Bounded monitoring at 11:38:14 and 11:43:18 showed the job running on the
  selected hosts. At 11:48:23 it was terminal `F`, `Exit_status=0`; PBS
  reported walltime used `00:11:45` of `01:30:00`.
- The script completed all six candidates sequentially in the one allocation.
  Every candidate status recorded exit status 0. All six application outputs
  contain a finite normalized residual and `PASSED`, the final test-loop
  markers, overall and LU performance, LU and iterative-solver times, and
  memory/headroom lines. The exact per-candidate values are preserved in the
  experiment README and raw `.out` files.
- Retrieved all six candidate `.out`, `.err`, and `.status` files plus PBS
  `.o` and `.e` into the canonical local `outputs/` directory. All 20 local
  files were verified byte-identical to the remote worktree copies by
  SHA-256.
- Appended six unique factual rows to `results/metrics.csv` and regenerated
  `results/RESULTS.md` with the existing generator. Updated the experiment
  README with job provenance and emitted per-candidate correctness,
  performance, timing, iteration, and memory values.

### 2.4 Operational Validation

- `bash -n` on the PBS script passed during preparation. The execution
  worktree was clean at the exact pushed commit before submission; task and
  script SHA-256 values matched the local approved tree. Section 1.11 was
  byte-identical and remained `status: APPROVED`, `approved_by: user`.
- The pre-submit gate checked queue enablement, node state, Qlist, and
  assigned resources immediately before qsub; the immediate qstat confirmed
  the requested queue, project, host-pinned 2×8 shape, scatter placement, and
  walltime.
- All 20 retrieved files matched their remote SHA-256 values. All 6 CSV rows
  are unique; existing rows and the header are preserved. The CSV has 200
  data rows with no malformed row. `git diff --check` passed for edited
  text artifacts; raw application/PBS output was left byte-exact and contains
  trailing spaces emitted by the benchmark/topology display.
- The PBS `.o` includes terminal color escape sequences and was preserved
  byte-for-byte. Candidate `.err` files retain the container bridge
  diagnostics and a group-ID warning; all six candidates nevertheless
  completed with exit status 0 and finite `PASSED` results.

### 2.5 Evidence and Artifacts

- Preparation: `experiments/2x8-GAAS/phase1a-n-coarse/` at commit
  `70c56a1b90643631dc9e89d1f77018b46ab76983`.
- Remote execution tree:
  `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test/.codex-worktrees/TASK-001-f9e3a5a-phase1a-v1`
  at `f9e3a5aa2cc3faf840a19a5c311e6857a8f16f6c`.
- PBS job `72624.gaas`; queue/hosts/project and scheduler facts are in the
  qstat record and `experiments/2x8-GAAS/phase1a-n-coarse/outputs/`.
- Per-candidate records: `experiments/2x8-GAAS/phase1a-n-coarse/outputs/`
  and the run-summary table in the experiment README.
- Structured results: `results/metrics.csv` and generated
  `results/RESULTS.md`.
- Remote primary clone was `87fb61e829832a3bc07c2579d8472aa1be279f13`
  with 168 pre-existing status entries. It and all pre-existing worktrees
  were left untouched. The newly created execution worktree now contains the
  submitted job's generated hostfile and raw outputs; it was not cleaned or
  removed.
- Queue and scheduler evidence was obtained through BatchMode SSH using
  bounded PBS checks immediately before submission and at the recorded
  monitoring times.

### 2.6 Files Changed

- `experiments/2x8-GAAS/phase1a-n-coarse/README.md`
- `experiments/2x8-GAAS/phase1a-n-coarse/outputs/` (20 attempt-specific raw
  evidence files; `.gitkeep` retained)
- `experiments/2x8-GAAS/phase1a-n-coarse/scripts/run_phase1a_n_coarse.pbs`
- `results/metrics.csv`
- `results/RESULTS.md`
- `tasks/TASK-001.md`
- `progress/2026-09-27-progress_s9.md`

### 2.7 Missing / Unavailable Evidence

No required execution evidence remains missing. No strategic analysis,
candidate ranking, percentage-baseline comparison table, or next-direction
recommendation was created; those remain with the Strategic Analyst under
explicit `ANALYSE_RESULTS` authorization.

### 2.8 Execution Errors / Exceptions

The earlier session's OpenCode API connection failures occurred before SSH
or qsub and were resolved for this resume. The resumed worker completed the
approved submission and evidence capture. No execution error prevented the
task from completing; the bridge/group warning remains visible in the
preserved `.err` files.

### 2.9 Scope Compliance

Work stayed within the approved TASK-001 scope. Exactly one job used the
approved `gpu_as` queue, project, topology, launcher, and fixed scientific
controls. No off-scope queue, second job, retry, control change, baseline
repeat, strategic analysis, or OpenMxP access occurred. The pre-existing
local untracked `hpl-mxp-runs-on-gaas/` directory, dirty remote primary clone,
and prior worktrees were preserved. All substantive assignments used the
NTU-HPC-Large OpenCode runtime.

### 2.10 Handoff to Strategic Analyst

Execution is complete. Front matter is `EXECUTED / strategic-analyst`;
Section 1.11 remains unchanged and approved. The Strategic Analyst may now
review the raw evidence and factual rows. No campaign interpretation or
recommendation was made by Codex; the user's separate analysis authorization
is required before analysis begins.
