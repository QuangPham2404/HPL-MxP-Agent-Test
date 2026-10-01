# 2x8-GAAS phase4a-fast-path-characterization

TASK-2X8-013 Phase 4A communication fast-path characterization for the
2 GAAS nodes x 8 H200 GPUs HPL-MxP campaign: a bounded, non-tuning
characterization of what the retained Phase-3 stack actually does on the
communication critical path, executed as sequential arms inside ONE 2x8
allocation with only diagnostic environment/logging differences between
arms (tasks/TASK-2X8-013.md Sections 1.6A-1.6F). No Phase 4B/4C tuning is
authorized or performed; the strategic reading belongs to the Strategic
Analyst via `ANALYSE_RESULTS`.

**Status: Reviewed locally; not yet submitted.**

## Structure

- `scripts/run_phase4a_fast_path_characterization.pbs` — single
  same-allocation Phase-4A run script: A0 (clean control) then A1
  (diagnostic clone) always, then conditional A2-U and/or A2-N only when
  A1 is transfer-level ambiguous for that stack; per-arm evidence files,
  per-arm pre/post per-node HCA snapshots, and the mechanical Section 1.6F
  gates; attempt tag comes from the `ATTEMPT_TAG` environment at
  submission
- `scripts/hca_counter_snapshot.sh` — host-side per-node HCA
  counter/link-state snapshot helper invoked on every allocated node via
  `pbsdsh --` (lock-guarded once per node; the validated resource-alloc
  read pattern over `/sys/class/infiniband`)
- `outputs/` — per-arm application `.out`/`.err`/`.status` evidence,
  per-arm `.envprobe` raw env-probe evidence, per-arm `.timings`
  timing-marker extracts, per-arm pre/post `_hca_<node>.log` snapshots and
  `.hcadelta` derivations, the attempt-specific deduplicated hostfile, the
  allocation-level rank-map / per-arm env-map / carry-forward logs, and
  PBS `.o`/`.e` job evidence (tracked, never overwritten; every rerun gets
  a new attempt tag; all runtime artifacts live beneath `outputs/` —
  nothing is written to the experiment root)

## Arm set (TASK-2X8-013 Sections 1.6B-1.6F)

| arm | label | kind | diagnostic environment (beyond the retained controls) |
|---|---|---|---|
| A0 | `a0-clean` | clean scored Phase-4 reference | none (verified UNSET on all 16 ranks) |
| A1 | `a1-diag` | exact scientific clone | `UCX_LOG_LEVEL=info`, `UCX_PROTO_INFO=y`, `NCCL_DEBUG=INFO`, `NCCL_DEBUG_SUBSYS=INIT,BOOTSTRAP,ENV,NET,GRAPH,P2P,COLL,SHM,TUNING`, `NCCL_DEBUG_FILE=/dev/stderr` |
| A2-U | `a2u-ucx-gdroff` | conditional (UCX ambiguity only) | A1 set + `UCX_IB_GPU_DIRECT_RDMA=n` |
| A2-N | `a2n-nccl-gdroff` | conditional (NCCL ambiguity only) | A1 set + `NCCL_NET_GDR_LEVEL=LOC` |

The arms run in exactly this order, one attempt each, at most once each:
A0 -> A1 -> conditional A2-U -> conditional A2-N. Maximum four HPL arms.
Never both GDR-off knobs in one arm. After the authorized conditional
arm(s) the task stops: no further diagnostics, no Phase 4B/4C values.

`NCCL_DEBUG_FILE=/dev/stderr` is part of the previously validated
in-container diagnostic style for this exact container NCCL 2.29.x +
IBext_v11 stack (`scripts/gaas-internode-coms-debug/debug-scripts/
phase2-stage2/README.md`); it routes NCCL logs into the arm `.err`
evidence file and changes no transport behavior. The GDR-off knobs are the
two independently validated diagnostic controls from the same debug
program (in-container, same SIF): `UCX_IB_GPU_DIRECT_RDMA=n` for MPI/UCX
and `NCCL_NET_GDR_LEVEL=LOC` for NCCL.

