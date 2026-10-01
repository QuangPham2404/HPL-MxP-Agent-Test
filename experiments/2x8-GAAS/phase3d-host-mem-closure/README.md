# 2x8-GAAS phase3d-host-mem-closure

TASK-2X8-012 Phase 3D closure for the 2 GAAS nodes x 8 H200 GPUs HPL-MxP
campaign: two independent, fixed, bracketed sweeps run sequentially inside
one 2x8 allocation at the fixed retained TASK-2X8-011 geometry/runtime
stack, with only the Phase-3D host/memory controls varying, one at a time
per stage (tasks/TASK-2X8-012.md Sections 1.6A-1.6C). There is no
interaction matrix, no adaptive refinement, and no downstream Phase-4 work;
the final Phase-3D conclusion is reserved for the Strategic Analyst via
`ANALYSE_RESULTS`.

**Status: Executed (2026-10-01) — Stage A + Stage B ran in PBS job
`76370.gaas` (completed, exit 0, all 15 arms PASSED with PASS settings
echo); TASK-2X8-012 stopped after Stage B as approved (no Phase 4). See
Run summary.**

**Prior status (2026-10-01, pre-submission): reviewed local scripts;
presubmit `pbsnodes -aSj` snapshot taken and the same-queue `gpu_as` pair
g14+g15 selected (see Submission). Submission was authorized under the
unchanged Section 1.12 authorization of TASK-2X8-012; submission remained
limited to the exact approved task scope.**

## Structure

- `scripts/run_phase3d_host_mem_closure.pbs` — single same-allocation
  Phase-3D run script: Stage A (R0a, R1-R4, R0b) then Stage B (D0a,
  D1-D7, D0b) always, in the exact approved order; per-arm evidence files;
  attempt tag comes from the `ATTEMPT_TAG` environment at submission
- `outputs/` — per-arm application `.out`/`.err`/`.status` evidence,
  per-arm `.envprobe` raw env-probe evidence, the attempt-specific
  deduplicated hostfile, the allocation-level rank-map / env-map /
  carry-forward logs, the presubmit contention snapshot, and PBS `.o`/`.e`
  job evidence (tracked, never overwritten; every rerun gets a new attempt
  tag; all runtime artifacts live beneath `outputs/` — nothing is written
  to the experiment root)

## Approved arm set (TASK-2X8-012 Sections 1.6B, 1.6C)

Stage A — `--cuda-host-register-step` sweep, exactly this order, once each,
with `--call-dgemv-with-multiple-threads` fixed at 0:

| arm | `--cuda-host-register-step` |
|---|---:|
| R0a | **2048** — opening default control |
| R1 | 512 |
| R2 | 1024 |
| R3 | 4096 |
| R4 | 8192 |
| R0b | **2048** — closing default control |

The range deliberately spans 4x below to 4x above the default 2048 with
mechanism-distinct granularity; no 1536/2560/3072/3584 or other
intermediate values, no added candidates, no adaptive refinement, no
repeats beyond the R0a/R0b bracket (Sections 1.6B rules 1-5, 1.7).

Stage-A completion rule (Section 1.6B rule 7):
`--cuda-host-register-step` is restored to 2048 before Stage B regardless
of the numerical Stage-A result — encoded by construction, since every
Stage-B arm passes `--cuda-host-register-step 2048` explicitly.

Stage B — `--call-dgemv-with-multiple-threads` sweep, exactly this order,
once each, with `--cuda-host-register-step` fixed at 2048:

| arm | `--call-dgemv-with-multiple-threads` |
|---|---:|
| D0a | **0** — opening default control |
| D1 | 128 |
| D2 | 512 |
| D3 | 2048 |
| D4 | 4096 |
| D5 | 8192 |
| D6 | 15360 |
| D7 | 30720 |
| D0b | **0** — closing default control |

The set covers the default, the historical low-range 128/512 region,
previously untested medium/coarse values 2048/4096/8192 under the current
stack, the historical bundled 15360 value, and a deliberately large 30720
endpoint; no intermediate or larger values, no refinement around a
numerical leader, no register-step x DGEMV Cartesian product (Sections
1.6C rules 1-4, 1.7). At Stage-B completion the task stops: no Phase 4.

