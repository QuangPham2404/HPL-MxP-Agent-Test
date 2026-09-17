# NCCL-tests 3-node × 4-GPU smoke test

## Purpose and scope

This is one functional smoke test of the host-native `nccl-tests` build on the
3-node × 4-GPU topology (12 MPI/NCCL ranks). It answers two questions:

1. Does one NCCL collective complete correctly on this topology?
2. Which NCCL network backend does the default configuration select for the
   collective data path: the IB plugin or Socket?

This smoke test is separate from the single-node build smoke and from the
Phase 1 Step 2 multi-arm sendrecv transport matrix. It has no A/B arms, forced
Socket/GDR settings, message-size sweep, performance comparison, or tuning
conclusion. Socket/bootstrap messages by themselves do not mean NCCL data
traffic fell back to sockets.

## Run definition

- Binary: `scripts/gaas-internode-coms-debug/build-nccl-tests/nccl-tests/build/all_reduce_perf`
- Stack: `nvhpc/26.3`, host HPC-X/OpenMPI, CUDA 13.1, NCCL 2.29.3.
- Layout: 3 distinct nodes, 4 MPI ranks per node, one visible GPU per rank.
- Test: one `all_reduce_perf` invocation at a fixed 1 MiB payload, one warmup,
  and two iterations. The output is used for functional correctness only.
- Launch: host `mpirun` and `multi-node-test/rsh_pbsdsh.sh`, following the
  working native-MPI recipe in Phase 1 Step 1. The HPL-MxP model contributes
  only the hostfile and local-rank-to-GPU mapping convention; its container
  launcher is not used for this host-native binary.
- NCCL settings: `NCCL_DEBUG=INFO` and network/topology diagnostics are enabled.
  `NCCL_IB_DISABLE`, `NCCL_NET`, `NCCL_NET_GDR_LEVEL`, `NCCL_IB_HCA`, and
  `NCCL_SOCKET_IFNAME` are unset so the run observes default network selection.

## Node selection and submission

Before each submission, inspect `pbsnodes -aSj`. Choose the cleanest three
eligible distinct nodes from `gpu_as` or `gpu_ded`, and use the queue matching
those nodes. `gpu_free` is currently disabled. Reserve four GPUs, 48 CPUs, and
1000 GB per node, matching the established clean-node shape. Do not specify
`mpiprocs`; the script derives 12 ranks from the topology. Use PBS group
`hpc_ebslee`.

Run from this directory on GAAS after the reviewed commit has been synchronized
and the persistent SSH check succeeds. The output directory is tracked with the
repository, but PBS still requires it to exist before submission.

```bash
pbsnodes -aSj
mkdir -p outputs
qsub -q <gpu_as-or-gpu_ded> \
  -l "select=host=<node1>:ngpus=4:ncpus=48:mem=1000GB+host=<node2>:ngpus=4:ncpus=48:mem=1000GB+host=<node3>:ngpus=4:ncpus=48:mem=1000GB" \
  -v "ATTEMPT=nccl_tests_3x4_smoke_v1,REQ_HOSTS=<node1>+<node2>+<node3>" \
  run_nccl_tests_smoke_3x4.pbs
```

Submit one job only. For any retry, choose a new `ATTEMPT` and new PBS `.o` / `.e`
names with `qsub -o` and `qsub -e`; preserve all earlier output.

## Validation and readout

The functional smoke passes when PBS completes with exit status 0, the script
confirms three requested/granted nodes and four local ranks per node, and
`all_reduce_perf` reports `Out of bounds values : 0 OK`. The script prints
rank/host/local-rank/GPU mappings and preserves the combined NCCL/application
log under `outputs/`.

Classify the selected data backend from NCCL `NET` lines in that log:

- `NET/IBext_v11` or another `NET/IB` backend together with selected HCA
  details indicates NCCL selected the IB data network.
- `NET/Socket` together with the selected interface indicates NCCL selected
  its Socket data network.
- A bootstrap/socket line alone describes NCCL setup/control traffic; use the
  network plugin selection and data-channel lines to classify the collective.
- If the log does not clearly identify the selected data backend, report
  transport as inconclusive even if the collective passes.

A Socket result is a valid smoke-test observation, not a script failure. This
test does not force either transport and does not compare performance.

## Current attempt

`nccl_tests_3x4_smoke_v1` is committed and pushed as `b34738d`, but has not
been synchronized to GAAS or submitted. The GAAS preflight command
`ssh -O check gaas` returned `No ControlPath specified`, so the required
persistent-connection gate did not pass. No remote inspection, synchronization,
node probe, or PBS submission was performed in this attempt.
