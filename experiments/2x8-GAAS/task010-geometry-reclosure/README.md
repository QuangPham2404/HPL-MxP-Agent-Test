# 2x8-GAAS task010-geometry-reclosure

TASK-010 Step A coarse N re-sweep for the 2 GAAS nodes x 8 H200 GPUs
HPL-MxP campaign: the five approved N candidates run sequentially inside
one 2x8 allocation, varying only N, under the verified TASK-009
host-runtime contract. TASK-009's verified host-runtime regime shift
materially reduced IR at the retained N while leaving LU essentially
unchanged, reopening the N dependency via E39 (tasks/TASK-010.md Sections
1.1, 1.2); Step A re-checks whether the useful N region moves under the
retained contract. TASK-010 is a bounded conditional task: Steps B/C/D run
only when the Step-A evidence triggers them through the mechanical
Section 1.5D branch rule, and they are not part of this experiment
directory's submission.

**Status: Executed (2026-10-01) — Step A ran in PBS job `76094.gaas`
(completed, exit 0, all five candidates PASSED); TASK-010 terminated after
Step A via the mechanical Section 1.5D STOP branch (see Run summary).**

## Structure

- `scripts/run_task010_stepa_n_coarse.pbs` — single reusable Step-A sweep
  PBS script (five candidates sequentially in one allocation; per-candidate
  evidence files; attempt tag comes from the `ATTEMPT_TAG` environment at
  submission)
- `outputs/` — per-candidate application `.out`/`.err`/`.status` evidence,
  the allocation-level rank-map / env-map / carry-forward logs, and PBS
  `.o`/`.e` job evidence (tracked, never overwritten; every rerun gets a
  new attempt tag)

## Approved candidate set (TASK-010 Section 1.5B)

| N | approx. % of pivot 505160 | per-GPU FP64 device matrix (GB) |
|---|---|---|
| 429056 | ~85% | 92.0 |
| 454656 | ~90% | 103.4 |
| 504832 | ~100% | 127.4 |
| 556032 | ~110% | 154.6 |
| 606208 | ~120% | 183.7 |

These five values are the complete Step-A scientific sweep for TASK-010;
no finer N sweep, no lower N values, and nothing above 606208 during Step
A (TASK-010 Section 1.5B). N=429056 is the retained Phase-2A/TASK-009
operating point (the control); the other four span the historical
residency transition through the previously valid higher-LU region. The
candidate set deliberately does not require every N to be divisible by
`NB=3072`.

## Fixed scientific controls (only N varies)

