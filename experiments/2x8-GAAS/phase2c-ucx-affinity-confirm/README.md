# 2x8-GAAS phase2c-ucx-affinity-confirm

TASK-008 minimal bracketed UCX device-affinity confirmation for the 2 GAAS
nodes x 8 H200 GPUs HPL-MxP campaign: exactly three scored arms run
sequentially inside ONE 2x8 allocation at the retained Phase-2A operating
point `N=429056`, `NB=3072`, `4x4 row`, `OMP_NUM_THREADS=8` and the fixed
retained scientific controls (tasks/TASK-008.md Section 1.2). Only the UCX
device-affinity policy varies, in the exact approved bracket order
(tasks/TASK-008.md Section 1.3):

```text
C0a — automatic UCX          (--ucx-affinity omitted)
C1  — explicit GPU-PIX-paired HCA affinity
C0b — automatic UCX repeat   (--ucx-affinity omitted)
```

The bracket re-tests the unresolved TASK-007 Stage-C result
(tasks/TASK-007.md / experiments/2x8-GAAS/phase2bc-placement-locality/):

```text
C0 automatic UCX:   5.5828e+06 GFLOP/s, IR 1.64 s
C1 PIX-paired UCX:  5.6949e+06 GFLOP/s, IR 1.47 s
C1 vs C0 = +2.008%
```

The measured C1 gain was mechanistically plausible but smaller than the
approximately 2.68% span observed across repeated identical controls inside
TASK-007, so Phase 2C is not strategically closed. This experiment answers
exactly one question: does explicit rank-to-PIX-HCA UCX affinity reproduce an
end-to-end and iterative-refinement advantage when bracketed by the unchanged
automatic UCX control inside one allocation?

**Status (2026-09-28): v1 attempt executed; raw evidence retrieved.** The
single authorized Phase-2C bracket run (attempt tag `v1`) completed on
2026-09-28 with all three arms `PASSED`; see Run summary below. TASK-008
remains `EXECUTING / codex` pending the Codex Execution Report. Any rerun
must use a new `ATTEMPT_TAG`, pass `-q gpu_as` or `-q gpu_ded` (the only
authorized queues), and never overwrite existing evidence.

## Structure

- `scripts/run_phase2c_ucx_affinity_confirm.pbs` — single reusable bracket
  PBS script (3 arms sequentially in one allocation; Phase-0 topology
  consistency gates — a mother-node gate from the job shell plus a per-host
  two-host gate inside the single 16-rank rank-map probe — before scored
  work; four mother-node per-HCA `port_xmit_data` snapshots bracketing the
  arms; per-arm evidence files; attempt tag comes from the `ATTEMPT_TAG`
  environment at submission and is validated against a conservative
  filename-safe pattern before use; environment provenance records —
  `module list`, Apptainer version, container MPI `mpirun --version`, and
  the execution-worktree Git revision — are echoed to the PBS `.o`)
- `outputs/` — per-arm application `.out`/`.err`/`.status` evidence, the
  allocation-level rank-map log (16 rank lines plus the per-host
  local-rank-0 topology reports for both allocated nodes), and PBS `.o`/`.e`
  job evidence (tracked, never overwritten; every rerun gets a new attempt
  tag)

## Fixed scientific controls (identical for all 3 arms)

