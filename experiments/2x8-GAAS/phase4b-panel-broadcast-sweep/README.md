# 2x8-GAAS phase4b-panel-broadcast-sweep

TASK-2X8-014 Phase 4B Stage A MPI/NCCL panel-broadcast sweep for the
2 GAAS nodes x 8 H200 GPUs HPL-MxP campaign: the Stage-A coarse sweep of
`--use-mpi-panel-broadcast`, executed as sequential scored arms inside ONE
2x8 allocation in which ONLY `--use-mpi-panel-broadcast` varies
scientifically (tasks/TASK-2X8-014.md Sections 1.6A-1.6B). Every arm is a
clean scored arm with no UCX/NCCL diagnostic logging, wrapped in per-arm
pre/post HCA counter snapshots, per-arm 16-rank environment probes, and
timing/rank/memory evidence. After the closing control the script records
the factual C0a/C0b bracket, the 5% stop gate, and the mechanical
Section 1.6C transition record (anchor + fine-window candidates) as facts
only. Stage B (the one fine sweep) and Stage C (finalist communication
diagnostics) are later execution segments under the same approved task,
NOT part of this Stage-A script: the experiment's second execution
segment (attempt tag `v2`, `scripts/run_phase4b_panel_broadcast_stage_bc.pbs`)
executes the Stage-B fine sweep (fixed window 5, 10, 15, 20, 25 from the
Stage-A mechanical transition) plus the mechanically selected Stage-C
diagnostic clone(s) in one same-allocation job; the strategic reading
belongs to the Strategic Analyst via `ANALYSE_RESULTS`.

**Status: Stage A executed (2026-10-02) — all six arms ran in PBS job
`76682.gaas` (completed, exit 0; every arm exit 0 with PASSED verification
and PASS settings echo; no stop condition fired). The mechanical
Section 1.6C transition record selected fine-window candidates
`5 10 15 20 25` (anchor 0). Stage B and Stage C have NOT been executed;
they remain later execution segments under the same approved task. See Run
summary.**

**Prior status (2026-10-02, pre-submission): reviewed local scripts;
presubmit `pbsnodes -aSj` snapshot taken and the same-queue `gpu_as` pair
g14+g15 selected (see Submission). Submission was authorized under the
unchanged Section 1.11 authorization of TASK-2X8-014; submission remained
limited to the exact approved task scope.**

## Stage-B/C run (attempt tags v2 failed, v2.1 retry)

**Status: v2 attempt FAILED at startup (2026-10-02, PBS job `76703.gaas`,
exit 1, 00:00:40 — deterministic workflow defect, no HPL arm ran; see the
failed-attempt record below). Track 1 patch applied; retry under attempt
tag `v2.1` planned.**

This is the second execution segment of TASK-2X8-014, under the same
approved scope as Stage A: ONE same-allocation 2x8 job in which Stage B
runs the fixed fine window and then the mechanical Section 1.6E
selection runs the Stage-C diagnostic clone(s) in the same allocation.
Only `--use-mpi-panel-broadcast` varies scientifically; the Stage-B
arms are clean scored arms, and the Stage-C diagnostic clones are
sanity/mechanism evidence only, never scored.

### Stage-B arm set (Section 1.6D)

| arm | label | `--use-mpi-panel-broadcast` | role |
|---|---|---:|---|
| F0a | `f0a-p0-ctl` | **0** | opening panel=0 control |
| (fine) | `f5-p5` | 5 | fine panel policy 5 |
| (fine) | `f10-p10` | 10 | fine panel policy 10 |
| (fine) | `f15-p15` | 15 | fine panel policy 15 |
| (fine) | `f20-p20` | 20 | fine panel policy 20 |
| (fine) | `f25-p25` | 25 | fine panel policy 25 |
| F0b | `f0b-p0-ctl` | **0** | closing panel=0 control |

Rules encoded in the script (Section 1.6D):

- the fine window `5 10 15 20 25` is FIXED input from the Stage-A v1
  mechanical transition record (Stage-A carry-forward: C0a/C0b spreads
  LU 0.44% / overall 0.43%; tolerances 0.50%; the 5% gate not fired;
  T={0}, S={0}, anchor=0 -> `5 10 15 20 25`); it is not recomputed,
  not reconsidered, and no values are added (Sections 1.6C step 5,
  1.6D);
- the arms run in exactly this order, one scored attempt each;
- no diagnostic logging on any scored arm (verified UNSET on all 16
  ranks);
- F0a/F0b define the fine-stage drift reference;
- a valid but surprising result is preserved and the fixed sequence
  continues;
- a correctness-failing arm is preserved as invalid evidence — the
  fixed sequence is finished if operationally safe, then the script
  stops before Stage C.

### Encoded Stage-B stop gates (before Stage C)

- (a) F0a/F0b bracket unavailable (either control invalid or a
  non-numeric spread) -> stop before Stage C;
- (b) any correctness-failing Stage-B arm (`arms_invalid > 0`) -> the
  fixed sequence completes, then stop before Stage C (invalid arms are
  excluded from candidate selection);
- (c) F0a/F0b bracket exceeds 5% in LU or overall GFLOP/s -> stop
  before Stage C (Sections 1.6D rule 9, 1.7 rule 13);
- (d) no valid nonzero Stage-B policy -> skip Stage C and record that
  fact (Section 1.6E rule 7);
- a nonzero exit of ANY arm stops the sweep immediately with evidence
  preserved (operational hard stop; a rerun needs a new `ATTEMPT_TAG`
  plus human direction).

### Mechanical Section 1.6E selection (in-script facts only)

