# TODO and NOTES

This is for user's use. Agents do not need to execute these todos unless specified.

## Todo

1. Inspect output from baseline (DONE)

2. Pull hpl-mxp.sh from container to host to see if the web page captures all tuning param (DONE - use baseline output as source of truth)

3. Proceed to tune simple starting param before proceeding to deeper optimization (hardware-track only, software track later)
- Push `--n`
- Sweep `--nprow` and `--npcol` and then `--nporder` --> re-verify results
- Balance `--nb` --> couple with `n`, nearly there, just need some final clarifications
- Analyse key steps with NVIDIA NSIGHT
- **POSSIBLE BOTTLENECK: System RAM is filled but VRAM is NOT**

## Notes
- From baseline run results, we see some of the params are different from the guide, including:
	- --mpi-use-host-threads = 1 (not mentioned in guide)
	- --fp4-scaling-factor-a = 1e-5 (not mentioned in guide)
	- --preset-gemm-kernel               = 90 (guide only accept 0 or 80 for Ampere structure)

- Furthermore, preserve the baseline run param output, as this is the actual default values for the params:

```txt
 ****** HPL MxP Settings ****** 

   --nprow =  2 
   --npcol =  4 
   --order = row 
   --n     = 370000 
   --nb    = 1024 
   --tolerance                        = 1.000000e-12 
   --test-loop                        = 1 
   --preset-gemm-kernel               = 90 
   --u-panel-chunk-nbs                = 8 
   --call-dgemv-with-multiple-threads = 0 
   --prioritize-trsm                  = 0 
   --prioritize-factorization         = 0 
   --use-separate-stream-for-gemm     = 1 
   --use-mpi-panel-broadcast          = 50 
   --mpi-use-host-threads             = 1 
   --sloppy-type                      = FP16 
   --Anq-device                       = 0 
   --cuda-host-register-step          = 2048 
   --mpi-use-mpi                      = 0 
   --use-host-mpi                     = 0 
   --fill-device                      = 0 
   --fill-device-buffer-size          = 3048 
   --fp4-scaling-factor-a             = 1.000000e-05 
   --skip-tests                       = 0 
   --gemm-iterations                  = 100 
```

- Also, remember to check the output of the runs for clues to analyse. For the baseline runs, we see that (1) VRAM is not filled and
 (2) GMRES time ~ factorization time, meaning that GMRES is a true bottleneck.

- Some notes on calculating metrics

```txt
ranks = nodes × GPUs_per_node
  Nraw = floor(sqrt(ranks × GPU_memory_bytes × 0.85 / 8))

  NBtarget = Nraw / (43 × sqrt(ranks))
  NB = clamp(round_to_nearest_1024(NBtarget), 2048, 8192)

  N = floor(Nraw / NB) × NB
  P × Q = squarest factorization of ranks, with P >= Q

  This makes NB proportional to sqrt(per-GPU VRAM) and independent of node count for the same GPU type.

  Other automatic settings:

  process order = row
  MPI panel broadcast = 100%
  DGEMV worker threads = physical cores/rank - 1
  local_blocks = ceil(ceil(N / NB) / P)
  DGEMV rows/thread = ceil(local_blocks / worker_threads) × NB
  U-panel chunk = max(8, floor((N / NB) / (20 × Q)) + 1)

on how to derive the optimal number without sweep (this is emprical on a 2 nodes of b300 sxm but most of them should transfer) 
```