```
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row
OMP_NUM_THREADS = 8

--gpu-affinity 0:1:2:3:4:5:6:7
--mem-affinity omitted
--cpu-affinity omitted

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
Leader in tasks/TASK-008.md Section 1.2; Codex/workers did not derive,
optimize, or modify it. All controls not listed (e.g.
`--fill-device-buffer-size`, `--Anq-device`, U-panel chunking, DGEMV
partitioning, precision, GEMM kernel, host registration) retain the same
installed package/default behavior used by the retained campaign control
(TASK-004/TASK-005/TASK-006/TASK-007), consistently for all arms.

OpenMP placement policy is unchanged: the job environment sets only
`OMP_NUM_THREADS=8`; `OMP_PLACES` and `OMP_PROC_BIND` are deliberately not
set (same as TASK-004/TASK-005/TASK-006/TASK-007), so the installed v26.02
launcher applies its package defaults `OMP_PROC_BIND=TRUE` and
`OMP_PLACES=sockets` inside the container (captured launcher implementation
in `todo.md`). No explicit CPU or memory affinity is introduced anywhere in
this confirmation.

Deferred controls are NOT used anywhere in this bracket (tasks/TASK-008.md
Section 1.6): `--ucx-tls`/`UCX_TLS`, `--use-mpi-panel-broadcast` (beyond the
fixed `0`), `--mpi-use-mpi`, `--use-host-mpi`, and `--u-panel-chunk-nbs`,
plus `OMP_NUM_THREADS`/`OMP_PLACES`/`OMP_PROC_BIND`, `--cpu-affinity`,
`--mem-affinity`, `N`/`NB`/grid/order, fill-device/device-buffer, DGEMV,
precision, GEMM-kernel, and TRSM/factorization/stream-scheduling controls.
`UCX_TLS × use-mpi-panel-broadcast` remains a Phase-4 communication study and
the dependency-E19 CPU-affinity × OpenMP revalidation stays out of scope
until Phase 2C is closed.

## Approved bracket arm set (TASK-008 Section 1.3)

Execution order is exactly C0a → C1 → C0b. GPU/memory/CPU placement is fixed
for every arm (identity GPU map, memory affinity omitted, CPU affinity
omitted); only the UCX device policy varies.

| arm | UCX device policy |
|---|---|
| C0a (control) | `--ucx-affinity` omitted (automatic/default device policy; the container default has been observed as `UCX_NET_DEVICES=all`) |
| C1 | explicit GPU-PIX-paired HCA map: `mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_8:mlx5_9` |
| C0b (control repeat) | `--ucx-affinity` omitted, identical to C0a |

The installed launcher maps each node-local rank to
`UCX_NET_DEVICES=<mlx5_X>:1` using the exact local-rank/HCA order above
(captured v26.02 launcher semantics; see `todo.md` and the wrapper flag-check
evidence in
`experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`). No
second C1 repeat and no other arm exists in this experiment; the purpose is a
minimal local drift bracket, not a general statistical sweep.

## Interpretation boundary (TASK-008 Section 1.5)

Execution may report factual derived quantities only — C1 vs C0a percentage,
C1 vs C0b percentage, C0b vs C0a drift, C1 relative to the arithmetic mean of
C0a/C0b, IR-time differences, and per-HCA transmitted-data deltas — but must
NOT make the strategic retain/reject decision. The post-task Strategic
Analyst determines whether the C1 effect is credible using the complete
bracket; the intended later interpretation is guidance for evidence
collection only. The run script itself computes no percentage deltas and
performs no ranking.

## Same-allocation requirement (TASK-008 Section 1.7)

All three arms run sequentially in one 2-node × 8-H200 PBS allocation:
`C0a -> C1 -> C0b`, sharing one PBS job/allocation, one node pair, one
rank-placement contract, and one container/software environment. Arms split
across multiple allocations are never compared. If the allocation terminates
after scientifically meaningful evidence is produced, the partial result is
preserved and the task returns PARTIAL/BLOCKED rather than silently
completing the bracket in another allocation. A fresh whole-task retry is
allowed only if the failed attempt produced no scientifically meaningful
scored result.

## Per-arm command

Identical for every arm except the UCX device policy
(`--ucx-affinity` omitted for C0a/C0b, the PIX-paired map for C1), launched
inside the PBS job through the validated Approach-1 container launcher (same
contract as TASK-001..TASK-007):

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
      --n 429056 --nb 3072 --nprow 4 --npcol 4 --nporder row \
      --gpu-affinity 0:1:2:3:4:5:6:7 \
      [--ucx-affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_8:mlx5_9] \
      --sloppy-type FP16 --use-mpi-panel-broadcast 0 \
      --use-separate-stream-for-gemm 1 \
      --prioritize-trsm 0 --prioritize-factorization 0 \
      --fill-device 1 --test-loop 1 --skip-tests 0 --monitor-gpu 0
```

## Resource metadata and launch contract