### Section 1.6F conditional logic (encoded mechanically in the script)

After A1 completes, the script evaluates A1's preserved raw evidence
(`.out` + `.err`) with fixed grep-count gates:

- **MPI/UCX conclusive** iff UCX_PROTO_INFO transfer-level protocol rows
  exist (rendezvous zero-copy / cuda_copy / gdr_copy / frag host) AND
  rc_mlx5 transport/lane evidence exists. Conclusive -> skip A2-U.
- **NCCL conclusive** iff per-channel inter-node `via NET/IBext` graph
  evidence exists (the GDRDMA-tagged fraction is then countable).
  Conclusive -> skip A2-N.
- Missing evidence class for a stack -> that stack's A2 arm runs.
- **A2-U direction check**: the validated GDR-off signature (frag-host
  staging rows) must appear in A2-U, confirming the knob changes the
  intended stack; otherwise the ambiguity is unresolved or the knob
  failed (stop condition, evidence preserved).
- **A2-N direction check**: GDRDMA-tagged inter-node channels must drop
  to 0 while the IBext backend remains; otherwise stop condition.
- **Unexpected transport revealed by A1 is a STOP, not an A2 trigger**
  (Section 1.9): inter-node UCX lanes tcp-only, NCCL data path Socket,
  NCCL backend other than the IBext family with no IBext channel
  evidence, or NCCL bond/RoCE/mixed-link warnings matching the case
  2026-09-17-A signature family.

All gate inputs, gate decisions, A2 decisions, direction checks, and stop
conditions are recorded in the carry-forward log. The gates are
mechanical operationalizations of the task's Section 1.6F wording; the
final transfer-path reading belongs to the Strategic Analyst.

## Fixed scientific controls (identical for every arm; nothing varies)

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
--ucx-affinity omitted / automatic
UCX_TLS / UCX_NET_DEVICES not set (automatic; recorded per rank)
OMP_PLACES / OMP_PROC_BIND omitted (effective launcher defaults sockets/TRUE)
--fill-device 1
--fill-device-buffer-size 3048
--cuda-host-register-step 2048
--call-dgemv-with-multiple-threads 0
--sloppy-type FP16
--use-mpi-panel-broadcast 0
--use-separate-stream-for-gemm 1
--prioritize-trsm 0
--prioritize-factorization 0
--test-loop 1
--skip-tests 0
--monitor-gpu 0
```

Default-equal controls applied via the installed package defaults —
exactly the validated TASK-010/TASK-2X8-011/012 launch form — with the
echoed effective value verified per arm:

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

The retained Phase-3D controls (`--cuda-host-register-step 2048`,
`--call-dgemv-with-multiple-threads 0`) are passed explicitly on every
arm (prior CLI acceptance evidence: TASK-2X8-012 phase3d, PBS job
76370.gaas). Every arm's `.status` records the application's echoed
settings for all fixed controls with a PASS/FAIL `settings_echo_check`; a
mismatch is control-application failure evidence: the arm is preserved
but marked not a valid performance point, and the mismatch is flagged in
the carry-forward log.

Configuration specified by the Strategic Analyst and approved by the
Human Leader in tasks/TASK-2X8-013.md Sections 1.2, 1.6A-1.6F;
Codex/workers did not derive, optimize, or modify it. No communication
tuning value is introduced by this task: `--ucx-affinity` stays
omitted/automatic (closed for this task), `--ucx-tls`/`UCX_TLS` is never
set, `--use-mpi-panel-broadcast` stays 0, `--u-panel-chunk-nbs` stays 8
via the package default. The prohibited list of TASK-2X8-013 Section 1.6G
(no HCA/bond/UCC/rendezvous mitigations, no microbenchmark ladder, no
profiler, no Phase 4B/4C values) is enforced by construction: the script
contains no such controls.

## Per-arm command

Identical for every arm (byte-identical HPL-MxP command line), launched
inside the PBS job through the validated Approach-1 container launcher
with the retained TASK-009 host-runtime `-x` forwarding plus the arm's
diagnostic variables (example: arm A1; A0 forwards no diagnostic
variables, A2-U adds `-x UCX_IB_GPU_DIRECT_RDMA`, A2-N adds `-x
NCCL_NET_GDR_LEVEL`):

```bash
apptainer exec --nv \
  -B /opt/pbs:/opt/pbs \
  -B /var/spool/pbs:/var/spool/pbs \
  -B "$REPO_ROOT":"$REPO_ROOT" \
  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif \
  /usr/local/mpi/bin/mpirun -np 16 \
    --hostfile "$PWD/outputs/2x8-GAAS-phase4a-fast-path-characterization_hostfile_<ATTEMPT_TAG>" \
    --mca plm_rsh_agent multi-node-test/rsh_pbsdsh_container.sh \
    --mca plm_rsh_no_tree_spawn 1 \
    --mca plm_rsh_num_concurrent 1 \
    --mca routed direct \
    -x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS \
    -x UCX_LOG_LEVEL -x UCX_PROTO_INFO \
    -x NCCL_DEBUG -x NCCL_DEBUG_SUBSYS -x NCCL_DEBUG_FILE \
    --bind-to none \
    /workspace/hpl-mxp.sh \
      --n 429056 --nb 3072 --nprow 4 --npcol 4 --nporder row \
      --gpu-affinity 0:1:2:3:4:5:6:7 --sloppy-type FP16 \
      --use-mpi-panel-broadcast 0 --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --fill-device-buffer-size 3048 \
      --cuda-host-register-step 2048 --call-dgemv-with-multiple-threads 0 \
      --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

