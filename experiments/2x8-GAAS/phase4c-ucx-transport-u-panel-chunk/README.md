# 2x8-GAAS phase4c-ucx-transport-u-panel-chunk

TASK-2X8-015 (Phase 4C) executes the UCX transport-family characterization (Stage A) plus, behind
the deterministic Section 1.6C gate, the U-panel chunk sweep (Stage B), as ONE same-allocation
sequential PBS job on 2 GAAS nodes x 8 H200 GPUs (16 MPI ranks, one rank per GPU). Task file:
`tasks/TASK-2X8-015.md`; parent `TASK-2X8-014`; analysis_id
`2x8-gaas-phase4c-ucx-transport-and-u-panel-chunk`. Panel broadcast is fixed at
`--use-mpi-panel-broadcast 0` (retained TASK-2X8-014 outcome) on every arm of both stages. This
is the pre-run README; a run summary is appended after execution. Execution-only record: no
strategic analysis, no baseline promotion (reserved for `ANALYSE_RESULTS`).

## Structure

- `README.md` — this file (pre-run README; run summary appended after execution)
- `scripts/run_phase4c_ucx_upanel.pbs` — the single same-allocation Stage-A + gate + Stage-B job:
  the in-job UCX/launcher capability preflight, the Stage-A arms in the exact approved order, the
  mechanical Section 1.6C transition record, and — only if the gate authorizes progression — the
  Stage-B arms in the exact approved order; per-arm evidence files, pre/post per-node HCA
  snapshots, and the factual carry-forward records (`ATTEMPT_TAG` at submission)
- `scripts/hca_counter_snapshot.sh` — host-side per-node HCA counter/link-state snapshot helper
  invoked on every allocated node via `pbsdsh --` (lock-guarded once per node; validated 4B
  helper copy, `.p4c` lock prefix)
- `outputs/` — all evidence: per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`/`.hcadelta`
  files, per-arm pre/post `_hca_<node>.log` snapshots, the attempt hostfile, the allocation-level
  rank-map / UCX-preflight / env-map / carry-forward logs, and PBS `.o`/`.e` job evidence
  (tracked, never overwritten; reruns get a new attempt tag)

## UCX/launcher capability preflight (Section 1.4A; in-job, before any arm)

Before any scored arm, the job records the transport capability evidence that Section 1.6B makes
authoritative for the exact Stage-A allow-list strings:

- the installed package README launcher-help record for `--ucx-tls`;
- the launcher source handling: installed v26.02 `hpl-mxp.sh` maps `--ucx-tls <string>` to `export UCX_TLS="$2"`;
- `ucx_info -v` from the execution container (UCX 1.20.0) and the full `ucx_info -d` transport
  listing;
- per-host transport inventories for both allocated nodes (captured in the rank-map probe);
- the mechanical Section 1.6B allow-list determination (which optional families run vs are
  mechanically skipped once) and the selected T1-T4 allow-list strings.

Capability evidence only; no microbenchmarks. Evidence file:
`outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_ucxpreflight_<tag>.log`.

## Arm set (TASK-2X8-015 Sections 1.6B/1.6D)

### Stage A — UCX transport-family characterization

| arm | label | `UCX_TLS` allow-list | role |
|---|---|---|---|
| T0a | `t0a-auto-ctl` | AUTO (`UCX_TLS` unset) | opening control |
| T1 | `t1-rc` | `sm,self,rc,cuda` | explicit RC family (if supported) |
| T2 | `t2-rcx` | `sm,self,rc_x,cuda` | accelerated RC only (if supported) |
| T3 | `t3-dc` | `sm,self,dc,cuda` | DC family (if supported) |
| T4 | `t4-ud` | `sm,self,ud,cuda` | UD family (if supported) |
| T0b | `t0b-auto-ctl` | AUTO (`UCX_TLS` unset) | closing control |

Rules encoded in the script (Sections 1.6B, 1.7):

- exact order, one scored attempt per supported arm; unsupported optional families are
  mechanically skipped once and recorded (no retries, no substitutions, no blocking); every
  explicit arm holds the common support set `sm,self,cuda` and isolates exactly ONE inter-node
  family;
- never combined inter-node families (no `rc,dc`, `rc,ud`, `dc,ud`, `rc,dc,ud`), never TCP, never
  raw mlx5/verb transport lists; T3 prefers the documented `dc` family alias (the `dc_x` fallback
  is not applicable on UCX 1.20 since both aliases derive from the same `dc` transports).

### Stage A -> Stage B transition gate (mechanical; Section 1.6C)

The gate is deterministic, computed in-script from facts only, and declares no winner. Both T0a
and T0b must be valid PASSED controls; the LU/overall bracket spreads are computed from that
bracket and the AUTO midpoint is `(T0a + T0b) / 2` per metric:

```
local_noise_pct
  = max(0.5%, LU_bracket_spread_pct, overall_bracket_spread_pct)

