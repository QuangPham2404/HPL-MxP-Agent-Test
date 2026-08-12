# NVIDIA HPL-MxP tuning-parameter guide

This guide explains the parameters exposed by NVIDIA's HPL-MxP launcher and connects them to the HPL/HPL-MxP mental model in the attached notes:

- `N` and `NB` define the global matrix and blocked-LU granularity.
- `P × Q` and `nporder` define the logical MPI process grid.
- The factorization still advances through panel factorization, panel distribution, triangular solves, and trailing updates; however, HPL-MxP moves much of the cubic work to low precision and uses the resulting LU factors as a preconditioner for FP64 GMRES-based iterative refinement.
- Therefore, a parameter can affect either the fast low-precision LU stage, the communication/synchronization around it, or the final refinement stage.

The explanations below are based on NVIDIA's [HPL-MxP benchmark documentation](https://docs.nvidia.com/nvidia-hpc-benchmarks/HPL_MxP_benchmark.html), checked on 12 August 2026. NVIDIA's web page gives concise command-line definitions; where it does not specify an implementation detail, the interpretation is marked as tuning guidance rather than a guaranteed internal behavior. The installed package's `README`, `RUNNING`, and `TUNING` files remain authoritative for the exact release you run.

## 1. The execution model to keep in mind

Your existing HPL picture is:

```text
panel factorization → panel broadcast → TRSM / triangular work
                     → trailing GEMM update → next panel
```

HPL-MxP keeps this blocked-LU structure, but the numerical role changes:

```text
low/mixed-precision LU → approximate x₀
                      → FP64 residual and GMRES iterative refinement
                      → accurate final x
```

This has two consequences for tuning:

1. `NB`, grid shape, affinity, and panel/GEMM scheduling still control the HPL-like LU pipeline.
2. A faster LU stage is not automatically better if it produces a poor preconditioner and causes many expensive refinement iterations. Always check both performance and successful final verification.

## 2. Parameter map

| Group | Parameters | Main question |
|---|---|---|
| Problem and grid | `--n`, `--nb`, `--nprow`, `--npcol`, `--nporder` | How is the distributed blocked matrix organized? |
| Device/process placement | `--gpu-affinity`, `--cpu-affinity`, `--mem-affinity` | Are logical ranks placed on suitable GPUs, cores, and NUMA nodes? |
| Network/transport | `--ucx-affinity`, `--ucx-tls`, `--mpi-use-mpi`, `--use-host-mpi` | Which communication path carries panel data? |
| LU scheduling | `--u-panel-chunk-nbs`, `--call-dgemv-with-multiple-threads`, `--prioritize-trsm`, `--prioritize-factorization`, `--use-separate-stream-for-gemm` | Which dependent operation is allowed to run first, and how much overlap is exposed? |
| GEMM and precision | `--preset-gemm-kernel`, `--sloppy-type`, `--Anq-device`, `--fill-device`, `--fill-device-buffer-size` | How aggressively is the low-precision compute path used? |
| Panel broadcast | `--use-mpi-panel-broadcast` | How much panel communication uses MPI versus NCCL? |
| Host-memory staging | `--cuda-host-register-step` | How much FP64 host data is pinned at a time? |
| Measurement and checking | `--tolerance`, `--test-loop`, monitoring flags, `--skip-tests`, `--gemm-iterations` | Is the run valid, repeatable, and diagnosable? |

## 3. Required problem and grid parameters

### `--n <int>` — global matrix dimension

`N` is the dimension of the dense matrix `A`: an `N × N` problem. It is the same global problem-size parameter you learned in HPL.

For the FP64 matrix representation, the rough raw storage is:

```text
8 × N² bytes
```

The actual footprint is larger because HPL-MxP also needs low-precision copies/conversions, panels, communication buffers, workspaces, and library allocations. Distributed memory reduces the amount owned by each rank, but does not remove the total-memory requirement.

**Performance effect:** larger `N` increases the useful cubic work, approximately proportional to `(2/3)N³`, and usually makes the GPUs spend a greater fraction of time in large GEMMs. This often improves sustained performance, provided the problem remains in memory.

