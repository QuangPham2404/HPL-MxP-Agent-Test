# Nsight Systems Profiling — Best Run Configuration

## Purpose

Capture an Nsight Systems (nsys) profile of the current best HPL-MxP run
configuration on GAAS, with the fill-device buffer and CUDA host-register step
both set to 2048. The profile is the input for analyzing the compute and
scheduling behavior of the HPL-MxP kernels (GEMM/kernel selection, LU
scheduling/overlap, panel communication mix) before the next optimization
direction.

This is a profiling run, not a performance sweep: the goal is the trace, not a
new GFLOP/s data point. No `results/metrics.csv` row is added for this run.

## Fixed config (the current best configuration)

- `--n 491520 --nb 3072 --nprow 2 --npcol 4 --nporder row`.
- `--gpu-affinity 0:1:2:3:4:5:6:7`, no `--cpu-affinity` / `--mem-affinity`.
- `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`.
- `--fill-device 1`.
- `--fill-device-buffer-size 2048` (buffer = 2048).
- `--cuda-host-register-step 2048` (register step = 2048).
- `--skip-tests 1`. GPU monitoring flags are omitted so the trace is not
  perturbed by monitor-induced sampling.

## Container and Nsight Systems

- Container: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`.
- Launcher: `/workspace/hpl-mxp.sh` inside the container.
- Nsight Systems binary (inside the container):
  `/usr/local/cuda-13.1/NsightSystems-cli-2025.6.1/target-linux-x64/nsys`
  (version 2025.6.1).
- Trace options: `--trace=cuda,nvtx,osrt,mpi --sample=cpu`.
- One profile per MPI rank (8 ranks), emitted via
  `-o .../hpl_mxp_rank_%q{OMPI_COMM_WORLD_RANK}`. Nsight Systems 2025.6.1
  writes native `.nsys-rep` report files.

## Run scripts

`run_nsight_systems.pbs` runs the profile of the fixed best config in a single
PBS job. Two lever variants add a single HPL-MxP flag on top of the best config
and export `.sqlite` traces (`--export=sqlite`) instead of `.nsys-rep`:

| Script | Variant | Output directory |
|---|---|---|
| `run_nsight_systems.pbs` | best config (baseline profile) | `outputs/nsys-trace/` |
| `run_nsight_systems_broadcast100.pbs` | `--use-mpi-panel-broadcast 100` | `outputs/nsys-trace-broadcast-100/` |
| `run_nsight_systems_chunk4.pbs` | `--u-panel-chunk-nbs 4` | `outputs/nsys-trace-chunk-4/` |

```text
cd experiments/nsight-systems
qsub run_nsight_systems.pbs
qsub run_nsight_systems_broadcast100.pbs
qsub run_nsight_systems_chunk4.pbs
```

## Output layout

Raw evidence lives under `outputs/`:

- `outputs/nsys-trace/hpl_mxp_rank_0.nsys-rep` … `hpl_mxp_rank_7.nsys-rep` —
  one profile per MPI rank (kept as-is, no sqlite export).
- `outputs/nsys-trace/hpl_stdout.log` — the HPL-MxP stdout (PASSED / GFLOP/s).
- PBS `.o`/`.e` job-level files.

The `.nsys-rep` traces are gitignored (`*.nsys-rep`) and remain on GAAS only.
Analysis is performed over SSH against the remote traces.

## Validation

A run is valid only when all of: PBS completes; the 8 `.nsys-rep` files and
`hpl_stdout.log` exist; and the HPL-MxP stdout reports `PASSED` with a finite
residual. The `.nsys-rep` files must be non-zero length and openable by
`nsys stats`.

## Logged attempts

| Attempt | PBS job | Node | Residual | files | Evidence |
|---|---|---|---|---|---|
| `nsight_systems_v1` | 53452 | hpc-gaas-g13 | PASSED (GFLOP/s 1.9668e+06) | 8 `.nsys-rep` | `outputs/nsys-trace/` |
| `nsight_systems_v2` (broadcast 100) | — | — | — | 8 `.sqlite` | `outputs/nsys-trace-broadcast-100/` |
| `nsight_systems_v3` (chunk 4) | — | — | — | 8 `.sqlite` | `outputs/nsys-trace-chunk-4/` |