positive_surprise_threshold_pct
  = max(2%, 2 * local_noise_pct)
```

A valid explicit arm is a material positive surprise only when its LU improvement versus the AUTO
midpoint is >= the threshold AND its overall improvement is > local_noise_pct (correctness,
iterations, and memory regime must remain valid). Encoded stop rules:

- an AUTO bracket spread above 5% (LU or overall) stops the job before Stage B (no automatic
  Stage-A rerun); no valid explicit RC-family point (neither T1 nor T2 valid) likewise stops
  before Stage B as a capability gap;
- any material positive surprise stops the task BEFORE Stage B (Outcome B): the fixed Stage-A set
  is completed first, all evidence is preserved, and the unexpected family is handed back for
  strategic investigation — no profiling or deeper investigation inside this task;
- otherwise Stage B runs automatically in the same allocation (Outcome A): AUTO is retained for
  execution purposes; ties, regressions, and cleanly skipped optional families take this path.

### Stage B — U-panel chunk sweep

Stage B runs only if the Section 1.6C gate authorizes progression.

| arm | label | `--u-panel-chunk-nbs` | role |
|---|---|---:|---|
| K8a | `k8a-chunk8-ctl` | 8 | opening retained control |
| K2 | `k2-chunk2` | 2 | fine-grained U-panel readiness |
| K4 | `k4-chunk4` | 4 | intermediate fine granularity |
| K16 | `k16-chunk16` | 16 | coarse granularity |
| K8b | `k8b-chunk8-ctl` | 8 | closing retained control |

Rules encoded in the script (Sections 1.6D, 1.7):

- `UCX_TLS` stays unset/AUTO and panel broadcast stays 0; only `--u-panel-chunk-nbs` varies,
  passed explicitly per arm;
- one scored attempt per arm; K8a/K8b are the only intentional repeat;
- a K8a/K8b drift above 2% records the wider uncertainty only: no reruns, no extra arms, no chunk values
  outside 2/4/8/16, no second sweep (Stage B is the terminal fixed stage; drift alone adds no arms).

## Fixed scientific controls (identical for every arm)

```
--n 429056
--nb 3072
--nprow 4
--npcol 4
--nporder row
--gpu-affinity 0:1:2:3:4:5:6:7
--cpu-affinity omitted
--mem-affinity omitted
--ucx-affinity omitted / automatic
UCX_NET_DEVICES unset / automatic
OMP_NUM_THREADS=4   (explicit export + mpirun -x; verified = 4 on all 16 ranks per arm)
OMP_PLACES / OMP_PROC_BIND omitted (effective launcher package defaults sockets/TRUE)
--fill-device 1
--fill-device-buffer-size 3048
--cuda-host-register-step 2048
--call-dgemv-with-multiple-threads 0
--sloppy-type FP16
--use-mpi-panel-broadcast 0   (explicit on every arm)
--use-separate-stream-for-gemm 1
--prioritize-trsm 0
--prioritize-factorization 0
--preset-gemm-kernel 90   (EFFECTIVE via package default; v26.02 CLI accepts only {0,80};
                           flag omitted; echoed value verified = 90 per arm)
--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Notes:

- Stage A holds `--u-panel-chunk-nbs` at the package default 8; Stage B passes it explicitly per
  arm (the only Stage-B variable).
- Explicit Stage-A arms apply `UCX_TLS` via BOTH the launcher flag `--ucx-tls` and a job-shell
  export forwarded with `mpirun -x UCX_TLS` (identical value; the per-arm env probe verifies the
  exact requested state on all 16 ranks).

Configuration specified by the Strategic Analyst and approved by the Human Leader in
tasks/TASK-2X8-015.md Sections 1.2, 1.6A-1.6D; Codex/workers did not derive, optimize, or modify
it. The Section 1.6F prohibited list is enforced by construction.

## Per-arm command

Identical form for every arm, launched inside the PBS job through the validated Approach-1
container launcher; only the stage variable differs:

```bash
apptainer exec --nv \
  -B /opt/pbs:/opt/pbs \
  -B /var/spool/pbs:/var/spool/pbs \
  -B "$REPO_ROOT":"$REPO_ROOT" \
  "$SIF" \
  /usr/local/mpi/bin/mpirun -np 16 \
    --hostfile <dedup hostfile, slots=8> \
    --mca plm_rsh_agent <bridge> \
    --mca plm_rsh_no_tree_spawn 1 \
    --mca plm_rsh_num_concurrent 1 \
    --mca routed direct \
    -x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS \
    [-x UCX_TLS] \
    --bind-to none \
    /workspace/hpl-mxp.sh <fixed args + stage variable>
```

