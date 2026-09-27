# 2x8-GAAS phase1a-n-coarse

TASK-001 Phase-1A coarse N / FP64-residency discovery sweep for the 2 GAAS
nodes x 8 H200 GPUs HPL-MxP campaign: the six approved N candidates run
sequentially inside one 2x8 allocation, varying only N. Every other
scientific control is fixed (tasks/TASK-001.md Section 1.4B), including
`--fill-device 1` for the whole sweep so changes in N can expose the
FP64-residency transition.

**Status (2026-09-27): PREPARED, not submitted.** Local preparation only:
script written and syntax-checked, README and `outputs/` created; no queue
selected, no cluster access, no submission. Submission belongs to the
TASK-001 execution step and must pass `-q gpu_as` or `-q gpu_ded` (the only
authorized queues); queue/node eligibility (`pbsnodes`/`Qlist`) is checked at
that time per TASK-001 Sections 1.4D and 1.7.7, not inferred from a node's
`free` state.

## Structure

- `scripts/run_phase1a_n_coarse.pbs` — single reusable sweep PBS script (six
  candidates sequentially in one allocation; per-candidate evidence files;
  attempt tag comes from the `ATTEMPT_TAG` environment at submission)
- `outputs/` — per-candidate application `.out`/`.err`/`.status` evidence and
  PBS `.o`/`.e` job evidence (tracked, never overwritten; every rerun gets a
  new attempt tag)

## Approved candidate set (TASK-001 Section 1.4A)

| N | approx. % of pivot 505160 | per-GPU FP64 device matrix (GB) |
|---|---|---|
| 353280 | ~70% | 62.4 |
| 404480 | ~80% | 81.8 |
| 454656 | ~90% | 103.4 |
| 504832 | ~100% | 127.4 |
| 556032 | ~110% | 154.6 |
| 606208 | ~120% | 183.7 |

These six values are the complete scientific sweep for TASK-001; no finer N
sweep, boundary points, or NB combinations. The candidate generation
intentionally does not require every N to be divisible by `NB=3072`.

## Fixed scientific controls (only N varies)

```
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

Configuration supplied by the Strategic Analyst and approved by the Human
Leader in tasks/TASK-001.md Section 1.4B; Codex/workers did not derive,
optimize, or modify it. Relative to the TASK-000 baseline run script,
`--fill-device 1` is the one added flag (intentionally enabled for the whole
Phase-1A sweep). All controls not listed above (e.g.
`--fill-device-buffer-size`, `--Anq-device`, U-panel chunking, DGEMV
partitioning, CPU/memory affinity, OpenMP placement beyond the thread count,
communication policy, precision, GEMM kernel) keep the installed
package/default behavior consistently for all six candidates.

## Per-candidate command

Identical for every candidate except `--n <N>`, launched inside the PBS job
through the validated Approach-1 container launcher:

```bash
apptainer exec --nv \
  -B /opt/pbs:/opt/pbs \
  -B /var/spool/pbs:/var/spool/pbs \
  -B "$REPO_ROOT":"$REPO_ROOT" \
  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif \
  /usr/local/mpi/bin/mpirun -np 16 \
    --hostfile "$PWD/hostfile" \
    --mca plm_rsh_agent multi-node-test/rsh_pbsdsh_container.sh \
    --mca plm_rsh_no_tree_spawn 1 \
    --mca plm_rsh_num_concurrent 1 \
    --mca routed direct \
    -x PATH -x LD_LIBRARY_PATH \
    --bind-to none \
    /workspace/hpl-mxp.sh \
      --n <N> --nb 3072 --nprow 4 --npcol 4 --nporder column \
      --gpu-affinity 0:1:2:3:4:5:6:7 --sloppy-type FP16 \
      --use-mpi-panel-broadcast 0 --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

with `<N>` one of the six approved values, application stdout/stderr
redirected to that candidate's `.out`/`.err` evidence file.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ngpus=8` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `01:30:00` for the six-run sequential sweep (the single-run N=700000 baseline job used 00:05:46 of 00:45:00); may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by all candidates in the allocation |
| Process grid | fixed 4x4, `nporder=column` (not auto-derived) |
| GPU affinity | `0:1:2:3:4:5:6:7` (node-local rank -> local GPU) |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mirrors
`experiments/2x8-GAAS/baseline/scripts/run_2x8_baseline.pbs` (TASK-000)
exactly for container/MPI/orted/pbsdsh launcher, hostfile, resource request,
accounting project, bind mounts, daemon flags, module set, and pre/post
health-snapshot pattern.

## Sequential-sweep behavior

- The candidates run one at a time inside the single 2x8 allocation (same
  nodes for all candidates; reduces node/allocation variation and scheduler
  overhead, TASK-001 Section 1.4C).
- A candidate with a nonzero exit is recorded and the sweep continues with
  the next candidate; the job exits nonzero overall if any candidate failed.
- Evidence guard: before any candidate starts, the script aborts if any
  target `.out`/`.err`/`.status` file already exists — reruns must use a new
  `ATTEMPT_TAG`; existing evidence is never overwritten.