After F0b, the script records — via the carry-forward log, all numeric
work in awk, no winner declared, and no arms launched beyond the
mechanically selected clone(s):

- the **F0 bracket spreads**: `spread = (hi-lo)/lo*100` for LU GFLOP/s
  and overall GFLOP/s, and the **tolerances**: `max(bracket spread,
  0.5%)` per metric (window-selection tolerances only, not statistical
  confidence intervals);
- the **policy estimates**: policy 0 = the F0a/F0b midpoint (LU and
  overall); the fine policies take their valid arms' values (invalid
  arms excluded with the reason);
- the **LU-competitive set T_B** (LU within the LU tolerance of the
  best) and the **score tie-break set S_B** (within T_B, overall score
  within the score tolerance of the best in T_B);
- the **representative**: the single S_B member, or the median of S_B
  rounded to the nearest 5 percentage points with exact halfway cases
  rounded UP; when the rounded median is not itself an S_B member, the
  S_B member closest to it, tie-broken by higher overall score then
  higher policy — hierarchy: LU primary -> overall score tie-break ->
  median/tie-tolerant representative;
- the **primary diagnostic policy**: the representative when nonzero,
  otherwise the strongest valid nonzero Stage-B policy by the same
  hierarchy (T_nz/S_nz over the nonzero candidates; Section 1.6E rule
  2);
- the **optional secondary diagnostic**: another valid nonzero policy
  at least 25 percentage points from the primary AND within the
  Stage-B LU tolerance of the best LU or within the Stage-B score
  tolerance of the best overall score — the farthest qualifying policy
  wins (overall score as the final tie-break); maximum two clones
  (Section 1.6E rules 3-6).

Factual note: within the fixed fine window 5-25 the maximum separation
between two nonzero policies is 20 percentage points, so a secondary
clone is mechanically impossible for this window — the check is still
encoded and will record `none` with that factual note. TASK-2X8-013
already provides the full panel=0 diagnostic reference; no panel=0
diagnostic clone is rerun (Section 1.6E rule 1). All records are
carry-forward facts prefixed `stageB:` / `selection:`; no winner is
declared.

### Stage-C diagnostic clone contract (Section 1.6F)

Each Stage-C diagnostic clone is one additional arm in the same
allocation:

- the proven 4A diagnostic environment ONLY — `UCX_LOG_LEVEL=info`,
  `UCX_PROTO_INFO=y`, `NCCL_DEBUG=INFO`,
  `NCCL_DEBUG_SUBSYS=INIT,BOOTSTRAP,ENV,NET,GRAPH,P2P,COLL,SHM,TUNING`,
  `NCCL_DEBUG_FILE=/dev/stderr` — forwarded via `mpirun -x` and
  verified to those exact values on all 16 ranks by the per-arm env
  probe (which also verifies `OMP_NUM_THREADS=4`,
  `OMP_PLACES`/`OMP_PROC_BIND` unset,
  `UCX_IB_GPU_DIRECT_RDMA`/`NCCL_NET_GDR_LEVEL` unset, and records the
  effective `UCX_TLS`/`UCX_NET_DEVICES` state);
- the exact same HPL scientific configuration as the selected policy
  (same panel percentage and all fixed controls; settings echo
  verified per arm);
- per-arm pre/post HCA snapshots + deltas on both nodes;
- factual UCX/NCCL marker counts recorded in the clone `.status` and
  the carry-forward log (the raw `.out`/`.err` are authoritative; the
  counts are not LU traffic percentages);
- clones are never scored or ranked (`performance_role` records
  `diagnostic clone`);
- unexpected transport revealed by a clone (inter-node UCX tcp-only
  lanes, NCCL Socket data path, unexpected NCCL backend,
  bond/RoCE/mixed-link warnings) is a recorded Section 1.9 stop
  condition and never triggers additional arms;
- an incomplete diagnostic log is a preserved gap, not a stop (Section
  1.7 rule 15);
- an invalid (exit-0, non-PASSED) primary clone is preserved and the
  secondary is not run;
- after the authorized clone(s), TASK-2X8-014 stops — no Phase 4C
  chunk tuning, no further diagnostics.

### Per-arm evidence (Stage B/C)

Around EVERY executed arm — scored Stage-B arms and diagnostic clones
alike — in the same six-step order as Stage A:

1. **pre-arm HCA snapshot** on both nodes + link gate (same pattern
   and gate as Stage A);
2. **per-arm env probe** with the mode-specific diagnostic
   verification (clean scored arms: all UCX/NCCL diagnostic variables
   UNSET on all 16 ranks; diagnostic clones: the exact 4A diagnostic
   values of the clone contract above);
3. **the HPL-MxP arm** (only `--use-mpi-panel-broadcast` differs
   between arms);
4. **post-arm HCA snapshot** (both nodes) + `.hcadelta` derivation;
5. **`.status` extraction** including the requested/effective panel
   pair and, for clones, the diag marker counts and the `diag_env`
   record;
6. **`.timings`** with every raw `<phase> seconds: AVG/MAX/MIN
   (rank->host)` line, including owning ranks.

Unit note: identical to Stage A — the same `port_xmit_data` unit
question and the same `4294967295` unavailable-counter sentinel (see
the Stage-A per-arm evidence unit note).

### Attempt and output naming (tags v2 / v2.1)

