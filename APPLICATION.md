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

Recorded GAAS runs use
`/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`.
The exact image digest and CUDA subdirectory remain unrecorded in this
overview; the filename identifies the recorded release, not an immutable
image revision. Capture these details in an approved provenance check before
new execution. Setup does not revalidate the cluster environment.

## Dependencies and runtime environment

The NVIDIA package supplies the HPL-MxP executable and launch wrapper. The
runtime environment must provide:

- Linux with a compatible glibc and NVIDIA GPU or supported NVIDIA Grace CPU;
- a compatible CUDA runtime and NVIDIA driver;
- the container's MPI runtime, used end-to-end for the validated multinode
  launch;
- the package libraries and environment wrapper;
- PBS allocation on GAAS, with the application launched inside the batch job.

The recorded GAAS launch uses one GPU per MPI process and modules
`apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`, and `gocryptfs/2.5.0`.
These are historical runtime metadata, not authorization to change modules.
Record GPU transport libraries and network/NCCL settings for each approved
execution environment.

## Package layout and executable

The package contains `hpl-mxp.sh`, the launch wrapper, and an `xhpl_mxp`
executable under the relevant benchmark directory. The package's environment
wrapper sets the library paths; the run scripts are intended to remain within
the package directory structure.

## Build command

This is a prebuilt NVIDIA benchmark package rather than application source
that this project compiles. The build step is therefore package/image
acquisition and environment validation, not compilation. Existing runs use
the SIF path above; no image acquisition or rebuild is authorized by setup.

## Run command

For x86_64 NVIDIA GPU systems, the documented launcher form is:

```bash
./hpl-mxp.sh \
  --n <N> --nb <NB> --nprow <NPROW> --npcol <NPCOL> \
  --nporder row --gpu-affinity <GPU_INDICES>
```

The command runs inside a PBS job. The validated multinode model is
`multi-node-test/HPL-MxP/run_hplmxp_baseline.pbs`; the recorded original 3×4
baseline command is preserved in
`experiments/3x4-baseline/run_3x4_baseline.pbs`. It uses Apptainer `--nv`,
the container's `/usr/local/mpi/bin/mpirun`, `/workspace/hpl-mxp.sh`, and
`multi-node-test/rsh_pbsdsh_container.sh`, with `/opt/pbs` and
`/var/spool/pbs` bound into the container. Use `place=scatter`, explicit
per-node hostfile slots, and one rank per GPU; do not set `mpiprocs`.
Follow `workflow/00-General-SSH-Rules.md` and the retained multinode adapter
for the complete launch gates. These references do not authorize submission.

New optimization runs use the root `AGENTS.md` controls:

```text
--skip-tests 1
--monitor-gpu 1
--monitor-gpu-interval 10
--monitor-gpu-pcie-width-warning 16
--monitor-gpu-pcie-gen-warning 5
```

New PBS scripts use accounting group `hpc_ebslee`. Preserve historical job
metadata as recorded rather than rewriting it to the current group.

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
3. The iterative-solver residual is finite and satisfies its configured
   tolerance, and the normalized HPL harness residual passes its verification
   criterion. These are different residual measures; do not compare the
   normalized harness value directly with the solver tolerance. Non-finite
   output such as `NaN` is invalid even if the process exits zero.
4. The run emits normal benchmark output, including a measured performance
   result, rather than stopping during initialization or internal tests.

Recorded stdout in
`experiments/3x4-baseline/outputs/3x4-baseline_v1.o` contains:

- `Solver iteration ... L-infinite residual = ...` for solver convergence;
- `||Ax-b||_oo / (EPS * (||A||_oo * ||x||_oo + ||b||_oo) * N)` followed by
  the finite normalized residual and `PASSED` or `FAILED`;
- `GFLOPS = ... , per GPU = ...` for the overall reported performance;
- `LU GFLOPS = ...` for performance excluding iterative refinement.

Use overall GFLOPS for the benchmark score. Preserve scheduler evidence
separately; application output alone does not establish PBS exit status.

## Baseline command

The historical single-node original baseline is `baseline-sweep_v1`,
documented in `experiments/baseline-sweep/README.md`: eight ranks on one node,
`N=370000`, `NB=1024`, 2×4 row grid, GPU affinity `0:1:2:3:4:5:6:7`,
and `1.4432e+06` GFLOP/s with PASSED verification. Its recorded PBS exit
status is unknown. The README records this application command, launched
through Apptainer and `mpirun -np 8 --bind-to none`:

```bash
/workspace/hpl-mxp.sh \
  --n 370000 --nb 1024 --nprow 2 --npcol 4 \
  --nporder row --gpu-affinity 0:1:2:3:4:5:6:7
```

The immutable original baseline for the 3-node × 4-GPU topology is separately
recorded as `3x4-baseline_v1`, PBS job `57232.gaas`: `N=480000`, `NB=1024`,
3×4 row grid, 12 ranks, local GPU affinity `0:1:2:3`, and
`4.0092e+04` GFLOP/s with normalized residual `3.402630E-04` and PASSED
verification. Its complete command and monitoring controls are preserved in
`experiments/3x4-baseline/run_3x4_baseline.pbs`, with raw `.o`/`.e` evidence
in that experiment's `outputs/` directory.

These are original baseline references, not new baseline selections or
performance conclusions. Keep comparisons topology-specific and include the
original baseline and percentage increase against it in authorized analysis.

## Primary references

- NVIDIA HPL-MxP documentation: https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html
- NVIDIA HPC Benchmarks overview: https://docs.nvidia.com/nvidia-hpc-benchmarks/overview.html
- NVIDIA HPC Benchmarks release notes: https://docs.nvidia.com/nvidia-hpc-benchmarks/release_notes.html
