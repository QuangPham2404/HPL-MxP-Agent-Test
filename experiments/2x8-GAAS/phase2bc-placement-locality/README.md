# 2x8-GAAS phase2bc-placement-locality

TASK-007 Phase-2B/2C same-allocation placement/locality sweep for the 2 GAAS
nodes x 8 H200 GPUs HPL-MxP campaign: the ten TASK-007-approved arms run
sequentially inside ONE 2x8 allocation at the retained Phase-2A operating
point `N=429056`, `NB=3072`, `4x4 row`, `OMP_NUM_THREADS=8` and the fixed
retained scientific controls (tasks/TASK-007.md Section 1.4A). Only the
physical placement controls vary, in three sequential stages with
pre-authorized mechanical carry-forward (tasks/TASK-007.md Sections
1.4B-1.4D):

```text
A. GPU affinity x memory affinity   (4 arms: A0, A1, A2, A3)
        ↓ pre-authorized mechanical carry-forward (>2.0% gates)
B. CPU affinity                     (4 arms: B0 free, B1 loose, B2 medium, B3 strict)
        ↓ pre-authorized mechanical carry-forward (>2.0% gates)
C. UCX device affinity              (2 arms: C0 automatic, C1 GPU-PIX-paired)
```

**Status (2026-09-27): prepared; the `v1` sweep has not been submitted yet.**
Any run must use a unique `ATTEMPT_TAG`, pass `-q gpu_as` or `-q gpu_ded`
(the only authorized queues), and never overwrite existing evidence. All ten
scored arms must share one PBS job/allocation (tasks/TASK-007.md Sections
1.4F, 1.7.10); this script has deliberately no arm-subset option.

## Structure

- `scripts/run_phase2bc_placement_locality.pbs` — single reusable sweep PBS
  script (10 arms sequentially in one allocation; Phase-0 topology
  consistency gates and a 16-rank rank-map probe before scored work; per-arm
  evidence files; in-script mechanical carry-forward decisions logged to
  `outputs/..._carryforward_<tag>.log`; attempt tag comes from the
  `ATTEMPT_TAG` environment at submission)
- `outputs/` — per-arm application `.out`/`.err`/`.status` evidence, the
  allocation-level rank-map log, the mechanical carry-forward decision log,
  and PBS `.o`/`.e` job evidence (tracked, never overwritten; every rerun
  gets a new attempt tag)

## Fixed scientific controls (identical for all 10 arms)