**Tuning rule:** choose `N` as large as the memory budget safely permits. Leave headroom for runtime allocations; an `N` that barely fits can fail nondeterministically or force a slower memory path. Do not compare two parameter sets using different `N` values unless you explicitly want a problem-size study.

**HPL-MxP connection:** increasing `N` gives the low-precision LU stage more work to amortize, but it can also increase the amount of refinement work. The final FP64 residual check—not just the reported GFLOP/s—must remain successful.

### `--nb <int>` — blocking constant / panel size

`NB` is the width and height of the logical tiles used by blocked LU. A panel is approximately `NB` columns wide, and trailing updates operate on `NB`-sized blocks.

This is the direct bridge to your HPL notes:

- smaller `NB` → more panels, more panel dependencies and more messages, but smaller panel operations;
- larger `NB` → fewer panels and larger GEMM-like updates, but heavier panel factorization, larger communication chunks, and potentially worse load balance.

On GPUs, `NB` also influences whether the trailing update reaches efficient tensor-core/cuBLAS GEMM sizes. The best value is hardware-, CUDA-, topology-, and problem-dependent. Sweep it rather than assuming the largest value is best.

For your 8×H200 work, values such as 1024, 1280, 1536, 1792, and 2048 are sensible candidates around a known-good baseline, but the NVIDIA page does not prescribe an optimal value.

### `--nprow <int>` and `--npcol <int>` — processor-grid dimensions

These define the logical two-dimensional MPI grid:

```text
number of MPI ranks = nprow × npcol
```

NVIDIA states that the benchmark expects one GPU per MPI process. Therefore, on one 8-GPU node, normally use eight MPI processes and choose a factorization such as `1×8`, `2×4`, `4×2`, or `8×1`.

The grid controls the same tradeoff you studied:

- larger `P = nprow` distributes the active panel across more ranks in a process column, potentially reducing concentrated panel work but increasing panel-column cooperation and synchronization;
- larger `Q = npcol` creates wider process rows, potentially making panel/update broadcasts longer but reducing the number of ranks cooperating in a panel column.

For two 4-GPU NVLink islands, `2×4` row-major is a strong hypothesis: each logical process row can map to one 4-GPU island, keeping row communication local while using the two process columns for cross-island traffic. It is a hypothesis, not a rule—verify with `nvidia-smi topo -m` and benchmark `1×8`, `2×4`, and `4×2`.

### `--nporder row|column` — rank layout in the process grid

This is NVIDIA's command-line name for the row-major/column-major placement you know as PMAP.

For `P=2, Q=4`:

```text
row:       rank 0  rank 1  rank 2  rank 3
           rank 4  rank 5  rank 6  rank 7

column:    rank 0  rank 2  rank 4  rank 6
           rank 1  rank 3  rank 5  rank 7
```

It does not change the abstract grid shape; it changes which MPI ranks become row neighbors and column neighbors. Because panel cooperation and broadcasts follow those groups, `nporder` can change the physical communication path even when `nprow`, `npcol`, and GPU IDs are unchanged.

For two contiguous GPU islands numbered `0–3` and `4–7`, row-major mapping is a natural starting point for `2×4`, because ranks `0–3` and `4–7` can form island-local rows. A column-major mapping would mix the islands across rows under that numbering. Confirm the actual rank-to-GPU mapping rather than relying on rank numbers.

## 4. Affinity and placement parameters

### `--gpu-affinity <colon-separated GPU indices>`

This maps each local MPI rank to a GPU. NVIDIA expects one GPU per MPI process, so the list should have one entry per local rank, for example:

```text
--gpu-affinity 0:1:2:3:4:5:6:7
```

This is not merely bookkeeping. It determines whether the logical HPL rows/columns match the physical NVLink/NVL topology. A topology-unaware mapping can turn an intended intra-island broadcast into repeated cross-island traffic.

**Tune after choosing a grid:** keep `P`, `Q`, and `nporder` fixed, then test alternative rank-to-GPU mappings if the node's GPU numbering is not topology-contiguous.

