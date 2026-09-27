# 2x8-GAAS phase1b-nb-screen

TASK-003 Phase-1B bounded NB screen for the 2 GAAS nodes x 8 H200 GPUs
HPL-MxP campaign: the six approved NB candidates run sequentially inside
one 2x8 allocation at the retained Phase-1A problem size `N=429056`,
varying only NB. Every other scientific control is fixed
(tasks/TASK-003.md Section 1.4B) and is identical to the validated TASK-002
Phase-1A controls, including `--fill-device 1`. `NB=3072` is the
same-protocol Phase-1A control and runs first; the remaining candidates run
ascending. One valid scored attempt per approved NB is sufficient
(tasks/TASK-003.md Sections 1.4A, 1.7.13).

**Status (2026-09-27): prepared locally; v1 sweep not yet submitted.**
Submission requires TASK-003 execution authorization and a lightweight live
queue/node eligibility check (Section 1.4D). Any rerun must use a new
`ATTEMPT_TAG` and pass `-q gpu_as` or `-q gpu_ded` (the only authorized
queues).

## Structure

- `scripts/run_phase1b_nb_screen.pbs` — single reusable sweep PBS script (six
  candidates sequentially in one allocation; per-candidate evidence files;
  attempt tag comes from the `ATTEMPT_TAG` environment at submission)
- `outputs/` — per-candidate application `.out`/`.err`/`.status` evidence and
  PBS `.o`/`.e` job evidence (tracked, never overwritten; every rerun gets a
  new attempt tag)

## Approved candidate set (TASK-003 Section 1.4A)

Execution order (recorded per Section 1.4C): `3072` first as the
same-protocol Phase-1A control, then ascending `1024, 2048, 4096, 5120,
6144` so panel/workspace pressure grows monotonically toward the top of the
approved range and any memory/workspace boundary is approached from below.

| order | NB | role |
|---|---|---|
| 1 | 3072 | same-protocol Phase-1A control (retained TASK-002 operating point) |
| 2 | 1024 | smaller-panel region |
| 3 | 2048 | smaller-panel region |
| 4 | 4096 | larger-panel region |
| 5 | 5120 | larger-panel region |
| 6 | 6144 | larger-panel region (top of approved range) |

These six values are the complete scientific candidate set for TASK-003; no
NB above 6144 and no adaptive intermediate values (Section 1.4A). All six
should normally be attempted. A larger remaining NB candidate may be
skipped only when an already-attempted candidate provides a clear safety
boundary (device/host OOM, benchmark-workspace allocation failure, or
correctness invalidity with memory-exhaustion evidence); skipped values and
boundary evidence must be recorded explicitly (Sections 1.4A, 1.7.15). A
valid but slower candidate is never grounds to truncate the sweep
(Section 1.7.16).

Mechanical note (arithmetic only): only `NB=1024` divides `N=429056`
evenly; per Section 1.3, `N % NB == 0` is not assumed to be a performance
requirement.

## Fixed scientific controls (only NB varies)

```
N = 429056
OMP_NUM_THREADS=8
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

Configuration supplied by the Strategic Analyst and approved by the Human
Leader in tasks/TASK-003.md Section 1.4B; it is identical to the TASK-002
Section 1.4B set at the retained N. Codex/workers did not derive, optimize,
or modify it. All controls not listed above (e.g. `--fill-device-buffer-size`,
`--Anq-device`, U-panel chunking, DGEMV partitioning, CPU/memory affinity,
OpenMP placement beyond the thread count, communication policy, precision,
GEMM kernel) retain the same installed package/default behavior used in
TASK-002, consistently for all six candidates.

## Per-candidate command

Identical for every candidate except `--nb <NB>`, at fixed `--n 429056`,
launched inside the PBS job through the validated Approach-1 container
launcher (same contract as TASK-001/TASK-002):

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
      --n 429056 --nb <NB> --nprow 4 --npcol 4 --nporder column \
      --gpu-affinity 0:1:2:3:4:5:6:7 --sloppy-type FP16 \
      --use-mpi-panel-broadcast 0 --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

with `<NB>` one of the six approved values, application stdout/stderr
redirected to that candidate's `.out`/`.err` evidence file.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ngpus=8` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `01:30:00`, same as the validated TASK-001/TASK-002 sweeps (TASK-002's five-candidate sequential sweep at larger N values used `00:07:01` of `01:30:00`); may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by all candidates in the allocation |
| Process grid | fixed 4x4, `nporder=column` (not auto-derived) |
| GPU affinity | `0:1:2:3:4:5:6:7` (node-local rank -> local GPU) |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mechanically
mirrors `experiments/2x8-GAAS/phase1a-n-refine/scripts/run_phase1a_n_refine.pbs`
(TASK-002), which itself mirrors the TASK-001/TASK-000 scripts, for
container/MPI/orted/pbsdsh launcher, hostfile, resource request, accounting
project, bind mounts, daemon flags, module set, and pre/post health-snapshot
pattern. Only the approved NB set (at fixed N=429056), the candidate order,
experiment/attempt identifiers, and task-section references differ.

## Sequential-sweep behavior

- The candidates run one at a time inside the single 2x8 allocation (same
  nodes for all candidates; reduces node/allocation variation and scheduler
  overhead, TASK-003 Section 1.4C).
- `NB=3072` runs first as the same-allocation, same-protocol control before
  any new NB territory is entered (Section 1.4C); the remaining candidates
  run ascending.
- A candidate with a nonzero exit is recorded and the sweep continues with
  the next candidate; the job exits nonzero overall if any candidate failed.
- The script itself always attempts every candidate in the submitted set.
  Any stop of larger remaining NB values under the Section 1.4A
  safety-boundary rule is an orchestrator decision made and documented
  against the preserved evidence (skipped values + boundary evidence), not
  an automatic in-script behavior.
- Evidence guard: before any candidate starts, the script aborts if any
  target `.out`/`.err`/`.status` file already exists — reruns must use a new
  `ATTEMPT_TAG`; existing evidence is never overwritten.
- If the job is killed mid-candidate (e.g. walltime), that candidate keeps
  its `.out`/`.err` but has no `.status` file, and later candidates were not
  run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query) are
  taken once around the whole sweep, matching the TASK-001/TASK-002 job
  pattern; per-candidate host/device memory evidence comes from the
  application's own memory-report lines in each `.out` file.
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-candidate attempt ID: `2x8-GAAS-phase1b-nb-screen_nb<NB>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase1b-nb-screen_nb3072_v1`).

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| candidate status | `outputs/<attempt>.status` (attempt, experiment, PBS job ID, queue, nodes, N, NB, fixed-controls line, start/end timestamps, exit status, evidence paths) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase1b-nb-screen_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase1b-nb-screen_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names. `NB_SUBSET` splits do not change the per-candidate ID
scheme; each submitted allocation is a separate sweep tag with
attempt-specific files.

