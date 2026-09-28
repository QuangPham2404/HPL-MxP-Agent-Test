# 2x8-GAAS phase3ab-host-runtime

TASK-009 coordinated Phase-3A/3B host-runtime sweep for the 2 GAAS nodes x 8
H200 GPUs HPL-MxP campaign: one bounded same-allocation experiment that
resolves the E19 CPU-affinity x OpenMP host-runtime group at the retained
TASK-008 operating point `N=429056`, `NB=3072`, `4x4 row`, identity GPU
affinity, memory affinity omitted, UCX affinity omitted/automatic and the
fixed retained scientific controls (tasks/TASK-009.md Section 1.2). Only the
host-runtime controls explicitly authorized by TASK-009 vary, in three
sequential **steps** (the task's word; the overall campaign remains in
Phase 3):

```text
Step A — OMP_NUM_THREADS sweep: 4, 6, 8, 10, 12 (once each)
        ↓ bounded 2.0% plateau carry-forward (<= 2 thread counts)
Step B — CPU-affinity matrix per carried T: free / loose / medium / strict
        ↓ bounded carry-forward (<= 2 total host candidates)
Step C — OMP_PLACES x OMP_PROC_BIND matrix per carried host candidate
```

**Status (2026-09-28): prepared; v1 attempt not yet executed.** TASK-009 is
`EXECUTING / codex`. Any rerun must use a new `ATTEMPT_TAG`, pass
`-q gpu_as` or `-q gpu_ded` (the only authorized queues) with project
`hpc_ebslee`, and never overwrite existing evidence.

## Structure

- `scripts/run_phase3ab_host_runtime.pbs` — single reusable sweep PBS script
  (all Step A/B/C arms sequentially in one allocation; Phase-0 topology
  consistency gates — a mother-node gate from the job shell plus a per-host
  two-host gate inside the single 16-rank rank-map probe — before scored
  work; an incoming-OpenMP-environment gate; a per-arm 16-rank
  effective-OMP environment probe before every scored launch; per-arm
  evidence files; the attempt tag comes from the `ATTEMPT_TAG` environment
  at submission and is validated against a conservative filename-safe
  pattern before use; environment provenance records — `module list`,
  Apptainer version, container MPI `mpirun --version`, and the
  execution-worktree Git revision — are echoed to the PBS `.o`)
- `outputs/` — per-arm application `.out`/`.err`/`.status` evidence, the
  allocation-level rank-map log (16 rank lines with the incoming OMP
  environment plus the per-host local-rank-0 topology reports for both
  allocated nodes), the per-arm effective-OMP env-map log, the mechanical
  carry-forward decision log, and PBS `.o`/`.e` job evidence (tracked,
  never overwritten; every rerun gets a new attempt tag)

## Fixed scientific controls (identical for all arms)