### `--cpu-affinity <colon-separated CPU ranges>`

This assigns CPU cores to local MPI ranks. Host threads may participate in MPI progress, panel work, data movement, launch overhead, and parts of the refinement path. Binding ranks prevents migration and reduces contention.

Example shape:

```text
--cpu-affinity 0-13:14-27:28-41:42-55:56-69:70-83:84-97:98-111
```

The ranges must match the node's actual NUMA/CPU layout. Do not copy DGX examples blindly to a different cluster.

### `--mem-affinity <colon-separated NUMA indices>`

This assigns each rank's host-memory allocations to a NUMA node. It matters when buffers are initialized or accessed by the CPU, when communication is host-mediated, and when FP64 data is staged between host and GPU.

A good placement keeps a rank's CPU cores and memory close to the GPU it drives. Bad NUMA placement can make a nominally GPU-bound run sensitive to CPU socket and PCIe traffic.

### `--ucx-affinity <UCX devices>` and `--ucx-tls <UCX transports>`

These are primarily multi-node controls:

- `--ucx-affinity` selects the UCX network/device path;
- `--ucx-tls` selects the UCX transport(s).

They become important when panel data crosses nodes. On a single node, they are normally not first-line tuning parameters. On multiple nodes, record them with the job because changing the selected NIC or transport can change panel-broadcast and refinement communication latency.

### `--exec-name <path>`

Selects the HPL-MxP executable used by the launcher instead of its default `xhpl_mxp`. This is useful for testing a custom build or a different NVIDIA package binary. It changes no numerical algorithm by itself, but it is essential for reproducibility: record the executable, CUDA version, driver, and package release.

## 5. Launcher and validation controls

### `--tolerance <float>`

Sets the tolerance used by the HPL harness. NVIDIA lists `1e-12` as the default.

This is a pass/fail checking threshold, not a precision selector. It should not be loosened to make an unstable low-precision preconditioner appear successful. HPL-MxP intentionally uses low precision internally, but its refinement stage must recover a sufficiently accurate final solution.

Use a changed tolerance only for a controlled diagnostic experiment, and report it prominently.

### `--test-loop <int>`

Sets the number of benchmark loops. The default is `1`.

Use more than one loop to study run-to-run stability, thermal behavior, clock changes, and allocation/warm-up effects. For a clean tuning sweep, keep it fixed across all configurations. Report both the first iteration and steady-state behavior if warm-up effects are large.

### `--skip-tests <int>` and `--gemm-iterations <int>`

The package can run internal tests. `--skip-tests` disables them; `--gemm-iterations` controls the number of GEMM iterations in those tests, with a documented default of `100`.

These are diagnostic/startup controls, not intended performance knobs for the main HPL-MxP score. Keep internal tests enabled when validating a new installation or affinity configuration. Skip them only when you have already validated the environment and want to reduce test overhead in a controlled benchmark script.

## 6. Compute and scheduling controls

### `--preset-gemm-kernel <int>`

Selects a preset GEMM kernel. NVIDIA documents `0` as none and `80` as the SM80 preset, with default `0`.

The important caution is architectural: an SM80 preset is associated with the Ampere-generation kernel path. H200 is Hopper (SM90), so do not assume that selecting `80` is appropriate or faster. Start with `0` on H200 and only test another value if the installed release explicitly documents it for your GPU. Compare achieved GEMM throughput and end-to-end HPL-MxP time, not a microbenchmark alone.

### `--u-panel-chunk-nbs <int>`

Sets the U-panel chunk size in units of `NB` blocks; default `8`.

Recall that the U panel is involved in the triangular/update pipeline after panel factorization. A value of 8 means the implementation schedules the U-panel work in groups of roughly eight `NB`-sized chunks, subject to its internal layout.

- smaller values can expose finer-grained overlap and earlier readiness, but increase scheduling and communication overhead;
- larger values reduce overhead and may improve bulk throughput, but can delay consumers and reduce overlap.