The bracketed `[-x UCX_TLS]` appears exactly on the explicit Stage-A arms (T1-T4), carrying the
identical value as that arm's `--ucx-tls` launcher flag and job-shell export; the AUTO controls
(T0a/T0b) and every Stage-B arm omit it. `<fixed args + stage variable>` is the fixed-controls
block above plus exactly one stage variable: the Stage-A `--ucx-tls <allow-list>` (explicit arms
only) or the Stage-B `--u-panel-chunk-nbs <2|4|8|16>`. No diagnostic `-x` variables on scored arms.

## Per-arm evidence (TASK-2X8-015 Sections 1.4B/1.4C)

Around EVERY executed arm the script preserves:

- per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`/`.hcadelta` files plus `hcapre`/`hcapost`
  snapshots on both nodes (all eight expected physical IB HCAs, Section 1.4C);
- requested + effective `UCX_TLS` state and requested + effective `--u-panel-chunk-nbs`;
- overall/LU GFLOP/s; LU/IR seconds; IR/LU ratio; refinement iteration count;
- finite residual + PASSED; host/device memory + device headroom; total arm wall-clock;
- all application-emitted `<phase> seconds: AVG/MAX/MIN (rank->host)` timing lines (raw, in
  `.timings`);
- OMP=4 verification on all 16 ranks; the rank/node/local-rank/GPU map (rankmap log);
- PBS job/node/queue/timestamps/exit status; per-arm env-probe records;
- the UCX preflight record; the carry-forward log (preflight determination, per-arm facts, gate
  records, stop records); the Stage-B K8a/K8b drift record.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ncpus=96:ngpus=8:mem=2000GB` (no `mpiprocs`) |
| Placement | `place=scatter` |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; pass `-q gpu_as` or `-q gpu_ded` at qsub; the script verifies the assigned queue. TASK-2X8-015 Section 1.6E combined eligible pool `gpu_as` UNION `gpu_ded`: the two nodes need not share a queue label, but the PBS allocation must be legal |
| Walltime | `03:00:00` default (may be overridden at qsub) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` |
| Launcher | container `mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (validated Approach 1; `multi-node-test/GAAS_MULTINODE_SETUP.md`) |
| Presubmit | `pbsnodes -aSj` snapshot over the eligible queues selects the cleanest schedulable pair (submission-side evidence) |

## Sequential-sweep behavior and encoded stopping rules

- One allocation; arms strictly sequential on the same two nodes (same-allocation comparability;
  if the allocation is lost mid-run, evidence is preserved and the job stops).
- Observational preflight failures abort before any arm: topology mismatch on either node,
  rank-map check failure, incoming `OMP_PLACES`/`OMP_PROC_BIND` set, HCA link-gate failure,
  missing per-host UCX inventory, UCX preflight capture failure.
- Per-arm sequence: pre-HCA snapshot + link gate -> per-arm env probe (OMP=4, diagnostic
  variables UNSET, exact requested `UCX_TLS` state on all 16 ranks) -> launch -> post-HCA
  snapshot + gate -> HCA deltas -> extraction -> settings-echo verification -> `.status`.
- A nonzero exit of an AUTO control or any Stage-B arm stops the sweep (Track 2; no in-script
  retry; a rerun needs a new `ATTEMPT_TAG` plus human direction).
- A nonzero exit of an explicit Stage-A arm within 240 s matching a UCX transport-rejection
  signature (fixed pattern list) is preserved as an invalid characterization point and the sweep
  continues; no rescue transport lists (post-arm HCA gate + next env probe are the health checks).
- An arm that exits 0 with an invalid verification is preserved invalid/boundary evidence and the
  sweep continues with the next authorized arm (Sections 1.7 rules 16-17); invalid arms are never
  used in the Section 1.6C gate. No diagnostic logging on any scored arm.
- Anti-loop: no extra families/lists/TCP/transport knobs/microbenchmarks/profilers/chunk
  values/second sweeps/leader repeats; every arm runs at most once per attempt.
- The carry-forward log records the preflight determination, per-arm facts, gate records, and
  stop records; the script declares no winner and computes no baseline-relative percentages
  (reserved for `ANALYSE_RESULTS`). One multinode job at a time; no concurrent submissions.

## Attempt and output naming