- If the job is killed mid-candidate (e.g. walltime), that candidate keeps
  its `.out`/`.err` but has no `.status` file, and later candidates were not
  run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query) are
  taken once around the whole sweep, matching the baseline job pattern;
  per-candidate host/device memory evidence comes from the application's own
  memory-report lines in each `.out` file.
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-candidate attempt ID: `2x8-GAAS-phase1a-n-coarse_n<N>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase1a-n-coarse_n353280_v1`).

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| candidate status | `outputs/<attempt>.status` (attempt, experiment, PBS job ID, queue, nodes, N, fixed-controls line, start/end timestamps, exit status, evidence paths) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase1a-n-coarse_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase1a-n-coarse_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names. `N_SUBSET` splits do not change the per-candidate ID
scheme; each submitted allocation is a separate sweep tag with
attempt-specific files.

## Submission (from this directory; requires TASK-001 execution authorization)

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase1a-n-coarse_v1.o \
     -e outputs/2x8-GAAS-phase1a-n-coarse_v1.e \
     scripts/run_phase1a_n_coarse.pbs
```

Optional operational split across equivalent 2x8 allocations (TASK-001
Section 1.4C fallback; unchanged controls, new tag, only approved values):

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v2,N_SUBSET=556032 606208" \
     -o outputs/2x8-GAAS-phase1a-n-coarse_v2.o \
     -e outputs/2x8-GAAS-phase1a-n-coarse_v2.e \
     scripts/run_phase1a_n_coarse.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (as validated
for the Phase-0 probe, job 72591.gaas):

```bash
qsub -l select=host=<n1>:ngpus=8:ncpus=96:mem=2000GB+host=<n2>:ngpus=8:ncpus=96:mem=2000GB ...
```

`N_SUBSET` values outside the six approved N values (and duplicates) are
rejected by the script; the candidate set cannot silently change.

## Mechanical feasibility context (arithmetic only)

Per-GPU FP64 device-matrix footprint under `--fill-device 1` is
`N^2 * 8 / 16` bytes (HPL-MxP fills the FP64 matrix onto the device;
`--fill-device` overrides `--Anq-device`). Measured reference points: device
memory available MIN at the N=700000 baseline run was 138.739 GB, and
Phase-0 initially-free device memory was 143156 MiB (~150.1 GB). The
per-GPU column in the candidate table above shows the resulting arithmetic;
whether the two largest candidates complete, spill, or fail under
`--fill-device 1` is the residency-transition evidence the sweep is designed
to produce, and per TASK-001 Sections 1.7.15-16 such failures are preserved
as evidence while the sweep continues. Host-side, the per-node FP64 matrix
(`N^2 * 8 / 2`) is 1470 GB at the largest candidate, below the 1960 GB at
the PASSED N=700000 baseline against the 2000 GB per-node cgroup. These are
mechanical derived values, not predictions or recommendations.

## Available baseline provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, hpc-gaas-g12 + hpc-gaas-g15, PASSED, exit 0 |
| Baseline performance | overall `4.8037e+06` GFLOP/s (per GPU 300228.24); LU 29.17 s / `7.8390e+06` GFLOP/s; IR 18.44 s, 3 iterations; normalized residual `2.520608E-04` |
| Baseline evidence | `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.{o,e}` (+ submission/monitor logs); `experiments/2x8-GAAS/baseline/README.md` |
| Boundary evidence | `2x8-GAAS-baseline_v1` (N=737280) host-memory OOM kill, exit 137 — historical; not retried in TASK-001 |
| Flag support | installed v26.02 binary records `--fill-device INT:{0,1} [0]` (overrides `--Anq-device`): `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |
| Phase-0 topology evidence | `experiments/2x8-GAAS/baseline/scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated, per TASK-001 Section 1.4D |

The baseline run used the same scored-run protocol as this sweep
(`--skip-tests 0 --monitor-gpu 0`) and is the campaign percentage denominator
for 2x8-GAAS comparisons. TASK-001 does not rerun it.

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
is preserved as evidence and is not ranked as a valid performance point
(TASK-001 Sections 1.7.15-16, 1.8). Do not classify success from exit status
alone.

## Run summary

No attempts submitted yet (experiment prepared 2026-09-27, local preparation
only). After execution, record per candidate: attempt, PBS job ID, queue,
allocated nodes, result, residuals, verification, overall/per-GPU GFLOP/s,
LU/IR timings and GFLOP/s, host/device memory headroom, and evidence paths.
Extracted rows go to `results/metrics.csv` / `results/RESULTS.md` during the
TASK-001 results-logging step, not inside this directory.

## Evidence paths

- `outputs/` — per-candidate `.out`/`.err`/`.status` and PBS `.o`/`.e`
- `scripts/run_phase1a_n_coarse.pbs` — the sweep script (header comment
  documents purpose, working directory, inputs, outputs, and assumptions)