This is a good second-stage sweep after `NB` and the process grid are stable.

### `--call-dgemv-with-multiple-threads <int>`

Controls host-thread parallelism when HPL-MxP calls DGEMV. The value is the number of rows each host thread handles; `0` means one thread calls DGEMV, the default.

DGEMV is matrix-vector work, not the dominant trailing GEMM. It can nevertheless appear in panel, correction, or auxiliary paths. Increasing parallelism may reduce CPU-side latency, but can steal cores from MPI progress or create oversubscription. Treat this as a targeted knob when CPU utilization or a panel/DGEMV phase is measurable—not as a first-line GPU-throughput knob.

### `--prioritize-trsm <int>`

Controls whether GEMMs wait for U-side TRSMs; default `0`.

TRSM is the triangular solve stage you already know from blocked LU. Setting this option changes dependency priority: GEMM work is held back so U-TRSM work can progress first. This may help when the solve path is starving the next update or when the critical path is dominated by TRSM readiness. It may hurt when GEMM throughput and overlap are already excellent.

Sweep `0` and `1` while recording phase timings. Do not interpret a higher GEMM utilization alone as success if TRSM or refinement becomes the bottleneck.

### `--prioritize-factorization <int>`

Controls whether GEMMs wait for panel factorizations; default `0`.

This is the analogous dependency-priority control for panel factorization. Enabling it can make the next panel ready sooner and reduce pipeline starvation, but it can also leave tensor cores idle while a large GEMM could have run independently.

This parameter is especially relevant to the HPL bottleneck you studied: panel factorization is synchronization-heavy and lies on the critical path. Test it when the panel timeline shows that the update stream is getting ahead of the next panel.

*Note: compared with `--prioritize-trsm`, this flag prioritize the WHOLE panel factorization process, which includes the TRSM (triangle-solve to find U), while the former only prioritze the TRSM step.*

### `--use-separate-stream-for-gemm <int>`

Controls whether GEMMs use a separate CUDA stream; default `1`.

The intended performance idea is concurrency: GEMM updates may overlap with panel, TRSM, communication, or other work when dependency constraints allow it. Setting `0` can simplify ordering or help diagnose synchronization issues, but usually reduces overlap.

The actual benefit depends on whether operations are independent, whether buffers are reused safely, and whether the GPU is already saturated. Compare end-to-end time and look for increased idle gaps, not just stream count.

*Note: stream is a "queue" for the GPU. Multiple streams in the GPU can be executed concurrently. This is for running GEMM in parralel with other steps in LU factorization.*

### `--use-mpi-panel-broadcast <int>`

Controls the percentage of panel-broadcast steps that use MPI. NVIDIA's example says `30` means the first 30% of steps use MPI; if the value is `0`, NCCL is used. The page lists default `1`.

This option is easy to misread. It is not simply “MPI enabled/disabled”; it is a percentage-based policy. The documentation's default of `1` means a small initial fraction uses MPI, while `0` selects NCCL for the panel-broadcast path.

Panel broadcast is the communication stage between panel calculation and trailing updates. MPI may be preferable for some multi-node or topology configurations; NCCL may be preferable for GPU-resident intra-node collectives. The best choice is empirical. Keep `P`, `Q`, affinities, and `NB` fixed while testing values such as `0`, `1`, and a larger percentage.

### `--mpi-use-mpi <int>`

Enables fallback to `MPI_Bcast`; default `0`.

This is distinct from `--use-mpi-panel-broadcast`: the latter selects how a percentage of panel-broadcast steps are assigned, while this option enables a fallback path using the MPI broadcast primitive. Use it as a troubleshooting or transport comparison control, especially when CUDA-aware collectives are unavailable or unstable.

### `--use-host-mpi`

Disables CUDA-aware MPI. Communication is therefore handled through a host-MPI path rather than directly using CUDA-aware buffers.

This can be useful if CUDA-aware MPI is misconfigured, but it commonly introduces extra device-host staging and synchronization. On a correctly configured GPU cluster it is normally a diagnostic fallback, not the preferred performance setting.