`ATTEMPT_TAG` (e.g. `v1`) is required via `qsub -v`. Per-arm attempt ID:
`2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_<label>_<ATTEMPT_TAG>` (e.g. `..._t1-rc_v1`), with
`<label>` one of `t0a-auto-ctl`, `t1-rc`, `t2-rcx`, `t3-dc`, `t4-ud`, `t0b-auto-ctl` (Stage A)
or `k8a-chunk8-ctl`, `k2-chunk2`, `k4-chunk4`, `k16-chunk16`, `k8b-chunk8-ctl` (Stage B). Every
evidence file is attempt-tagged beneath `outputs/`; the pre-run guard refuses any pre-existing
target (existing evidence is never overwritten; reruns need a new tag).

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` |
| arm status | `outputs/<attempt>.status` |
| per-arm env-probe evidence | `outputs/<attempt>.envprobe` |
| per-arm timing markers | `outputs/<attempt>.timings` |
| per-arm HCA snapshots | `outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_<label>_<ATTEMPT_TAG>_hca{pre,post}_hca_<node>.log` (both nodes, pre and post) |
| per-arm HCA deltas | `outputs/<attempt>.hcadelta` |
| allocation rank-map log | `outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_rankmap_<tag>.log` |
| UCX preflight record | `outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_ucxpreflight_<tag>.log` |
| per-arm env-map log | `outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_envmap_<tag>.log` |
| carry-forward log | `outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_carryforward_<tag>.log` |
| attempt hostfile | `outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_hostfile_<tag>` |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_<tag>.e` |

## Submission (planned; under the approved TASK-2X8-015 Section 1.11 authorization)

Submission is planned under the unchanged approved Section 1.11 authorization of TASK-2X8-015
and the exact approved task scope. The exact queue, host-pinned select, and PBS job IDs are
recorded here after the actual submission. One multinode job at a time; monitoring is bounded.

Planned submission form (`ATTEMPT_TAG=v1` shown; `-q` takes one of the eligible queues; the
optional host-pinned select names the cleanest schedulable pair from the combined pool):

```bash
qsub -q <gpu_as|gpu_ded> \
     [-l host-pinned select...,place=scatter,walltime=...] \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_v1.o \
     -e outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_v1.e \
     scripts/run_phase4c_ucx_upanel.pbs
```

## Available baseline provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s; same scored-run protocol (`--skip-tests 0 --monitor-gpu 0`); campaign percentage denominator for 2x8-GAAS comparisons. The protocol-mismatch disclosure applies to the separate 3x4 baseline only, not this one. |
| Phase-4 in-sweep local reference (4B) | 4B Stage-B panel-0 midpoint: overall `6.54645e+06` / LU `6.7899e+06` GFLOP/s — context only |
| Phase-4 in-sweep local reference (4A) | 4A clean reference A0: overall `6.5324e+06` GFLOP/s — context only |

This task does not rerun, select, or promote any baseline; baseline-relative percentages belong to
the post-task analysis under `ANALYSE_RESULTS`. T0a/T0b and K8a/K8b are in-sweep controls, not
baselines.

## Expected output markers and validation criteria

An arm is valid only when its `outputs/<attempt>.out` contains:

- `****** Matrix Generation ******`;
- `Solver iteration ... L-infinite residual = ...` lines;
- the normalized-residual line
  `||Ax-b||_oo / (EPS * (||A||_oo * ||x||_oo + ||b||_oo) * N) = <finite residual> ...... PASSED`
  (`FAILED`/non-finite is invalid — the finite residual is a hard validity gate even with exit 0);
- `GFLOPS = ... , per GPU = ...` (the overall score to report) and `LU GFLOPS = ...`;
- the settings block echoing the arm's exact effective controls, verified per arm by the
  script's `settings_echo_check`;
- a measured performance result (normal benchmark output, not a stop during initialization or
  internal tests).

Job-level: a run is correct only when PBS completes, the expected files exist, the harness reports
successful verification, the residuals are finite within tolerance, and the output is normal
benchmark output with a measured performance. Each `.status` records `exit_status`,
`verification=PASSED`, and `settings_echo_check=PASS`; do not classify success from exit status
alone.

## Evidence paths

- `outputs/` — per-arm
  `2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_<label>_<tag>.{out,err,status,envprobe,timings,hcadelta}`,
  per-arm pre/post `..._<label>_<tag>_hca{pre,post}_hca_<node>.log` snapshots, the attempt
  hostfile `..._hostfile_<tag>`, the allocation-level logs `..._rankmap_<tag>.log`,
  `..._ucxpreflight_<tag>.log`, `..._envmap_<tag>.log`, and `..._carryforward_<tag>.log`, and
  the PBS-level `outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_<tag>.{o,e}`
- `scripts/run_phase4c_ucx_upanel.pbs` — the single same-allocation Stage-A + gate + Stage-B run
  script (header documents purpose, working directory, inputs, outputs, assumptions, and the
  encoded stopping/gate rules)
- `scripts/hca_counter_snapshot.sh` — the per-node HCA snapshot helper