```
OMP_NUM_THREADS=4
--nb 3072
--nprow 4
--npcol 4
--nporder row
--gpu-affinity 0:1:2:3:4:5:6:7
--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted
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

Retained host-runtime contract (TASK-010 Section 1.3, quoted as in the
task):

```
OMP_NUM_THREADS = 4
--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted
OMP_PLACES omitted
OMP_PROC_BIND omitted
effective launcher defaults = sockets / TRUE
```

`OMP_NUM_THREADS=4` is explicitly exported in the job shell after module
setup, forwarded to all MPI ranks via `mpirun -x OMP_NUM_THREADS`, and
verified = 4 on all 16 ranks by a per-arm environment probe run
immediately before every scored launch (the arm is aborted before its
scored launch on any mismatch). `OMP_PLACES`/`OMP_PROC_BIND` are unset in
the job shell after recording the incoming values; the allocation-level
rank-map probe verifies they are UNSET on all 16 ranks (abort before any
scored arm otherwise), and the per-arm env probe verifies
`omp_places=UNSET omp_proc_bind=UNSET` on all 16 ranks with the arm's
exact `-x` set (`PATH`, `LD_LIBRARY_PATH`, `OMP_NUM_THREADS`). The
effective placement policy is the installed launcher's package defaults
`OMP_PLACES=sockets` / `OMP_PROC_BIND=TRUE` (documented from the captured
v26.02 launcher;
`experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`).

Configuration supplied by the Strategic Analyst and approved by the Human
Leader in tasks/TASK-010.md Sections 1.3 and 1.5; Codex/workers did not
derive, optimize, or modify it. All controls not listed above (e.g.
`--fill-device-buffer-size`, `--Anq-device`, U-panel chunking, DGEMV
partitioning, communication policy, precision, GEMM kernel) keep the
installed package/default behavior consistently for all five candidates.
CPU affinity is not reopened by TASK-010 (Sections 1.3, 1.9).

## Per-candidate command

Identical for every candidate except `--n <N>`, launched inside the PBS job
through the validated Approach-1 container launcher with the retained
TASK-009 host-runtime `-x` forwarding:

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
    -x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS \
    --bind-to none \
    /workspace/hpl-mxp.sh \
      --n <N> --nb 3072 --nprow 4 --npcol 4 --nporder row \
      --gpu-affinity 0:1:2:3:4:5:6:7 --sloppy-type FP16 \
      --use-mpi-panel-broadcast 0 --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

with `<N>` one of the five approved values, `OMP_NUM_THREADS=4` exported
in the job shell (and verified on all 16 ranks by the per-arm env probe)
before the launch, and application stdout/stderr redirected to that
candidate's `.out`/`.err` evidence file.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ngpus=8` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `01:30:00` for the five-run sequential sweep plus five per-arm env probes (phase1a's six-candidate sweep used 00:11:45 of 01:30:00); may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by all candidates in the allocation |
| Process grid | fixed 4x4, `nporder=row` (not auto-derived) |
| GPU affinity | `0:1:2:3:4:5:6:7` (node-local rank -> local GPU) |
| OMP host-runtime contract (Step A) | `OMP_NUM_THREADS=4` explicit job-shell export after module setup + `mpirun -x OMP_NUM_THREADS`, verified = 4 on all 16 ranks by the per-arm env probe; `OMP_PLACES`/`OMP_PROC_BIND` omitted (unset in the job shell, verified UNSET on all 16 ranks); effective launcher package defaults `sockets` / `TRUE`; `--cpu-affinity`/`--mem-affinity`/`--ucx-affinity` omitted |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mirrors
`experiments/2x8-GAAS/phase3ab-host-runtime/scripts/run_phase3ab_host_runtime.pbs`
(TASK-009, validated v2) for container/MPI/orted/pbsdsh launcher,
hostfile, resource request, accounting project, bind mounts, daemon flags,
module set, topology gates, probes, and pre/post health-snapshot pattern,
with the TASK-009 Step-A/B/C thread/carry-forward machinery and CPU-mask
builders removed (TASK-010 Step A varies only N).

## Sequential-sweep behavior

- The candidates run one at a time inside the single 2x8 allocation (same
  nodes for all candidates; same-step same-allocation comparability,
  TASK-010 Section 1.10).
- A per-arm environment probe runs immediately before every scored launch
  and verifies `OMP_NUM_THREADS=4` with `OMP_PLACES`/`OMP_PROC_BIND` unset
  on all 16 ranks; a mismatch aborts before that arm's scored launch
  (control-application failure; TASK-010 Section 1.14).
- A candidate with a nonzero exit or an invalid verification is recorded
  and the sweep continues with the next candidate (isolated arm failure is
  boundary evidence; TASK-010 Section 1.4 rule 7); the job exits nonzero
  overall if any candidate failed.
- Evidence guard: before any candidate starts, the script aborts if any
  target `.out`/`.err`/`.status` file (or rank-map/env-map/carry-forward
  log) of this attempt already exists — reruns must use a new
  `ATTEMPT_TAG`; existing evidence is never overwritten.
- If the job is killed mid-candidate (e.g. walltime), that candidate keeps
  its `.out`/`.err` but has no `.status` file, and later candidates were
  not run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query)
  are taken once around the whole sweep; per-candidate host/device memory
  evidence comes from the application's own memory-report lines in each
  `.out` file.
- After all five candidates the script applies the mechanical Section 1.5D
  branch rule and records the outcome in the carry-forward log; the branch
  outcome does not affect the job exit status.
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-candidate attempt ID:
`2x8-GAAS-task010-geometry-reclosure_stepa-n<N>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-task010-geometry-reclosure_stepa-n429056_v1`).

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| candidate status | `outputs/<attempt>.status` (attempt, experiment, task step, arm label, PBS job ID, queue, nodes, N, NB/grid/order, verified OMP environment, fixed-controls line, start/end timestamps, exit status, score/LU/IR/memory evidence, verification verdict, evidence paths) |
| allocation rank-map log | `outputs/2x8-GAAS-task010-geometry-reclosure_rankmap_<tag>.log` (16 rank lines with the incoming OMP environment + per-host local-rank-0 topology reports for both allocated nodes) |
| per-arm env-map log | `outputs/2x8-GAAS-task010-geometry-reclosure_envmap_<tag>.log` (per-arm 16-rank effective-OMP verification lines) |
| carry-forward log | `outputs/2x8-GAAS-task010-geometry-reclosure_carryforward_<tag>.log` (Step-A scores, LU/IR facts, and the mechanical Section 1.5D branch outcome) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-task010-geometry-reclosure_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-task010-geometry-reclosure_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names.