```
N = 429056
NB = 3072
nprow = 4
npcol = 4
nporder = row
OMP_NUM_THREADS = 8

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
Leader in tasks/TASK-007.md Section 1.4A; Codex/workers did not derive,
optimize, or modify it. All controls not listed (e.g.
`--fill-device-buffer-size`, `--Anq-device`, U-panel chunking, DGEMV
partitioning, precision, GEMM kernel, host registration) retain the same
installed package/default behavior used by the retained campaign control
(TASK-004/TASK-005/TASK-006), consistently for all arms.

OpenMP placement policy is unchanged: the job environment sets only
`OMP_NUM_THREADS=8`; `OMP_PLACES` and `OMP_PROC_BIND` are deliberately not
set (same as TASK-004/TASK-005/TASK-006), so the installed v26.02 launcher
applies its package defaults `OMP_PROC_BIND=TRUE` and `OMP_PLACES=sockets`
inside the container (captured launcher implementation in `todo.md`).

Deferred communication controls are NOT used anywhere in this sweep
(tasks/TASK-007.md Section 1.4E): `--ucx-tls`/`UCX_TLS`,
`--use-mpi-panel-broadcast` (beyond the fixed `0`),
`--mpi-use-mpi`, `--use-host-mpi`, and `--u-panel-chunk-nbs`. `--ucx-affinity`
remains in scope because it is a physical NIC/device-association control.

## Approved arm set (TASK-007 Sections 1.4B-1.4D)

Execution order is exactly A0, A1, A2, A3 → B0, B1, B2, B3 → C0, C1.

### Stage A — GPU affinity x memory affinity (exact strings)

| arm | GPU affinity | memory affinity | interpretation |
|---|---|---|---|
| A0 (control) | `0:1:2:3:4:5:6:7` | omitted | G0 identity, process rows NUMA-local |
| A1 | `0:1:2:3:4:5:6:7` | `0:0:0:0:1:1:1:1` | G0 identity + matching memory affinity |
| A2 | `0:4:2:6:1:5:3:7` | omitted | G1 column-local, process-column pairs NUMA-local |
| A3 | `0:4:2:6:1:5:3:7` | `0:1:0:1:0:1:0:1` | G1 column-local + matching memory affinity |

Under the retained 4x4-row grid and the validated contiguous 8-rank/node
placement, the same-node process-column pairs are local-rank pairs
`(0,4),(1,5),(2,6),(3,7)`; G1 maps each pair into one NUMA domain
(GPU0-3 -> NUMA0 CPUs 0-49, GPU4-7 -> NUMA1 CPUs 56-101).

### Stage B — CPU affinity (exact masks, selected by the retained G0/G1 map)

| arm | policy | G0 identity masks | G1 column-local masks |
|---|---|---|---|
| B0 (control) | free (no `--cpu-affinity`) | — | — |
| B1 | loose (whole NUMA domain of the rank's GPU) | `0-49:0-49:0-49:0-49:56-101:56-101:56-101:56-101` | `0-49:56-101:0-49:56-101:0-49:56-101:0-49:56-101` |
| B2 | medium (10 CPUs/rank, non-overlapping) | `0-9:10-19:20-29:30-39:56-65:66-75:76-85:86-95` | `0-9:56-65:10-19:66-75:20-29:76-85:30-39:86-95` |
| B3 | strict (8 CPUs/rank, non-overlapping) | `0-7:8-15:16-23:24-31:56-63:64-71:72-79:80-87` | `0-7:56-63:8-15:64-71:16-23:72-79:24-31:80-87` |

All ranges lie inside the Phase-0 PBS-visible cpuset `0-49,56-101`
(50 CPUs per NUMA node). No policy below 8 CPUs/rank is tested.

### Stage C — UCX device affinity (exact maps, selected by the retained G0/G1 map)

| arm | UCX device policy |
|---|---|
| C0 (control) | `--ucx-affinity` omitted (automatic/default device policy; the container default has been observed as `UCX_NET_DEVICES=all`) |
| C1 | GPU-PIX-paired HCA map: G0 `mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_8:mlx5_9`; G1 `mlx5_0:mlx5_4:mlx5_2:mlx5_8:mlx5_1:mlx5_5:mlx5_3:mlx5_9` |

Each local rank maps to the 400G IB HCA PIX-paired with its assigned GPU
(Phase-0 topology: GPU0-7 -> mlx5_0,mlx5_1,mlx5_2,mlx5_3,mlx5_4,mlx5_5,
mlx5_8,mlx5_9). The installed launcher converts the local-rank map to
`UCX_NET_DEVICES=<mlx5_X>:1` per rank.

## Pre-authorized mechanical carry-forward rules (execution logic, not analysis)

The sweep script applies these rules mechanically inside the allocation;
each decision is recorded in
`outputs/2x8-GAAS-phase2bc-placement-locality_carryforward_<tag>.log`.
A value exactly 2.0% above the base does **not** clear a gate (strictly
`> 2.0%`). Invalid/failed arms cannot be promoted.

- **Stage A (Section 1.4B):** within G0, retain memory affinity only if A1
  is >2.0% above valid A0; within G1, only if A3 is >2.0% above valid A2;
  carry G1 into Stage B only if the retained G1 variant is >2.0% above the
  retained G0 variant; otherwise carry G0. If A0 is not a valid control the
  sweep stops before Stage B/C (no valid branching basis). All four results
  are preserved regardless of branch.
- **Stage B (Section 1.4C):** an explicit CPU policy is eligible only if it
  is valid and >2.0% above valid B0; if several clear the gate, carry the
  highest valid score; if none clears (or B0 is invalid), carry free. All
  four results are preserved. `OMP_NUM_THREADS`/`OMP_PLACES`/`OMP_PROC_BIND`
  are not altered in response to Stage-B results.
- **Stage C (Section 1.4D):** retain explicit PIX-paired UCX affinity only
  if C1 is >2.0% above valid C0; otherwise retain the automatic/default
  device policy. Both results are preserved. This is only an execution
  carry-forward result; final strategic closure requires explicit
  `ANALYSE_RESULTS`.

## Per-arm command

Identical for every arm except the placement arguments
(`--gpu-affinity`/`--mem-affinity`/`--cpu-affinity`/`--ucx-affinity` as
defined above and derived from the retained map for Stages B/C), launched
inside the PBS job through the validated Approach-1 container launcher
(same contract as TASK-001..TASK-006):

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
      --gpu-affinity <G0|G1 map> [--mem-affinity <map>] \
      [--cpu-affinity <mask>] [--ucx-affinity <map>] \
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
| Walltime | `01:30:00` (validated request used by the TASK-001..TASK-006 sweeps; 10 arms x ~1 min plus probe/snapshots is expected to fit with wide margin), may be overridden at qsub |
| Container | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (NVIDIA HPC Benchmarks v26.02, HPL-MxP-NVIDIA 26.2.0) |
| Modules | `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0` (validated set) |
| Launcher | container `/usr/local/mpi/bin/mpirun` + `multi-node-test/rsh_pbsdsh_container.sh` bridge (container `orted` end-to-end, Approach 1) |
| Bind mounts | `/opt/pbs`, `/var/spool/pbs`, and the repo root into the container |
| MPI daemon flags | `plm_rsh_agent=<bridge>`, `plm_rsh_no_tree_spawn=1`, `plm_rsh_num_concurrent=1`, `routed=direct`, `-x PATH -x LD_LIBRARY_PATH`, `--bind-to none` |
| Hostfile | de-duplicated `$PBS_NODEFILE` with explicit `slots=8` per node (GAAS Blocker 8), shared by the rank-map probe and all arms in the allocation |
| Process grid/order | FIXED 4x4 row for every arm (only placement controls vary) |
| Affinity semantics | installed v26.02 launcher: `--gpu-affinity` maps node-local rank -> `CUDA_VISIBLE_DEVICES`; `--mem-affinity` -> `numactl --membind=<idx>`; `--cpu-affinity` -> `numactl --physcpubind=<range>`; `--ucx-affinity` -> `UCX_NET_DEVICES=<dev>:1` (all indexed by node-local rank; captured launcher in `todo.md`, wrapper flags confirmed in `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`) |
| Rank-map probe | one lightweight 16-rank probe before scored work per allocation; aborts before scored work on mechanical failure |
| Topology gates | pre-scored fatal checks that the mother node matches the accepted Phase-0 topology: cpuset `0-49,56-101`, `Mems_allowed_list 0-1`, 8 GPUs, the eight 400G IB HCAs `mlx5_0..mlx5_5,mlx5_8,mlx5_9` present, GPU0 -> NUMA0 `0-49` and GPU4 -> NUMA1 `56-101`, and the `nvidia-smi topo -m` NIC legend `NIC0..NIC7 -> mlx5_0..mlx5_9` (TASK-007 Section 1.9: an allocation whose topology invalidates the approved CPU/HCA strings aborts before scored work) |
| Health snapshots | one pre-sweep and one post-sweep hardware-health snapshot (`nvidia-smi topo -m` + GPU query) around the whole sweep |
| HCA counters | cheap, non-perturbing `port_xmit_data` snapshots on the mother node before C0, between C0 and C1, and after C1 (Stage-C rail/locality evidence, informational) |

The launch contract follows `multi-node-test/GAAS_MULTINODE_SETUP.md` and
`workflow/08-Workflow-Multinode-Tuning.md`; the run script mechanically
mirrors the validated TASK-006 sweep script
(`experiments/2x8-GAAS/phase2a-grid-order-confirm/scripts/run_phase2a_grid_order_confirm.pbs`)
for container/MPI/orted/pbsdsh launcher, hostfile, resource request,
accounting project, bind mounts, daemon flags, module set, rank-map probe,
and pre/post health-snapshot pattern. Differences: the candidate set is the
10-arm Stage-A/B/C placement matrix with in-script mechanical carry-forward,
the Phase-0 topology consistency gates, the Stage-C HCA counter snapshots,
and the carry-forward decision log.

## Sequential-sweep behavior

- The arms run one at a time inside the single 2x8 allocation (same nodes
  and job ID for all arms; this same-allocation property is a scientific
  requirement of TASK-007, Section 1.4F).
- Stage-B/C argument strings are derived inside the script from the retained
  G0/G1 map exactly as specified in TASK-007 Section 1.4 (the exact masks
  above are the only masks in the script).
- An arm with a nonzero exit or a non-`PASSED` verification is recorded
  (status file + job stdout + carry-forward log) and the sweep continues
  with the next arm if the allocation remains healthy; the job exits nonzero
  overall if any arm exited nonzero or failed verification (isolated arm
  failure is preserved evidence, Sections 1.7.12-14).
- Stop conditions handled in-script: an invalid A0 control stops before
  Stage B/C; a topology/cpuset/HCA mismatch aborts before scored work; a
  failed rank-map probe aborts before scored work.
- Evidence guard: abort if any target `.out`/`.err`/`.status`, rankmap
  `.log`, or carryforward `.log` exists — reruns need a new `ATTEMPT_TAG`;
  existing evidence is never overwritten.
- Mid-run kill (e.g. walltime): that arm keeps its `.out`/`.err` but has no
  `.status`, and later arms were not run; per TASK-007 Section 1.4F the
  partial evidence is preserved and the task returns PARTIAL/BLOCKED rather
  than splitting across allocations.
- One multinode job at a time (GAAS Blocker 7); no concurrent submissions.

## Attempt and output naming

Per-arm attempt ID:
`2x8-GAAS-phase2bc-placement-locality_<stage-arm-label>_<ATTEMPT_TAG>`
(e.g. `2x8-GAAS-phase2bc-placement-locality_a0-identity-nomem_v1`).

Arm labels: `a0-identity-nomem`, `a1-identity-mem`, `a2-columnlocal-nomem`,
`a3-columnlocal-mem`, `b0-cpu-free`, `b1-cpu-loose`, `b2-cpu-medium`,
`b3-cpu-strict`, `c0-ucx-auto`, `c1-ucx-pix`.

| artifact | path |
|---|---|
| application stdout | `outputs/<attempt>.out` |
| application stderr | `outputs/<attempt>.err` (includes bridge `cmd=[...]` and mpirun diagnostics) |
| arm status | `outputs/<attempt>.status` (attempt, experiment, stage/arm, PBS job ID, queue, nodes, effective gpu/mem/cpu/ucx affinity, N/NB/grid/order, fixed-controls line, start/end timestamps, exit status, extracted overall GFLOP/s, verification verdict, normalized residual, evidence paths) |
| rank-map log | `outputs/2x8-GAAS-phase2bc-placement-locality_rankmap_<ATTEMPT_TAG>.log` |
| carry-forward log | `outputs/2x8-GAAS-phase2bc-placement-locality_carryforward_<ATTEMPT_TAG>.log` |
| PBS job stdout | passed at qsub: `-o outputs/2x8-GAAS-phase2bc-placement-locality_<tag>.o` |
| PBS job stderr | passed at qsub: `-e outputs/2x8-GAAS-phase2bc-placement-locality_<tag>.e` |

Retries use a new sweep tag (e.g. `v2`) for both `ATTEMPT_TAG` and the
`-o`/`-e` names. A whole-attempt retry is permitted only when the failed
attempt produced no scientifically meaningful scored result (TASK-007
Section 1.4F); there is no arm-subset resubmission path.

## Submission (from this directory; requires TASK-007 execution authorization)

```bash
qsub -q <gpu_as|gpu_ded> \
     -v "ATTEMPT_TAG=v1" \
     -o outputs/2x8-GAAS-phase2bc-placement-locality_v1.o \
     -e outputs/2x8-GAAS-phase2bc-placement-locality_v1.e \
     scripts/run_phase2bc_placement_locality.pbs