| item | value |
|---|---|
| Resource shape | 2 nodes x 8 H200 GPUs; 16 MPI ranks, one rank/GPU |
| PBS select | `select=2:ngpus=8` (no `mpiprocs`); may be overridden at qsub by the documented host-pinned select |
| Placement | `place=scatter` (distinct physical nodes) |
| Accounting project | `hpc_ebslee` |
| Queue | NOT selected in the script; must be passed at qsub as `-q gpu_as` or `-q gpu_ded`; the script verifies the actually-assigned queue and aborts on any other queue |
| Walltime | `01:30:00` (validated request used by the TASK-001..TASK-007 sweeps; 3 arms x ~1 min plus probe/snapshots is expected to fit with wide margin), may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Environment provenance records | after the validated module load the job echoes to the PBS `.o`: loaded modules (`module list` — an optional record that must not fail the job; it warns and continues on failure), the Apptainer version, and the container MPI version (`/usr/local/mpi/bin/mpirun --version`, a lightweight read-only query of the exact container mpirun the probe and arms launch, run through the same `apptainer exec --nv` prefix and bind mounts, before the rank-map probe). The two version invocations are required-runtime checks handled deterministically: explicit rc capture, and a nonzero rc aborts with a clear FATAL before any scored work (the rank-map probe and every arm launch through these exact runtimes). No external image-digest inspection is performed |
| Execution-worktree revision | the job prints `git -C "$REPO_ROOT" rev-parse HEAD` (the commit of the execution worktree actually used) to the PBS `.o` as non-fatal provenance — `unknown` plus a warning if git or the revision is unavailable. `REPO_ROOT` is derived from the submission directory and stays inside the approved remote project root (primary clone or `.codex-worktrees/` execution worktree beneath it), and a commit SHA exposes no secrets |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by the rank-map probe and all arms in the allocation |
| Process grid/order | FIXED 4x4 row for every arm (only the UCX device policy varies) |
| Affinity semantics | installed v26.02 launcher: `--gpu-affinity` maps node-local rank -> `CUDA_VISIBLE_DEVICES`; `--ucx-affinity` -> `UCX_NET_DEVICES=<dev>:1` (indexed by node-local rank; captured launcher in `todo.md`, wrapper flags confirmed in `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`); `--mem-affinity`/`--cpu-affinity` are omitted for every arm |
| Rank-map probe | one lightweight 16-rank probe before scored work per allocation (same launcher, hostfile, and rankmap log for every attempt); preserves global rank / local rank / hostname for all 16 ranks, and node-local rank 0 on EACH allocated host additionally reports that host's topology facts (hostname, cpuset, `Mems_allowed_list`, GPU count, presence of `mlx5_0..mlx5_5,mlx5_8,mlx5_9`, and `nvidia-smi topo -m`) into the same rank-map log; aborts before scored work on mechanical failure or any per-host topology mismatch |
| Topology gates | pre-scored fatal checks against the accepted Phase-0 topology, applied to BOTH allocated nodes: (a) a mother-node gate from the job shell (retained from the validated TASK-007 script) and (b) a two-host gate in the rank-map stage validating each host's reported cpuset `0-49,56-101`, `Mems_allowed_list 0-1`, 8 GPUs, the eight 400G IB HCAs `mlx5_0..mlx5_5,mlx5_8,mlx5_9` present, GPU0 -> NUMA0 `0-49` and GPU4 -> NUMA1 `56-101`, and the `nvidia-smi topo -m` NIC legend `NIC0..NIC7 -> mlx5_0,mlx5_1,mlx5_2,mlx5_3,mlx5_4,mlx5_5,mlx5_8,mlx5_9` in order (TASK-008 Section 1.4). The two-host gate was added 2026-09-28: remote preflight found g13+g15 as the only currently free eligible pair, and g13 has no accepted Phase-0 capture (only g12 and g15 do), so replacement-node eligibility under TASK-008 Section 1.8 ("any replacement pair must satisfy the same topology assumptions required by the exact HCA mapping") is verified per host inside the rank-map stage; any host mismatch aborts before scored work with the rankmap evidence preserved |
| Health snapshots | one pre-bracket and one post-bracket hardware-health snapshot (`nvidia-smi topo -m` + GPU query) around the whole bracket |
| HCA counters | cheap, non-perturbing `port_xmit_data` snapshots on the mother node at four points: before C0a, after C0a/before C1, after C1/before C0b, and after C0b (informational rail/locality evidence; no profiling or tracing) |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mechanically
mirrors the validated TASK-007 sweep script
(`experiments/2x8-GAAS/phase2bc-placement-locality/scripts/run_phase2bc_placement_locality.pbs`)
for container/MPI/orted/pbsdsh launcher, hostfile, resource request,
accounting project, bind mounts, daemon flags, module set, rank-map probe,
pre/post health-snapshot pattern, and no-overwrite evidence guard.
Differences: the candidate set is the 3-arm C0a/C1/C0b bracket (no
carry-forward rules and no in-script percentage computation), the fourth HCA
counter snapshot after C0b, the extended per-arm `.status` fields
(LU/IR/iteration/ratio/memory evidence required by TASK-008 Section 1.4),
the follow-up provenance additions (environment version records:
`module list`, Apptainer version, container MPI `mpirun --version` before
the rank-map probe; the execution-worktree Git revision record; and the
`ATTEMPT_TAG` filename-safety gate), plus the per-host (two-host) topology
validation inside the rank-map probe (added 2026-09-28; see Topology gates
above): node-local rank 0 on each allocated host reports that host's
cpuset/mems/GPU count/HCA inventory/`nvidia-smi topo -m` into the same
rank-map log, and both hosts are gated before scored work because the
preflight pair g13+g15 includes g13, which has no accepted Phase-0 capture.
None of these changes any scientific setting or launch behavior.

