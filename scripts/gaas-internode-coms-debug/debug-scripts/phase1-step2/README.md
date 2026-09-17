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

Collective wrappers `run_phase1_step2_gdr_coll_{2x1,3x1,3x4}.pbs` were added
after the P2P ladder validated (all three rungs PASS with valid GDR A/B,
2026-09-17 ~22:35 +08). `broadcast_perf` is pinned to fixed root 0 via
`-r 0` in the shared runner — its default (`-r -1`) rotates the root across
all ranks (src/broadcast.cu), which is not the agreed convention.

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

### P2P attempt log

- `step2_gdr_p2p_2x1_v1` — PBS job `67456.gaas`, 2026-09-17 17:45 +08 on
  pinned gpu_ded g22 (pristine) + g20 (one co-tenant, job 67357), 31 s,
  exit 0, `STEP2_GDR_P2P_RESULT=PASS`. **Valid GDR A/B**: ctrl 16 via-IBext
  channels with 8 GDRDMA vs gdroff 16 via-IBext with 0 GDRDMA; zero socket
  channels. GDR-on gain (algbw, out-of-place): +11–17% at ≥1 MiB (64 MiB:
  24.72 vs 22.06 GB/s; 1 MiB: 15.04 vs 12.85), neutral at ≤512 KiB.
  **Track 1 defect**: the per-node fabric evidence
  (`nvidia-smi topo`/inventory/peermem/ibv) was silently lost — the runner
  never exported `OUTDIR`, so `mpirun -x OUTDIR` forwarded nothing and the
  redirect to `/_fabric_...` failed behind a misleading success echo
  (inherited from the original runner; jobs 67037/67038 lost theirs the same
  way). Measurements and transport evidence unaffected. Patched
  (`export OUTDIR`, commit `2972fc9`) and rerun as v2. Evidence:
  `../../outputs/phase1-step2/step2_gdr_p2p_2x1_v1*` (byte-verified).
- `step2_gdr_p2p_2x1_v2` — PBS job `67488.gaas`, 2026-09-17 18:51 +08, same
  pinned pair, 31 s, exit 0, `STEP2_GDR_P2P_RESULT=PASS`. **The scored 2x1
  attempt**: identical transport evidence (ctrl 16/8 GDRDMA, gdroff 16/0),
  numbers reproduce v1 (64 MiB algbw 24.63 vs 21.74 GB/s), and the fabric
  evidence is now correctly captured for g22 and g20 (nvidia_peermem loaded,
  8-HCA inventory, GPU topo). Evidence:
  `../../outputs/phase1-step2/step2_gdr_p2p_2x1_v2*` (byte-verified).
- `step2_gdr_p2p_3x1_v1` — PBS job `67575.gaas`, 2026-09-17 22:33 +08 on
  pinned gpu_ded g22 (pristine) + g20 (one co-tenant) + g02 (three
  co-tenants: 67043, 67148[1], 67148[2]; 4/8 GPUs free — the third-node
  slot g01 never freed, g02 substituted, documented), 41 s, exit 0,
  `STEP2_GDR_P2P_RESULT=PASS`. **Valid GDR A/B**: ctrl 24 via-IBext
  channels with 8 GDRDMA vs gdroff 24/0. GDR-on algbw (64 MiB: 24.54 vs
  22.11 GB/s, +11%; 4 MiB: +10%; 1 MiB: +5%), neutral ≤64 KiB. Evidence:
  `../../outputs/phase1-step2/step2_gdr_p2p_3x1_v1*` (byte-verified).
- `step2_gdr_p2p_3x4_v1` — PBS job `67576.gaas`, 2026-09-17 22:35 +08, same
  pinned trio, 12 ranks (4/node), 54 s, exit 0,
  `STEP2_GDR_P2P_RESULT=PASS`. **Valid GDR A/B**: ctrl 24 via-IBext channels
  with 8 GDRDMA vs gdroff 24/0. **Largest GDR gain of the ladder** (mixed
  ring: 6 intra-node NVLink + 6 inter-node IB legs): algbw 64 MiB 40.78 vs
  26.44 GB/s (**+54%**), 16 MiB +38%, 4 MiB +24%, 1 MiB +5%, neutral at
  64 KiB. Evidence:
  `../../outputs/phase1-step2/step2_gdr_p2p_3x4_v1*` (byte-verified,
  fabric logs for all three nodes present).

### Collective attempt log