```

A documented host-pinned select may be passed at qsub when live
`pbsnodes`/`Qlist` checks identify a clean eligible node pair (as validated
for the Phase-0 probe, job 72591.gaas, and used by the TASK-001..TASK-006
sweeps):

```bash
qsub -l select=host=<n1>:ngpus=8:ncpus=96:mem=2000GB+host=<n2>:ngpus=8:ncpus=96:mem=2000GB ...
```

`free` alone does not establish queue eligibility; verify live Qlist/queue
eligibility before host-pinning (TASK-007 Section 1.7.7). Codex may choose
`gpu_as` or `gpu_ded` based on live eligibility and may host-pin any
eligible pair that satisfies the approved topology (Section 1.6).

## Lightweight placement evidence (TASK-007 Section 1.4G)

- The 16-rank rank-map probe (global rank, local rank, hostname) runs before
  scored work; together with each arm's recorded `gpu_affinity` /
  `mem_affinity` / `cpu_affinity` / `ucx_affinity` strings and the accepted
  Phase-0 GPU->NUMA / GPU->PIX-HCA table, it reconstructs the effective
  local-rank -> GPU -> HCA mapping of every arm, including Stage C.
- The Phase-0 hardware characterization (PBS-visible cpuset, NUMA CPU
  ranges, GPU->NUMA mapping, GPU->PIX-HCA mapping, IB HCA inventory/link
  state on both g12 and g15) is reused from
  `scripts/probing_report.md` (2x8 supplement) and
  `scripts/outputs/phase0_2x8_probe_v1_node_hpc-gaas-g{12,15}.log`, not
  repeated; the in-script topology gates verify the allocated mother node
  still matches it, and the pre/post snapshots preserve the allocated-node
  topology tables.
- Cheap per-HCA `port_xmit_data` snapshots around the Stage-C arms
  (mother node) provide optional rail/locality evidence; no profiling or
  tracing is performed.
- Pre-submit parser review (2026-09-27): byte-level inspection of every
  stored `nvidia-smi topo -m` capture (TASK-000/TASK-006 PBS `.o` pre/post
  snapshots and the Phase-0 per-node logs for g12 and g15) shows the GPU
  data rows starting at column 0 with only the header line tab-indented
  (tab + ANSI bold before `GPU0`). The script's gate row anchors are
  whitespace-tolerant, so the header stays excluded on the verified format
  and a differently indented data row cannot cause a false abort; the gate
  assertions (GPU0 -> `0-49`, GPU4 -> `56-101`, NIC legend
  `NIC0..NIC7 -> mlx5_0..mlx5_9`) are unchanged.

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
- the memory lines `Per process host memory consumption MAX = ..., available MIN = ...`
  and the device equivalent.

Arm-level: the `.status` file records `exit_status=0` and
`verification=PASSED`. With `--monitor-gpu 0`, GPU-monitoring output is
unavailable by design. An arm with an OOM, `FAILED`, or invalid result is
preserved as evidence, is not ranked as a valid performance point, and is
not rerun merely for being slower or unexpected (TASK-007 Sections 1.4H,
1.7.12-14). Do not classify success from exit status alone.

## Available baseline provenance (context only; no analysis)

| item | value |
|---|---|
| Immutable 2x8-GAAS original baseline | `2x8-GAAS-baseline_n700k_v1` (TASK-000), PBS job 72602.gaas, queue gpu_as, hpc-gaas-g12 + hpc-gaas-g15, overall `4.8037e+06` GFLOP/s, PASSED; evidence `experiments/2x8-GAAS/baseline/` — the campaign percentage denominator for 2x8-GAAS comparisons |
| Retained Phase-2A operating point | `2x8-GAAS-phase2a-grid-order-confirm_grid4x4-row_v1` (TASK-006), PBS job 72845.gaas, queue gpu_as, g12+g15, overall `5.6860e+06` GFLOP/s, PASSED, same protocol (`--skip-tests 0 --monitor-gpu 0`); evidence `experiments/2x8-GAAS/phase2a-grid-order-confirm/` |
| Phase-0 topology evidence | `scripts/probing_report.md` (2x8 supplement; job 72591.gaas) — reused, not regenerated, per TASK-007 Section 1.4G |

TASK-007 does not rerun the baseline. Ranking, baseline-percentage tables,
retention decisions, and Phase-2B/2C closure are reserved for the authorized
`ANALYSE_RESULTS` step (tasks/TASK-007.md Sections 1.4H, 1.10).

## Run summary

(To be completed after execution; factual data only, no interpretation.)

## Evidence paths

- `outputs/` — per-arm `.out`/`.err`/`.status`, the allocation-level
  rank-map log, the mechanical carry-forward decision log, and PBS `.o`/`.e`
- `scripts/run_phase2bc_placement_locality.pbs` — the sweep script (header
  documents purpose, working directory, inputs, outputs, and assumptions)