## Sequential-bracket behavior

- The arms run one at a time inside the single 2x8 allocation (same nodes
  and job ID for all arms; this same-allocation property is a scientific
  requirement of TASK-008, Section 1.7). There is deliberately no
  arm-subset option.
- An arm with a nonzero exit or a non-`PASSED` verification is recorded
  (status file + job stdout) and the bracket continues with the next arm if
  the allocation remains healthy; the job exits nonzero overall if any arm
  exited nonzero or failed verification (isolated arm failure is preserved
  evidence). There is no in-script retry of any arm.
- Observational preflight failures abort BEFORE any scored arm (Track 2
  stop rules; workflow/05 and workflow/08 Section 5): a topology/cpuset/HCA
  mismatch on EITHER allocated node (the mother-node job-shell gate or the
  rank-map per-host topology gate) invalidates the approved GPU-to-HCA map,
  and a failed rank-map probe indicates a launch or rank-mapping problem. In
  both cases evidence is preserved, nothing scored runs, and a rerun needs a
  new `ATTEMPT_TAG` plus human direction. The script never retries a hang,
  failed `MPI_Init`, rank misplacement, transport fallback, or uncertain
  correctness result.
- Required-runtime version records are deterministic tool checks, not
  scientific gates: `apptainer --version` and the container
  `/usr/local/mpi/bin/mpirun --version` query each capture their rc
  explicitly, and a nonzero rc aborts with a clear FATAL before any scored
  work (workflow/03: a tool check is fatal when the next command directly
  depends on the tool — the rank-map probe and every arm launch through
  these exact runtimes). The optional `module list` record and the
  worktree Git-revision record warn and continue instead (provenance must
  not block an otherwise valid run). None of these records changes any
  scientific setting or launch behavior.
- Evidence guard: abort if any target `.out`/`.err`/`.status` or the
  rankmap `.log` exists — reruns need a new `ATTEMPT_TAG`; existing evidence
  is never overwritten.
- Mid-run kill (e.g. walltime): that arm keeps its `.out`/`.err` but has no
  `.status`, and later arms were not run; per TASK-008 Section 1.7 the
  partial evidence is preserved and the task returns PARTIAL/BLOCKED rather
  than splitting across allocations.
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-arm attempt ID:
`2x8-GAAS-phase2c-ucx-affinity-confirm_<arm-label>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase2c-ucx-affinity-confirm_c0a-ucx-auto_v1`).