## Submission (from this directory; requires TASK-010 execution authorization)

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-task010-geometry-reclosure_v1.o \
     -e outputs/2x8-GAAS-task010-geometry-reclosure_v1.e \
     scripts/run_task010_stepa_n_coarse.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (only
eligible idle `gpu_as`/`gpu_ded` nodes; same validated pattern as the
Phase-0 probe and the phase1a/phase3ab submissions):

```bash
qsub -q <gpu_as|gpu_ded> \
     -l select=host=hpc-gaas-<n1>:ngpus=8:ncpus=96:mem=2000GB+host=hpc-gaas-<n2>:ngpus=8:ncpus=96:mem=2000GB,place=scatter,walltime=01:30:00 \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-task010-geometry-reclosure_v1.o \
     -e outputs/2x8-GAAS-task010-geometry-reclosure_v1.e \
     scripts/run_task010_stepa_n_coarse.pbs
```

## Mechanical feasibility context (arithmetic only)

Per-GPU FP64 device-matrix footprint under `--fill-device 1` is
`N^2 * 8 / 16` bytes (HPL-MxP fills the FP64 matrix onto the device;
`--fill-device` overrides `--Anq-device`); the per-GPU column in the
candidate table above shows that arithmetic (`N^2 * 8 / 16 / 1e9` GB, e.g.
429056^2 * 8 / 16 = 92,044,525,568 bytes ≈ 92.0 GB). Phase-1A precedent:
all four larger candidates (454656, 504832, 556032, 606208) previously
PASSED under `--fill-device 1` at the OLD host runtime
(`experiments/2x8-GAAS/phase1a-n-coarse/`, PBS job 72624.gaas); whether
they remain valid under the retained TASK-009 host runtime is exactly the
Step-A evidence this sweep is designed to produce, and per TASK-010
Section 1.4 rule 7 any invalid/OOM candidate is preserved as boundary
evidence while the sweep continues. Host-side, the per-node FP64 matrix
(`N^2 * 8 / 2`) is 1470 GB at the largest candidate N=606208, below the
2000 GB per-node cgroup (1960 GB was in use at the PASSED N=700000
baseline). These are mechanical derived values, not predictions or
recommendations.

## Available baseline provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s |
| Baseline evidence | `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.{o,e}`; `experiments/2x8-GAAS/baseline/README.md` |
| TASK-009 host-runtime contract run | `2x8-GAAS-phase3ab-host-runtime` v2 (TASK-009), PBS job 73174.gaas, queue gpu_as, hpc-gaas-g13 + hpc-gaas-g15, 21 scored arms all PASSED, establishing the retained host-runtime contract this sweep runs under |
| TASK-009 evidence | `experiments/2x8-GAAS/phase3ab-host-runtime/outputs/` (`2x8-GAAS-phase3ab-host-runtime_*_v2.*`, including rankmap/envmap/carryforward logs); `experiments/2x8-GAAS/phase3ab-host-runtime/README.md` |
| Flag support | installed v26.02 binary records `--fill-device INT:{0,1} [0]` (overrides `--Anq-device`) and the launcher OpenMP package defaults (`OMP_PROC_BIND=TRUE`, `OMP_PLACES=sockets`): `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |
| Phase-0 topology evidence | `experiments/2x8-GAAS/baseline/scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated |

The original baseline run used the same scored-run protocol as this sweep
(`--skip-tests 0 --monitor-gpu 0`) and is the campaign percentage
denominator for 2x8-GAAS comparisons. TASK-010 does not rerun it.

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
(TASK-010 Sections 1.4 rule 7, 1.5C). Do not classify success from exit
status alone.

## Step-A branch rule (mechanical; TASK-010 Section 1.5D)

After all five candidates the script records each candidate's
score/validity/exit/LU seconds/IR seconds/IR-LU ratio and the highest
valid score (leader) in the carry-forward log, then applies the
pre-authorized mechanical rule:

- if NO candidate is valid at all: systemic no-valid-candidate stop
  (TASK-010 Section 1.14), job exit 1, Steps B/C/D not run;
- if the control N=429056 is invalid and at least one larger N is valid:
  `outcome=PROCEED_TO_STEP_B`
  (`reason=control_N_429056_invalid_outside_leading_region`; the anomaly
  is logged factually);