```
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row

--gpu-affinity 0:1:2:3:4:5:6:7
--mem-affinity omitted
--ucx-affinity omitted (automatic/default device policy; retained TASK-008 outcome)

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
Leader in tasks/TASK-009.md Section 1.2; Codex/workers did not derive,
optimize, or modify it. All controls not listed (e.g.
`--fill-device-buffer-size`, `--Anq-device`, U-panel chunking, DGEMV
partitioning, precision, GEMM kernel, host registration) retain the same
installed package/default behavior used by the retained campaign control,
consistently for all arms.

Deferred controls are NOT used anywhere in this sweep (tasks/TASK-009.md
Section 1.10 prohibited list): `--mem-affinity`, `--ucx-affinity`,
`--ucx-tls`/`UCX_TLS`, panel-broadcast/MPI/NCCL fallback and chunk policy,
DGEMV, `N`/`NB`/grid/order, fill-device/residency/buffer, precision, GEMM
kernel, and TRSM/factorization/separate-stream scheduling. Memory-affinity
and E20/DGEMV decisions are deferred to post-task strategic analysis
(tasks/TASK-009.md Section 1.9).

## Host-runtime controls and environment propagation

TASK-009 varies exactly three host-runtime control groups, one per step:

| step | control | values |
|---|---|---|
| A | `OMP_NUM_THREADS` | 4, 6, 8, 10, 12 (OMP=8 is the retained campaign control but receives no automatic promotion) |
| B | `--cpu-affinity` | free (omitted) / loose / medium / strict, derived per carried T from the live cpuset |
| C | `OMP_PLACES` x `OMP_PROC_BIND` | default control (both omitted, expected effective `sockets`/`TRUE`) plus `sockets`x{CLOSE,SPREAD} and `cores`x{TRUE,CLOSE,SPREAD} |

`OMP_PLACES` and `OMP_PROC_BIND` are omitted from the job environment for
Step A, Step B and the C0 control policy, so the installed v26.02 launcher's
package defaults `OMP_PROC_BIND=TRUE` and `OMP_PLACES=sockets` remain the
effective placement policy exactly as in TASK-004..TASK-008 (captured
launcher in `todo.md`).

**Environment-propagation contract (operational design, documented for the
analyst).** With this launcher combination, remote-node ranks inherit the
remote orted/container environment and receive ONLY variables explicitly
forwarded through `mpirun -x` (multi-node-test/GAAS_MULTINODE_SETUP.md
"Blocker E": the `--nv` library path was absent from remote ranks until
`-x PATH -x LD_LIBRARY_PATH` was added; Open MPI documents that remote
processes inherit the remote daemon's environment, not mpirun's). Since
`OMP_NUM_THREADS` is TASK-009's Step-A control variable, every scored arm
(a) re-exports the selected thread count in the job shell AFTER the
module/job environment is established (TASK-009 Section 1.3: PBS has
previously populated/clobbered `OMP_NUM_THREADS` with the allocation CPU
count) and (b) forwards it with `-x OMP_NUM_THREADS` so the selected value
is effective on ALL 16 ranks; Step-C explicit arms additionally forward
`-x OMP_PLACES -x OMP_PROC_BIND`. The `-x` mechanism is the validated
environment-propagation channel of the retained launch contract (already
used for `PATH`/`LD_LIBRARY_PATH`); no daemon flag, launcher, bridge,
resource or bind-mount change is involved.

Factual consequence recorded for the Strategic Analyst (mechanical
observation, not interpretation): in the TASK-001..TASK-008 2x8 launches,
`OMP_NUM_THREADS` was exported only in the mother-node job shell and was
NOT among the `-x`-forwarded variables, so under the documented Blocker-E
propagation semantics the remote node's 8 ranks did not receive the
exported value. TASK-009's Step-A arms therefore establish the selected
thread count on all 16 ranks uniformly, which is not literally identical to
the historical control state; the incoming (pre-override) per-rank values
are captured as evidence by the rank-map probe, and each arm's effective
values are verified per rank by the env probe. The post-task Strategic
Analyst should weigh this when interpreting Step-A scores against
TASK-007/TASK-008 history under E19.

**Gates and probes (lightweight, no workload, no profiling).**

- The allocation-level rank-map probe (before any scored arm) records, for
  every rank, the incoming `OMP_NUM_THREADS`/`OMP_PLACES`/`OMP_PROC_BIND`
  values with no override in effect. Gate: any rank reporting an incoming
  `OMP_PLACES` or `OMP_PROC_BIND` value aborts before scored work — the
  "omitted" placement-control policy could not be guaranteed on all ranks
  (TASK-009 Section 1.13). Incoming `OMP_NUM_THREADS` values are recorded
  as evidence only; every arm overrides them deterministically.
- A per-arm 16-rank environment probe runs immediately before every scored
  launch with that arm's exact `-x` set and verifies all 16 ranks report
  the intended `OMP_NUM_THREADS` (and `OMP_PLACES`/`OMP_PROC_BIND` values,
  or their absence for omitted-policy arms). A mismatch aborts before that
  arm's scored launch (control-application failure; evidence preserved).
  This is the TASK-009 Section 1.3/1.8 "effective OpenMP values seen inside
  the execution environment" evidence.

## Step A — OMP_NUM_THREADS sweep (TASK-009 Section 1.5)

Controls per Section 1.5A: `--cpu-affinity` omitted, `--mem-affinity`
omitted, `--ucx-affinity` omitted, `OMP_PLACES`/`OMP_PROC_BIND` omitted.
Only `OMP_NUM_THREADS` varies. Arms: `a-omp4`, `a-omp6`, `a-omp8`,
`a-omp10`, `a-omp12` — one scored attempt each, no additions, no repeats of
valid points. Before the sweep the script records the allocated cpuset on
both nodes (topology gates) and confirms the five thread counts are
executable without changing the approved resource shape (the free CPU
policy leaves all 96 scheduled CPUs per node available; 12 << 96).

Mechanical carry-forward (Section 1.5D, implemented in the script and
logged): the highest valid score defines a plateau of valid candidates
within 2.0% (score >= leader x 0.98); carry one count when the leader is
>2.0% above every other valid candidate, otherwise carry the numerical
leader plus one neighboring/lower-overhead plateau member (prefer a
neighbor at leader +/- 2; ties prefer the smaller thread count; if no
neighbor is in the plateau, the best remaining plateau member), at most two
counts. Invalid candidates cannot be promoted; OMP=8 receives no automatic
promotion; valid points are never repeated and no new counts are added.

## Step B — CPU-affinity matrix (TASK-009 Section 1.6)

For each Step-A carried T, with the thread count fixed and
`OMP_PLACES`/`OMP_PROC_BIND` still omitted:

- **B0 free control**: `--cpu-affinity` omitted — identical configuration
  to the Step-A arm at T, so the Step-A score is REUSED as the same-T free
  control and B0 is not rerun (identical controls per Sections 1.5A/1.6B;
  1.6C collapse principle; 1.5D rule 8 forbids repeating valid points).
- **B1 loose**: each rank gets the whole CPU set of the NUMA domain of its
  GPU (shared same-NUMA territory): `0-49:0-49:0-49:0-49:56-101:56-101:56-101:56-101`
  (the validated TASK-007 B1 mechanism, identical for every T).
- **B2 medium**: non-overlapping rank-local slices sized T+2 CPUs/rank when
  `4*(T+2)` fits BOTH NUMA domains, else the nearest legal uniform width
  that still leaves helper/progress headroom (width > T), else infeasible.
- **B3 strict**: non-overlapping rank-local slices sized exactly T CPUs/rank
  when `4*T` fits BOTH NUMA domains, else infeasible (recorded and skipped;
  no approximation).

All masks are derived in the script from the live NUMA CPU ranges extracted
from the gate-verified `nvidia-smi topo -m` (GPU0 row -> NUMA0 range,
GPU4 row -> NUMA1 range, pinned to the accepted Phase-0 values
`0-49`/`56-101`) and the retained GPU/NUMA map (local ranks 0-3 -> GPU0-3 ->
NUMA0, ranks 4-7 -> GPU4-7 -> NUMA1). Slices are packed consecutively from
the first CPU of each NUMA domain (TASK-007 mask convention; for T=8 the
medium and strict masks are exactly the validated TASK-007 B2/B3 masks).
Feasibility table under the accepted topology (50 CPUs on NUMA0, 46 on
NUMA1; binding constraint NUMA1, max uniform width `floor(46/4)` = 11):

| T | B2 medium | B3 strict |
|---|---|---|
| 4 | w=6 (`0-5:6-11:12-17:18-23:56-61:62-67:68-73:74-79`) | w=4 (`0-3:4-7:8-11:12-15:56-59:60-63:64-67:68-71`) |
| 6 | w=8 (`0-7:8-15:16-23:24-31:56-63:64-71:72-79:80-87`) | w=6 (`0-5:6-11:12-17:18-23:56-61:62-67:68-73:74-79`) |
| 8 | w=10 (`0-9:10-19:20-29:30-39:56-65:66-75:76-85:86-95`) | w=8 (`0-7:8-15:16-23:24-31:56-63:64-71:72-79:80-87`) |
| 10 | w=11 (T+2=12 needs 4x12=48 > 46 CPUs on NUMA1; nearest legal uniform width with headroom) | w=10 (`0-9:10-19:20-29:30-39:56-65:66-75:76-85:86-95`) |
| 12 | infeasible (no legal width > 12; max 11) | infeasible (4x12=48 > 46 on NUMA1) |

Infeasible arms are recorded as **not scientifically instantiated /
infeasible under the approved topology constraint** and skipped; they are
never replaced with cross-NUMA or overlapping improvised masks
(Section 1.6C anti-stall rule). A medium policy that collapses to the same
effective mask as strict is never run twice (within one T the widths are
T+2 vs T, so this cannot occur; the check is recorded anyway).

Mechanical carry-forward (Section 1.6D): an explicit B1/B2/B3 policy is
operationally promotable only when valid and >2.0% above the same-T free
control; if none clears, free remains that T's candidate; if several clear,
carry the highest, or the top two when within 2.0% of each other (distinct
policies are distinct CPU-territory mechanisms). Across all carried thread
counts at most two total host candidates enter Step C; one candidate is
carried alone when >2.0% above every other; ranking tie-breaks prefer the
simpler/free policy and then the smaller thread count.

## Step C — OMP_PLACES x OMP_PROC_BIND matrix (TASK-009 Section 1.7)

For each carried host candidate (T, CPU policy):

- **C0 default control** (`OMP_PLACES`/`OMP_PROC_BIND` omitted; expected
  effective `sockets`/`TRUE`): the candidate's establishing arm — the
  Step-A arm for a free candidate or the winning Step-B arm for an explicit
  candidate — already scored exactly this configuration, so C0 is recorded
  as REDUNDANT and its existing score is reused as the Step-C control; it
  is not rerun (Section 1.7C: do not run a cell whose verified effective
  placement is identical to another already-scored cell under the same
  carried host candidate).
- **Approved explicit cells** when legal and non-redundant:
  `sockets`x{CLOSE, SPREAD} and `cores`x{TRUE, CLOSE, SPREAD}, maximum 6
  scored Step-C arms per carried candidate. `OMP_PROC_BIND=FALSE` is not
  added.

Legality verification (Section 1.7B, lightweight place-list arithmetic from
the live topology, no profiling): the script records the candidate's
effective rank CPU territory (free = full scheduled cpuset under
`--bind-to none`; loose = the rank's whole NUMA domain; medium/strict = the
rank's slice), computes the OpenMP place lists with the OpenMP default
mask-respecting semantics (sockets = one place per NUMA domain intersected
with the territory; cores = one place per CPU, 1 thread per core, no SMT on
this platform), and verifies no out-of-mask placement and no impossible
binding request. Redundancy rule actually applied: when every rank's
territory lies inside a single NUMA domain (loose/medium/strict
candidates), `OMP_PLACES=sockets` produces exactly ONE place per rank, and
with a single place CLOSE, SPREAD and TRUE all bind every thread to that
same place — so `sockets`x{CLOSE,SPREAD} are provably identical in
effective placement to the C0 default and both cells are recorded REDUNDANT
and skipped; only `cores`x{TRUE,CLOSE,SPREAD} are scored for such
candidates (3 arms). For free candidates (2 socket places per rank) all
five explicit cells are distinct and scored (5 arms).

## Interpretation boundary

Execution may report factual scores, timings, iteration counts, memory
evidence, carry-forward decisions and mechanical derived quantities only.
The carry-forward rules are operational pruning rules, not strategic
retention decisions: the final host-runtime winner, any baseline
comparison interpretation, the E19 memory-affinity checkpoint and the E20
DGEMV review are reserved for the post-task Strategic Analyst via
explicitly authorized `ANALYSE_RESULTS` (tasks/TASK-009.md Sections 1.1,
1.5D, 1.6D, 1.7A, 1.15). The run script computes no percentage deltas and
performs no ranking.

## Same-allocation requirement (TASK-009 Section 1.11)

Preferably all Step A/B/C arms run sequentially in ONE 2-node x 8-H200 PBS
allocation sharing one node pair, one launcher/container environment, one
cpuset/resource contract and one contemporaneous platform state; the PBS
script implements the approved conditional branching inside the single
allocation. There is deliberately no arm-subset option. If the allocation
terminates after meaningful scored evidence, the partial result is
preserved and the task returns PARTIAL/BLOCKED rather than silently
stitching remaining steps across unrelated allocations; a clean whole-task
Track-1 retry is allowed only if the failed attempt produced no
scientifically meaningful scored result. Completed valid steps are never
rerun merely to obtain a cosmetically complete matrix.

## Sequential behavior and stop conditions

- The arms run one at a time inside the single allocation. An arm with a
  nonzero exit or a non-`PASSED` verification is recorded (status file +
  job stdout) and the sweep continues with the next arm; the job exits
  nonzero overall if any arm exited nonzero or failed verification
  (isolated arm failure is preserved evidence). There is no in-script
  retry of any arm.
- Mechanical hard stop before Step B: if NO Step-A candidate is valid, the
  carry-forward has no basis; Step-A evidence is preserved and Steps B/C
  are not run (TASK-009 Section 1.13 systemic condition).
- Observational preflight failures abort BEFORE any scored arm (Track 2
  stop rules; workflow/05 and workflow/08 Section 5): a topology/cpuset
  mismatch on EITHER allocated node (mother-node gate or the rank-map
  per-host topology gate) invalidates the retained GPU/NUMA map and the
  Step-B mask derivations; a failed rank-map probe mechanical check
  indicates a launch/rank-mapping problem; an incoming `OMP_PLACES`/
  `OMP_PROC_BIND` value on any rank, or a per-arm env-probe mismatch,
  means the approved OpenMP controls cannot be guaranteed/applied on all
  ranks. In all cases evidence is preserved, nothing scored runs, and a
  rerun needs a new `ATTEMPT_TAG` plus human direction. The script never
  retries a hang, failed `MPI_Init`, rank misplacement, transport
  fallback, or uncertain correctness result.
- Required-runtime version records are deterministic tool checks, not
  scientific gates: `apptainer --version` and the container
  `/usr/local/mpi/bin/mpirun --version` query each capture their rc
  explicitly, and a nonzero rc aborts with a clear FATAL before any scored
  work. The optional `module list` record and the worktree Git-revision
  record warn and continue instead (provenance must not block an otherwise
  valid run).
- Evidence guard: abort if any POSSIBLE target `.out`/`.err`/`.status` or
  the rank-map/env-map/carry-forward `.log` exists — the arm set is
  carry-forward dependent, so the guard covers the maximal approved label
  set; reruns need a new `ATTEMPT_TAG`; existing evidence is never
  overwritten.
- Mid-run kill (e.g. walltime): that arm keeps its `.out`/`.err` but has no
  `.status`, and later arms were not run; the partial evidence is
  preserved per the same-allocation rule.
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-arm attempt ID:
`2x8-GAAS-phase3ab-host-runtime_<arm-label>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase3ab-host-runtime_a-omp8_v1`).

Arm labels: Step A `a-omp{4,6,8,10,12}`; Step B
`b{1,2,3}-cpu-{loose,medium,strict}-t<T>` for the carried T values only;
Step C `c-{sockets-close,sockets-spread,cores-true,cores-close,cores-spread}-t<T>-{free,loose,medium,strict}`
for the carried candidates only.

Before it is used in any evidence filename, `ATTEMPT_TAG` must pass a
conservative filename-safety gate in the script: nonempty, only ASCII
alphanumeric characters, dot, underscore, and hyphen, and not `.` or `..`.
The match runs under `LC_ALL=C` inside a subshell, so it is byte-exact and
locale-independent without modifying the job environment; any other value
aborts before anything runs (the outcome is recorded in the PBS `.o` as
`attempt_tag_validation=`).

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| arm status | `outputs/<attempt>.status` (attempt, experiment, task step, arm key/label, PBS job ID, queue, nodes, OMP_NUM_THREADS, supplied + effective OMP_PLACES/OMP_PROC_BIND, env-probe provenance, gpu/mem/cpu/ucx affinity, N/NB/grid/order, fixed-controls line, allocated cpuset and NUMA topology, start/end timestamps, exit status, extracted overall GFLOP/s, LU seconds, LU GFLOP/s, IR seconds, solver iteration count, IR/LU ratio, host/device memory lines, post-matgen headroom, verification verdict, normalized residual, evidence paths) |
| rank-map log | `outputs/2x8-GAAS-phase3ab-host-runtime_rankmap_<ATTEMPT_TAG>.log` (16 rank lines with the incoming OMP environment plus the per-host local-rank-0 topology reports for both allocated nodes) |
| env-map log | `outputs/2x8-GAAS-phase3ab-host-runtime_envmap_<ATTEMPT_TAG>.log` (per-arm 16-rank effective-OMP probe lines) |
| carry-forward log | `outputs/2x8-GAAS-phase3ab-host-runtime_carryforward_<ATTEMPT_TAG>.log` (mechanical Step-A/B/C decisions, mask derivations, feasibility/redundancy records, the exact rule for each branch) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase3ab-host-runtime_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase3ab-host-runtime_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names; there is no arm-subset resubmission path.

## Per-arm command

Identical for every arm except the authorized host-runtime controls
(`OMP_NUM_THREADS`; `--cpu-affinity` in Step B; `OMP_PLACES`/`OMP_PROC_BIND`
exports in Step C), launched inside the PBS job through the validated
Approach-1 container launcher (same contract as TASK-001..TASK-008):

```bash
export OMP_NUM_THREADS=<T>            # per arm, after module load
# Step-C explicit arms additionally:
# export OMP_PLACES=<sockets|cores> OMP_PROC_BIND=<TRUE|CLOSE|SPREAD>
# (Step-A/B arms: OMP_PLACES/OMP_PROC_BIND guaranteed unset)

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
    -x PATH -x LD_LIBRARY_PATH -x OMP_NUM_THREADS \
    [-x OMP_PLACES -x OMP_PROC_BIND] \
    --bind-to none \
    /workspace/hpl-mxp.sh \
      --n 429056 --nb 3072 --nprow 4 --npcol 4 --nporder row \
      --gpu-affinity 0:1:2:3:4:5:6:7 \
      [--cpu-affinity <mask>] \
      --sloppy-type FP16 --use-mpi-panel-broadcast 0 \
      --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

