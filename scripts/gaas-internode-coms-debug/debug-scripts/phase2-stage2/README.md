# Phase 2 Stage 2 — container-native OSU/NCCL GDR A/B (2x1 then 3x4)

## Purpose

Verify, inside the HPL-MxP container and on the validated container launch
path, whether the two communication stacks select GPUDirect RDMA for real
GPU-buffer traffic, using same-job A/B arms:

- **MPI/UCX arm:** staged host OSU-CUDA binaries (Stage 1 option (a)
  mechanism: shared `osu-cuda-host/` tree → node-local `/tmp/phase2_osu`)
  exercised through the container HPC-X MPI/UCX stack. ctrl = container
  defaults; gdroff = `UCX_IB_GPU_DIRECT_RDMA=n`.
- **NCCL arm:** container-native `*_mpi` nccl-tests binaries through the
  container NCCL stack (`NET/IBext_v11`). ctrl = defaults; gdroff =
  `NCCL_NET_GDR_LEVEL=LOC` (the GDR-off control proven effective on host in
  Phase 1 Step 2: 0 GDRDMA channels vs 8/16/24 in ctrl arms).

Design decisions (user-confirmed 2026-09-18): 4 jobs, one per stack × rung,
both arms in the same job on the same allocation; cleanest-eligible node
hunting in `gpu_as`/`gpu_ded` with contention recorded; group `hpc_ebslee`;
one job at a time; ladder order OSU-2x1 → NCCL-2x1 → OSU-3x4 → NCCL-3x4.

## Experiment matrix

| # | Attempt | Script | Rung / ranks | Stack / tests (per arm) | Sweep |
|---|---|---|---|---|---|
| 1 | `phase2_stage2_osu_2x1_v1` | `run_phase2_stage2_osu_2x1.pbs` | 2x1 / 2 | `osu_bw` D D + H H, `osu_latency` D D + H H (np=2 inter-node pair) | OSU default |
| 2 | `phase2_stage2_nccl_2x1_v1` | `run_phase2_stage2_nccl_2x1.pbs` | 2x1 / 2 | `sendrecv_perf_mpi`, `broadcast_perf_mpi` (-r 0), `all_reduce_perf_mpi` | 8 B→64 MiB, f2, w5, n20 |
| 3 | `phase2_stage2_osu_3x4_v1` | `run_phase2_stage2_osu_3x4.pbs` | 3x4 / 12 (pt2pt np=2) | same as #1 | OSU default |
| 4 | `phase2_stage2_nccl_3x4_v1` | `run_phase2_stage2_nccl_3x4.pbs` | 3x4 / 12 | same as #2 | same as #2 |

Run conditions (all jobs): container `mpirun` + `rsh_pbsdsh_container.sh`
bridge + container `orted`; `--bind-to none`; chunks
`ngpus=4:ncpus=48:mem=1000GB` per pinned node on every rung; `place=scatter`;
no `mpiprocs`; one rank per GPU (`CUDA_VISIBLE_DEVICES=local rank`, plus
`NCCL_TESTS_DEVICE=0` for the NCCL arm); walltime 45 min; arms sequential
(ctrl first) with pre/prectrl/mid/post co-tenant checkpoints, per-node fabric
evidence (`fabric_capture.sh`), rank/GPU maps, and (NCCL jobs) a cross-node
MPI health gate via the packaged `osu_bw H H`.

Evidence requirements:

- **MPI/UCX:** `UCX_LOG_LEVEL=info` + `UCX_PROTO_INFO=y` in BOTH arms,
  `-x` forwarded to every rank; the gdroff knob is echoed per rank in each
  test log. Cell validity (analysis-time): ctrl shows zero-copy GPU-buffer
  traffic over `rc_mlx5` for D D; gdroff switches to staging; H H unchanged
  between arms. The runner prints coarse `rc_mlx5`/`cuda_copy`/`gdr_copy`
  marker counts only.
- **NCCL:** `NCCL_DEBUG=INFO` + `SUBSYS=INIT,BOOTSTRAP,ENV,NET,GRAPH,P2P,
  COLL,SHM,TUNING` + `FILE=/dev/stderr` in both arms. Cell validity: both
  arms select `NET/IBext_v11` (per-channel `via` lines), ctrl ≥1 inter-node
  `GDRDMA` channel, gdroff = 0 GDRDMA channels, and the ENV subsys proves
  the knob reached every rank. The runner prints per-arm channel counts and
  a per-test `AB_VALID`/`AB_INCONCLUSIVE` gate line.