- `step2_gdr_coll_2x1_v1` — PBS job `67577.gaas`, 2026-09-17 22:47 +08 on
  g22+g20, 44 s, exit 0, `STEP2_GDR_COLL_RESULT=PASS`. **Valid GDR A/B for
  both tests** (ctrl 16 IB/8 GDRDMA vs gdroff 16/0 each). Broadcast root 0
  (pinned via `-r 0`; the default rotates root across ranks). GDR gains
  mild: bcast 64 MiB 48.28 vs 48.13 GB/s (+1%); allreduce 64 MiB 28.43 vs
  24.60 (+16%). Evidence: `../../outputs/phase1-step2/step2_gdr_coll_2x1_v1*`.
- `step2_gdr_coll_3x1_v1` — PBS job `67578.gaas`, 22:50 +08, g22+g20+g02,
  54 s, exit 0, PASS. **Valid A/B both tests** (bcast ctrl 24/8 vs 24/0;
  allreduce ctrl 40/14 vs 40/0). GDR gains: allreduce 64 MiB algbw +22%
  (23.39 vs 19.23; busbw 31.18 vs 25.64), bcast +3%; allreduce 1 MiB is
  GDR-on slower (2.53 vs 3.15 algbw, −25%) — small-size penalty noted.
  Evidence: `../../outputs/phase1-step2/step2_gdr_coll_3x1_v1*`.
- `step2_gdr_coll_3x4_v1` — PBS job `67581.gaas`, 22:51 +08, g22+g20+g02,
  12 ranks, 81 s, **exit 1 — SPLIT result.** Broadcast: **PASS, valid A/B,
  largest GDR gain of the whole campaign** — 64 MiB algbw **70.88 vs
  28.28 GB/s (+151%, 2.51×)**; 16 MiB +74%; 4 MiB +99%; 1 MiB +19%
  (ctrl 72 IB/24 GDRDMA vs gdroff 48/0). Allreduce: **ctrl arm FAILED
  before the first measured size** — NCCL internal error at
  `all_reduce.cu:507` after 6× mixed-link-type warnings (RoCE
  `mlx5_bond_0` vs IB HCAs) unique to this arm; gdroff arm passed (600
  IB/0 GDRDMA; 64 MiB algbw 18.85, busbw 34.56). The 3x4 allreduce cell is
  recorded FAILED/INCONCLUSIVE; classified Track 2, case
  `2026-09-17-A` in root `MANUAL_INSPECTION_ERROR.md` (options: unchanged
  retry / `NCCL_IB_HCA=^mlx5_bond` arm / reduced-rank diagnostic / upstream
  report — awaiting user decision). Evidence:
  `../../outputs/phase1-step2/step2_gdr_coll_3x4_v1*` (byte-verified).
- `step2_gdr_coll_3x4_v2` — PBS job `67584.gaas`, 2026-09-17 23:02 +08,
  same trio g22+g20+g02, 83 s, exit 0, `STEP2_GDR_COLL_RESULT=PASS`.
  **Track 2 case `2026-09-17-A` fix validated**: wrapper
  `run_phase1_step2_gdr_coll_3x4_hca.pbs` sets
  `NCCL_IB_HCA=mlx5_0,mlx5_1,mlx5_2,mlx5_3,mlx5_4,mlx5_5,mlx5_8,mlx5_9`
  (eight IB HCAs, RoCE bond excluded) for BOTH arms. Root cause of the v1
  ctrl-allreduce failure: that arm's channel plan assigned g22 rank 1's
  inter-node links to `mlx5_bond_0` (Dev 8, RoCE) while the peers used
  `mlx5_4` (IB) — incompatible link types at connect → ncclInternalError;
  no other arm used Dev 8. With the filter: zero bond channels in any arm;
  ctrl allreduce 628 IB/236 GDRDMA vs gdroff 600/0. **Recovered cell — 3x4
  allreduce (algbw): 64 MiB 43.92 vs 18.86 GB/s (+2.33×; busbw 80.51 vs
  34.57), 16 MiB +1.94×, 4 MiB +1.47×, 1 MiB +1.12×.** Broadcast reproduces
  v1 (+2.92× @64 MiB). Full case record: root
  `MANUAL_INSPECTION_ERROR.md` → `2026-09-17-A` (RESOLVED). Evidence:
  `../../outputs/phase1-step2/step2_gdr_coll_3x4_v2*` (byte-verified).