Arm labels (TASK-008 Section 1.9): `c0a-ucx-auto`, `c1-ucx-pix`,
`c0b-ucx-auto`.

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
| arm status | `outputs/<attempt>.status` (attempt, experiment, bracket arm, PBS job ID, queue, nodes, effective gpu/mem/cpu/ucx affinity, N/NB/grid/order, fixed-controls line, OpenMP policy, start/end timestamps, exit status, extracted overall GFLOP/s, LU seconds, LU GFLOP/s, IR seconds, solver iteration count, IR/LU ratio, host/device memory lines, post-matgen headroom, verification verdict, normalized residual, evidence paths) |
| rank-map log | `outputs/2x8-GAAS-phase2c-ucx-affinity-confirm_rankmap_<ATTEMPT_TAG>.log` (16 rank lines plus the per-host local-rank-0 topology reports for both allocated nodes) |
| HCA snapshots | four `port_xmit_data` snapshot blocks echoed to the PBS `.o` (before C0a / after C0a before C1 / after C1 before C0b / after C0b) |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase2c-ucx-affinity-confirm_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase2c-ucx-affinity-confirm_<tag>.e` |

Retries use a new bracket tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names. A whole-attempt retry is permitted only when the failed
attempt produced no scientifically meaningful scored result (TASK-008
Section 1.7); there is no arm-subset resubmission path.

## Submission (from this directory; requires TASK-008 execution authorization)

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase2c-ucx-affinity-confirm_v1.o \
     -e outputs/2x8-GAAS-phase2c-ucx-affinity-confirm_v1.e \
     scripts/run_phase2c_ucx_affinity_confirm.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (as validated
for the Phase-0 probe, job 72591.gaas, and used by the TASK-001..TASK-007
sweeps):

```bash
qsub -l select=host=<n1>:ngpus=8:ncpus=96:mem=2000GB+host=<n2>:ngpus=8:ncpus=96:mem=2000GB ...
```

`free` alone does not establish queue eligibility; verify live Qlist/queue
eligibility before host-pinning (TASK-008 Section 1.8). g12+g15 are
acceptable if eligible and clean, but are not mandatory; any replacement
pair must satisfy the same topology assumptions required by the exact HCA
mapping.

## Lightweight placement evidence (TASK-008 Section 1.4)

- The 16-rank rank-map probe (global rank, local rank, hostname) runs before
  scored work and mechanically confirms 16 MPI ranks, 8 ranks/node, 2
  distinct hosts; together with each arm's recorded `gpu_affinity` /
  `mem_affinity` / `cpu_affinity` / `ucx_affinity` strings and the accepted
  Phase-0 GPU->NUMA / GPU->PIX-HCA table, it reconstructs the effective
  local-rank -> GPU -> HCA mapping of every arm. Inside the same single
  probe launch (same launcher, hostfile, and log; no extra job, rank, or
  arm), node-local rank 0 on each allocated host also collects that host's
  topology (hostname, cpuset, `Mems_allowed_list`, GPU count, the eight
  400G IB HCAs, and the full `nvidia-smi topo -m` matrix) into the same
  rank-map log — read-only node-local `/proc`, `/sys`, and `nvidia-smi`
  observation through the exact container runtime the arms use.
- The Phase-0 hardware characterization (PBS-visible cpuset, NUMA CPU
  ranges, GPU->NUMA mapping, GPU->PIX-HCA mapping, IB HCA inventory/link
  state on both g12 and g15) is reused from `scripts/probing_report.md`
  (2x8 supplement) and
  `scripts/outputs/phase0_2x8_probe_v1_node_hpc-gaas-g{12,15}.log`, not
  repeated; the in-script topology gates verify the allocated mother node
  (job-shell gate) AND both allocated hosts (rank-map per-host gate) still
  match it, and the pre/post snapshots preserve the allocated-node topology
  tables. The two-host gate exists because the accepted Phase-0 evidence
  covers only g12 and g15: the 2026-09-28 remote preflight found g13+g15 as
  the only currently free eligible pair, and g13 has no accepted Phase-0
  capture, so replacement-node eligibility under TASK-008 Section 1.8 ("any
  replacement pair must satisfy the same topology assumptions required by
  the exact HCA mapping") is verified live per host inside the rank-map
  stage before any scored arm.
- The four cheap per-HCA `port_xmit_data` snapshots on the mother node
  (before C0a, after C0a/before C1, after C1/before C0b, after C0b) cover
  the same eight 400G IB HCAs `mlx5_0 mlx5_1 mlx5_2 mlx5_3 mlx5_4 mlx5_5
  mlx5_8 mlx5_9`; the counters are informational only and no
  profiling/tracing is added.
- Pre-submit parser review precedent (2026-09-27, TASK-007): byte-level
  inspection of every stored `nvidia-smi topo -m` capture showed the GPU
  data rows starting at column 0 with only the header line tab-indented; the
  script's gate row anchors are whitespace-tolerant, and the gate assertions
  (GPU0 -> `0-49`, GPU4 -> `56-101`, NIC legend `NIC0..NIC7 ->
  mlx5_0..mlx5_9`) are unchanged from the validated TASK-007 gates.

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
| Unresolved TASK-007 Stage-C measurements | C0 `c0-ucx-auto_v1` `5.5828e+06` GFLOP/s / IR 1.64 s; C1 `c1-ucx-pix_v1` `5.6949e+06` GFLOP/s / IR 1.47 s; C1 vs C0 = +2.008%; identical-configuration control span inside TASK-007 approx. 2.68%; evidence `experiments/2x8-GAAS/phase2bc-placement-locality/` |
| Phase-0 topology evidence | `scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated, per TASK-008 Section 1.4 |