`OMP_NUM_THREADS=4` is exported in the job shell (and verified on all 16
ranks by the per-arm env probe) before the launch; application
stdout/stderr are redirected to that arm's `.out`/`.err` evidence file
(UCX logs and NCCL logs, including the per-channel `via NET/IBext_v11/...`
graph lines, land in the `.err`).

## Per-arm evidence (TASK-2X8-013 Section 1.4)

Around EVERY executed arm, in this order:

1. **pre-arm HCA snapshot** on both nodes (pbsdsh +
   `hca_counter_snapshot.sh`): per-device/port numa_node, link state,
   rate, and the full counter set — `port_xmit_data`, `port_rcv_data`,
   `port_xmit_packets`, `port_rcv_packets`, `port_xmit_discards`,
   `port_xmit_wait`, `port_rcv_errors`, `port_rcv_constraint_errors`,
   `port_xmit_constraint_errors`, `port_rcv_remote_physical_errors`,
   `port_rcv_switch_relay_errors`, `link_error_recovery`, `link_downed`,
   `excessive_buffer_overrun_errors`, `symbol_error` — with a
   counters_ext fallback. Link gate: all eight expected physical IB HCAs
   (`mlx5_0 mlx5_1 mlx5_2 mlx5_3 mlx5_4 mlx5_5 mlx5_8 mlx5_9`) must be
   ACTIVE at 400 Gb/sec on both nodes (Section 1.9 stop otherwise). Any
   other visible device (e.g. the known RoCE bond `mlx5_bond_0`) is
   recorded factually with `expected=no`.
2. **per-arm env probe**: 16-rank verification of `OMP_NUM_THREADS=4`,
   `OMP_PLACES`/`OMP_PROC_BIND` UNSET, the arm's diagnostic variables
   (exact values, including UNSET for everything the mode must not set),
   and the recorded effective `UCX_TLS`/`UCX_NET_DEVICES` state
   (expected unset/automatic; recorded, not gated).
