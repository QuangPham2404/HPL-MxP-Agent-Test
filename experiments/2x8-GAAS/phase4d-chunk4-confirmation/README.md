# 2x8-GAAS phase4d-chunk4-confirmation

TASK-2X8-016 (Phase 4 Closure — Chunk-4 Confirmation Run) executes exactly **one**
fresh scored confirmation arm of the TASK-2X8-015 retained best Phase-4
configuration (`--u-panel-chunk-nbs = 4`) on 2 GAAS nodes x 8 H200 GPUs
(16 MPI ranks, one rank per GPU). Task file: `tasks/TASK-2X8-016.md`; parent
`TASK-2X8-015`; analysis_id `2x8-gaas-phase4c-chunk4-confirmation`. This is a
one-point confirmation, not a sweep: no chunk-8 control, no other chunk value, no
second scored attempt, no tuning, no heavy diagnostics, no microbenchmarks, no
profiling, and no strategic Phase-4 closure analysis (reserved for
`ANALYSE_RESULTS`). This is the pre-run README; an execution record is appended
after execution. Execution-only record: no baseline promotion.

## Provenance (TASK-2X8-016 Section 1.4A gate — PASSED before submission)

Evidence: `outputs/2x8-GAAS-phase4d-chunk4-confirmation_provenance_v1.md`
(read-only gate executed 2026-10-02 on GAAS via `hpc-gaas-hn2`; verdict PASS).

| item | value |
|---|---|
| SIF path (exact, unchanged) | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` |
| SIF size / mtime | 5,307,924,480 bytes / 2026-05-06 06:07:56.408241441 +0800 |
| SIF SHA-256 | `123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628` (freshly computed at the gate; matches the independent TASK-2X8-015 phase4c compute-node record) |
| Package release | NVIDIA HPC Benchmarks **v26.02** (SIF built from `nvcr.io/nvidia/hpc-benchmarks:26.02`; run banner `HPL-MxP-NVIDIA 26.2.0`) |
| Executable | `/workspace/hpl-mxp-linux-x86_64/xhpl_mxp` (single binary; no CUDA-versioned package subdirectories exist in v26.02) |
| CUDA subdirectory (launcher-selected) | `/usr/local/cuda/lib64` → `/etc/alternatives/cuda` → `/usr/local/cuda-13.1` (CUDA 13.1; `libcudart.so.13.1.80`, `libcublas.so.13.2.1.1`, `libnvJitLink.so.13.1.115`), selected by the launcher's `export LD_LIBRARY_PATH="/usr/local/cuda/lib64..."` |

The run script re-records the in-job container image identity (size, mtime,
one-shot sha256) and hard-stops before the arm if the computed digest differs
from the gate digest above (image-substitution guard; Section 1.7 rule 10); an
unavailable sha256 is a non-fatal provenance record (workflow/03).

## Structure

- `README.md` — this file (pre-run README; execution record appended after execution)
- `scripts/run_phase4d_chunk4_confirm.pbs` — the single-arm PBS job: observational
  preflights (topology, rank map, incoming-OMP, HCA link gate, in-job image
  digest check), the per-arm env probe, exactly ONE scored chunk-4 launch, and
  the full evidence extraction (no arm loop, no retry)
- `scripts/hca_counter_snapshot.sh` — host-side per-node HCA counter/link-state
  snapshot helper invoked on every allocated node via `pbsdsh --` (lock-guarded
  once per node; validated phase4c helper copy, `.p4d` lock prefix)
- `outputs/` — all evidence: the pre-submission provenance gate record, the
  per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`/`.hcadelta` files,
  pre/post `_hca_<node>.log` snapshots on both nodes, the attempt hostfile, the
  allocation-level rank-map / env-map / carry-forward logs, and PBS `.o`/`.e`
  job evidence (tracked, never overwritten; reruns get a new attempt tag)

## The single arm (TASK-2X8-016 Section 1.1 — nothing varies)