Per-arm attempt ID:
`2x8-GAAS-phase4b-panel-broadcast-sweep_<label>_<tag>`, with `<label>` one
of `f0a-p0-ctl`, `f5-p5`, `f10-p10`, `f15-p15`, `f20-p20`, `f25-p25`,
`f0b-p0-ctl`, `d1-p<pol>-diag`, `d2-p<pol>-diag` and `<tag>` the current
attempt tag (`v2` = the failed startup attempt, evidence preserved;
`v2.1` = the Track 1 retry). The artifact names
follow the same pattern as the v1 table: per-arm
`.out`/`.err`/`.status`/`.envprobe`/`.timings`/`.hcadelta`, the
per-node `hcapre`/`hcapost` snapshot logs, the
rankmap/envmap/carryforward logs and the hostfile with `_<tag>`, and the
PBS `-o`/`-e` names with `_<tag>` at qsub. The pre-run guard refuses to
overwrite any existing file of the attempt — covering the seven
Stage-B labels and the ten potential `d1`/`d2` labels; retries use a
new tag.

### Submission (v2 failed; v2.1 retry)

**Failed attempt record (Track 1, workflow/05):**

- Attempt tag `v2`, PBS job `76703.gaas` (queue gpu_as, project
  hpc_ebslee, host-pinned g14+g15, submitted 2026-10-02T08:56:19+08:00,
  `job_state=F`, `Exit_status=1`, walltime 00:00:40, run_count 1).
- Observed error (PBS `.e`, final line):
  `FATAL: unknown env-probe mode 'scored' (expected clean or diag)`.
- Suspected cause (confirmed by inspection): a deterministic
  workflow-machinery control-flow defect — `run_arm` passes its arm-role
  mode (`scored`) to `run_env_probe`, whose dispatch accepted only
  `clean|diag`. The job aborted at the F0a per-arm env probe, BEFORE any
  HPL arm launched (all preflight gates PASS: topology, rank map 16/2x8,
  incoming-OMP gate, HCA link gate; the F0a pre-arm HCA snapshots were
  captured). No scientific control was applied or varied; no HPL-MxP
  binary ran; same-allocation scientific comparability is unaffected.
- Planned patch (applied): accept `clean|scored` as the clean scored-arm
  environment in both `run_env_probe` dispatch cases (a scored arm uses
  the clean environment; `diag` unchanged); function comment updated.
  `bash -n` PASS. No scientific control, resource, launcher, or transport
  setting changed.
- Preserved evidence (retrieved, SHA-256 verified 8/8):
  `outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_v2.{o,e}`,
  `..._carryforward_v2.log`, `..._envmap_v2.log` (empty — the probe never
  ran), `..._hostfile_v2`, `..._rankmap_v2.log`, and the two
  `..._f0a-p0-ctl_v2_hcapre_hca_hpc-gaas-g{14,15}.log` snapshots.
- Retry: new attempt tag `v2.1` (fresh evidence names; the v2 files are
  never overwritten), fresh presubmit `pbsnodes -aSj` snapshot
  (`..._v2.1.presubmit_pbsnodes.log`), same fixed scientific controls,
  same submission form with `-v "ATTEMPT_TAG=v2.1"` and `_v2.1` PBS
  output names.

A fresh presubmit `pbsnodes -aSj` snapshot over the eligible queues
is preserved as submission-side evidence (the v2 snapshot:
`outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_v2.presubmit_pbsnodes.log`,
2026-10-02T08:56:05+08:00; the v2.1 retry takes its own fresh snapshot);
the cleanest eligible same-queue `gpu_as`/`gpu_ded` pair is selected via
the host-pinned `select` pattern (only eligible idle `gpu_as`/`gpu_ded`
nodes), one multinode job at a time. Exact submission form (queue and
node placeholders; ATTEMPT_TAG and output names use the current attempt
tag):

```bash
qsub -q <gpu_as|gpu_ded> \
     -l select=host=<n1>:ncpus=96:ngpus=8:mem=2000GB+host=<n2>:ncpus=96:ngpus=8:mem=2000GB,place=scatter,walltime=02:00:00 \
     -v "ATTEMPT_TAG=v2" \
     -o outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_v2.o \
     -e outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_v2.e \
     scripts/run_phase4b_panel_broadcast_stage_bc.pbs
```

Submission occurs only under the approved TASK-2X8-014 Section 1.11
authorization; the resource/launcher/transport controls are unchanged
from Stage A (container MPI/orted + the tested bridge, `place=scatter`,
no `mpiprocs`, project `hpc_ebslee`); the job is submitted exactly
once, with bounded monitoring.

## Run summary (Stage A only)

One submitted attempt family (tag `v1`, PBS job `76682.gaas`, submitted
2026-10-02T07:42:35+08:00, queue `gpu_as`, project `hpc_ebslee`, host-pinned
`select=host=hpc-gaas-g14:ncpus=96:ngpus=8:mem=2000GB+host=hpc-gaas-g15:ncpus=96:ngpus=8:mem=2000GB,place=scatter,walltime=02:00:00`;
completed 2026-10-02T07:55:00+08:00, `job_state=F`, `Exit_status=0`,
`resources_used.walltime` 00:12:24, run_count 1). All six arms ran
sequentially in the exact approved order on the same node pair (g14+g15)
with identical fixed controls; only `--use-mpi-panel-broadcast` differed
per arm. Every `.status` records `exit_status=0`, `verification=PASSED`,
`settings_echo_check=PASS`, and matching requested/effective panel values.
No stop condition fired; the job-level recap records
`arms_run=6 arms_exited_nonzero=0 arms_invalid=0 stop_conditions=none`.
Stage B/C were not executed (Stage-A-only script and session segment).