## Submission (from this directory; requires TASK-003 execution authorization)

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase1b-nb-screen_v1.o \
     -e outputs/2x8-GAAS-phase1b-nb-screen_v1.e \
     scripts/run_phase1b_nb_screen.pbs
```

Optional operational split across equivalent 2x8 allocations (TASK-003
Section 1.4C fallback; unchanged controls, new tag, only approved values):

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v2,NB_SUBSET=4096 5120 6144" \
     -o outputs/2x8-GAAS-phase1b-nb-screen_v2.o \
     -e outputs/2x8-GAAS-phase1b-nb-screen_v2.e \
     scripts/run_phase1b_nb_screen.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (as validated
for the Phase-0 probe, job 72591.gaas, and used by the TASK-001 sweep, job
72624.gaas, and the TASK-002 sweep, job 72688.gaas):

```bash
qsub -l select=host=<n1>:ngpus=8:ncpus=96:mem=2000GB+host=<n2>:ngpus=8:ncpus=96:mem=2000GB ...
```

`NB_SUBSET` values outside the six approved NB values (and duplicates) are
rejected by the script; the candidate set cannot silently change.

## Mechanical feasibility context (arithmetic only)

The per-GPU FP64 device-matrix footprint under `--fill-device 1` is
`N^2 * 8 / 16` bytes, i.e. approximately 92.0 GB per GPU at `N=429056` —
identical for every candidate because N is fixed; NB does not change the
stored-matrix footprint. What NB does change (panel count/geometry,
workspace demand, and thus memory headroom) is observed from each
candidate's application memory-report lines, not predicted here. TASK-002
measured device memory available MIN 138.739 GB with post-matrix-generation
headroom 2.767 GB at this N with NB=3072. These are mechanical derived
values, not predictions or recommendations.

## Available baseline provenance (context only; no analysis)

| item | value |
|---|---|
| Retained Phase-1A operating point (TASK-002) | `2x8-GAAS-phase1a-n-refine_n429056_v1` (N=429056, NB=3072), PBS job 72688.gaas, queue gpu_as, hpc-gaas-g12 + hpc-gaas-g15, PASSED, exit 0; overall `5.6091e+06` GFLOP/s; LU 7.96 s / `6.6130e+06` GFLOP/s; IR 1.43 s / 3 iterations; device headroom after matrix generation 2.767 GB; host consumption MAX 0.004 GB |
| TASK-002 evidence | `experiments/2x8-GAAS/phase1a-n-refine/` (README + `outputs/`) |
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, overall `4.8037e+06` GFLOP/s, PASSED; evidence `experiments/2x8-GAAS/baseline/` |
| Phase-0 topology evidence | `experiments/2x8-GAAS/baseline/scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated, per TASK-003 Section 1.4D |

Both the retained operating point and the original baseline used the same
scored-run protocol as this sweep (`--skip-tests 0 --monitor-gpu 0`); the
original baseline is the campaign percentage denominator for 2x8-GAAS
comparisons. TASK-003 does not rerun it. Ranking, baseline-percentage
tables, and retention decisions are reserved for the authorized
`ANALYSE_RESULTS` step (tasks/TASK-003.md Sections 1.4F, 1.10).

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
should have its phase of failure identified when possible (TASK-003
Sections 1.4E, 1.7.14-15, 1.8). Do not classify success from exit status
alone.

## Evidence paths

- `outputs/` — per-candidate `.out`/`.err`/`.status` and PBS `.o`/`.e`
- `scripts/run_phase1b_nb_screen.pbs` — the sweep script (header comment
  documents purpose, working directory, inputs, outputs, and assumptions)
