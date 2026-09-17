# Phase 1 Step 2 — host NCCL sendrecv topology matrix

## Current status

The host nccl-tests build and single-node smoke passed on 2026-09-17 in PBS
job 67034.gaas on hpc-gaas-g06. The build completed, mpirun-launched osu_hello
passed with one process, and all three all_reduce_perf smoke arms returned 0
with the nccl-tests zero-error marker. The default arm loaded NCCL's IB
network plugin and reported GPUDirect RDMA enabled.

This validates the host binary, MPI launcher path, and local NCCL startup. It
does not validate communication between nodes because v3 used one MPI/NCCL
rank. The v3 PBS evidence is on GAAS at
scripts/gaas-internode-coms-debug/build-nccl-tests/outputs/build_nccl_tests_host_v3.{o,e}.

## Submission status — 2026-09-17

| Topology | PBS job | Nodes / queue | Scheduler result | Test assessment |
|---|---|---|---|---|
| 2x1 | `67037.gaas` | g21 + g22 / `gpu_ded` | Exit 0, 42 s | MPI/mapping and all three NCCL arms returned 0 with zero out-of-bounds values; transport-control validation is blocked (see below). |
| 3x1 | `67038.gaas` | g21 + g22 + g03 / `gpu_ded` | Exit 0, 47 s | MPI/mapping and all three NCCL arms returned 0 with zero out-of-bounds values; transport-control validation is blocked (see below). |
| 3x4 | — | — | Not submitted | Stopped after the socket-floor transport mismatch in the earlier topologies. |

The `sockfloor` arms printed `NCCL_IB_DISABLE=1`, but their logs still loaded
`NCCL RDMA Plugin v11`, enumerated IB virtual devices, and selected
`NET/IBext_v11`; GDRDMA was still reported in the 3x1 arm. The expected socket
transport was not used. The runner's own `STEP2_SENDRECV_RESULT=PASS` marker
only checks return codes and correctness markers, so it overstates validation
when a requested transport control is ignored. Treat 2x1 and 3x1 as
communication/correctness evidence with an unresolved transport-control
blocker, not fully validated matrix passes.

Likely cause, not yet confirmed: this build's external NCCL RDMA plugin path
is still active despite `NCCL_IB_DISABLE=1`. Do not change transport settings
or submit 3x4 until the supported way to select/force socket transport for
this plugin is manually verified.

## Draft topology matrix

The test uses nccl-tests sendrecv_perf with one rank per GPU. Each topology
runs the same three arms on the same allocated nodes:

| Topology | Nodes | Ranks per node | Total ranks | GPU ranks per node |
|---|---:|---:|---:|---:|
| 2x1 | 2 | 1 | 2 | 1 |
| 3x1 | 3 | 1 | 3 | 1 |
| 3x4 | 3 | 4 | 12 | 4 |

Each arm sweeps 8 B through 64 MiB by factors of two, with 5 warmups and 20
iterations:

1. Default NCCL settings (control).
2. NCCL_NET_GDR_LEVEL=LOC (InfiniBand with GPUDirect RDMA disabled).
3. NCCL_IB_DISABLE=1 (socket transport floor).

The node-pinned host MPI launch follows Phase 1 Step 1:
a de-duplicated hostfile with explicit slots, no mpiprocs in PBS select,
place=scatter, the host mpirun, and multi-node-test/rsh_pbsdsh.sh with
plm_rsh_no_tree_spawn=1, plm_rsh_num_concurrent=1, routed=direct, and
--bind-to none. Per-rank output records global/local rank, host, GPU
visibility, CPU/memory affinity, and nccl-tests device identity. Per-node
logs capture GPU topology, GDR modules, and IB devices. This follows the
host-native MPI precedent in
debug-scripts/phase1-step1/run_phase1_step1_p2p_2x1.pbs. The 3x4 hostfile and
rank/GPU mapping also follow multi-node-test/HPL-MxP/run_hplmxp_baseline.pbs;
the NCCL test uses the host MPI build, while that HPL-MxP script uses its
container MPI and container bridge because the application is inside
Apptainer. The bridge and GAAS launch requirements are documented in
multi-node-test/GAAS_MULTINODE_SETUP.md.

Every topology reserves four GPUs, 48 CPUs, and 1000 GB per pinned node, as
used by the clean-node Phase 1 Step 1 jobs. The 2x1 and 3x1 tests use one
rank/GPU per node while reserving the same node chunk; 3x4 uses all four
reserved GPUs. The PBS script checks that the granted host set matches
REQ_HOSTS and the requested node count.

## Submission sequence