| arm | label | `--u-panel-chunk-nbs` | role |
|---|---|---:|---|
| C4 | `k4-confirm` | 4 | the one scored chunk-4 confirmation arm of the TASK-2X8-015 retained configuration |

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
UCX_TLS = unset / AUTO
UCX_NET_DEVICES = unset / automatic
OMP_NUM_THREADS=4   (explicit export + mpirun -x; verified = 4 on all 16 ranks)
OMP_PLACES / OMP_PROC_BIND omitted (effective launcher package defaults sockets / TRUE)
--fill-device 1
--fill-device-buffer-size 3048
--cuda-host-register-step 2048
--call-dgemv-with-multiple-threads 0
--sloppy-type FP16
--use-mpi-panel-broadcast 0
--u-panel-chunk-nbs 4
--use-separate-stream-for-gemm 1
--prioritize-trsm 0
--prioritize-factorization 0
--preset-gemm-kernel 90 (EFFECTIVE via package default; v26.02 CLI accepts only
                         {0,80}; flag omitted; echoed value verified = 90)
--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Configuration specified by the Strategic Analyst and approved by the Human Leader
in `tasks/TASK-2X8-016.md` Sections 1.1, 1.6, 1.11; Codex/workers did not
derive, optimize, or modify it. The Section 1.6 prohibited list is enforced by
construction.

## Per-arm command

Identical to the validated TASK-2X8-015 phase4c AUTO-arm launch (Approach-1
container launcher), with `--u-panel-chunk-nbs 4` explicit:

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
    --bind-to none \
    /workspace/hpl-mxp.sh <fixed args above>
```

No UCX/NCCL diagnostic `-x` variables; UCX_TLS is deliberately NOT forwarded
(AUTO arm, verified UNSET on all 16 ranks).

## Per-arm evidence (TASK-2X8-016 Section 1.4B)

Around the single executed arm the script preserves:

- per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`/`.hcadelta` files plus
  `hcapre`/`hcapost` snapshots on both nodes (all eight expected physical IB
  HCAs, Section 1.4B);
- overall/LU GFLOP/s; LU/IR seconds; IR/LU ratio; refinement iteration count;
- finite residual + PASSED (hard validity gates); host/device memory
  consumption and device headroom; total arm wall-clock;
- all application-emitted `<phase> seconds: AVG/MAX/MIN (rank->host)` timing
  lines (raw, in `.timings`);
- `OMP_NUM_THREADS=4` verification on all 16 ranks; the
  rank/node/local-rank/GPU map (rank-map log + fixed identity GPU map, local
  rank r -> GPU r, confirmed by the settings echo);
- requested + effective settings echo verification (`settings_echo_check`);
- PBS job ID, queue, nodes, timestamps, arm exit status (run count from the PBS
  job records / post-run `qstat -fx`, submission-side);
- exact UCX/NCCL diagnostic environment state (all verified UNSET on all 16
  ranks) and the UCX_TLS=UNSET (AUTO) / UCX_NET_DEVICES unset state;
- HCA TX/RX deltas per HCA and per node, rail shares/CV, `port_xmit_wait`
  deltas where usable, and error/discard/recovery counter deltas (any nonzero
  delta is flagged; a material HCA/link error is a Section 1.9
  stop-and-report condition);
- pre/post-run hardware-health snapshots (mother node; ordinary evidence).

Failure behavior: a nonzero arm exit, a FAILED/non-finite verification, or a
failed settings-echo check preserves all evidence and exits nonzero — no retry
and no second scored attempt under this task; a rerun needs a new `ATTEMPT_TAG`
plus human direction. A numerically slower confirmation that is otherwise valid
remains valid evidence and is never repeated.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ncpus=96:ngpus=8:mem=2000GB` (no `mpiprocs`) |
| Placement | `place=scatter` |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; pass `-q gpu_as` or `-q gpu_ded` at qsub; the script verifies the assigned queue. TASK-2X8-016 Section 1.6 combined eligible pool `gpu_as` UNION `gpu_ded`: the two nodes need not share a queue label, but the PBS allocation must be legal |
| Walltime | `01:00:00` default (may be overridden at qsub) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (digest-gated, see Provenance) |
| Launcher | container `mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (validated Approach 1; `multi-node-test/GAAS_MULTINODE_SETUP.md`) |
| Presubmit | `pbsnodes -aSj` snapshot over the eligible queues immediately before submission selects the cleanest schedulable pair from the combined pool (submission-side evidence, not part of the script) |