## 7. Precision and memory-placement controls

### `--sloppy-type <value>`

Selects the low-precision (“sloppy”) type used by the HPL-MxP computation. NVIDIA lists FP4, FP8, and FP16/`2`, with FP16 as the default. The page's syntax description is compact, so use `./hpl-mxp.sh --help` and the package release notes to confirm whether your build expects the string (`FP16`) or numeric encoding (`2`).

This is the most direct precision knob. Lower precision can increase tensor-core throughput and reduce data movement, but it also reduces range and accuracy. In your HPL-MxP model, the low-precision LU factors are a preconditioner, not the final answer; GMRES refinement must repair the error. A more aggressive type may therefore trade faster LU for more refinement iterations or even failed convergence.

Do not compare only the LU GFLOP/s. Record:

- total runtime;
- number of refinement iterations, if reported;
- final residual/verification status;
- any overflow, NaN, or convergence warning.

### `--Anq-device <int>`

Controls how many columns of the FP64 matrix are placed on the GPU. The default is `0`.

This is an FP64 residency control. It does not mean that the whole algorithm becomes FP64; it controls how much of the high-precision matrix representation is resident on the device. More device-resident FP64 data can reduce host-device movement during operations that need the original high-precision problem, but consumes GPU memory that could otherwise hold workspaces or low-precision data.

Use it when experimenting with the balance between device memory capacity, host-device transfers, and refinement/residual work. Keep it at default while first tuning `N`, `NB`, grid, and communication.

*Note: For HPL-MxP, the original FP64 matrix is not discarded, as it is needed for the iterative refinement (GMRES) step. Storing it in the GPU reduce transfer time and speed up IR, but it takes away VRAM for other computations.*

### `--fill-device <0|1>`

Controls whether the device is filled with the FP64 matrix. Default `0`. When enabled, it overrides `--Anq-device`.

This is a stronger device-residency policy than selecting a fixed number of columns. It may reduce transfers but can leave less memory for low-precision factors, buffers, and cuBLAS workspaces. On an in-core H200 run, test it only after establishing that memory capacity and the implementation's intended data path support it.

### `--fill-device-buffer-size <int>`

When `--fill-device=1`, specifies the device-memory buffer zone to leave unused, in MB; default `3048`.

The reserved zone protects space for driver allocations, cuBLAS workspaces, communication buffers, and runtime overhead. Decreasing it may permit more matrix data on the GPU but increases OOM and allocation-failure risk. Increasing it improves safety at the cost of less FP64 residency. Tune this only together with memory-use measurements.

### `--cuda-host-register-step <int>`

Controls how many FP64-matrix columns are CUDA-host-registered at a time; default `2048`.

Host registration pins pages so the GPU can access or transfer them efficiently. Registering too little at a time may increase registration overhead; registering too much can increase pinned-memory pressure and startup latency. This matters most when the FP64 matrix is host-resident or partially staged. It is usually not a first-line knob for a fully in-GPU, in-core configuration.

## 8. GPU monitoring parameters

Monitoring does not improve the algorithm; it helps explain bad results. All warning thresholds default to `0`, which means no warning threshold is configured.

### `--monitor-gpu <0|1>` and `--monitor-gpu-interval <seconds>`

Enables GPU monitoring and sets the sampling interval; default interval is `1` second. Monitoring too frequently can add small overhead and produce noisy logs; monitoring too infrequently can miss short throttling events.

### Warning thresholds

The following options print warnings when a measured value crosses the selected threshold:

| Option | Meaning |
|---|---|
| `--monitor-gpu-clock-warning <MHz>` | Warn if GPU clock falls below the threshold. |
| `--monitor-gpu-power-warning <W>` | Warn if GPU power rises above the threshold. |
| `--monitor-gpu-temp-warning <C>` | Warn if temperature rises above the threshold. |
| `--monitor-gpu-pcie-width-warning <width>` | Warn if negotiated PCIe width falls below the threshold. |
| `--monitor-gpu-pcie-gen-warning <generation>` | Warn if PCIe generation falls below the threshold. |