`--mem-affinity` and `--ucx-affinity` are never passed. The per-arm
environment probe uses the identical `mpirun` invocation shape with a
read-only `bash -c 'echo ...'` payload instead of the application.

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ngpus=8` (no `mpiprocs`); may be overridden at qsub by the documented host-pinned select |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `01:30:00` (worst-case arm budget: 5 Step-A + up to 6 Step-B + up to 10 Step-C scored arms plus per-arm probes, each arm ~1 min based on TASK-007/TASK-008 measurements, fits with wide margin), may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Environment provenance records | after the validated module load the job echoes to the PBS `.o`: loaded modules (`module list` — optional, non-fatal), the Apptainer version, and the container MPI version (`/usr/local/mpi/bin/mpirun --version`, required runtime with deterministic rc capture and a fatal abort before scored work on nonzero rc). No external image-digest inspection is performed |
| Execution-worktree revision | the job prints `git -C "$REPO_ROOT" rev-parse HEAD` to the PBS `.o` as non-fatal provenance — `unknown` plus a warning if unavailable. `REPO_ROOT` is derived from the submission directory and stays inside the approved remote project root |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH` (+ the per-arm `-x OMP_NUM_THREADS` and, for Step-C explicit arms, `-x OMP_PLACES -x OMP_PROC_BIND`; the validated environment-propagation channel, see above), `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by the probes and all arms in the allocation |
| Process grid/order | FIXED 4x4 row for every arm |
| Affinity semantics | installed v26.02 launcher: `--gpu-affinity` maps node-local rank -> `CUDA_VISIBLE_DEVICES`; `--cpu-affinity` -> `numactl --physcpubind=<range>` indexed by node-local rank (captured launcher in `todo.md`, wrapper flags confirmed in `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`); `--mem-affinity`/`--ucx-affinity` are omitted for every arm |
| OpenMP semantics | installed v26.02 launcher: `OMP_PROC_BIND=${OMP_PROC_BIND:-TRUE}`, `OMP_PLACES=${OMP_PLACES:-sockets}` package defaults when omitted; `OMP_NUM_THREADS` passes through from the (per-arm, `-x`-forwarded) rank environment |
| Rank-map probe | one lightweight 16-rank probe before scored work per allocation (same launcher and hostfile); preserves global rank / local rank / hostname for all 16 ranks plus the incoming OMP environment per rank, and node-local rank 0 on EACH allocated host additionally reports that host's topology facts (hostname, cpuset, `Mems_allowed_list`, GPU count, presence of `mlx5_0..mlx5_5,mlx5_8,mlx5_9`, and `nvidia-smi topo -m`) into the same log; aborts before scored work on mechanical failure, any per-host topology mismatch, or any incoming `OMP_PLACES`/`OMP_PROC_BIND` value |
| Topology gates | pre-scored fatal checks against the accepted Phase-0 topology, applied to BOTH allocated nodes: (a) a mother-node gate from the job shell and (b) a two-host gate in the rank-map stage validating each host's reported cpuset `0-49,56-101`, `Mems_allowed_list 0-1`, 8 GPUs, the eight 400G IB HCAs present, GPU0 -> NUMA0 `0-49` and GPU4 -> NUMA1 `56-101`, and the `nvidia-smi topo -m` NIC legend in order (retained unchanged from the validated TASK-008 script; replacement-node eligibility). The gate also extracts the live NUMA ranges used by the Step-B mask builder |
| Health snapshots | one pre-sweep and one post-sweep hardware-health snapshot (`nvidia-smi topo -m` + GPU query) around the whole sweep |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mechanically
mirrors the validated TASK-007/TASK-008 sweep scripts
(`experiments/2x8-GAAS/phase2bc-placement-locality/scripts/run_phase2bc_placement_locality.pbs`,
`experiments/2x8-GAAS/phase2c-ucx-affinity-confirm/scripts/run_phase2c_ucx_affinity_confirm.pbs`)
for container/MPI/orted/pbsdsh launcher, hostfile, resource request,
accounting project, bind mounts, daemon flags, module set, rank-map probe,
pre/post health-snapshot pattern and no-overwrite evidence guard.
Differences: the candidate set is the TASK-009 Step A/B/C host-runtime
matrix with its pre-authorized carry-forward rules; the OpenMP environment
contract (per-arm explicit `OMP_NUM_THREADS` export + `-x` forwarding,
guaranteed `OMP_PLACES`/`OMP_PROC_BIND` omission outside Step-C explicit
arms, incoming-environment gate, per-arm env probes); the Step-B mask
derivation from the live NUMA ranges; the Step-C place-list legality/
redundancy checks; and the carry-forward/env-map logs. None of these
changes any fixed scientific control or the validated launcher behavior.

## Submission (from this directory; requires TASK-009 execution authorization)

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase3ab-host-runtime_v1.o \
     -e outputs/2x8-GAAS-phase3ab-host-runtime_v1.e \
     scripts/run_phase3ab_host_runtime.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (as validated
for the Phase-0 probe, job 72591.gaas, and used by the TASK-001..TASK-008
sweeps):

```bash
qsub -l select=host=<n1>:ngpus=8:ncpus=96:mem=2000GB+host=<n2>:ngpus=8:ncpus=96:mem=2000GB ...
```

`free` alone does not establish queue eligibility; verify live Qlist/queue
eligibility before host-pinning (TASK-009 Section 1.12). g12/g13/g15-style
eligible topology-matching pairs are acceptable; a replacement pair must
satisfy the retained topology assumptions before CPU-mask derivation (the
in-script two-host topology gate verifies this live before any scored arm).

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
- `GFLOPS = <value>, per GPU = <value>` (the overall score to report; the
  first `GFLOPS = ` match) and `LU GFLOPS = <value>`;
- `Iterative Solver seconds: AVG = ...` (IR time) and the solver iteration
  lines (iteration count);
- the memory lines `Per process host memory consumption MAX = ..., available MIN = ...`,
  the device equivalent, and the post-matrix-generation
  `Per process memory available MIN system = ..., device = ...` headroom.

Arm-level: the `.status` file records `exit_status=0` and
`verification=PASSED`. With `--monitor-gpu 0`, GPU-monitoring output is
unavailable by design. An arm with an OOM, `FAILED`, or invalid result is
preserved as evidence, is not ranked as a valid performance point, and is
not rerun merely for being slower or unexpected. Do not classify success
from exit status alone.

## Available baseline provenance (context only; no analysis)

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, hpc-gaas-g12 + hpc-gaas-g15, overall `4.8037e+06` GFLOP/s, PASSED; evidence `experiments/2x8-GAAS/baseline/` — the campaign percentage denominator for 2x8-GAAS comparisons |
| Retained Phase-2A operating point | `2x8-GAAS-phase2a-grid-order-confirm_grid4x4-row_v1` (TASK-006), PBS job 72845.gaas, queue gpu_as, g12+g15, overall `5.6860e+06` GFLOP/s, PASSED, same protocol (`--skip-tests 0 --monitor-gpu 0`); evidence `experiments/2x8-GAAS/phase2a-grid-order-confirm/` |
| Retained TASK-008 host-runtime state entering TASK-009 | OMP_NUM_THREADS=8 (job shell), OMP_PLACES/OMP_PROC_BIND omitted (launcher defaults sockets/TRUE), CPU affinity omitted/free, memory affinity omitted, UCX affinity automatic; TASK-008 bracket PBS job 73068.gaas (g13+g15): C0a `5.6421e+06`, C1 `5.5794e+06`, C0b `5.6285e+06` GFLOP/s, all PASSED; evidence `experiments/2x8-GAAS/phase2c-ucx-affinity-confirm/` |
| TASK-007 CPU-affinity prior mechanism evidence | B0 free `5.6247e+06`, B1 loose `5.5530e+06`, B2 medium (10 CPUs/rank) `5.6912e+06`, B3 strict (8 CPUs/rank) `5.3783e+06` GFLOP/s at OMP=8; evidence `experiments/2x8-GAAS/phase2bc-placement-locality/` (used as prior mechanism evidence, not as fixed literal strings for every T) |
| Phase-0 topology evidence | `scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated, per TASK-009 Section 1.12; the in-script topology gates verify both allocated hosts still match |

TASK-009 does not rerun any baseline. Ranking, baseline-percentage tables,
retention decisions, the E19 memory-affinity checkpoint and the E20 DGEMV
review are reserved for the authorized `ANALYSE_RESULTS` step
(tasks/TASK-009.md Sections 1.9, 1.15).

## Run summary

(pending; to be recorded after the v1 attempt)

## Evidence paths

- `outputs/` — per-arm `.out`/`.err`/`.status`, the allocation-level
  rank-map log, the per-arm env-map log, the carry-forward decision log,
  and PBS `.o`/`.e` (including the environment provenance records:
  `module list`, Apptainer version, container MPI `mpirun --version`, and
  the execution-worktree Git revision)
- `scripts/run_phase3ab_host_runtime.pbs` — the sweep script (header
  documents purpose, working directory, inputs, outputs, and assumptions)