Choose nodes only from `gpu_as` or `gpu_ded`, matching the queue to each node's
`resources_available.Qlist`. In the 2026-09-17 `pbsnodes -aSj` probe, the
cleanest eligible three-node set was `hpc-gaas-g21`, `hpc-gaas-g22`, and
`hpc-gaas-g03` in `gpu_ded`: g21/g22 were idle with all GPUs and CPUs free;
g03 was shared, with 6/8 GPUs and 76/100 CPUs free, more capacity than the
eligible shared alternatives. Use g21/g22 for 2x1 and the same ordered trio
for 3x1 and 3x4. Recheck and record scheduler state before each job, and
record any host substitution. Save a post-run snapshot after completion.
Create the PBS output directory before qsub. Submit one topology at a time
and wait for it to finish before submitting the next.

Run these from this directory on GAAS after the draft scripts are synchronized:

~~~bash
mkdir -p ../../outputs/phase1-step2
pbsnodes -aSj > ../../outputs/phase1-step2/step2_sendrecv_2x1_v1_presched.txt
qsub -q gpu_ded -l "select=host=hpc-gaas-g21:ngpus=4:ncpus=48:mem=1000GB+host=hpc-gaas-g22:ngpus=4:ncpus=48:mem=1000GB" -v "ATTEMPT=step2_sendrecv_2x1_v1,REQ_HOSTS=hpc-gaas-g21+hpc-gaas-g22" -o ../../outputs/phase1-step2/step2_sendrecv_2x1_v1.o -e ../../outputs/phase1-step2/step2_sendrecv_2x1_v1.e run_phase1_step2_sendrecv_2x1.pbs
~~~

After that job completes, capture its post-run scheduler snapshot, then submit 3x1:

~~~bash
pbsnodes -aSj > ../../outputs/phase1-step2/step2_sendrecv_2x1_v1_postsched.txt
pbsnodes -aSj > ../../outputs/phase1-step2/step2_sendrecv_3x1_v1_presched.txt
qsub -q gpu_ded -l "select=host=hpc-gaas-g21:ngpus=4:ncpus=48:mem=1000GB+host=hpc-gaas-g22:ngpus=4:ncpus=48:mem=1000GB+host=hpc-gaas-g03:ngpus=4:ncpus=48:mem=1000GB" -v "ATTEMPT=step2_sendrecv_3x1_v1,REQ_HOSTS=hpc-gaas-g21+hpc-gaas-g22+hpc-gaas-g03" -o ../../outputs/phase1-step2/step2_sendrecv_3x1_v1.o -e ../../outputs/phase1-step2/step2_sendrecv_3x1_v1.e run_phase1_step2_sendrecv_3x1.pbs
~~~

After 3x1 completes, capture its post-run snapshot, then submit 3x4 on three
freshly checked/pinned hosts:

~~~bash
pbsnodes -aSj > ../../outputs/phase1-step2/step2_sendrecv_3x1_v1_postsched.txt
pbsnodes -aSj > ../../outputs/phase1-step2/step2_sendrecv_3x4_v1_presched.txt
qsub -q gpu_ded -l "select=host=hpc-gaas-g21:ngpus=4:ncpus=48:mem=1000GB+host=hpc-gaas-g22:ngpus=4:ncpus=48:mem=1000GB+host=hpc-gaas-g03:ngpus=4:ncpus=48:mem=1000GB" -v "ATTEMPT=step2_sendrecv_3x4_v1,REQ_HOSTS=hpc-gaas-g21+hpc-gaas-g22+hpc-gaas-g03" -o ../../outputs/phase1-step2/step2_sendrecv_3x4_v1.o -e ../../outputs/phase1-step2/step2_sendrecv_3x4_v1.e run_phase1_step2_sendrecv_3x4.pbs
pbsnodes -aSj > ../../outputs/phase1-step2/step2_sendrecv_3x4_v1_postsched.txt
~~~

Use the recorded host set only if the fresh pre-submit probe still supports it;
otherwise stop and report the changed availability. Use the matching queue,
PBS group hpc_ebslee, and do not add mpiprocs to the select chunks.

## Validation and failure handling

A topology passes only when PBS completes with exit status 0, both PBS output
files exist, the MPI health phase reports the expected process count, all
three sendrecv arms return 0, every arm prints the zero-error marker, and the
final stdout marker is STEP2_SENDRECV_RESULT=PASS. NCCL stderr must also
identify the selected backend/HCA and show the intended GDR or socket control
reached the ranks.

A timeout, MPI launch failure, rank/GPU mapping mismatch, missing correctness
marker, or unexpected NCCL transport is preserved for manual inspection.
Do not automatically retry or change launcher, resources, modules, or
transport settings.

## NCCL GDR A/B family (`step2_gdr_*`) — agreed 2026-09-17