| arm | panel % | normalized residual | verdict | overall GFLOP/s | LU s / LU GFLOP/s | IR s / IR/LU / iters | host mem MAX | device mem MAX | arm wall-clock |
|---|---:|---|---|---|---|---|---|---|---|
| c0a-p0-ctl | 0 | 1.416310E-05 | PASSED | 6.5249e+06 | 7.78 / 6.7666e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB | 00:00:59 |
| c1-p25 | 25 | 1.416310E-05 | PASSED | 5.2281e+06 | 9.78 / 5.3823e+06 | 0.29 / 0.030 / 3 | 0.004 GB | 135.254 GB | 00:01:23 |
| c2-p50 | 50 | 1.416310E-05 | PASSED | 3.7761e+06 | 13.66 / 3.8558e+06 | 0.29 / 0.021 / 3 | 0.004 GB | 135.254 GB | 00:01:30 |
| c3-p75 | 75 | 1.416310E-05 | PASSED | 3.2660e+06 | 15.83 / 3.3256e+06 | 0.29 / 0.018 / 3 | 0.004 GB | 135.254 GB | 00:01:31 |
| c4-p100 | 100 | 1.416310E-05 | PASSED | 3.2885e+06 | 15.72 / 3.3487e+06 | 0.29 / 0.018 / 3 | 0.004 GB | 135.254 GB | 00:01:28 |
| c0b-p0-ctl | 0 | 1.416310E-05 | PASSED | 6.5527e+06 | 7.75 / 6.7963e+06 | 0.29 / 0.037 / 3 | 0.004 GB | 135.254 GB | 00:00:57 |

Per-arm start times (+08:00): c0a 07:43:35, c1 07:45:14, c2 07:47:17,
c3 07:49:27, c4 07:51:38, c0b 07:53:46 (ends in each `.status`). All six
per-arm env probes verified `OMP_NUM_THREADS=4` with
`OMP_PLACES`/`OMP_PROC_BIND` unset and every UCX/NCCL diagnostic variable
UNSET on all 16 ranks (`diag_ok` 16/16 on every field, both arms' pattern
x6), plus `ucx_tls=UNSET ucx_net_devices=UNSET` on all 16 ranks of every
arm. Each arm `.err` contains only the known benign bridge `cmd=[...]`
diagnostic and one `unknown groupid` warning; per-arm warning-marker
counts are 0 (out and err) for all six arms.

### Stage-A control bracket and mechanical transition record (Section 1.6C; from the carry-forward log)

~~~text
stageA_bracket C0a/C0b:
  LU      = 6.7666e+06 / 6.7963e+06  symmetric spread = 0.44 %
  overall = 6.5249e+06 / 6.5527e+06  symmetric spread = 0.43 %
  (spread = (hi-lo)/lo*100; both below the 0.5% floor)
tolerances (max(bracket spread, 0.5%)):
  lu_transition_tolerance_pct    = 0.50
  score_transition_tolerance_pct = 0.50
5% stop gate: NOT FIRED (0.44% / 0.43%)
policy estimates (policy 0 = C0a/C0b midpoint):
  0   -> LU 6.78145e+06 / overall 6.5388e+06  (midpoint)
  25  -> LU 5.3823e+06  / overall 5.2281e+06
  50  -> LU 3.8558e+06  / overall 3.7761e+06
  75  -> LU 3.3256e+06  / overall 3.2660e+06
  100 -> LU 3.3487e+06  / overall 3.2885e+06
LU_competitive_set T = 0   (LU_best = 6.78145e+06, lu_tolerance 0.50%)
score_tiebreak_set  S = 0   (score_best_within_T = 6.5388e+06, 0.50%)
anchor = 0  ->  fine_window_candidates = 5 10 15 20 25
~~~

Stage B (F0a control, candidates 5/10/15/20/25 ascending, F0b control)
and Stage C were NOT executed; they are later execution segments under
TASK-2X8-014. The strategic reading of the coarse shape belongs to the
Strategic Analyst via `ANALYSE_RESULTS`.

### Fabric summary (factual; per-arm `.hcadelta` files are authoritative)

Per-arm pre/post HCA snapshots were captured on both nodes around every
arm (24 snapshot logs + 6 delta files). No nonzero
error/discard/recovery counter delta appeared in any arm on either node.
Factual node-total pattern: the two panel-0 control arms move
~82.80e9/~59.05e9 raw TX/RX (g14) and ~59.04e9/~82.81e9 (g15), while all
four nonzero-policy arms move ~105.3-105.5e9/~50.7-50.9e9 (g14) and
~50.7e9/~105.3-105.5e9 (g15) — i.e., every nonzero policy shifts the
inter-node traffic shape toward more g14 TX / less g14 RX relative to the
panel-0 controls. Full per-HCA TX/RX shares, `port_xmit_wait` deltas,
max/mean, and CV values are preserved in each `.hcadelta`; interpretation
belongs to the Strategic Analyst.

## Structure

- `scripts/run_phase4b_panel_broadcast_stage_a.pbs` — single
  same-allocation Stage-A run script: the six coarse arms in the exact
  approved order, per-arm evidence files, per-arm pre/post per-node HCA
  snapshots, the factual Stage-A bracket + 5% stop gate + mechanical
  Section 1.6C transition record; attempt tag comes from the
  `ATTEMPT_TAG` environment at submission
- `scripts/run_phase4b_panel_broadcast_stage_bc.pbs` — single
  same-allocation Stage-B/C run script (second execution segment,
  attempt tags v2/v2.1): the seven Stage-B arms in the exact approved order,
  the factual F0 bracket + tolerances + stop gates, the mechanical
  Section 1.6E selection, and the Stage-C diagnostic clone(s); per-arm
  evidence files, per-arm pre/post per-node HCA snapshots, and the
  factual carry-forward records; attempt tag comes from the
  `ATTEMPT_TAG` environment at submission