For your H200 tuning, these are valuable for separating algorithmic effects from hardware state. A run with lower GFLOP/s may simply be clock-limited, power-limited, thermally limited, or using an unexpected PCIe link. Use monitoring for diagnosis, then turn it off for the clean final measurement if it adds overhead.

## 9. Grace CPU-only parameters

The same page documents `hpl-mxp-aarch64.sh` for Grace CPU systems. The core parameters remain `--nprow`, `--npcol`, `--nporder`, `--n`, and `--nb`. The CPU-only launcher also supports `--cpu-affinity`, `--mem-affinity`, `--exec-name`, `--tolerance`, and `--u-panel-chunk-nbs`.

The GPU-specific options—GPU affinity, sloppy type, GPU FP64 residency, CUDA host registration, GPU monitoring, and GPU GEMM preset—do not apply to the CPU-only launcher. NVIDIA recommends binding MPI processes to NUMA nodes on Grace. This reinforces the same principle as the GPU case: logical rank placement must match physical memory locality.

## 10. What to tune first on your 8×H200 node

Use a controlled one-variable-at-a-time sequence:

1. **Validate the platform:** CUDA/driver/package version, `nvidia-smi topo -m`, GPU clocks, power, temperature, PCIe state, CPU and NUMA topology.
2. **Fix a safe large `N`:** use the largest value that leaves memory headroom.
3. **Sweep `NB`:** for example, 1024, 1280, 1536, 1792, and 2048.
4. **Sweep grid and layout:** `1×8`, `2×4`, `4×2`, and relevant `nporder` choices.
5. **Align affinity:** map logical rows to physical GPU islands; bind CPU cores and NUMA memory.
6. **Test panel communication:** compare NCCL-dominant and MPI-dominant policies using `--use-mpi-panel-broadcast`, then investigate `--mpi-use-mpi` or `--use-host-mpi` only when needed.
7. **Tune scheduling:** `--use-separate-stream-for-gemm`, `--prioritize-trsm`, `--prioritize-factorization`, and `--u-panel-chunk-nbs`.
8. **Tune precision only after the baseline is stable:** compare FP16/FP8/FP4 only if supported and verify refinement convergence.
9. **Use diagnostics:** internal tests and GPU monitoring to explain anomalies; disable extra diagnostics for final scoring.

For every run, keep constant: `N`, `NB`, rank count, executable, CUDA environment, input precision policy, tolerance, and measurement procedure. Record at least total runtime, reported HPL-MxP/LU performance, final verification, refinement behavior if available, GPU clocks/power/temperature, and the exact command line.

## 11. A sensible baseline command shape

For a single 8-GPU node with two presumed 4-GPU islands:

```bash
srun --ntasks-per-node=8 --cpu-bind=none --mpi=pmix \
  ./hpl-mxp.sh \
  --n 320000 \
  --nb 1536 \
  --nprow 2 \
  --npcol 4 \
  --nporder row \
  --gpu-affinity 0:1:2:3:4:5:6:7
```

Treat the values as a reproducible starting point, not a universal optimum. The exact `N` must be chosen from your memory budget, and the affinity list must be validated against the real topology.

## 12. Final mental checklist

When a result changes, ask which part of the HPL-MxP pipeline was affected:

- **`N`, `NB`:** amount and granularity of computation;
- **`P`, `Q`, `nporder`:** panel split and row/column communication groups;
- **affinity:** physical path taken by those logical groups;
- **broadcast/UCX/MPI options:** transport and synchronization cost;
- **stream/priority/chunk options:** overlap and critical-path scheduling;
- **sloppy type:** tensor-core speed versus preconditioner quality;
- **FP64 residency/registration:** host-device traffic and memory pressure;
- **monitoring/test options:** observability, not mathematical speed.

The most important HPL-MxP-specific warning is this: the fastest low-precision LU is not necessarily the fastest complete solver. HPL-MxP pays for LU, refinement, communication, and verification together. Optimize the time to a valid FP64-quality solution.