## Attempt and output naming

`ATTEMPT_TAG` (e.g. `v1`) is required via `qsub -v`. Attempt ID:
`2x8-GAAS-phase4d-chunk4-confirmation_k4-confirm_<ATTEMPT_TAG>`. Every evidence
file is attempt-tagged beneath `outputs/`; the pre-run guard refuses any
pre-existing target (the six per-arm file suffixes, both per-node hcapre/hcapost
snapshot globs, and the rankmap/envmap/carryforward logs and attempt hostfile);
existing evidence is never overwritten and reruns need a new tag.

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` |
| arm status | `outputs/<attempt>.status` |
| per-arm env-probe evidence | `outputs/<attempt>.envprobe` |
| per-arm timing markers | `outputs/<attempt>.timings` |
| per-arm HCA snapshots | `outputs/<attempt>_hca{pre,post}_hca_<node>.log` (both nodes) |
| per-arm HCA deltas | `outputs/<attempt>.hcadelta` |
| allocation rank-map log | `outputs/2x8-GAAS-phase4d-chunk4-confirmation_rankmap_<tag>.log` |
| per-arm env-map log | `outputs/2x8-GAAS-phase4d-chunk4-confirmation_envmap_<tag>.log` |
| carry-forward log | `outputs/2x8-GAAS-phase4d-chunk4-confirmation_carryforward_<tag>.log` |
| attempt hostfile | `outputs/2x8-GAAS-phase4d-chunk4-confirmation_hostfile_<tag>` |
| provenance gate record | `outputs/2x8-GAAS-phase4d-chunk4-confirmation_provenance_v1.md` (pre-existing) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase4d-chunk4-confirmation_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase4d-chunk4-confirmation_<tag>.e` |

## Submission (planned; under the approved TASK-2X8-016 Section 1.11 authorization)

Submission is planned under the unchanged approved Section 1.11 authorization of
TASK-2X8-016 and the exact approved task scope. Before submitting: complete the
provenance check (already PASSED, see above), run `pbsnodes -aSj` over the
eligible queues to select the cleanest schedulable 2-node x 8-GPU pair from the
combined `gpu_as` UNION `gpu_ded` pool (the pair need not share a queue label;
if a specific pair cannot legally co-allocate, automatically choose the
next-cleanest schedulable pair), and record the snapshot as submission-side
evidence. The exact queue, host-pinned select (if used), and PBS job ID are
recorded here after the actual submission. One multinode job at a time;
monitoring is bounded.

Planned submission form (`ATTEMPT_TAG=v1` shown; `-q` takes one of the eligible
queues; the optional host-pinned select names the cleanest schedulable pair from
the combined pool):

```bash
qsub -q <gpu_as|gpu_ded> \
     [-l host-pinned select...,place=scatter,walltime=...] \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase4d-chunk4-confirmation_v1.o \
     -e outputs/2x8-GAAS-phase4d-chunk4-confirmation_v1.e \
     scripts/run_phase4d_chunk4_confirm.pbs
```

## Expected output markers and validation criteria

The arm is valid only when its `outputs/<attempt>.out` contains:

- `****** Matrix Generation ******`;
- `Solver iteration ... L-infinite residual = ...` lines;
- the normalized-residual line
  `||Ax-b||_oo / (EPS * (||A||_oo * ||x||_oo + ||b||_oo) * N) = <finite residual> ...... PASSED`
  (`FAILED`/non-finite is invalid — the finite residual is a hard validity gate
  even with exit 0);
- `GFLOPS = ... , per GPU = ...` (the overall score to report) and `LU GFLOPS = ...`;
- the settings block echoing the arm's exact effective controls, verified by the
  script's `settings_echo_check`;
- a measured performance result (normal benchmark output, not a stop during
  initialization or internal tests).