3. **the HPL-MxP arm** (identical command line; mode-specific `-x` set).
4. **post-arm HCA snapshot** (both nodes) + link gate, taken
   unconditionally so fabric state around a failure is also evidence.
5. **derived per-arm HCA deltas** (`.hcadelta`): per node and per HCA —
   raw TX/RX counter deltas (plus a x4 octet column; see unit note),
   `port_xmit_wait` delta, node TX/RX totals, per-HCA TX share, max/mean
   and coefficient of variation across the eight rails, and any
   nonzero/new error/discard/recovery counter delta (flagged in the
   carry-forward log). Explanatory metrics only.
6. **benchmark extraction** into `.status`: overall GFLOP/s, LU
   seconds/GFLOP/s, IR seconds, IR/LU ratio, solver iteration count,
   normalized residual + PASSED/FAILED, host/device memory consumption
   and matgen headroom, constructor seconds, arm wall-clock, warning
   counts, settings echo, and — for diagnostic arms — the UCX/NCCL
   marker counts (the Section 1.6F gate inputs). The raw `.timings` file
   preserves every emitted `<phase> seconds: AVG/MAX/MIN (rank->host)`
   line (Constructor, GEMM, MPI/NCCL U and L2 broadcast, pdgemv, LU,
   Iterative Solver, and the rest), including owning ranks.

Unit note: `port_xmit_data`/`port_rcv_data` raw deltas are recorded
as-is; GAAS precedent (resource-alloc) treats the sysfs values as byte
counts while IBTA defines PortXmitData/PortRcvData in 4-octet units, so a
x4 octet column is also provided. The unit question is flagged for the
Strategic Analyst, not resolved here. `port_xmit_wait=4294967295` is
treated as the unavailable-counter sentinel seen in prior GAAS evidence.

A1/A2 benchmark scores are **diagnostic only**: logging or forced-path
controls can perturb timing, so A1/A2 are never ranked against A0 as
optimization candidates (Sections 1.4A, 1.6C, 1.7 rule 9).

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ncpus=96:ngpus=8:mem=2000GB` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `02:00:00` for at most four ~1 min full-fill arms (diagnostic arms pay bounded info-level logging overhead) + per-arm probes + per-arm pre/post HCA snapshots on both nodes; may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0); size/mtime/sha256 recorded in the PBS `.o` (provenance if available, non-fatal) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS` (+ the arm's diagnostic `-x` set), `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by the rank-map probe, the per-arm env probes, the HCA snapshot node set, and all arms; written beneath `outputs/` with an attempt-specific name |
| Process grid | fixed 4x4, `nporder=row` (not auto-derived) |
| GPU affinity | `0:1:2:3:4:5:6:7` (node-local rank -> local GPU) |
| OMP host-runtime contract | `OMP_NUM_THREADS=4` explicit job-shell export after module setup + `mpirun -x OMP_NUM_THREADS`, verified = 4 on all 16 ranks by the per-arm env probe; `OMP_PLACES`/`OMP_PROC_BIND` omitted (unset in the job shell, verified UNSET on all 16 ranks); effective launcher package defaults `sockets` / `TRUE`; `--cpu-affinity`/`--mem-affinity`/`--ucx-affinity` omitted |
| HCA snapshot transport | `/opt/pbs/bin/pbsdsh --` host-side per-node capture (validated resource-alloc/fabric-capture pattern; lock-guarded once per node) |
| Flag support evidence | installed v26.02 binary records `--cuda-host-register-step INT:POSITIVE [2048]`, `--call-dgemv-with-multiple-threads INT:NONNEGATIVE [0]`, `--fill-device INT:{0,1} [0]`, `--fill-device-buffer-size INT:NONNEGATIVE [3048]`, `--preset-gemm-kernel INT:{0,80} [0]`: `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md`,
`workflow/08-Workflow-Multinode-Tuning.md`, and the retained TASK-009
host-runtime contract; the run script mirrors the validated
`experiments/2x8-GAAS/phase3d-host-mem-closure/scripts/run_phase3d_host_mem_closure.pbs`
(PBS job 76370.gaas) for container/MPI/orted/pbsdsh launcher, hostfile,
resource request, accounting project, bind mounts, daemon flags, module
set, topology gates, probes, and pre/post health-snapshot pattern, with
the 15-arm Phase-3D sweep replaced by the TASK-2X8-013 Sections 1.6B-1.6F
Phase-4A arm set, the per-arm pre/post HCA counter snapshots, and the
mechanical conditional gates.

## Sequential-sweep behavior and encoded stopping rules

- The arms run one at a time inside the single 2x8 allocation (same nodes
  for all arms; same-allocation comparability, Sections 1.6A, 1.7 rules
  1-2, 10: A0, A1, and any triggered A2 arm all run in one clean
  allocation; if the allocation is lost mid-run, evidence is preserved
  and the job stops rather than silently continuing elsewhere).
- A per-arm environment probe runs immediately before every arm and
  verifies `OMP_NUM_THREADS=4` with `OMP_PLACES`/`OMP_PROC_BIND` unset on
  all 16 ranks plus the arm's exact diagnostic environment (including
  UNSET for everything the mode must not set); a mismatch aborts before
  that arm's launch (control-application failure; Section 1.9).