- if the control is valid and NO larger N is valid:
  `outcome=STOP_AFTER_STEP_A_RETAIN_N429056`
  (`reason=all_larger_candidates_invalid_boundary_evidence`; retain
  N=429056, NB=3072, 4x4 row mechanically, TASK-010 Section 1.5D last
  paragraph);
- otherwise (control valid, at least one larger N valid): material move =
  any valid larger N with score strictly >2.0% above the control score;
  within leading = control score >= leader score * 0.98. Material move or
  not within leading -> `outcome=PROCEED_TO_STEP_B`
  (`reason=valid_larger_N_over_2pct_above_control` or
  `reason=control_outside_2pct_leading_region`); otherwise
  `outcome=STOP_AFTER_STEP_A_RETAIN_N429056`
  (`reason=control_within_2pct_leading_region_no_material_move`; retain
  N=429056, NB=3072, 4x4 row mechanically).

The qualitative regime-shift clause (Section 1.5D third proceed clause) is
deliberately NOT evaluated by the script; the orchestrator reviews the
recorded LU/IR facts after the run. Steps B/C/D are NOT executed by the
script: a `PROCEED_TO_STEP_B` outcome means the orchestrator constructs
the bounded Section 1.6B fine-N refinement in a separate allocation. The
job exit status is unaffected by the branch outcome (STOP and PROCEED are
both normal outcomes). Anti-loop rules (TASK-010 Section 1.12) are
respected: Step A runs once, no candidate is repeated, and no new
candidates are added.

## Run summary

One submitted attempt family (tag `v1`, PBS job `76094.gaas`, submitted
2026-10-01, queue `gpu_as`, project `hpc_ebslee`, host-pinned
`select=host=hpc-gaas-g12:ngpus=8:ncpus=96:mem=2000GB+host=hpc-gaas-g14:ngpus=8:ncpus=96:mem=2000GB,place=scatter,walltime=01:30:00`;
PBS `stime` 2026-10-01 11:13:39, completion 2026-10-01 11:26:27 (derived from
`stime` + `resources_used.walltime` 00:12:48), `job_state=F`,
`Exit_status=0`). All five candidates ran sequentially on the same node pair
with identical fixed controls; each `.status` records `exit_status=0`.
Factual per-candidate data as emitted by the application output (no
interpretation):

| N | attempt | normalized residual | verdict | overall GFLOP/s (per GPU) | LU s / LU GFLOP/s | IR s / iterations | host mem cons. MAX / avail. MIN | device mem cons. MAX / avail. MIN |
|---|---|---|---|---|---|---|---|---|
| 429056 | `..._stepa-n429056_v1` | 1.416310E-05 | PASSED | 6.4431e+06 (402691.12) | 7.85 / 6.6784e+06 | 0.29 / 3 | 0.004 GB / 239.659 GB | 135.254 GB / 138.739 GB |
| 454656 | `..._stepa-n454656_v1` | 1.204088E-04 | PASSED | 5.9212e+06 (370077.78) | 8.98 / 6.9761e+06 | 1.60 / 3 | 15.024 GB / 239.594 GB | 135.762 GB / 138.739 GB |
| 504832 | `..._stepa-n504832_v1` | 2.067393E-04 | PASSED | 5.2147e+06 (325915.77) | 11.96 / 7.1739e+06 | 4.49 / 3 | 51.561 GB / 239.430 GB | 135.763 GB / 138.739 GB |
| 556032 | `..._stepa-n556032_v1` | 2.453680E-04 | PASSED | 5.0581e+06 (316129.83) | 15.06 / 7.6101e+06 | 7.60 / 3 | 95.340 GB / 239.367 GB | 135.763 GB / 138.739 GB |
| 606208 | `..._stepa-n606208_v1` | 2.520783E-04 | PASSED | 4.3901e+06 (274382.91) | 19.16 / 7.7508e+06 | 14.67 / 3 | 136.519 GB / 239.359 GB | 135.763 GB / 138.739 GB |

Attempt IDs are the full
`2x8-GAAS-task010-geometry-reclosure_stepa-n<N>_v1` stems. Per-candidate
`.status` start/end (+08:00; runtime = end − start): n429056
11:14:29→11:15:26 (00:00:57), n454656 11:15:49→11:17:03 (00:01:14), n504832
11:17:25→11:19:20 (00:01:55), n556032 11:19:41→11:22:24 (00:02:43), n606208
11:22:47→11:26:25 (00:03:38).