## Fixed scientific controls (only the Phase-3D controls vary)

```
OMP_NUM_THREADS=4
--n 429056
--nb 3072
--nprow 4
--npcol 4
--nporder row
--gpu-affinity 0:1:2:3:4:5:6:7
--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted
--fill-device 1
--fill-device-buffer-size 3048
--sloppy-type FP16
--use-mpi-panel-broadcast 0
--use-separate-stream-for-gemm 1
--prioritize-trsm 0
--prioritize-factorization 0
--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Default-equal controls applied via the installed package defaults — exactly
the validated TASK-010/TASK-2X8-011 launch form — with the echoed effective
value verified per arm against the task's fixed values:

```
--u-panel-chunk-nbs                    = 8    (installed default [8])
--preset-gemm-kernel                   = 90   (EFFECTIVE value on H200)
```

`--preset-gemm-kernel` note: the installed v26.02 CLI accepts only
`{0,80}` (`--preset-gemm-kernel INT:{0,80} [0]`; flag-check evidence
`experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`).
The effective SM90 preset `90` comes from the default when the flag is
omitted. The flag is omitted in every arm and the echoed effective value
is verified `= 90` per arm.

The two swept Phase-3D controls are passed **explicitly** on every arm
(installed flag contract `--cuda-host-register-step INT:POSITIVE [2048]`,
`--call-dgemv-with-multiple-threads INT:NONNEGATIVE [0]`; flag-check
evidence in the same v26.02 flag-check log; both values have prior CLI
acceptance evidence: register-step 2048 in SingleNode-resweep v1.1, dgemv
0..15360 in dgemv-with-multiple-threads / SingleNode-resweep).

Retained host-runtime contract (TASK-2X8-012 Section 1.6A, quoted as in the
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
verified = 4 on all 16 ranks by a per-arm environment probe run immediately
before every scored launch (the arm is aborted before its scored launch on
any mismatch). `OMP_PLACES`/`OMP_PROC_BIND` are unset in the job shell after
recording the incoming values; the allocation-level rank-map probe verifies
they are UNSET on all 16 ranks (abort before any scored arm otherwise), and
the per-arm env probe verifies `omp_places=UNSET omp_proc_bind=UNSET` on all
16 ranks with the arm's exact `-x` set (`PATH`, `LD_LIBRARY_PATH`,
`OMP_NUM_THREADS`). The effective placement policy is the installed
launcher's package defaults `OMP_PLACES=sockets` / `OMP_PROC_BIND=TRUE`.

Every arm's `.status` file records the application's echoed settings for all
fixed controls plus both Phase-3D controls with a PASS/FAIL
`settings_echo_check` (Section 1.8 rule 4 requires the effective echo of
both Phase-3D controls on every arm). A settings-echo mismatch is
control-application failure evidence: the arm is preserved but marked not a
valid performance point, and the mismatch is flagged in the carry-forward
log.

Configuration supplied by the Strategic Analyst and approved by the Human
Leader in tasks/TASK-2X8-012.md Sections 1.6A-1.6C; Codex/workers did not
derive, optimize, or modify it. All controls not listed above keep the
installed package/default behavior consistently for all arms. N, NB,
grid/order, placement, host runtime, residency mode/buffer, communication,
precision, kernel, and scheduling are NOT reopened by this task
(Section 1.7).

## Per-arm command

Identical for every arm except the two Phase-3D flags, launched inside the
PBS job through the validated Approach-1 container launcher with the
retained TASK-009 host-runtime `-x` forwarding. Example (Stage-A arm R1;
Stage-B arms differ only in the Phase-3D pair):

```bash
apptainer exec --nv \
  -B /opt/pbs:/opt/pbs \
  -B /var/spool/pbs:/var/spool/pbs \
  -B "$REPO_ROOT":"$REPO_ROOT" \
  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif \
  /usr/local/mpi/bin/mpirun -np 16 \
    --hostfile "$PWD/outputs/2x8-GAAS-phase3d-host-mem-closure_hostfile_<ATTEMPT_TAG>" \
    --mca plm_rsh_agent multi-node-test/rsh_pbsdsh_container.sh \
    --mca plm_rsh_no_tree_spawn 1 \
    --mca plm_rsh_num_concurrent 1 \
    --mca routed direct \
    -x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS \
    --bind-to none \
    /workspace/hpl-mxp.sh \
      --n 429056 --nb 3072 --nprow 4 --npcol 4 --nporder row \
      --gpu-affinity 0:1:2:3:4:5:6:7 --sloppy-type FP16 \
      --use-mpi-panel-broadcast 0 --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --fill-device-buffer-size 3048 \
      --cuda-host-register-step 512 --call-dgemv-with-multiple-threads 0 \
      --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