- An arm command that exits nonzero is preserved evidence that STOPS the
  sweep: its `.status` file is fully written first (together with its
  `.out`/`.err`, post-arm HCA snapshot, and `.hcadelta`), the
  carry-forward log records the abort, the job returns nonzero
  immediately, and no later arm is launched. There is no in-script
  retry; a rerun needs a new `ATTEMPT_TAG` plus human direction (error
  classification per the workflow from the preserved evidence).
- An arm that exits 0 with an invalid verification, an OOM/non-finite
  residual, or a failed settings-echo check is a scientific-correctness
  failure: preserved invalid/boundary evidence (Sections 1.4, 1.8); the
  sweep continues with the next authorized arm and the job exits nonzero
  overall if any arm was invalid. Invalid/OOM/correctness-failing points
  are never promoted or repeated.
- Section 1.9 stop conditions are encoded as hard stops with preserved
  evidence: shape/rank-map mismatch, OMP=4 unverifiable, same-allocation
  comparability lost (nonzero arm exit), HCA/link down or derated
  (pre/post link gates), unexpected transport (tcp-only UCX inter-node
  lanes, NCCL Socket data path, unexpected NCCL backend, bond/RoCE/
  mixed-link warning signature), A2-U/A2-N direction-check failure or
  unresolved ambiguity. Stop conditions never trigger additional
  diagnostics, mitigations, or tuning.
- Evidence guard: before anything runs, the script aborts if any target
  file of this attempt already exists (every arm label x
  {out,err,status,envprobe,timings,hcadelta}, both per-node
  hcapre/hcapost snapshot globs, the rankmap/envmap/carryforward logs,
  and the attempt hostfile). Reruns must use a new `ATTEMPT_TAG`;
  existing evidence is never overwritten. Anti-loop: every arm runs at
  most once per attempt; no extra arms, no alternative GDR-off
  mechanisms, no repeats (Sections 1.6F rule 7, 1.6G).
- If the job is killed mid-arm (e.g. walltime), that arm keeps its
  `.out`/`.err` (and whatever snapshots were completed) but has no
  `.status` file, and later arms were not run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query)
  are taken once around the whole task; per-arm host/device memory
  evidence comes from the application's own memory-report lines in each
  `.out` file.
- The carry-forward log records factual per-arm facts, gate inputs and
  decisions, A2 decisions and direction checks, new error counters, and
  stop conditions. The script declares no winner, computes no
  baseline-relative percentages, and performs no ranking; the strategic
  conclusion is reserved for the Strategic Analyst via `ANALYSE_RESULTS`
  (Sections 1.4E, 1.10-1.11).
