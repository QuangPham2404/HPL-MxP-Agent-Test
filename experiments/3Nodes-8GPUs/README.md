# 3Nodes-8GPUs experiment area

HPL-MxP full-node N sweep on 3 GAAS nodes x 8 H200 GPUs (24 ranks, one rank
per GPU, process grid 4x6, row order). Single experiment family, small number
of arms: find the maximum N before the memory wall (OOM) and record
performance along the way.

**Status (2026-09-17): ON HOLD before first submission** — user paused the
series because too few fully-free 8-GPU nodes were available in the approved
queues at the time. Nothing has been run from this directory yet. The run
script is prepared, committed, and synced to GAAS (commit `0d90604` or
later); a resuming session only needs to verify the queue state, then submit
the smoke test below with user confirmation.

## Structure

- `scripts/run_hplmxp_n_sweep.pbs` — parametrized PBS run script
- `outputs/` — attempt-specific PBS `.o`/`.e` evidence (tracked, never
  overwritten; every retry gets a new attempt label)

## Protocol (user-authorized 2026-09-17)

1. Smoke test at `N=500000`. If it does not succeed, stop and report.
2. On success, step `N` by `+100000` per run (600000, 700000, ...) until OOM.
   The run that OOMs is recorded as the memory wall; the series ends there.
3. Any non-OOM failure stops the series for manual inspection (Track 2).

Execution order: the 2Nodes-8GPUs series runs first; this series starts only
after the user reviews those results. The 2x8 N-sweep completed on 2026-09-17
(peak 4.1061e+06 GFLOPS at N=700000; device-HBM CUDA-OOM wall at N=800000),
and the 3x8 series was subsequently put on hold by the user (node
availability), before any 3x8 submission.

## Fixed parameters

- `NB=3072` (user decision 2026-09-17), `nporder=row`
- Grid auto-derived: 24 ranks -> `nprow=4 npcol=6`
- `--gpu-affinity 0:1:2:3:4:5:6:7` (node-local rank -> local GPU)
- `--skip-tests 1` plus GPU monitoring flags (project convention)
- Project `hpc_ebslee`; queue `gpu_ded` by default, `gpu_as` allowed (both
  approved for this campaign; chosen per submission based on node
  availability and recorded per attempt)
- Resources: `select=3:ngpus=8`, `place=scatter`, `walltime=00:45:00`

## Launch contract

Validated Approach-1 multinode launch (see
`multi-node-test/GAAS_MULTINODE_SETUP.md`): container `mpirun` +
`multi-node-test/rsh_pbsdsh_container.sh` bridge, `/opt/pbs` and
`/var/spool/pbs` bound into the container, de-duplicated hostfile with
`slots=8`, fixed daemon flags (`plm_rsh_no_tree_spawn=1`,
`plm_rsh_num_concurrent=1`, `routed=direct`, `--bind-to none`), and
`-x PATH -x LD_LIBRARY_PATH` so remote ranks resolve NVML. One job at a
time; no concurrent multinode submissions.

## Submission (from this directory)

```bash
qsub -q gpu_ded -v "N=500000,ATTEMPT=3x8-n-sweep_n500k_v1" \
     -o outputs/3x8-n-sweep_n500k_v1.o -e outputs/3x8-n-sweep_n500k_v1.e \
     scripts/run_hplmxp_n_sweep.pbs
```

## Validation

A run is valid only when PBS completes, the raw outputs exist, HPL-MxP
reports `PASSED` with a finite residual within tolerance, and a finite
`GFLOPS` value is present. OOM evidence: exit 137 / cgroup OOM kill /
CUDA out-of-memory / `bad_alloc`.

Expected wall, refined by the 2x8 finding (2026-09-17) that the binding
constraint is the **device HBM** (FP32 device matrix, ~4 B/element:
`_mat_sp_dev` cudaMalloc), not host RAM: device ceiling
N ≈ sqrt(139.8 GB x 24 GPUs / 4 B) ≈ 915000; host-RAM cgroup (~2 TB/node,
N^2*8/3 bytes per node) would bind at ~890000. Predicted wall: between
850000 and 920000, likely the host-RAM cgroup just before the device
ceiling. The 2x8 series OOM'd via device HBM at N=800000 while host RAM
still had ~238 GB headroom per process — check both failure modes in the
`.e` evidence when the wall is hit.

## Run summary

| attempt | N | job id | queue | nodes | result | GFLOPS | per-GPU GFLOPS |
|---|---|---|---|---|---|---|---|

## Runtime error-patching history

None yet.