`OMP_NUM_THREADS=4` is exported in the job shell (and verified on all 16
ranks by the per-arm env probe) before the launch, and application
stdout/stderr are redirected to that arm's `.out`/`.err` evidence file.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ncpus=96:ngpus=8:mem=2000GB` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `02:00:00` for the 15 scored full-fill arms + per-arm env probes (TASK-2X8-011's ten-arm sweep used 00:18:04 of 02:00:00; every arm here is a ~1 min full-fill arm); may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by all arms in the allocation; written beneath `outputs/` with an attempt-specific name (`2x8-GAAS-phase3d-host-mem-closure_hostfile_<tag>`) so no runtime artifact is left in the experiment root |
| Process grid | fixed 4x4, `nporder=row` (not auto-derived) |
| GPU affinity | `0:1:2:3:4:5:6:7` (node-local rank -> local GPU) |
| OMP host-runtime contract | `OMP_NUM_THREADS=4` explicit job-shell export after module setup + `mpirun -x OMP_NUM_THREADS`, verified = 4 on all 16 ranks by the per-arm env probe; `OMP_PLACES`/`OMP_PROC_BIND` omitted (unset in the job shell, verified UNSET on all 16 ranks); effective launcher package defaults `sockets` / `TRUE`; `--cpu-affinity`/`--mem-affinity`/`--ucx-affinity` omitted |
| Flag support evidence | installed v26.02 binary records `--cuda-host-register-step INT:POSITIVE [2048]`, `--call-dgemv-with-multiple-threads INT:NONNEGATIVE [0]`, `--fill-device INT:{0,1} [0]` (overrides `--Anq-device`), `--fill-device-buffer-size INT:NONNEGATIVE [3048]`: `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mirrors
`experiments/2x8-GAAS/phase3c-residency-closure/scripts/run_phase3c_residency_closure.pbs`
(PBS job 76167.gaas, validated) for container/MPI/orted/pbsdsh launcher,
hostfile, resource request, accounting project, bind mounts, daemon flags,
module set, topology gates, probes, and pre/post health-snapshot pattern,
with the TASK-2X8-011 residency arm set and branch rules replaced by the
TASK-2X8-012 Sections 1.6B/1.6C fixed 15-arm Phase-3D sweep (no conditional
branches: all 15 arms run unconditionally in the approved order).

## Sequential-sweep behavior and encoded stopping rules

- The arms run one at a time inside the single 2x8 allocation (same nodes
  for all arms; same-allocation comparability, TASK-2X8-012 Section 1.8
  rules 1-2: the entire authorized path — Stage A plus Stage B — runs in
  one clean allocation).
- A per-arm environment probe runs immediately before every scored launch
  and verifies `OMP_NUM_THREADS=4` with `OMP_PLACES`/`OMP_PROC_BIND` unset
  on all 16 ranks; a mismatch aborts before that arm's scored launch
  (control-application failure; TASK-2X8-012 Section 1.10).
- A scored arm command that exits nonzero is preserved evidence that STOPS
  the sweep: its `.status` file is fully written first (together with its
  `.out`/`.err`), the carry-forward log records the abort, the job returns
  nonzero immediately, and no later arm of the authorized path is launched
  (the post-sweep hardware-health snapshot is skipped on this abort path).
  There is no in-script retry; a rerun needs a new `ATTEMPT_TAG` plus
  human direction (error classification per the workflow from the
  preserved evidence).
- An arm that exits 0 with an invalid verification, an OOM/non-finite
  residual, or a failed settings-echo check is a scientific-correctness
  failure: preserved invalid/boundary evidence (Sections 1.4, 1.8 rules
  6-7); the sweep continues with the next arm of the already-authorized
  path and the job exits nonzero overall if any arm was invalid.
  Invalid/OOM/correctness-failing points are never promoted or repeated
  for performance.
- Evidence guard: before anything runs, the script aborts if any target
  `.out`/`.err`/`.status`/`.envprobe` file (every arm label of the
  authorized path), rank-map/env-map/carry-forward log, or the
  attempt-specific hostfile of this attempt already exists — reruns must
  use a new `ATTEMPT_TAG`; existing evidence is never overwritten.
  Anti-loop: every arm runs at most once per attempt; no additional
  register-step/DGEMV values, no intermediate points, no refinement pass,
  no interaction matrix, no repeats beyond the R0a/R0b and D0a/D0b
  brackets (Sections 1.7, 1.10).
- If the job is killed mid-arm (e.g. walltime), that arm keeps its
  `.out`/`.err` but has no `.status` file, and later arms were not run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query) are
  taken once around the whole sweep; per-arm host/device memory evidence
  comes from the application's own memory-report lines in each `.out` file;
  per-arm setup/registration evidence comes from the ordinary
  `Constructor seconds:` line plus the per-arm start/end wall-clock
  timestamps (recorded in each `.status`).
- The carry-forward log records factual per-arm facts plus the mechanical
  R0a/R0b and D0a/D0b symmetric bracket spreads (drift references only).
  The script declares no winner, computes no baseline-relative percentages,
  and performs no ranking; the final Phase-3D conclusion is reserved for
  the Strategic Analyst via `ANALYSE_RESULTS` (Sections 1.4, 1.11).
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Run summary

One submitted attempt family (tag `v1`, PBS job `76370.gaas`, submitted
2026-10-01T18:10:06+08:00, queue `gpu_as`, project `hpc_ebslee`, host-pinned
`select=host=hpc-gaas-g14:ncpus=96:ngpus=8:mem=2000GB+host=hpc-gaas-g15:ncpus=96:ngpus=8:mem=2000GB,place=scatter,walltime=02:00:00`;
started 18:10:06, finished 18:30:47, `job_state=F`, `Exit_status=0`,
`resources_used.walltime` 00:20:40, run_count 1). All 15 arms ran
sequentially on the same node pair (g14+g15) with identical fixed controls;
each `.status` records `exit_status=0`, `verification=PASSED`, and
`settings_echo_check=PASS`, with the requested and echoed Phase-3D controls
matching on every arm. Factual per-arm data as emitted by the application
output (no interpretation):

Stage A — `--cuda-host-register-step` (DGEMV fixed 0):

| arm | reg-step | normalized residual | verdict | overall GFLOP/s (per GPU) | LU s / LU GFLOP/s | IR s / IR/LU / iters | host mem cons. MAX | device mem cons. MAX / post-matgen headroom | arm wall-clock |
|---|---:|---|---|---|---|---|---|---|---|
| R0a | 2048 | 1.416310E-05 | PASSED | 6.5311e+06 (408193.03) | 7.78 / 6.7723e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:00:56 |
| R1 | 512 | 1.416310E-05 | PASSED | 6.5578e+06 (409864.36) | 7.74 / 6.8013e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 134.023 GB / 3.997 GB | 00:00:58 |
| R2 | 1024 | 1.416310E-05 | PASSED | 6.5198e+06 (407489.98) | 7.79 / 6.7607e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 134.433 GB / 3.587 GB | 00:00:56 |
| R3 | 4096 | 3.303710E-05 | PASSED | 6.3877e+06 (399230.04) | 7.72 / 6.8163e+06 | 0.52 / 0.067 / 3 | 1.136 GB | 135.762 GB / 2.257 GB | 00:00:57 |
| R4 | 8192 | 6.675518E-05 | PASSED | 6.1579e+06 (384868.94) | 7.76 / 6.7870e+06 | 0.79 / 0.102 / 3 | 4.418 GB | 135.762 GB / 2.257 GB | 00:01:01 |
| R0b | 2048 | 1.416310E-05 | PASSED | 6.5384e+06 (408648.31) | 7.77 / 6.7806e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:00:58 |

Stage B — `--call-dgemv-with-multiple-threads` (register-step fixed 2048):

| arm | DGEMV | normalized residual | verdict | overall GFLOP/s (per GPU) | LU s / LU GFLOP/s | IR s / IR/LU / iters | host mem cons. MAX | device mem cons. MAX / post-matgen headroom | arm wall-clock |
|---|---:|---|---|---|---|---|---|---|---|
| D0a | 0 | 1.416310E-05 | PASSED | 6.5455e+06 (409094.25) | 7.76 / 6.7894e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:00:58 |
| D1 | 128 | 1.416310E-05 | PASSED | 6.5644e+06 (410272.56) | 7.73 / 6.8086e+06 | 0.29 / 0.038 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:00:57 |
| D2 | 512 | 1.416310E-05 | PASSED | 6.5459e+06 (409118.50) | 7.76 / 6.7899e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:01:00 |
| D3 | 2048 | 1.416310E-05 | PASSED | 6.5456e+06 (409101.26) | 7.76 / 6.7883e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:01:00 |
| D4 | 4096 | 1.416310E-05 | PASSED | 6.5634e+06 (410214.76) | 7.74 / 6.8072e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:00:55 |
| D5 | 8192 | 1.416310E-05 | PASSED | 6.5586e+06 (409911.86) | 7.74 / 6.8017e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:00:55 |
| D6 | 15360 | 1.416310E-05 | PASSED | 6.5480e+06 (409251.85) | 7.75 / 6.7913e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:00:56 |
| D7 | 30720 | 1.416310E-05 | PASSED | 6.5564e+06 (409773.15) | 7.74 / 6.7999e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:00:57 |
| D0b | 0 | 1.416310E-05 | PASSED | 6.5579e+06 (409866.04) | 7.74 / 6.8016e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB / 2.767 GB | 00:00:55 |

Attempt IDs are the full
`2x8-GAAS-phase3d-host-mem-closure_<arm>_v1` stems. Per-arm `.status`
start/end (+08:00; runtime = end − start): stagea-r0a 18:10:57→18:11:53
(00:00:56), stagea-r1 18:12:16→18:13:14 (00:00:58), stagea-r2
18:13:38→18:14:34 (00:00:56), stagea-r3 18:14:57→18:15:54 (00:00:57),
stagea-r4 18:16:17→18:17:18 (00:01:01), stagea-r0b 18:17:41→18:18:39
(00:00:58), stageb-d0a 18:19:04→18:20:02 (00:00:58), stageb-d1
18:20:26→18:21:23 (00:00:57), stageb-d2 18:21:46→18:22:46 (00:01:00),
stageb-d3 18:23:09→18:24:09 (00:01:00), stageb-d4 18:24:32→18:25:27
(00:00:55), stageb-d5 18:25:51→18:26:46 (00:00:55), stageb-d6
18:27:09→18:28:05 (00:00:56), stageb-d7 18:28:28→18:29:25 (00:00:57),
stageb-d0b 18:29:48→18:30:43 (00:00:55). The strictly sequential arm
timestamps confirm the exact approved arm order.

Post-matrix-generation per-process available MIN (from each `.status`
`matgen_headroom` line), system/device: 72.772/2.767 GB (R0a),
72.707/3.997 GB (R1), 72.695/3.587 GB (R2), 72.248/2.257 GB (R3),
69.107/2.257 GB (R4), 72.339/2.767 GB (R0b), 72.401/2.767 GB (D0a),
72.432/2.767 GB (D1), 72.518/2.767 GB (D2), 72.480/2.767 GB (D3),
72.463/2.767 GB (D4), 72.488/2.767 GB (D5), 72.564/2.767 GB (D6),
72.596/2.767 GB (D7), 72.662/2.767 GB (D0b).

Constructor (setup/registration) seconds AVG per arm: R0a 0.24, R1 0.24,
R2 0.19, R3 0.16, R4 0.16, R0b 0.21, D0a 0.20, D1 1.11, D2 1.16, D3 0.20,
D4 0.22, D5 0.34, D6 0.22, D7 0.19, D0b 0.22.

Facts not representable in the current `results/metrics.csv` schema,
recorded here for Codex review (schema/extractor unchanged; the CSV carries
the shared fixed controls, the swept DGEMV value, and the per-arm score;
the swept register-step value is identified by the attempt label and
recorded in each `.status`):

- OMP contract verified per arm: fifteen per-arm env probes each confirmed
  `OMP_NUM_THREADS=4` with `OMP_PLACES`/`OMP_PROC_BIND` unset on all 16
  ranks (15 x 16 = 240 verification lines in the env-map log;
  allocation-level rank-map gate PASS on both hosts: 16 rank lines, 2
  hosts, 8 ranks/host, OMP_PLACES/OMP_PROC_BIND unset on all 16). The
  incoming PBS-supplied `OMP_NUM_THREADS=96` was recorded in the rank-map
  log and neutralized per arm by the explicit job-shell export + `mpirun
  -x OMP_NUM_THREADS` forwarding; the effective placement policy is the
  launcher package defaults `OMP_PLACES=sockets` / `OMP_PROC_BIND=TRUE`.
- The settings block of every `.out` echoed `--u-panel-chunk-nbs = 8`,
  `--preset-gemm-kernel = 90` (effective via default; flag omitted),
  `--fill-device = 1`, `--fill-device-buffer-size = 3048`, and the exact
  requested `--cuda-host-register-step` and
  `--call-dgemv-with-multiple-threads` values for that arm
  (`settings_echo_check=PASS` on all 15).
- Iterative refinement emitted 3 solver iterations for every arm; IR
  seconds (AVG) and L-infinite residuals per iteration are in each `.out`.
- Allocation-level observation (factual, this g14+g15 allocation): the
  per-process host memory available MIN reported by the application is
  ~69-73 GB (e.g. 73.006 GB pre-matgen for R0a), lower than the ~238 GB
  reported on the TASK-2X8-011 g12+g14 allocation; host consumption MAX
  is 0.004 GB/process and the device full-fill regime (135.254 GB
  consumption MAX, 2.767 GB post-matgen headroom) is identical to the
  retained TASK-2X8-011 control for the default arms. Stage-A arms R3/R4
  (register-step 4096/8192) factually displaced FP64 data to host memory
  (host consumption MAX 1.136/4.418 GB, IR 0.52/0.79 s, device headroom
  2.257 GB, differing finite residuals 3.303710E-05/6.675518E-05) — all
  still PASSED; the interpretation belongs to the Strategic Analyst.
- Known non-fatal stderr notes preserved in the evidence: the PBS `.e`
  contains module-load notes and 31 `unknown groupid 1304617061` warnings;
  each per-arm `.err` contains the bridge `cmd=[...]` diagnostic and one
  `unknown groupid` warning. Per-arm warning-marker counts are 0
  (out and err) for all 15 arms. None affected probes or scored runs.
- Integrity: all 66 remote output files were retrieved from the remote
  execution worktree `.codex-worktrees/TASK-2X8-012-e766b5f-phase3d-v1`
  (commit `e766b5ff726bc07cfc0b8274d54bb97f3e13b766`) and verified
  byte-identical by SHA-256 against the remote copies (66/66). Two
  local-only operational logs (the presubmit pbsnodes snapshot, taken
  before submission, and `..._v1_submission.log`) are preserved alongside.

### Mechanical bracket facts (factual, no interpretation)

- Stage-A bracket: R0a/R0b = 6.5311e+06 / 6.5384e+06, symmetric spread
  0.11%.
- Stage-B bracket: D0a/D0b = 6.5455e+06 / 6.5579e+06, symmetric spread
  0.19%.
- Every Stage-A arm except R3 (6.3877e+06, -2.20% vs R0a) and R4
  (6.1579e+06, −5.71% vs R0a) lies within 0.41% of the bracket controls
  (R1 +0.41%/+0.30% and R2 −0.17%/−0.28% vs R0a/R0b); LU seconds span
  7.72-7.79 across all 15 arms; Stage-B arms all lie within 0.29% of the
  bracket controls with IR 0.29 s and 3 iterations each.
- These are mechanical carry-forward facts only; the final Phase-3D
  conclusion belongs to the Strategic Analyst via `ANALYSE_RESULTS`.

## Attempt and output naming

Per-arm attempt ID:
`2x8-GAAS-phase3d-host-mem-closure_<label>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase3d-host-mem-closure_stagea-r2_v1`), with `<label>` one
of `stagea-r0a`, `stagea-r1`..`stagea-r4`, `stagea-r0b`, `stageb-d0a`,
`stageb-d1`..`stageb-d7`, `stageb-d0b`.

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| arm status | `outputs/<attempt>.status` (attempt, experiment, task id/step, arm label, requested + echoed Phase-3D controls, all echoed fixed-control settings with PASS/FAIL settings-echo check, PBS job ID, queue, nodes, N, NB/grid/order, verified OMP environment, rank-map reference, fixed-controls line, start/end timestamps + arm wall-clock seconds, exit status, score/LU/IR/constructor/iteration/memory/warning evidence, verification verdict, evidence paths) |
| per-arm env-probe evidence | `outputs/<attempt>.envprobe` (that arm's raw 16-rank effective-OMP probe output; the rank lines are also appended, arm-prefixed, to the env-map log) |
| allocation rank-map log | `outputs/2x8-GAAS-phase3d-host-mem-closure_rankmap_<tag>.log` (16 rank lines with the incoming OMP environment + per-host local-rank-0 topology reports for both allocated nodes) |
| per-arm env-map log | `outputs/2x8-GAAS-phase3d-host-mem-closure_envmap_<tag>.log` (per-arm 16-rank effective-OMP verification lines) |
| carry-forward log | `outputs/2x8-GAAS-phase3d-host-mem-closure_carryforward_<tag>.log` (per-arm facts, R0a/R0b and D0a/D0b bracket spreads, register-step restoration record, sweep-end/anti-loop state) |
| attempt hostfile | `outputs/2x8-GAAS-phase3d-host-mem-closure_hostfile_<tag>` (deduplicated `$PBS_NODEFILE` with `slots=8` per node; shared by the rank-map probe, the per-arm env probes, and all arms in the allocation) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase3d-host-mem-closure_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase3d-host-mem-closure_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names.

## Submission (from this directory; already authorized under Section 1.12)

Submission was already authorized under the unchanged Section 1.12
authorization of TASK-2X8-012; no new approval was needed, and submission
remained limited to the exact approved task scope.

Presubmit node-status check (TASK-2X8-012 Section 1.6A), taken
2026-10-01T18:09:51+08:00: the `pbsnodes -aSj` snapshot over the eligible
queues is preserved as submission-side contention/provenance evidence at
`outputs/2x8-GAAS-phase3d-host-mem-closure_v1.presubmit_pbsnodes.log`.
Selected same-queue `gpu_as` pair: `hpc-gaas-g14` + `hpc-gaas-g15`.
Factual selection basis, from the snapshot: g14 and g15 were both `free`
with 0 jobs, 8/8 GPUs, 100/100 ncpus, and full 2tb/2tb memory, and both
carry `Qlist = gpu_as,gpu_ppu`; the remaining idle full-GPU nodes were
off-limits by queue scope (g05/g16/g17 are `gpu_aisg`) or singleton
(`gpu_ded` had exactly one eligible free full-GPU node, g22, so no
same-queue `gpu_ded` pair existed). The cleanest eligible same-queue pair
was therefore g14+g15. The current-session user override permitting a
mixed `gpu_as`/`gpu_ded` pair was not needed and was not exercised (a
same-queue pair was available); for the record, a mixed pair under one
allowed queue is not allocatable in a single job on this scheduler because
all vnodes of a host-pinned select must be members of the single submitted
queue's Qlist, and no eligible node is a member of both `gpu_as` and
`gpu_ded`. This is the same validated host-pinned pattern as the
phase1a/phase3ab/TASK-010/TASK-2X8-011 submissions (only eligible idle
`gpu_as`/`gpu_ded` nodes).

Exact approved host-pinned submission command (`ATTEMPT_TAG=v1`, walltime
`02:00:00`; submitted exactly once as PBS job `76370.gaas` on 2026-10-01,
see Run summary):

```bash
qsub -q gpu_as \
     -l select=host=hpc-gaas-g14:ncpus=96:ngpus=8:mem=2000GB+host=hpc-gaas-g15:ncpus=96:ngpus=8:mem=2000GB,place=scatter,walltime=02:00:00 \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase3d-host-mem-closure_v1.o \
     -e outputs/2x8-GAAS-phase3d-host-mem-closure_v1.e \
     scripts/run_phase3d_host_mem_closure.pbs
