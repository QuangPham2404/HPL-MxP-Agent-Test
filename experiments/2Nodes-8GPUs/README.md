# 2Nodes-8GPUs experiment area

HPL-MxP full-node N sweep on 2 GAAS nodes x 8 H200 GPUs (16 ranks, one rank
per GPU, process grid 4x4, row order). Single experiment family, small number
of arms: find the maximum N before the memory wall (OOM) and record
performance along the way.

## Structure

- `scripts/run_hplmxp_n_sweep.pbs` — parametrized PBS run script
- `outputs/` — attempt-specific PBS `.o`/`.e` evidence (tracked, never
  overwritten; every retry gets a new attempt label)

## Protocol (user-authorized 2026-09-17)

1. Smoke test at `N=500000`. If it does not succeed, stop and report.
2. On success, step `N` by `+100000` per run (600000, 700000, ...) until OOM.
   The run that OOMs is recorded as the memory wall; the series ends there.
3. Any non-OOM failure stops the series for manual inspection (Track 2).

## Fixed parameters

- `NB=3072` (user decision 2026-09-17), `nporder=row`
- Grid auto-derived: 16 ranks -> `nprow=4 npcol=4`
- `--gpu-affinity 0:1:2:3:4:5:6:7` (node-local rank -> local GPU)
- `--skip-tests 1` plus GPU monitoring flags (project convention)
- Project `hpc_ebslee`; queue `gpu_ded` by default, `gpu_as` allowed (both
  approved for this campaign; chosen per submission based on node
  availability and recorded per attempt)
- Resources: `select=2:ngpus=8`, `place=scatter`, `walltime=00:45:00`

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
qsub -q gpu_ded -v "N=500000,ATTEMPT=2x8-n-sweep_n500k_v1" \
     -o outputs/2x8-n-sweep_n500k_v1.o -e outputs/2x8-n-sweep_n500k_v1.e \
     scripts/run_hplmxp_n_sweep.pbs
```

## Validation

A run is valid only when PBS completes, the raw outputs exist, HPL-MxP
reports `PASSED` with a finite residual within tolerance, and a finite
`GFLOPS` value is present. OOM evidence: exit 137 / cgroup OOM kill /
CUDA out-of-memory / `bad_alloc`. Expected wall (host-RAM cgroup ~2000 GB
per node, FP64 matrix in host RAM, N^2*8/2 bytes per node): ~700000-800000.

## Run summary

| attempt | N | job id | queue | nodes | result | GFLOPS | per-GPU GFLOPS |
|---|---|---|---|---|---|---|---|
| 2x8-n-sweep_n500k_v1 | 500000 | 67383.gaas | gpu_ded | g01+g22 | PASSED (residual 3.06e-04), exit 0, walltime 00:02:04, mem ~996 GB/node | 2.9133e+06 | 1.8208e+05 |

## Runtime error-patching history

None yet.
