# 2x8-GAAS phase1a-n-refine

TASK-002 Phase-1A local N / FP64-residency refinement for the 2 GAAS
nodes x 8 H200 GPUs HPL-MxP campaign: the five approved N candidates run
sequentially inside one 2x8 allocation, varying only N. Every other
scientific control is fixed (tasks/TASK-002.md Section 1.4B), identical to
the validated TASK-001 Phase-1A coarse-sweep controls, including
`--fill-device 1` for the whole sweep. The candidates 404480, 454656, and
504832 deliberately repeat the TASK-001 coarse anchors as the approved
reproducibility/bracketing check (tasks/TASK-002.md Sections 1.4A, 1.7.13);
one valid scored attempt per approved N is sufficient.

**Status (2026-09-27): v1 sweep submitted and completed.** All five approved
candidates ran sequentially in one allocation (PBS job `72688.gaas`, queue
`gpu_as`, nodes `hpc-gaas-g12` + `hpc-gaas-g15`, PBS state `F`, exit status
0, walltime used `00:07:01` of `01:30:00`); every candidate exited 0 with
final HPL-MxP output and `PASSED` verification. Evidence is under `outputs/`;
factual rows are recorded in `results/metrics.csv` / `results/RESULTS.md`.
Any rerun must use a new `ATTEMPT_TAG` and pass `-q gpu_as` or `-q gpu_ded`
(the only authorized queues).

## Structure

- `scripts/run_phase1a_n_refine.pbs` — single reusable sweep PBS script (five
  candidates sequentially in one allocation; per-candidate evidence files;
  attempt tag comes from the `ATTEMPT_TAG` environment at submission)
- `outputs/` — per-candidate application `.out`/`.err`/`.status` evidence and
  PBS `.o`/`.e` job evidence (tracked, never overwritten; every rerun gets a
  new attempt tag)

## Approved candidate set (TASK-002 Section 1.4A)

| N | approx. % of pivot 505160 | role | per-GPU FP64 device matrix (GB) |
|---|---|---|---|
| 404480 | ~80% | lower coarse anchor / deliberate TASK-001 repeat | 81.8 |
| 429056 | ~85% | new ~85% pivot refinement point | 92.0 |
| 454656 | ~90% | current numerical leader / deliberate TASK-001 repeat | 103.4 |
| 480256 | ~95% | new ~95% pivot refinement point | 115.3 |
| 504832 | ~100% | upper coarse anchor / deliberate TASK-001 repeat | 127.4 |

These five values are the complete scientific sweep for TASK-002; no
additional N values, boundary points, or adaptive follow-up points
(tasks/TASK-002.md Section 1.4A). The candidate generation intentionally does
not require every N to be divisible by `NB=3072`.

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
Leader in tasks/TASK-002.md Section 1.4B; it is identical to the TASK-001
Section 1.4B set (the TASK-000 baseline configuration plus `--fill-device 1`,
the one flag Phase 1A added). Codex/workers did not derive, optimize, or
modify it. All controls not listed above (e.g. `--fill-device-buffer-size`,
`--Anq-device`, U-panel chunking, DGEMV partitioning, CPU/memory affinity,
OpenMP placement beyond the thread count, communication policy, precision,
GEMM kernel) retain the same installed package/default behavior used in
TASK-001, consistently for all five candidates.

## Per-candidate command

Identical for every candidate except `--n <N>`, launched inside the PBS job
through the validated Approach-1 container launcher (same contract as
TASK-001):

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
      --n <N> --nb 3072 --nprow 4 --npcol 4 --nporder column \
      --gpu-affinity 0:1:2:3:4:5:6:7 --sloppy-type FP16 \
      --use-mpi-panel-broadcast 0 --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

with `<N>` one of the five approved values, application stdout/stderr
redirected to that candidate's `.out`/`.err` evidence file.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ngpus=8` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `01:30:00` for the five-run sequential sweep (the TASK-001 six-candidate coarse sweep, which includes three of these five N values, used `00:11:45` of `01:30:00`); may be overridden at qsub |
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
mirrors
`experiments/2x8-GAAS/phase1a-n-coarse/scripts/run_phase1a_n_coarse.pbs`
(TASK-001), which itself mirrors
`experiments/2x8-GAAS/baseline/scripts/run_2x8_baseline.pbs` (TASK-000), for
container/MPI/orted/pbsdsh launcher, hostfile, resource request, accounting
project, bind mounts, daemon flags, module set, and pre/post health-snapshot
pattern. Only the approved N set, experiment/attempt identifiers, and
task-section references differ.

## Sequential-sweep behavior

- The candidates run one at a time inside the single 2x8 allocation (same
  nodes for all candidates; reduces node/allocation variation and scheduler
  overhead, TASK-002 Section 1.4C).
