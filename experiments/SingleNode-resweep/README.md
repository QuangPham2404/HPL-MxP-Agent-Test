# SingleNode-resweep

## Purpose

Evaluate an externally sourced single-node (1 node x 8 GPUs) HPL-MxP
configuration — the "cmax" configuration, provided by the user from a
CloudMax pod log (`cmax-hpl-mxp-1n-1786076245-179914-launcher/hpl-mxp`) — on
the GAAS 8xH200 single-node topology, and compare it against the historical
single-node records (`baseline-sweep_v1` original baseline and the
`factorization-priority` best `fp_0_1`).

The experiment is a scored single run (user decision 2026-09-18: v1 only, no
same-node paired control; comparisons against historical values therefore
carry the recorded 1-4% cross-node noise caveat).

## Fixed configuration (v1, literal cmax replication)

Problem/grid:

- `--n 356352` (116 x 3072, NB-aligned; ~127 GB FP64/rank, full device
  residency on H200's ~139 GB VRAM)
- `--nb 3072`
- `--nprow 4 --npcol 2 --nporder row`
- `--gpu-affinity 0:1:2:3:4:5:6:7` (identity map)

Compute/precision:

- `--preset-gemm-kernel 90` (effective default on SM90)
- `--sloppy-type FP16`
- `--Anq-device 0`

LU scheduling / communication:

- `--u-panel-chunk-nbs 8`
- `--call-dgemv-with-multiple-threads 15360` (cmax value; all previously
  tested non-zero values 128-640 regressed the solver phase at N=491520)
- `--prioritize-trsm 0`
- `--prioritize-factorization 0` (GAAS best used 1, a +3.5% win at
  N=491520/2x4 row)
- `--use-separate-stream-for-gemm 1`
- `--use-mpi-panel-broadcast 100` (GAAS runs used 50)
- `--mpi-use-host-threads 1`

Memory placement:

- `--fill-device 1`
- `--fill-device-buffer-size 3048`
- `--cuda-host-register-step 2048`

Measurement/validation controls (user decision 2026-09-18: literal cmax
replication, overriding the project's usual `--skip-tests 1` + GPU-monitoring
convention for optimization runs):

- `--skip-tests 0`
- `--monitor-gpu 0`
- `--tolerance 1e-12`, `--test-loop 1`
- `--gemm-iterations 100`, `--fp4-scaling-factor-a 1e-05`,
  `--mpi-use-mpi 0`, `--use-host-mpi 0` left at launcher defaults (same
  effective values as the cmax settings block)

GAAS-side fixed host control (cmax host env unknown; GAAS-established
envelope for this workload, from `omp-sweep`):

- `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`
- No explicit HPL `--cpu-affinity` / `--mem-affinity`

Container/launcher metadata:

- Container: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`
  (NVIDIA HPC Benchmarks v26.02), `apptainer exec --nv`
- Launch: container `mpirun -np 8 --bind-to none` (proven single-node
  pattern; no multinode bridge)
- Modules: `apptainer/1.4.1 nvhpc/26.3 squashfuse/0.5.2 gocryptfs/2.5.0`
- PBS: `select=1:ngpus=8`, `walltime=00:45:00`, accounting group
  `hpc_ebslee`, queue `gpu_as` (or `gpu_ded` if the cleanest eligible node
  lives there; both allowed per user decision 2026-09-18)

## Differences vs the GAAS single-node best (`fp_0_1`)

| Setting | cmax (this run) | GAAS best `fp_0_1` |
|---|---|---|
| n | 356352 | 491520 |
| grid | 4x2 row | 2x4 row |
| call-dgemv-with-multiple-threads | 15360 | 0 |
| prioritize-factorization | 0 | 1 |
| use-mpi-panel-broadcast | 100 | 50 |
| fill-device-buffer-size | 3048 | 2048 |

## Dependency-graph edges reopened by this configuration

If this configuration outperforms the current records, the following closed
conclusions reopen (per `planning/dependency-graph/README.md`):

- E07/E08 (N<->NB coupling and memory boundary): N moved 491520 -> 356352
- E09 (N -> grid/order): 4x2 row vs the 2x4-row winner established at
  N=491520 (grid already reversed once between N=399360 and N=491520)
- E14 (N -> FP64 residency): N=356352 is near full device residency
- E20/E21 (host runtime / N -> DGEMV partition): dgemv 15360 vs the
  "keep 0" conclusion
- E25 (panel transport interpretation): broadcast 100 vs the flat sweep
- E31 (factorization priority -> TRSM interpretation): factorization 0

## Run script

`run_single_node_resweep.pbs`, parameterized via `qsub -v "ATTEMPT=<label>"`:

```text
qsub -v "ATTEMPT=SingleNode-resweep_v1" \
     -o outputs/SingleNode-resweep_v1.o -e outputs/SingleNode-resweep_v1.e \
     [-q gpu_as|gpu_ded] \
     run_single_node_resweep.pbs
```

## Validation

A run is valid only when all of: PBS completes; expected raw outputs exist;
the echoed HPL-MxP settings block matches the intended configuration;
verification reports `PASSED` with a finite residual within the configured
tolerance; and a finite HPL-MxP `GFLOPS` value is present.

## Logged attempts

| Attempt | Config | PBS job | Node | Residual check | GFLOP/s | Evidence |
|---|---|---|---|---|---|---|
| `SingleNode-resweep_v1` | cmax 1x8 (above) | pending | pending | pending | pending | `outputs/SingleNode-resweep_v1.{o,e}` |

## Result

Pending.