- **Correctness:** every NCCL test must return rc=0, `Out of bounds values :
  0`, and no `nranks 1 ` comm (MPI-bootstrap proof). OSU tests: rc=0 with
  the expected table shape.

Caveat (host-campaign lesson, recorded): the runner `RESULT=PASS` markers
cover execution and correctness markers only — transport-control validation
is the recorded `ab_gate`/marker evidence, classified at analysis time. The
3x4 NCCL sendrecv is a ring (6 NVLink + 6 IB legs) and is not directly
comparable to the pure inter-node 2x1 rung.

## Pre-authorized contingency

If the container default NCCL 3x4 allreduce fails with the case
`2026-09-17-A` signature (mixed RoCE/IB link warnings + `ib_plugin` reject),
a rerun with `NCCL_IB_HCA` bond-excluded in BOTH arms is pre-authorized as a
separate documented attempt (`..._v2` naming), matching the host fix
validated in job `67584.gaas`. No other transport/affinity/launcher changes
are authorized in this family.

## Submission sequence (from this directory on GAAS)

Node hunting per job: `pbsnodes -aSj` immediately before submission; pick
the cleanest eligible nodes from `gpu_as`/`gpu_ded` only (matching the queue
to each node's `resources_available.Qlist`); save the pre-submission
snapshot as evidence; recheck before every job; record any host substitution
or co-tenant arrivals. Post-run snapshot after each completion. Submit one
job at a time and wait for it to finish.

~~~bash
mkdir -p ../../outputs/phase2-stage2
pbsnodes -aSj > ../../outputs/phase2-stage2/phase2_stage2_osu_2x1_v1_presched.txt
qsub -q gpu_ded -l "select=host=<h1>:ngpus=4:ncpus=48:mem=1000GB+host=<h2>:ngpus=4:ncpus=48:mem=1000GB" \
  -v "ATTEMPT=phase2_stage2_osu_2x1_v1,REQ_HOSTS=<h1>+<h2>" \
  -o ../../outputs/phase2-stage2/phase2_stage2_osu_2x1_v1.o \
  -e ../../outputs/phase2-stage2/phase2_stage2_osu_2x1_v1.e \
  run_phase2_stage2_osu_2x1.pbs
~~~

Repeat per job with the matching script, attempt name, node count (three
`host=` chunks for the 3x4 rungs), and fresh pre/post snapshots:
`phase2_stage2_nccl_2x1_v1`, `phase2_stage2_osu_3x4_v1`,
`phase2_stage2_nccl_3x4_v1`.

## Validation and failure handling

- `bash -n` on all scripts before first submission; `git diff --check` on
  reviewed changes.
- Track 1 (deterministic workflow-machinery defects: paths, output names,
  quoting, evidence loss): preserve the failed attempt's evidence, record it
  in the attempt log below, patch, resubmit under a new attempt label
  (`_v2`, `_v3`, ...).
- Track 2 (anything requiring judgment: launch failures, transport
  anomalies beyond the recorded contingency, node loss, uncertain output):
  stop, preserve evidence, record a case, and report to the user.
- Failed/never-started submissions (wrong host names, node filled before
  start, node offline): qdel with recorded reason; evidence preserved.

## Attempt log

| Attempt | PBS job | Nodes / queue | Result | Notes |
|---|---|---|---|---|
| `phase2_stage2_osu_2x1_v1` | `67922.gaas` | g14+g15 / `gpu_as` (both pristine) | FAIL (fast, staging) | Track 1: `SHARED_STAGE` misspelled as `osu-microbenchmarks-cuda` (missing hyphen) — the shared tree exists at `osu-micro-benchmarks-cuda` and the host-source rsync actually merged into it, but the completeness check used the misspelled path and FATAL'd. Same typo class as smoke v3 (job `67820.gaas`). Evidence: `phase2_stage2_osu_2x1_v1.{o,e}` + pre snapshots + presched. Patch: fixed `SHARED_STAGE`; resubmit as `_v2`. |
| `phase2_stage2_osu_2x1_v2` | `67956.gaas` | g14+g15 / `gpu_as` (both pristine) | **PASS** (8/8 tests, ~4 min) | Execution+shape PASS; ABI clean; marker counts recorded (D D arms show cuda_copy asymmetry ctrl 6 vs gdroff 12/22; H H symmetric 6/6). Formal GDR classification at analysis. Evidence: 26 files incl. per-arm/per-test logs, rank map, fabric, pre/prectrl/mid1/post checkpoints, hostfiles, presched. |
| `phase2_stage2_nccl_2x1_v1` | `67958.gaas` | g14+g15 / `gpu_as` (both pristine) | FAIL (fast, tooling gate) | Track 1: health-gate binary path missing `mpi/pt2pt/` (`/workspace/microbenchmarks/osu_mpi_tests/osu_bw` vs actual `.../mpi/pt2pt/osu_bw`, preflight v3 inventory), and the ldd gate was over-strict for the documented benign `libverifiable.so.0 => not found` quirk. Patch: `OSU_HEALTH_BIN` full path + quirk exclusion; resubmit as `_v2`. Evidence: `phase2_stage2_nccl_2x1_v1.{o,e}` + pre snapshots + presched. |
| `phase2_stage2_nccl_2x1_v2` | `67963.gaas` | g13+g15 / `gpu_as` (bad pick) | never started (qdelt) | Node misjudgment: `pbsnodes -aSj` f/t columns are FREE/total, so g13 was fully occupied (67215 holds 96 cpus + 8 GPUs + ~2TB); the chunk could never place ("Insufficient Qlist" comment). qdelt with recorded reason; no output files. |
| `phase2_stage2_nccl_2x1_v3` | `67965.gaas` | g20+g22 / `gpu_ded` (g22 pristine; g20 one light co-tenant: 12 cpus + 1 GPU) | **PASS** (6/6 runs; all 3 tests AB_VALID) | ctrl 16 IBext / 8 GDRDMA vs gdroff 16 / 0 on all three tests — same IB backend in both arms, knob reach proven (ENV lines). Container NCCL GDR engaged by default at 2x1. |
| `phase2_stage2_osu_3x4_v1` | `67969.gaas` | g22+g20+g03 / `gpu_ded` (g22 pristine; g20 12cpu+1GPU tenant; g03 idle-holder 48cpu+4GPU) | **PASS** (8/8 tests, ~7 min) | pt2pt pair g22+g20; 12/12 ranks mapped, ABI clean. Marker counts recorded (D D arms show cuda_copy asymmetry; H H symmetric). Formal GDR classification at analysis. |
| `phase2_stage2_nccl_3x4_v1` | `67973.gaas` | g22+g20+g03 / `gpu_ded` | FAIL (5/6 runs; **pre-authorized contingency triggered**) | ctrl allreduce aborted rc=3 with the case 2026-09-17-A signature (ib_plugin.c mixed RoCE/IB link warnings + connection closed) on this node mix — the same bond-rail misalignment as the host case. All other cells valid: sendrecv ctrl 24 IB/16 GDRDMA vs gdroff 24/0; broadcast 72/48 vs 48/0; gdroff allreduce 610/0. Rerun as `_v2` with `NCCL_IB_HCA` bond-excluded (both arms), full test set, per the pre-authorization. |
| `phase2_stage2_nccl_3x4_v2` | `67974.gaas` | g22+g20+g03 / `gpu_ded` (same trio as v1) | **PASS** (6/6 runs; all 3 tests AB_VALID, HCA bond-excluded both arms) | `ib_hca_filter=mlx5_0..5,8,9` recorded; sendrecv ctrl 24 IB/16 GDRDMA vs gdroff 24/0; broadcast 72/48 vs 48/0; allreduce ctrl 616 IB/448 GDRDMA vs gdroff 610/0. Condition documented: 3x4 NCCL cells carry "NCCL_IB_HCA bond-excluded, both arms". |

Evidence note: per-job `postsched.txt` snapshots were not captured between
jobs (deviation from the submission sequence); the in-job post checkpoints
(`*_post_hpc-gaas-g*.log`, which include each node's pbsnodes co-tenant
view) plus the per-attempt `presched.txt` files serve as the scheduler-state
evidence for this session.