- A candidate with a nonzero exit is recorded and the sweep continues with
  the next candidate; the job exits nonzero overall if any candidate failed.
- Evidence guard: before any candidate starts, the script aborts if any
  target `.out`/`.err`/`.status` file already exists — reruns must use a new
  `ATTEMPT_TAG`; existing evidence is never overwritten.
- If the job is killed mid-candidate (e.g. walltime), that candidate keeps
  its `.out`/`.err` but has no `.status` file, and later candidates were not
  run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query) are
  taken once around the whole sweep, matching the TASK-001 job pattern;
  per-candidate host/device memory evidence comes from the application's own
  memory-report lines in each `.out` file.
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-candidate attempt ID: `2x8-GAAS-phase1a-n-refine_n<N>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase1a-n-refine_n404480_v1`).

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| candidate status | `outputs/<attempt>.status` (attempt, experiment, PBS job ID, queue, nodes, N, fixed-controls line, start/end timestamps, exit status, evidence paths) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase1a-n-refine_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase1a-n-refine_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names. `N_SUBSET` splits do not change the per-candidate ID
scheme; each submitted allocation is a separate sweep tag with
attempt-specific files.

## Submission (from this directory; requires TASK-002 execution authorization)

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase1a-n-refine_v1.o \
     -e outputs/2x8-GAAS-phase1a-n-refine_v1.e \
     scripts/run_phase1a_n_refine.pbs