- One multinode job at a time (GAAS Blocker 7); no concurrent
  submissions.

## Attempt and output naming

Per-arm attempt ID:
`2x8-GAAS-phase4a-fast-path-characterization_<label>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase4a-fast-path-characterization_a1-diag_v1`), with
`<label>` one of `a0-clean`, `a1-diag`, `a2u-ucx-gdroff`,
`a2n-nccl-gdroff`.

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]`, UCX info/proto logs, and NCCL debug incl. per-channel `via NET/...` graph lines) |
| arm status | `outputs/<attempt>.status` (attempt, experiment, task id/step, arm label/mode/kind, all echoed fixed-control settings with PASS/FAIL settings-echo check, diagnostic marker counts, HCA evidence references, PBS job ID, queue, nodes, verified OMP environment, start/end timestamps + arm wall-clock, exit status, score/LU/IR/constructor/iteration/memory/warning evidence, verification verdict, performance role, evidence paths) |
| per-arm env-probe evidence | `outputs/<attempt>.envprobe` (that arm's raw 16-rank effective-environment probe output; rank lines are also appended, arm-prefixed, to the env-map log) |
| per-arm timing markers | `outputs/<attempt>.timings` (every emitted `<phase> seconds: AVG/MAX/MIN (rank->host)` line, raw) |
| per-arm HCA snapshots | `outputs/2x8-GAAS-phase4a-fast-path-characterization_<label>_<ATTEMPT_TAG>_hca{pre,post}_hca_<node>.log` (both nodes, pre and post) |
| per-arm HCA deltas | `outputs/<attempt>.hcadelta` (per node/HCA TX/RX/wait deltas, shares, max/mean, CV, new error counters) |
| allocation rank-map log | `outputs/2x8-GAAS-phase4a-fast-path-characterization_rankmap_<tag>.log` (16 rank lines with the incoming OMP environment + per-host local-rank-0 topology reports for both allocated nodes) |
| per-arm env-map log | `outputs/2x8-GAAS-phase4a-fast-path-characterization_envmap_<tag>.log` (per-arm 16-rank verification lines) |
| carry-forward log | `outputs/2x8-GAAS-phase4a-fast-path-characterization_carryforward_<tag>.log` (per-arm facts, Section 1.6F gate inputs/decisions, A2 decisions/direction checks, new error counters, stop records, sweep-end/anti-loop state) |
| attempt hostfile | `outputs/2x8-GAAS-phase4a-fast-path-characterization_hostfile_<tag>` (deduplicated `$PBS_NODEFILE` with `slots=8` per node) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase4a-fast-path-characterization_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase4a-fast-path-characterization_<tag>.e` |

Retries use a new tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names.

## Submission (from this directory; authorized under TASK-2X8-013 Section 1.11)

Presubmit node-status check (Section 1.6A): take a `pbsnodes -aSj`
snapshot over the eligible queues and preserve it as submission-side
contention/provenance evidence (e.g.
`outputs/2x8-GAAS-phase4a-fast-path-characterization_<tag>.presubmit_pbsnodes.log`,
local-side); choose the cleanest eligible **same-queue** pair from
`gpu_as`/`gpu_ded` only (idle, 0 jobs, full GPUs/CPUs/memory, matching
`Qlist`), following the validated phase1a/phase3ab/TASK-010/TASK-2X8-011/
012 host-pinned selection pattern. Record any node substitution. One job
at a time; bounded `qstat` monitoring; submit:

```bash
qsub -q <gpu_as|gpu_ded> \
     -l "select=host=<h1>:ncpus=96:ngpus=8:mem=2000GB+host=<h2>:ncpus=96:ngpus=8:mem=2000GB,place=scatter,walltime=02:00:00" \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase4a-fast-path-characterization_v1.o \
     -e outputs/2x8-GAAS-phase4a-fast-path-characterization_v1.e \
     scripts/run_phase4a_fast_path_characterization.pbs
```