```

The complete submission/monitoring/retrieval record (bounded qstat polling
5 polls + 1 final-state fetch; final job metadata; SHA-256 verification
66/66) is preserved as submission-side evidence at
`outputs/2x8-GAAS-phase3d-host-mem-closure_v1_submission.log`.

## Available baseline provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s; same scored-run protocol (`--skip-tests 0 --monitor-gpu 0`); campaign percentage denominator for 2x8-GAAS comparisons |
| Baseline evidence | `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.{o,e}`; `experiments/2x8-GAAS/baseline/README.md` |
| Retained-control precedent | TASK-2X8-011 full-fill control (register-step 2048 default, DGEMV 0 default): F0 `6.5296e+06` / F1 `6.5238e+06` / B2 `6.5373e+06` GFLOP/s, IR 0.29 s, IR/LU 0.037, host 0.004 GB/process, device headroom 2.767 GB/process — PBS job 76167.gaas, `experiments/2x8-GAAS/phase3c-residency-closure/` |
| TASK-2X8-011 analysis | `planning/analysis/2x8-gaas-phase3c-residency-closure.md` (E17/E20/E21 context) |
| Flag support | installed v26.02 binary records `--cuda-host-register-step INT:POSITIVE [2048]`, `--call-dgemv-with-multiple-threads INT:NONNEGATIVE [0]`, `--fill-device INT:{0,1} [0]` (overrides `--Anq-device`), `--fill-device-buffer-size INT:NONNEGATIVE [3048]`, `--preset-gemm-kernel INT:{0,80} [0]` (effective 90 via default on H200), and the launcher OpenMP package defaults (`OMP_PROC_BIND=TRUE`, `OMP_PLACES=sockets`): `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |
| Phase-0 topology evidence | `scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated |

This task does not rerun the baseline. No run here promotes or replaces any
baseline; baseline-relative percentages belong to the post-task analysis
under `ANALYSE_RESULTS`.

## Expected output markers and validation criteria

An arm is valid only when its `outputs/<attempt>.out` contains:

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
  and the device equivalent, plus the post-matrix-generation
  `Per process memory available MIN system = ..., device = ...` line;
- the settings block echoing the arm's exact effective Phase-3D controls
  (`--cuda-host-register-step`, `--call-dgemv-with-multiple-threads`) and
  the fixed controls (verified by the script's `settings_echo_check`);
- the `Constructor seconds: AVG = ...` line (ordinary setup/registration
  timing evidence; recorded in each `.status`).

Job-level: PBS completes, the `.o`/`.e` files exist, and `.status` records
`exit_status=0`, `verification=PASSED`, and `settings_echo_check=PASS`.
With `--monitor-gpu 0`, GPU-monitoring output is unavailable by design. An
arm with an OOM, `FAILED`, non-finite residual, or a settings-echo mismatch
is preserved as evidence and is not ranked as a valid performance point
(TASK-2X8-012 Sections 1.4, 1.8 rules 6-7). Do not classify success from
exit status alone.

## Evidence paths

- `outputs/` — per-arm `.out`/`.err`/`.status`, per-arm `.envprobe` raw
  env-probe evidence, the attempt-specific deduplicated hostfile, the
  allocation-level rank-map log, the per-arm env-map log, the factual
  carry-forward log, the presubmit `pbsnodes -aSj` node-status snapshot,
  and PBS `.o`/`.e` (including the environment provenance records:
  `module list`, Apptainer version, container MPI `mpirun --version`, and
  the execution-worktree Git revision)
- `scripts/run_phase3d_host_mem_closure.pbs` — the Phase-3D run script
  (header documents purpose, working directory, inputs, outputs,
  assumptions, and the encoded stopping rules)