- `scripts/hca_counter_snapshot.sh` — host-side per-node HCA
  counter/link-state snapshot helper invoked on every allocated node via
  `pbsdsh --` (lock-guarded once per node; this experiment's copy of the
  validated 4A helper, with the `.p4b` lock prefix; the same validated
  resource-alloc read pattern over `/sys/class/infiniband`)
- `outputs/` — per-arm application `.out`/`.err`/`.status` evidence,
  per-arm `.envprobe` raw env-probe evidence, per-arm `.timings`
  timing-marker extracts, per-arm pre/post `_hca_<node>.log` snapshots and
  `.hcadelta` derivations, the attempt-specific deduplicated hostfile, the
  allocation-level rank-map / per-arm env-map / carry-forward logs, and
  PBS `.o`/`.e` job evidence (tracked, never overwritten; every rerun gets
  a new attempt tag; all runtime artifacts live beneath `outputs/` —
  nothing is written to the experiment root)

## Arm set (TASK-2X8-014 Section 1.6B; Stage A only)

| arm | label | `--use-mpi-panel-broadcast` | role |
|---|---|---:|---|
| C0a | `c0a-p0-ctl` | **0** | opening retained control |
| C1 | `c1-p25` | 25 | mostly NCCL / lower mixed policy |
| C2 | `c2-p50` | 50 | mixed policy |
| C3 | `c3-p75` | 75 | upper mixed / mostly MPI |
| C4 | `c4-p100` | 100 | MPI endpoint |
| C0b | `c0b-p0-ctl` | **0** | closing retained control |

Rules encoded in the script (Section 1.6B):

- the arms run in exactly this order, one scored attempt per arm;
- the fixed coarse set is completed even if intermediate values decline
  (no early stop because an endpoint or neighboring value is slower);
- no additional panel values are added during Stage A (no 10, 20, 30, 40,
  60, 70, 80, 90, or any other value);
- NO diagnostic logging on any scored arm (rule 4): the per-arm env probe
  verifies all UCX/NCCL diagnostic variables UNSET on all 16 ranks;
- HCA counters and normal timing/rank evidence are captured around every
  arm (rule 5);
- C0a/C0b define the local drift reference (rule 6);
- a valid but surprising result is preserved and the fixed set continues
  (rule 7);
- a correctness failure/non-finite residual in any coarse arm is preserved
  as invalid evidence; the already authorized coarse set is finished if
  the allocation and hardware remain healthy, then the script stops before
  adaptive Stage B (rule 8) — no refinement around a correctness-failing
  policy.

## Fixed scientific controls (identical for every arm; only the panel value varies)

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
--use-mpi-panel-broadcast <per-arm value: 0 / 25 / 50 / 75 / 100>  (the ONLY scientific control that varies)
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
settings for all fixed controls plus the requested/effective panel value
with a PASS/FAIL `settings_echo_check`; a mismatch is
control-application failure evidence: the arm is preserved but marked not
a valid performance point, and the mismatch is flagged in the
carry-forward log.

Configuration specified by the Strategic Analyst and approved by the
Human Leader in tasks/TASK-2X8-014.md Sections 1.2, 1.6A-1.6B;
Codex/workers did not derive, optimize, or modify it. The prohibited list
of TASK-2X8-014 Section 1.6G is enforced by construction: `--ucx-affinity`
stays omitted/automatic, `UCX_TLS`/`UCX_NET_DEVICES` are never set,
`--u-panel-chunk-nbs` stays 8 via the package default, no
`--mpi-use-mpi`/`--use-host-mpi`, no N/NB/grid/order/affinity/OpenMP/
residency/precision/kernel/scheduling changes, no historical
HCA/bond/UCC/rendezvous mitigations, no microbenchmark ladder, no
profiler, no Phase 4C chunk tuning, no second fine sweep, and no panel
values beyond the fixed Stage-A set — the script contains no such
controls.

## Per-arm command

Identical for every arm except the requested panel value, launched inside
the PBS job through the validated Approach-1 container launcher with the
retained TASK-009 host-runtime `-x` forwarding (only the
`--use-mpi-panel-broadcast` argument differs between arms; no diagnostic
`-x` variables exist on any Stage-A arm):