Post-matrix-generation per-process available MIN (from each `.status`
`matgen_headroom` line), system/device: 239.423/2.767 GB (n429056),
224.264/2.257 GB (n454656), 189.366/2.257 GB (n504832), 149.690/2.257 GB
(n556032), 107.795/2.257 GB (n606208).

Facts not representable in the current `results/metrics.csv` schema,
recorded here for Codex review (schema/extractor unchanged):

- OMP contract verified per arm: five per-arm env probes each confirmed
  `OMP_NUM_THREADS=4` with `OMP_PLACES`/`OMP_PROC_BIND` unset on all 16
  ranks (5 × 16 = 80 verification lines in the env-map log; allocation-level
  rank-map gate PASS on both hosts). The incoming PBS-supplied
  `OMP_NUM_THREADS=96` was recorded in the rank-map log and neutralized per
  arm by the explicit job-shell export + `mpirun -x OMP_NUM_THREADS`
  forwarding; the effective placement policy is the launcher package
  defaults `OMP_PLACES=sockets` / `OMP_PROC_BIND=TRUE`.
- The settings block of every `.out` echoed `--u-panel-chunk-nbs = 8`,
  `--call-dgemv-with-multiple-threads = 0`, and
  `--fill-device-buffer-size = 3048` (package defaults, not tuned).
- Iterative refinement emitted 3 solver iterations for every candidate; IR
  seconds (AVG) are in the table above; L-infinite residuals per iteration
  are in each `.out`. LU GFLOP/s (excluding IR) and per-GPU values are in
  the table above.
- Known non-fatal stderr notes preserved in the evidence: the PBS `.e`
  contains 11 `unknown groupid 1304617061` warnings plus the `cuda/13.1`
  compile-hint/module note; each per-arm `.err` contains one
  `unknown groupid` warning. None affected probes or scored runs.
- Integrity: all 20 evidence files retrieved from the remote execution
  worktree `.codex-worktrees/TASK-010-d5a789b-stepa-v1` (commit
  `d5a789b609a8b0f7742c6e8dc347b3e59b46d900`) and verified byte-identical
  by MD5 against the remote copies (20/20). Three additional local logs
  (presubmit `pbsnodes` snapshot, submission, `qstat` monitoring) were
  produced on the submission side and are preserved alongside.

### Step-A branch outcome

The script applied the mechanical TASK-010 Section 1.5D rule after the five
scored arms (material move = a valid larger-N score strictly
> control × 1.02; within leading = control score ≥ leader × 0.98) and
recorded in the carry-forward log:

- `outcome=STOP_AFTER_STEP_A_RETAIN_N429056`,
  `reason=control_within_2pct_leading_region_no_material_move`: the control
  N=429056 was valid and was itself the highest valid end-to-end score
  (6.4431e+06 GFLOP/s); no valid larger N exceeded it by >2.0% — every
  larger N scored below the control (454656 by 8.1%, 504832 by 19.1%,
  556032 by 21.5%, 606208 by 31.9%).
- Mechanical retention (Section 1.5D): `N=429056`, `NB=3072`,
  `grid/order=4x4 row`. This is a mechanical carry-forward, not a strategic
  decision.
- Orchestrator review of the qualitative regime-shift clause (Section 1.5D
  third proceed clause): NOT triggered. The recorded LU/IR facts show IR
  time and the IR/LU ratio rising monotonically with N (0.29→14.67 s;
  0.037→0.766) while the end-to-end score falls monotonically; no larger-N
  regime is materially faster, and nothing is borderline.
- Steps B/C/D were correctly skipped under the TASK-010 Section 1.15 early
  completion path; all Step-A evidence is preserved and ownership returns
  to the Strategic Analyst.

Extracted rows for all five attempts are in `results/metrics.csv` /
`results/RESULTS.md` (experiment id `2x8-GAAS-task010-geometry-reclosure`).

## Evidence paths

- `outputs/` — per-candidate `.out`/`.err`/`.status`, the allocation-level
  rank-map log, the per-arm env-map log, the carry-forward decision log,
  and PBS `.o`/`.e` (including the environment provenance records:
  `module list`, Apptainer version, container MPI `mpirun --version`, and
  the execution-worktree Git revision)
- `scripts/run_task010_stepa_n_coarse.pbs` — the Step-A sweep script
  (header documents purpose, working directory, inputs, outputs, and
  assumptions)