Job-level: a run is correct only when PBS completes, the expected files exist,
the harness reports successful verification, the residuals are finite within
tolerance, and the output is normal benchmark output with a measured
performance. The `.status` records `exit_status`, `verification=PASSED`, and
`settings_echo_check=PASS`; do not classify success from exit status alone. An
arm killed mid-run (e.g. by walltime) keeps its `.out`/`.err` but has no
`.status` file.

## Available reference provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s; same scored-run protocol (`--skip-tests 0 --monitor-gpu 0`); campaign percentage denominator for 2x8-GAAS comparisons. |
| TASK-2X8-015 K4 reference (the configuration under confirmation) | overall `6.8223e+06` GFLOP/s; LU `7.43` s / `7.0862e+06` GFLOP/s; IR `0.29` s; residual `1.416310E-05`; PASSED (phase4c Stage-B arm `k4-chunk4_v1`, PBS job 76826.gaas) |

This task does not rerun, select, or promote any baseline, and computes no
percentage deltas; baseline-relative percentages and the Phase-4 closure
comparison belong to the post-task analysis under `ANALYSE_RESULTS`. No exact
score reproduction is required — the Strategic Analyst determines whether the
fresh run remains clearly in the improved chunk-4 regime.

## Execution record — attempt v1 (2026-10-02)

The provenance gate passed before submission. Its exact SIF path, SHA-256,
NVIDIA HPC Benchmarks v26.02 label, and launcher-selected CUDA 13.1 path are
recorded in
`outputs/2x8-GAAS-phase4d-chunk4-confirmation_provenance_v1.md`. The in-job
image digest matched the gate digest.

PBS job `76998.gaas` was submitted at `2026-10-02T15:12:39+0800` to `gpu_as`,
project `hpc_ebslee`, pinned to `hpc-gaas-g14` + `hpc-gaas-g15` with
`place=scatter`, 8 GPUs and 96 CPUs per node, 16 ranks total, and a 1-hour
walltime. The presubmit snapshot showed both nodes fully free and eligible for
`gpu_as`; the other fully free node in the eligible pool was `g22` in
`gpu_ded`, with no fully free `gpu_ded` partner. The snapshot and pair
selection are recorded in
`outputs/2x8-GAAS-phase4d-chunk4-confirmation_v1.presubmit_pbsnodes.log` and
`outputs/2x8-GAAS-phase4d-chunk4-confirmation_v1.submission.log`.

PBS finished with `job_state=F`, `Exit_status=0`, `run_count=1`, and walltime
`00:02:11` (start `15:12:40`, end `15:14:52`, +0800). The only scored arm was
`k4-confirm_v1`; its status records exit 0, `verification=PASSED`, and
`settings_echo_check=PASS`.

| Metric | v1 result |
|---|---:|
| Overall GFLOP/s | `6.8196e+06` |
| LU time | `7.43 s` |
| LU GFLOP/s | `7.0833e+06` |
| Iterative refinement | `0.29 s`; IR/LU `0.039` |
| Solver iterations | 3 |
| Normalized residual | `1.416310E-05`, finite, `PASSED` |
| Host memory maximum | `0.004 GB`; available minimum `72.863 GB` |
| Device memory maximum | `135.254 GB`; available minimum `138.739 GB`; matrix-generation headroom `2.767 GB` |

OMP_NUM_THREADS=4 was verified on all 16 ranks; OMP_PLACES and OMP_PROC_BIND
were unset on all ranks (effective package defaults `sockets` / `TRUE`). UCX_TLS
was unset/AUTO and UCX_NET_DEVICES plus the UCX/NCCL diagnostic variables were
unset. Rank mapping and the per-host topology gate passed. Pre/post HCA
snapshots passed the link gates; the HCA delta reports no new error, discard,
or recovery counters. TX/RX, rail shares/CV, and usable `port_xmit_wait`
deltas are preserved in the HCA evidence.

All 20 new v1 files were retrieved from the execution worktree and SHA-256
verified against the remote copies. The task report-writing session corrected
one logging-mechanics error: the first submission-log write was cut off by a
nested-shell quoting error after the successful qsub. The complete log was
transferred from a local reconstruction and its SHA-256 was verified; this
replacement is recorded in the task Execution Report. No scheduler action or
scientific run was repeated.