Implements the "NCCL GPUDirect RDMA A/B experiment plan" in the parent
`../README.md`: six jobs (mode × topology), two GDR arms per job on the same
allocation. The shared runner `run_phase1_step2_sendrecv_common.sh` is now
parameterized — `TESTS` (`sendrecv` | `broadcast` | `allreduce`), `ARMS`
(`ctrl gdroff sockfloor`), `RESULT_TAG` — with defaults preserving the
original three-arm sendrecv behavior above. Changes carried by every new arm
run: `NCCL_TESTS_DEVICE=0` under per-rank `CUDA_VISIBLE_DEVICES` (smoke v2
lesson), extended `NCCL_DEBUG_SUBSYS=INIT,BOOTSTRAP,ENV,NET,GRAPH,P2P,COLL,SHM,TUNING`,
`NCCL_DEBUG_FILE=/dev/stderr`, per-arm per-test logs
`<attempt>_<arm>_<test>.log` capturing stdout+stderr, and a per-run
`transport_summary` line (via_ibext / gdrdma / via_socket channel counts from
channel `via` lines — the A/B validity evidence).

| Job | Attempt | Tests | Topology | Ranks | Arms |
|---|---|---|---|---:|---|
| 1 | `step2_gdr_p2p_2x1_v1` | `sendrecv_perf` | 2x1 | 2 | ctrl, gdroff |
| 2 | `step2_gdr_p2p_3x1_v1` | `sendrecv_perf` | 3x1 | 3 | ctrl, gdroff |
| 3 | `step2_gdr_p2p_3x4_v1` | `sendrecv_perf` | 3x4 | 12 | ctrl, gdroff |
| 4 | `step2_gdr_coll_2x1_v1` | `broadcast_perf` (root 0) + `all_reduce_perf` | 2x1 | 2 | ctrl, gdroff |
| 5 | `step2_gdr_coll_3x1_v1` | `broadcast_perf` (root 0) + `all_reduce_perf` | 3x1 | 3 | ctrl, gdroff |
| 6 | `step2_gdr_coll_3x4_v1` | `broadcast_perf` (root 0) + `all_reduce_perf` | 3x4 | 12 | ctrl, gdroff |

Collective wrappers are added after the P2P ladder validates; they are not
submitted as part of the P2P stage.

### Submission sequence (P2P ladder; one job at a time, fresh node probe before each)

Same node-pinning and clean-node rules as above: choose the cleanest
eligible nodes from `gpu_as`/`gpu_ded` matching each node's queue, reserve
`ngpus=4:ncpus=48:mem=1000GB` per pinned node, group `hpc_ebslee`, no
`mpiprocs`. Prefer reusing the same node set across rungs for cross-rung
comparability when the fresh probe still supports it. From this directory on
GAAS after synchronization:

~~~bash
mkdir -p ../../outputs/phase1-step2
pbsnodes -aSj > ../../outputs/phase1-step2/step2_gdr_p2p_2x1_v1_presched.txt
qsub -q gpu_ded \
  -l "select=host=<node1>:ngpus=4:ncpus=48:mem=1000GB+host=<node2>:ngpus=4:ncpus=48:mem=1000GB" \
  -v "ATTEMPT=step2_gdr_p2p_2x1_v1,REQ_HOSTS=<node1>+<node2>" \
  -o ../../outputs/phase1-step2/step2_gdr_p2p_2x1_v1.o \
  -e ../../outputs/phase1-step2/step2_gdr_p2p_2x1_v1.e \
  run_phase1_step2_gdr_p2p_2x1.pbs
~~~

After completion, capture the post-run snapshot, re-probe, and submit 3x1
(`step2_gdr_p2p_3x1_v1`, three host chunks, `run_phase1_step2_gdr_p2p_3x1.pbs`),
then 3x4 (`step2_gdr_p2p_3x4_v1`, `run_phase1_step2_gdr_p2p_3x4.pbs`), each
with its own `presched`/`postsched` snapshots and attempt-specific `.o`/`.e`
names.

### Validation (GDR A/B)

A run passes only when PBS exits 0, the MPI health phase reports the expected
process count, every arm×test returns 0 with `Out of bounds values : 0 OK`,
the expected rank/GPU mapping is printed, and the final marker is
`STEP2_GDR_P2P_RESULT=PASS`. A GDR comparison cell is valid only when both
arms show `via_ibext_channels > 0` with `gdrdma_channels >= 1` in ctrl and
`gdrdma_channels = 0` in gdroff (from the `transport_summary` line, i.e.
channel `via` lines). Cells failing that transport gate are labeled
inconclusive — a PASS marker alone does not certify the comparison.
