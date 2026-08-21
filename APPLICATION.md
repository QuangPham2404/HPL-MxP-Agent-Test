# HPL-MxP Application Overview

## Application

HPL-MxP is NVIDIA's mixed-precision distributed dense linear-system
benchmark. It uses mixed-precision arithmetic and Tensor Core acceleration on
NVIDIA GPU systems, with a higher-precision correction process and an HPL
harness for numerical verification.

- Application: NVIDIA HPL-MxP Benchmark, NVIDIA HPC Benchmarks container implementation
- Documentation: https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html
- Package release/source revision: NVIDIA HPC Benchmarks `v26.02`
- Release notes: https://docs.nvidia.com/nvidia-hpc-benchmarks/release_notes.html#v26-02
- Active cluster: GAAS
- Remote project root: `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test`

The `v26.02` release is the current release identified in NVIDIA's release
notes at the time this overview was prepared. The exact container image
digest and CUDA subdirectory (`cuda12` or `cuda13`) must be recorded after
the GAAS package/image is selected and before the first build or run.

## Dependencies and runtime environment

The NVIDIA package supplies the HPL-MxP executable and launch wrapper. The
runtime environment must provide:

- Linux with a compatible glibc and NVIDIA GPU or supported NVIDIA Grace CPU;
- a compatible CUDA runtime and NVIDIA driver;
- an MPI implementation supported by the selected package, such as MPICH or
  an ABI-compatible implementation;
- the package libraries and environment wrapper;
- PBS allocation on GAAS, with the application launched inside the batch job.

For GPU HPL-MxP, NVIDIA documents one GPU per MPI process. CUDA-aware MPI,
Cray MPICH GPU support, GPU transport libraries, and network/NCCL settings
are cluster- and package-dependent and must be recorded from the actual GAAS
environment before execution.

## Package layout and executable

The package contains `hpl-mxp.sh`, the launch wrapper, and an `xhpl_mxp`
executable under the relevant benchmark directory. The package's environment
wrapper sets the library paths; the run scripts are intended to remain within
the package directory structure.

## Build command

This is a prebuilt NVIDIA benchmark package rather than application source
that this project compiles. The build step is therefore package/image
acquisition and environment validation, not compilation. The exact command
will be recorded after the approved GAAS package or container location is
identified.

## Run command

For x86_64 NVIDIA GPU systems, the documented launcher form is:

```bash
./hpl-mxp.sh \
  --n <N> --nb <NB> --nprow <NPROW> --npcol <NPCOL> \
  --nporder row --gpu-affinity <GPU_INDICES>
```

The command runs inside a PBS job and must use the launcher and resource
syntax validated for GAAS. NVIDIA's documented multi-node example uses
`srun`, but this project uses PBS on GAAS, so the corresponding PBS launcher
form will be established from the cluster environment before submission.

Required HPL-MxP inputs are `--gpu-affinity`, `--nprow`, `--npcol`,
`--nporder`, `--n`, and `--nb`. Important optional or tuning inputs include
CPU, memory, and UCX affinity; `--tolerance` (default `1e-12`);
`--test-loop` (default `1`); `--sloppy-type` (`FP4`, `FP8`, or `FP16`);
`--u-panel-chunk-nbs`; MPI-panel-broadcast selection; device-fill controls;
GPU monitoring; and `--skip-tests`.

For NVIDIA Grace CPU-only systems, use `hpl-mxp-aarch64.sh` with the required
grid and matrix arguments plus CPU and memory affinity. The applicable GAAS
architecture will be confirmed before selecting this path.

## Correctness criteria and expected output

A run is correct only when all of the following are true:

1. PBS completes successfully and the expected stdout/stderr files exist.
2. The HPL-MxP harness reports successful verification.
3. The reported numerical error/residual is finite and within the configured
   tolerance; non-finite output such as `NaN` is invalid even if the process
   exits zero.
4. The run emits normal benchmark output, including a measured performance
   result, rather than stopping during initialization or internal tests.

The exact verification and performance-marker strings will be recorded from
the selected package's README/RUNNING guide and first validated output before
result extraction. NVIDIA documents the harness tolerance as `1e-12` by
default.

## Baseline command

The initial baseline is the unmodified NVIDIA package launch with the
package-default tuning parameters and a GAAS-compatible resource mapping:

```bash
./hpl-mxp.sh \
  --n <N> --nb <NB> --nprow <NPROW> --npcol <NPCOL> \
  --nporder row --gpu-affinity <GPU_INDICES> \
  --tolerance 1e-12 --test-loop 1
```

The concrete `N`, `NB`, processor grid, GPU affinity, PBS resource request,
MPI launcher, package path/image digest, and CUDA variant are baseline
metadata decisions to be confirmed against GAAS before the first submission.

## Primary references

- NVIDIA HPL-MxP documentation: https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html
- NVIDIA HPC Benchmarks overview: https://docs.nvidia.com/nvidia-hpc-benchmarks/overview.html
- NVIDIA HPC Benchmarks release notes: https://docs.nvidia.com/nvidia-hpc-benchmarks/release_notes.html