TASK-008 does not rerun the baseline. Ranking, baseline-percentage tables,
bracket interpretation, retention decisions, and Phase-2C closure are
reserved for the authorized `ANALYSE_RESULTS` step (tasks/TASK-008.md
Sections 1.5, 1.10).

## Run summary

### v1 attempt (2026-09-28, PBS job 73068.gaas)

One authorized bracket submission, exactly as approved by TASK-008 Section
1.11 (one qsub, no retry).

**Node/queue selection (live preflight immediately before submission).**
`gpu_as` was enabled and started (walltime limit 336:00:00; ACL includes
`hpc_ebslee_group`, so project `hpc_ebslee` is eligible; precedent jobs
72624/72845/72879). `hpc-gaas-g12` was NOT clean: another user's job
`72885.gaas` (`tr_para-3`) held 96 CPUs, 8 GPUs, and ~2000 GB on it, so the
preferred g12+g15 pair was unavailable. `hpc-gaas-g13` and `hpc-gaas-g15`
were both `free` with zero assigned CPU/GPU/memory and
`Qlist = gpu_as,gpu_ppu` — completely idle and eligible for `gpu_as` (the
only authorized queue containing the pair; `gpu_ded` is not in their Qlist).
The submitted pair was therefore **g13+g15 on `gpu_as`**.

**PBS provenance.**