## Available baseline provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s; same scored-run protocol (`--skip-tests 0 --monitor-gpu 0`); campaign percentage denominator for 2x8-GAAS comparisons |
| Baseline evidence | `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.{o,e}`; `experiments/2x8-GAAS/baseline/README.md` |
| Retained-control precedent | TASK-2X8-012 phase3d default controls (register-step 2048, DGEMV 0): R0a `6.5311e+06` / R0b `6.5384e+06` / D0a `6.5455e+06` / D0b `6.5579e+06` GFLOP/s, IR 0.29 s, IR/LU 0.037, host 0.004 GB/process, device headroom 2.767 GB/process — PBS job 76370.gaas, `experiments/2x8-GAAS/phase3d-host-mem-closure/` |
| TASK-2X8-012 analysis | `planning/analysis/2x8-gaas-phase3d-host-memory-closure.md` (Phase-3 closure; E12/E13 unblocked) |
| Flag support | `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |
| Phase-0 topology evidence | `scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated |

This task does not rerun the baseline. No run here promotes or replaces
any baseline; baseline-relative percentages belong to the post-task
analysis under `ANALYSE_RESULTS`. A0 is the clean Phase-4 reference for
this allocation, not a new baseline.

## Expected output markers and validation criteria

An arm is valid only when its `outputs/<attempt>.out` contains:

- normal HPL-MxP output: internal tests completed (`--skip-tests 0`:
  GEMM / MPI / NCCL broadcast / pdgemv sections), `****** Matrix Generation ******`,
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
- the settings block echoing the arm's exact effective controls, verified
  by the script's `settings_echo_check`;
- the `Constructor seconds: AVG = ...` line (ordinary setup/registration
  timing evidence; recorded in each `.status`).

Job-level: PBS completes, the `.o`/`.e` files exist, and `.status`
records `exit_status=0`, `verification=PASSED`, and
`settings_echo_check=PASS`. With `--monitor-gpu 0`, GPU-monitoring output
is unavailable by design. An arm with an OOM, `FAILED`, non-finite
residual, or a settings-echo mismatch is preserved as evidence and is not
ranked as a valid performance point (Sections 1.4, 1.8). Do not classify
success from exit status alone.

For the diagnostic arms (A1/A2), additional validation evidence classes
(Section 1.4C/1.4D): UCX log lines proving the variables reached the
ranks (`UCX_* env variables:`), inter-node transport/lane configuration
lines, UCX_PROTO_INFO protocol rows (zero-copy vs staging), NCCL backend
selection (`Using network ...`), per-channel `via NET/IBext_v11/...`
graph lines with the GDRDMA-tagged subset, and any transport
fallback/warning lines — all preserved raw in the arm `.out`/`.err` and
counted into `.status`/carry-forward. Capability messages alone (e.g.
per-HCA "GPU Direct RDMA Enabled") are not treated as transfer-level
evidence; the per-channel/per-protocol rows are.

## Evidence paths

- `outputs/` — per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`,
  per-arm pre/post `_hca_<node>.log` snapshots and `.hcadelta`
  derivations, the attempt-specific deduplicated hostfile, the
  allocation-level rank-map log, the per-arm env-map log, the factual
  carry-forward log, and PBS `.o`/`.e` (including the environment
  provenance records: `module list`, Apptainer version, container MPI
  `mpirun --version`, the container-image identity records, and the
  execution-worktree Git revision)
- `scripts/run_phase4a_fast_path_characterization.pbs` — the Phase-4A run
  script (header documents purpose, working directory, inputs, outputs,
  assumptions, and the encoded stopping/gate rules)
- `scripts/hca_counter_snapshot.sh` — the per-node HCA snapshot helper