```

Optional operational split across equivalent 2x8 allocations (TASK-002
Section 1.4C fallback; unchanged controls, new tag, only approved values):

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v2,N_SUBSET=480256 504832" \
     -o outputs/2x8-GAAS-phase1a-n-refine_v2.o \
     -e outputs/2x8-GAAS-phase1a-n-refine_v2.e \
     scripts/run_phase1a_n_refine.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (as validated
for the Phase-0 probe, job 72591.gaas, and used by the TASK-001 sweep, job
72624.gaas):

```bash
qsub -l select=host=<n1>:ngpus=8:ncpus=96:mem=2000GB+host=<n2>:ngpus=8:ncpus=96:mem=2000GB ...
```

`N_SUBSET` values outside the five approved N values (and duplicates) are
rejected by the script; the candidate set cannot silently change.

## Mechanical feasibility context (arithmetic only)

Per-GPU FP64 device-matrix footprint under `--fill-device 1` is
`N^2 * 8 / 16` bytes (HPL-MxP fills the FP64 matrix onto the device;
`--fill-device` overrides `--Anq-device`). The per-GPU column in the
candidate table above shows the resulting arithmetic; the two new refinement
points (429056, 480256) fall between the TASK-001 measured anchors, whose
device memory available MIN was 138.739 GB with post-matrix-generation
headroom 17.450 GB at N=404480 and 2.257 GB at N=454656 and N=504832.
Host-side, the per-node FP64 matrix (`N^2 * 8 / 2`) is 1019.4 GB at the
largest candidate (504832), below the 1960 GB at the PASSED N=700000
baseline against the 2000 GB per-node cgroup. These are mechanical derived
values, not predictions or recommendations.

## Available baseline provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, hpc-gaas-g12 + hpc-gaas-g15, PASSED, exit 0 |
| Baseline performance | overall `4.8037e+06` GFLOP/s (per GPU 300228.24); LU 29.17 s / `7.8390e+06` GFLOP/s; IR 18.44 s, 3 iterations; normalized residual `2.520608E-04` |
| Baseline evidence | `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.{o,e}` (+ submission/monitor logs); `experiments/2x8-GAAS/baseline/README.md` |
| TASK-001 coarse sweep (anchor-repeat reference) | `experiments/2x8-GAAS/phase1a-n-coarse/`, PBS job 72624.gaas, queue gpu_as, hpc-gaas-g12 + hpc-gaas-g15, all six candidates PASSED, exit 0 |
| Flag support | installed v26.02 binary records `--fill-device INT:{0,1} [0]` (overrides `--Anq-device`): `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |
| Phase-0 topology evidence | `experiments/2x8-GAAS/baseline/scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated, per TASK-002 Section 1.4D |

The baseline run used the same scored-run protocol as this sweep
(`--skip-tests 0 --monitor-gpu 0`) and is the campaign percentage denominator
for 2x8-GAAS comparisons. TASK-002 does not rerun it.

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
(TASK-002 Sections 1.7.14-15, 1.8). Do not classify success from exit status
alone.

## Run summary

One submitted attempt family (tag `v1`, PBS job `72688.gaas`, submitted
2026-09-27 14:18:55 +08:00 (qtime), queue `gpu_as`, project `hpc_ebslee`,
host-pinned
`select=host=hpc-gaas-g12:ngpus=8:ncpus=96:mem=2000GB+host=hpc-gaas-g15:ngpus=8:ncpus=96:mem=2000GB,place=scatter,walltime=01:30:00`;
PBS `stime` 2026-09-27 14:18:56, completion (`mtime`) 2026-09-27 14:25:58,
`resources_used.walltime` 00:07:01, `job_state=F`, `Exit_status=0`).
All five candidates ran sequentially on the same node pair with identical
fixed controls; each `.status` records `exit_status=0`. Factual per-candidate
data as emitted by the application output (no interpretation):

| N | attempt | normalized residual | verdict | overall GFLOP/s (per GPU) | LU s / LU GFLOP/s | IR s / iterations | host mem cons. MAX / avail. MIN | device mem cons. MAX / avail. MIN |
|---|---|---|---|---|---|---|---|---|
| 404480 | `..._n404480_v1` | 1.416706E-05 | PASSED | 5.1045e+06 (319030.72) | 6.83 / 6.4584e+06 (403652.16) | 1.81 / 3 | 0.004 GB / 231.766 GB | 120.570 GB / 138.739 GB |
| 429056 | `..._n429056_v1` | 1.263430E-05 | PASSED | 5.6091e+06 (350566.78) | 7.96 / 6.6130e+06 (413311.25) | 1.43 / 3 | 0.004 GB / 231.645 GB | 135.254 GB / 138.739 GB |
| 454656 | `..._n454656_v1` | 1.124709E-04 | PASSED | 5.2584e+06 (328652.78) | 9.17 / 6.8314e+06 (426960.69) | 2.75 / 3 | 15.024 GB / 231.580 GB | 135.762 GB / 138.739 GB |
| 480256 | `..._n480256_v1` | 1.900141E-04 | PASSED | 5.2514e+06 (328213.72) | 10.29 / 7.1777e+06 (448603.64) | 3.78 / 3 | 34.205 GB / 231.482 GB | 135.763 GB / 138.739 GB |
| 504832 | `..._n504832_v1` | 1.934756E-04 | PASSED | 4.9704e+06 (310649.10) | 12.25 / 7.0018e+06 (437613.62) | 5.01 / 3 | 51.561 GB / 231.457 GB | 135.763 GB / 138.739 GB |

Attempt IDs are the full `2x8-GAAS-phase1a-n-refine_n<N>_v1` stems.
Per-candidate `.status` start/end (+08:00): n404480 14:18:57→14:19:55,
n429056 14:19:55→14:20:58, n454656 14:20:58→14:22:16, n480256
14:22:16→14:23:55, n504832 14:23:55→14:25:55.

Facts not representable in the current `results/metrics.csv` schema,
recorded here for Codex review (schema/extractor unchanged):

- `--fill-device 1` was active for all five candidates (settings block of
  every `.out`); the binary additionally echoed
  `--fill-device-buffer-size = 3048`, `--u-panel-chunk-nbs = 8`,
  `--call-dgemv-with-multiple-threads = 0`, and
  `--tolerance = 1.000000e-12` (package defaults, not tuned).
- Iterative refinement emitted 3 solver iterations (iterations 0, 1, 2) for
  every candidate; IR seconds (AVG) are in the table above. L-infinite
  residuals per iteration are in each `.out`.
- The two `Per process memory available MIN system/device` lines per
  candidate: n404480 231.526/17.450 then 231.522/17.450 GB; n429056
  231.418/2.767 then 231.417/2.767 GB; n454656 231.335/2.257 then
  216.249/2.257 GB; n480256 231.247/2.257 then 198.679/2.257 GB; n504832
  231.206/2.257 then 181.400/2.257 GB.
- LU GFLOP/s (excluding IR) and per-GPU values are in the table above.
- The `metrics.csv` `submission_time`/`completion_time` for these rows are
  the PBS `qstat -x -f` `qtime`/`mtime` (14:18:55 / 14:25:58 +08:00).
- Integrity: all 17 evidence files (five `.out`/`.err`/`.status` triplets
  plus PBS `.o`/`.e`) were retrieved from the remote execution worktree
  `.codex-worktrees/TASK-002-9d3ab3c-phase1a-v1` (commit
  `9d3ab3c9e11d46ad28bce99f1ddfc77c9fc2c382`) and verified byte-identical by
  SHA-256 against the remote copies. The remote worktree and its generated
  `hostfile` were left intact.
- The three repeated coarse anchors (404480, 454656, 504832) ran under the
  identical protocol and controls as TASK-001; reproducibility comparison is
  reserved for the authorized analysis step.

Extracted rows for all five attempts are in `results/metrics.csv` /
`results/RESULTS.md` (experiment id `2x8-GAAS-phase1a-n-refine`).

## Evidence paths

- `outputs/` — per-candidate `.out`/`.err`/`.status` and PBS `.o`/`.e`
- `scripts/run_phase1a_n_refine.pbs` — the sweep script (header comment
  documents purpose, working directory, inputs, outputs, and assumptions)