```bash
apptainer exec --nv \
  -B /opt/pbs:/opt/pbs \
  -B /var/spool/pbs:/var/spool/pbs \
  -B "$REPO_ROOT":"$REPO_ROOT" \
  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif \
  /usr/local/mpi/bin/mpirun -np 16 \
    --hostfile "$PWD/outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_hostfile_<ATTEMPT_TAG>" \
    --mca plm_rsh_agent multi-node-test/rsh_pbsdsh_container.sh \
    --mca plm_rsh_no_tree_spawn 1 \
    --mca plm_rsh_num_concurrent 1 \
    --mca routed direct \
    -x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS \
    --bind-to none \
    /workspace/hpl-mxp.sh \
      --n 429056 --nb 3072 --nprow 4 --npcol 4 --nporder row \
      --gpu-affinity 0:1:2:3:4:5:6:7 --sloppy-type FP16 \
      --use-mpi-panel-broadcast "$PANEL_PCT" --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --fill-device-buffer-size 3048 \
      --cuda-host-register-step 2048 --call-dgemv-with-multiple-threads 0 \
      --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

`OMP_NUM_THREADS=4` is exported in the job shell (and verified on all 16
ranks by the per-arm env probe) before the launch; application
stdout/stderr are redirected to that arm's `.out`/`.err` evidence file.

## Per-arm evidence (TASK-2X8-014 Section 1.4A/1.4B)

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
   `OMP_PLACES`/`OMP_PROC_BIND` UNSET, and the clean-arm diagnostic
   prohibition — `UCX_LOG_LEVEL`, `UCX_PROTO_INFO`, `NCCL_DEBUG`,
   `NCCL_DEBUG_SUBSYS`, `NCCL_DEBUG_FILE`, `UCX_IB_GPU_DIRECT_RDMA`, and
   `NCCL_NET_GDR_LEVEL` all UNSET on all 16 ranks — plus the recorded
   effective `UCX_TLS`/`UCX_NET_DEVICES` state (expected
   unset/automatic; recorded, not gated).
3. **the HPL-MxP arm** (only `--use-mpi-panel-broadcast` differs between
   arms; identical `-x` set: `PATH`, `LD_LIBRARY_PATH`,
   `OMP_NUM_THREADS`).
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
   counts, settings echo, and the requested/effective panel pair
   (`requested_panel_pct` / `effective_panel_pct`, recorded in every
   `.status`). The raw `.timings` file preserves every emitted
   `<phase> seconds: AVG/MAX/MIN (rank->host)` line (Constructor, GEMM,
   MPI/NCCL U and L2 broadcast, pdgemv, LU, Iterative Solver, and the
   rest), including owning ranks.

Unit note: `port_xmit_data`/`port_rcv_data` raw deltas are recorded
as-is; GAAS precedent (resource-alloc) treats the sysfs values as byte
counts while IBTA defines PortXmitData/PortRcvData in 4-octet units, so a
x4 octet column is also provided. The unit question is flagged for the
Strategic Analyst, not resolved here. `port_xmit_wait=4294967295` is
treated as the unavailable-counter sentinel seen in prior GAAS evidence.

## Stage-A bracket and transition record (mechanical; in-script facts only)

After C0b, the script records — via the carry-forward log, every line
prefixed `transition:`, all numeric work in awk, no winner declared, and
no further arms launched:

- the **C0a/C0b bracket spreads**: `spread = (hi-lo)/lo*100` for LU
  GFLOP/s and overall GFLOP/s (the factual local drift reference; the
  phase3d `spread_pct` calculation reused verbatim);
- the **transition tolerances**: `max(bracket spread, 0.5%)` per metric —
  window-selection tolerances only, not statistical confidence intervals
  (Section 1.6C step 2);
- the **5% stop gate**: if the identical-control bracket exceeds 5% in LU
  GFLOP/s or overall GFLOP/s, the script records
  `STOP_GATE_FIRED`, adds the `stageA_bracket_gt5pct` stop condition, and
  stops before Stage B (Sections 1.6C step 2 / 1.7 rule 13);
- the **policy estimates**: policy 0 = the C0a/C0b midpoint (LU and
  overall); policies 25/50/75/100 = their arm's values when usable
  (otherwise excluded with the reason); one `policy_estimate` line per
  included policy;
- the **LU-competitive set T** (LU within the LU tolerance of the best)
  and the **score tie-break set S** (within T, overall score within the
  score tolerance of the best in T) — Sections 1.6C steps 3-4;
- the **anchor**: the single S member, or the median of S's policy values
  rounded to the nearest 5 percentage points with exact halfway cases
  rounded UP (e.g. 37.5 -> 40);
- the **fine window candidates**: anchor <= 15 -> `5 10 15 20 25`;
  anchor >= 85 -> `80 85 90 95 100`; otherwise
  `anchor-15 anchor-10 anchor-5 anchor anchor+5 anchor+10 anchor+15`
  (Section 1.6C step 5; policy 0 is supplied separately by the Stage-B
  F0a/F0b controls and is not a candidate).

Defensive NOT_COMPUTABLE handling: if the C0a/C0b bracket is unavailable
(either control arm invalid or missing numeric LU/score evidence) or a
spread is non-numeric, the script records the fact, adds the
`stageA_transition_not_computable` stop condition, and stops before
adaptive Stage B; if no usable nonzero coarse policy exists, it records
`stageA_no_valid_nonzero_policy` and stops before Stage B. The record is
mechanical and factual only; Stage B is NOT executed by this job (Stage
B/C are later execution segments under TASK-2X8-014).

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ncpus=96:ngpus=8:mem=2000GB` (no `mpiprocs`) |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `02:00:00` for six ~1-min full-fill clean arms + per-arm probes + per-arm pre/post HCA snapshots on both nodes (the phase3d 15-arm sweep used 00:20:40 of 02:00:00, PBS job 76370.gaas); may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0); size/mtime/sha256 recorded in the PBS `.o` (provenance if available, non-fatal) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS` (no diagnostic `-x` variables on any Stage-A arm), `--bind-to none` |
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
(PBS job 76370.gaas) and
`experiments/2x8-GAAS/phase4a-fast-path-characterization/scripts/run_phase4a_fast_path_characterization.pbs`
(PBS job 76519.gaas) scripts for container/MPI/orted/pbsdsh launcher,
hostfile, resource request, accounting project, bind mounts, daemon
flags, module set, topology gates, probes, and pre/post health-snapshot
pattern, with the 15-arm Phase-3D sweep / 4-arm Phase-4A characterization
replaced by the TASK-2X8-014 Section 1.6B Stage-A arm set, the per-arm
requested panel value, and the mechanical bracket/stop-gate/transition
records.

## Sequential-sweep behavior and encoded stopping rules

- The arms run one at a time inside the single 2x8 allocation (same nodes
  for all arms; same-allocation comparability, Sections 1.6A, 1.7 rules
  1-2, 10: all six Stage-A arms run in one clean allocation; if the
  allocation is lost mid-run, evidence is preserved and the job stops
  rather than silently continuing elsewhere).
- A per-arm environment probe runs immediately before every arm and
  verifies `OMP_NUM_THREADS=4` with `OMP_PLACES`/`OMP_PROC_BIND` unset on
  all 16 ranks plus the clean-arm diagnostic prohibition (all UCX/NCCL
  diagnostic variables UNSET on all 16 ranks); a mismatch aborts before
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
  failure: preserved invalid/boundary evidence (Sections 1.4A, 1.6B rule
  8, 1.8); the sweep continues with the next authorized arm and the job
  exits nonzero overall if any arm was invalid. Invalid/OOM/
  correctness-failing points are never promoted or repeated; after the
  fixed coarse set completes, the script stops before adaptive Stage B
  when the bracket/transition rules so indicate.
- Section 1.9 stop conditions are encoded as hard stops with preserved
  evidence: shape/rank-map mismatch, OMP=4 unverifiable, same-allocation
  comparability lost (nonzero arm exit), HCA/link down or derated
  (pre/post link gates), the >5% identical-control bracket, an
  unavailable/non-numeric C0a/C0b bracket, or no valid nonzero coarse
  policy. Stop conditions never trigger additional arms, diagnostics,
  mitigations, or tuning.
- Evidence guard: before anything runs, the script aborts if any target
  file of this attempt already exists (every arm label x
  {out,err,status,envprobe,timings,hcadelta}, both per-node
  hcapre/hcapost snapshot globs, the rankmap/envmap/carryforward logs,
  and the attempt hostfile). Reruns must use a new `ATTEMPT_TAG`;
  existing evidence is never overwritten. Anti-loop: every arm runs at
  most once per attempt; no extra arms, no additional panel values, no
  repeats (Sections 1.6B, 1.6G).
- If the job is killed mid-arm (e.g. walltime), that arm keeps its
  `.out`/`.err` (and whatever snapshots were completed) but has no
  `.status` file, and later arms were not run.
- Pre/post hardware-health snapshots (`nvidia-smi topo -m` + GPU query)
  are taken once around the whole task; per-arm host/device memory
  evidence comes from the application's own memory-report lines in each
  `.out` file.
- The carry-forward log records factual per-arm facts, the bracket
  spreads, tolerances, stop-gate and transition records, new error
  counters, and stop conditions. The script declares no winner, computes
  no baseline-relative percentages, and performs no ranking; the
  strategic conclusion is reserved for the Strategic Analyst via
  `ANALYSE_RESULTS` (Sections 1.4D, 1.10-1.11).
- One multinode job at a time (GAAS Blocker 7); no concurrent
  submissions.

## Attempt and output naming

Per-arm attempt ID:
`2x8-GAAS-phase4b-panel-broadcast-sweep_<label>_<ATTEMPT_TAG>` (e.g.
`2x8-GAAS-phase4b-panel-broadcast-sweep_c1-p25_v1`), with `<label>` one
of `c0a-p0-ctl`, `c1-p25`, `c2-p50`, `c3-p75`, `c4-p100`, `c0b-p0-ctl`.

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` diagnostics) |
| arm status | `outputs/<attempt>.status` (attempt, experiment, task id/step, arm label/requested+effective panel values/stage-A arm kind, all echoed fixed-control settings with PASS/FAIL settings-echo check, HCA evidence references, PBS job ID, queue, nodes, verified OMP environment, start/end timestamps + arm wall-clock, exit status, score/LU/IR/constructor/iteration/memory/warning evidence, verification verdict, performance role, evidence paths) |
| per-arm env-probe evidence | `outputs/<attempt>.envprobe` (that arm's raw 16-rank effective-environment probe output; rank lines are also appended, arm-prefixed, to the env-map log) |
| per-arm timing markers | `outputs/<attempt>.timings` (every emitted `<phase> seconds: AVG/MAX/MIN (rank->host)` line, raw) |
| per-arm HCA snapshots | `outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_<label>_<ATTEMPT_TAG>_hca{pre,post}_hca_<node>.log` (both nodes, pre and post) |
| per-arm HCA deltas | `outputs/<attempt>.hcadelta` (per node/HCA TX/RX/wait deltas, shares, max/mean, CV, new error counters) |
| allocation rank-map log | `outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_rankmap_<tag>.log` (16 rank lines with the incoming OMP environment + per-host local-rank-0 topology reports for both allocated nodes) |
| per-arm env-map log | `outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_envmap_<tag>.log` (per-arm 16-rank verification lines) |
| carry-forward log | `outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_carryforward_<tag>.log` (per-arm facts, Stage-A bracket/stop-gate/transition records, new error counters, stop records, sweep-end/anti-loop state) |
| attempt hostfile | `outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_hostfile_<tag>` (deduplicated `$PBS_NODEFILE` with `slots=8` per node) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_<tag>.e` |

Retries use a new tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names.

## Submission (executed 2026-10-02, under the approved TASK-2X8-014 Section 1.11 authorization)

Submission was authorized under the unchanged Section 1.11 authorization of
TASK-2X8-014; no new approval was needed, and submission remained limited
to the exact approved task scope (Stage A only in this segment).

Presubmit node-status check (Section 1.6A), taken 2026-10-02T07:42:08+08:00:
the `pbsnodes -aSj` snapshot over the eligible queues is preserved as
submission-side contention/provenance evidence at
`outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_v1.presubmit_pbsnodes.log`.
Selected same-queue `gpu_as` pair: `hpc-gaas-g14` + `hpc-gaas-g15`.
Factual selection basis, from the snapshot: g14 and g15 were both `free`
with 0 jobs, 8/8 GPUs, 100/100 ncpus, and full 2tb/2tb memory, and both
carry `Qlist = gpu_as,gpu_ppu`; this is the same host-pinned allocation
pair as the validated Phase-4A clean reference (PBS job 76519.gaas),
preserving same-pair fabric context with the 4A reference evidence; the
remaining idle full-GPU nodes were off-limits by queue scope (g16/g17 are
`gpu_aisg`) or singleton (`gpu_ded` had exactly one eligible free
full-GPU node, g22, so no same-queue `gpu_ded` pair existed; g12, the
third clean `gpu_as` node, was not needed for a pair). No user jobs were
running at submission (one job at a time).

Exact approved host-pinned submission command (`ATTEMPT_TAG=v1`, walltime
`02:00:00`; submitted exactly once as PBS job `76682.gaas` on 2026-10-02,
see Run summary):

```bash
qsub -q gpu_as \
     -l select=host=hpc-gaas-g14:ncpus=96:ngpus=8:mem=2000GB+host=hpc-gaas-g15:ncpus=96:ngpus=8:mem=2000GB,place=scatter,walltime=02:00:00 \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_v1.o \
     -e outputs/2x8-GAAS-phase4b-panel-broadcast-sweep_v1.e \
     scripts/run_phase4b_panel_broadcast_stage_a.pbs
```

Monitoring was bounded (qstat checks at ~2, ~5, ~8, ~11, and ~14 min after
submission; final-state fetch `qstat -x -f` after completion). No retries;
the attempt completed with `Exit_status=0`. All 66 remote output files
were retrieved via `scp` and verified byte-identical by SHA-256 (66/66;
the only manifest difference during verification was a locale sort-order
artifact with zero hash mismatches). Local-only submission-side evidence:
the presubmit `pbsnodes -aSj` snapshot and the job metadata recorded
above.

## Available baseline provenance

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, PASSED, exit 0, overall `4.8037e+06` GFLOP/s; same scored-run protocol (`--skip-tests 0 --monitor-gpu 0`); campaign percentage denominator for 2x8-GAAS comparisons |
| Baseline evidence | `experiments/2x8-GAAS/baseline/outputs/2x8-GAAS-baseline_n700k_v1.{o,e}`; `experiments/2x8-GAAS/baseline/README.md` |
| Retained-control precedent | TASK-2X8-012 phase3d default controls (register-step 2048, DGEMV 0): R0a `6.5311e+06` / R0b `6.5384e+06` / D0a `6.5455e+06` / D0b `6.5579e+06` GFLOP/s, IR 0.29 s, IR/LU 0.037, host 0.004 GB/process, device headroom 2.767 GB/process — PBS job 76370.gaas, `experiments/2x8-GAAS/phase3d-host-mem-closure/` |
| TASK-2X8-012 analysis | `planning/analysis/2x8-gaas-phase3d-host-memory-closure.md` (Phase-3 closure; E12/E13 unblocked) |
| Flag support | `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` |
| Phase-0 topology evidence | `scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated |
| Phase-4A clean reference | overall `6.5324e+06` GFLOP/s, LU `7.77` s / `6.7741e+06` LU GFLOP/s, IR `0.29` s (PASSED) — PBS job 76519.gaas, `experiments/2x8-GAAS/phase4a-fast-path-characterization/` (the validated 4A predecessor of this experiment; TASK-2X8-013) |

This task does not rerun or promote any baseline. No run here promotes or
replaces any baseline; baseline-relative percentages belong to the
post-task analysis under `ANALYSE_RESULTS`. C0a/C0b are in-sweep
controls, not baselines.

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
  by the script's `settings_echo_check` including this arm's
  `--use-mpi-panel-broadcast` value;
- the `Constructor seconds: AVG = ...` line (ordinary setup/registration
  timing evidence; recorded in each `.status`).

Job-level: PBS completes, the `.o`/`.e` files exist, and `.status`
records `exit_status=0`, `verification=PASSED`,
`settings_echo_check=PASS`, and matching
`requested_panel_pct`/`effective_panel_pct`. With `--monitor-gpu 0`,
GPU-monitoring output is unavailable by design. An arm with an OOM,
`FAILED`, non-finite residual, or a settings-echo mismatch is preserved
as evidence and is not ranked as a valid performance point (Sections
1.4A, 1.8). Do not classify success from exit status alone.

## Evidence paths

- `outputs/` — per-arm `.out`/`.err`/`.status`/`.envprobe`/`.timings`,
  per-arm pre/post `_hca_<node>.log` snapshots and `.hcadelta`
  derivations, the attempt-specific deduplicated hostfile, the
  allocation-level rank-map log, the per-arm env-map log, the factual
  carry-forward log (including the Stage-A bracket / stop-gate /
  transition records), and PBS `.o`/`.e` (including the environment
  provenance records: `module list`, Apptainer version, container MPI
  `mpirun --version`, the container-image identity records, and the
  execution-worktree Git revision)
- `scripts/run_phase4b_panel_broadcast_stage_a.pbs` — the Stage-A run
  script (header documents purpose, working directory, inputs, outputs,
  assumptions, and the encoded stopping/gate rules)
- `scripts/hca_counter_snapshot.sh` — the per-node HCA snapshot helper