| item | value |
|---|---|
| PBS job | `73068.gaas` (job name `2x8_phase2c_ucx`) |
| Submitted | 2026-09-28T07:32:27+08:00 (single qsub) |
| Job running from | 2026-09-28T07:32:28+08:00 |
| Completed | 2026-09-28T07:35:57+08:00 (walltime `00:03:29` of `01:30:00` requested) |
| Final state | `F`, `Exit_status=0`, `run_count=1` |
| Queue / project | `gpu_as` / `hpc_ebslee` |
| Select (host-pinned at qsub) | `select=host=hpc-gaas-g13:ngpus=8:ncpus=96:mem=2000GB+host=hpc-gaas-g15:ngpus=8:ncpus=96:mem=2000GB`, `place=scatter`, no `mpiprocs` |
| Allocated hosts | `hpc-gaas-g13/0*96 + hpc-gaas-g15/0*96` |
| Execution worktree | `.codex-worktrees/TASK-008-962545e-phase2c-v2` at `962545ec71cc79cb1e3686893f2f4d033f3aecd4` (recorded in the PBS `.o`) |
| Modules / container | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0`; Apptainer 1.4.1; container MPI Open MPI 4.1.9a1; `hpc-benchmarks_26.02.sif` |

**Single-allocation proof.** All three arms share job `73068.gaas`, the
g13+g15 pair, one hostfile/rank-placement contract, and one container
environment: C0a ran 07:32:57–07:33:55, C1 07:33:55–07:34:54, C0b
07:34:55–07:35:55 (+08:00), bracketed by the four HCA snapshots
(07:32:56 / 07:33:55 / 07:34:55 / 07:35:56). Arm order was exactly
C0a → C1 → C0b.

**Preflight gates (all PASS, before any scored arm).**
`attempt_tag_validation=PASS`; mother-node (g13) topology gate PASS
(cpuset `0-49,56-101`, mems `0-1`, 8 GPUs, HCAs `mlx5_0..mlx5_5,mlx5_8,mlx5_9`,
GPU0→NUMA0, GPU4→NUMA1, NIC legend match); rank-map probe `rc=0`,
16 rank lines, 2 hosts, 8 ranks/host; per-host topology gate PASS on BOTH
`hpc-gaas-g13` and `hpc-gaas-g15` (g13, which has no accepted Phase-0
capture, was validated live as required for replacement-node eligibility).
Rank map: global ranks 0–7 on g13, ranks 8–15 on g15
(`outputs/2x8-GAAS-phase2c-ucx-affinity-confirm_rankmap_v1.log`).

**Per-arm measurements (from the arm `.status` files / `.out` evidence).**
Identical fixed controls per TASK-008 Section 1.2; only the UCX policy
varied (`--ucx-affinity` omitted for C0a/C0b; the PIX-paired map for C1).
All arms: exit_status=0, verification `PASSED`, finite normalized residual
`1.416310E-05`, 3 solver iterations.

| arm | attempt | overall GFLOP/s | LU seconds | LU GFLOP/s | IR seconds | IR/LU | host mem MAX / avail MIN | device mem MAX / avail MIN | post-matgen headroom (sys/dev) |
|---|---|---|---|---|---|---|---|---|---|
| C0a | `..._c0a-ucx-auto_v1` | 5.6421e+06 | 7.76 | 6.7818e+06 | 1.57 | 0.202 | 0.004 GB / 49.569 GB | 135.254 GB / 138.739 GB | 49.349 GB / 2.767 GB |
| C1 | `..._c1-ucx-pix_v1` | 5.5794e+06 | 7.75 | 6.7936e+06 | 1.69 | 0.218 | 0.004 GB / 50.970 GB | 135.254 GB / 138.739 GB | 50.751 GB / 2.767 GB |
| C0b | `..._c0b-ucx-auto_v1` | 5.6285e+06 | 7.75 | 6.7967e+06 | 1.61 | 0.208 | 0.004 GB / 49.622 GB | 135.254 GB / 138.739 GB | 49.391 GB / 2.767 GB |

Attempt ids: `2x8-GAAS-phase2c-ucx-affinity-confirm_{c0a-ucx-auto,c1-ucx-pix,c0b-ucx-auto}_v1`.

**HCA `port_xmit_data` snapshots (mother node g13, raw cumulative values).**

| HCA | before C0a | after C0a | after C1 | after C0b |
|---|---|---|---|---|
| mlx5_0 | 7204104 | 10310374981 | 20614979371 | 30918150241 |
| mlx5_1 | 7202016 | 10393838773 | 20782210099 | 31168849192 |
| mlx5_2 | 7204032 | 10298268970 | 20591071665 | 30882139982 |
| mlx5_3 | 7202448 | 10393586241 | 20781704918 | 31168088198 |
| mlx5_4 | 7203816 | 10304729707 | 20603719452 | 30901246062 |
| mlx5_5 | 7203600 | 10388049294 | 20770629604 | 31151474743 |
| mlx5_8 | 7202808 | 10471478531 | 20937490663 | 31401770535 |
| mlx5_9 | 7202376 | 10292411062 | 20579357917 | 30864567812 |

**Anomalies.** None blocking. PBS stderr preserves the recurring
`cuda/13.1` module note and `unknown groupid 1304617061` warnings (same as
TASK-007); arm `.err` files contain the normal bridge `cmd=[...]` orted
diagnostics. GPU-monitoring output is unavailable by design
(`--monitor-gpu 0`). Pre/post-bracket hardware-health snapshots are in the
PBS `.o`.

**Evidence (all retrieved to this directory, SHA-256-verified against the
remote worktree copies).** `outputs/` contains the 12 v1 files: PBS
`..._v1.o`/`..._v1.e`, three arm `.out`/`.err`/`.status` sets, and the
rank-map log. Factual rows for the three attempts were appended to
`results/metrics.csv` (experiment id
`2x8-GAAS-phase2c-ucx-affinity-confirm`). Strategic conclusions in
`planning/2x8-GAAS.md` and any final Phase-2C analysis are NOT updated
during execution (TASK-008 Section 1.9); bracket interpretation and the
retain/reject decision are reserved for the authorized `ANALYSE_RESULTS`
step (TASK-008 Section 1.5).

## Evidence paths

- `outputs/` — per-arm `.out`/`.err`/`.status`, the allocation-level
  rank-map log, and PBS `.o`/`.e` (including the four HCA `port_xmit_data`
  snapshot blocks and the environment provenance records: `module list`,
  Apptainer version, container MPI `mpirun --version`, and the
  execution-worktree Git revision)
- `scripts/run_phase2c_ucx_affinity_confirm.pbs` — the bracket script
  (header documents purpose, working directory, inputs, outputs, and
  assumptions)
