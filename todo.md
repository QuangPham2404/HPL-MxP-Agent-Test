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

4. communciation: `--use-mpi-panel-broadcast <int>` and `--u-panel-chunk-nbs <int>` only (as u panel chunk may increase-decrease load, which can affect choice for MPI vs NCCL. sweep, then nsys the best run to see if the rank assymetry and delay improve.

5. rank assymetry and delay: Sweep: --prioritize-trsm <int>, --prioritize-factorization <int>,

6. Remaining: --use-separate-stream-for-gemm <int> (this is separate to the rest, combining and separating may or may not cause delay but can be tested when other are fixed)

## Notes

**Baseline results**

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

**Conatiner's launch script**

```bash
#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "$( readlink -f "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )
XHPL="$SCRIPT_DIR/xhpl_mxp"

if [[ -r "$SCRIPT_DIR/../hpc-benchmarks-gpu-env.sh" ]]; then
  source "$SCRIPT_DIR/../hpc-benchmarks-gpu-env.sh"
fi

# FIXME - workaround for Singularity
export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# FIXME - workaround for HPC-X 2.18
export UCC_LOG_LEVEL=error

export UCX_WARN_UNUSED_ENV_VARS=${UCX_WARN_UNUSED_ENV_VARS:-n}

export OMP_PROC_BIND=${OMP_PROC_BIND:-TRUE}
export OMP_PLACES=${OMP_PLACES:-sockets}

export MKL_DEBUG_CPU_TYPE=${MKL_DEBUG_CPU_TYPE:-5}

# Set OpenMPI Bcast settings
export OMPI_MCA_coll_tuned_use_dynamic_rules=${OMPI_MCA_coll_tuned_use_dynamic_rules:-1}
export OMPI_MCA_coll_tuned_bcast_algorithm=${OMPI_MCA_coll_tuned_bcast_algorithm:-3}
export OMPI_MCA_coll_tuned_bcast_algorithm_segmentsize=${OMPI_MCA_coll_tuned_bcast_algorithm_segmentsize:-4194304}

usage() {
  echo ""
  echo "$(basename "$0") [OPTION]"
  echo "    --gpu-affinity <string>                  REQUIRED. colon separated list of gpu indices"
  echo "    --cpu-affinity <string>                  OPTIONAL. colon separated list of cpu index ranges"
  echo "    --mem-affinity <string>                  OPTIONAL. colon separated list of memory indices"
  echo "    --ucx-affinity <string>                  OPTIONAL. colon separated list of UCX devices"
  echo "    --ucx-tls <string>                       OPTIONAL. UCX transport to use"
  echo "    --exec-name <string>                     OPTIONAL. HPL executable file"
  echo "HPL-MxP parameters:"
  echo "    --nprow <int>                            REQUIRED. Number of rows in the processor grid"
  echo "    --npcol <int>                            REQUIRED. Number of columns in the processor grid"
  echo "    --nporder <string>                       REQUIRED. "row" or "column" major layout of the processor grid"
  echo "    --n <int>                                REQUIRED. Size of N-by-N matrix"
  echo "    --nb <int>                               REQUIRED. NB: the blocking constant (panel size)"
  echo "    --tolerance <float>                      OPTIONAL. Tolerance of the HPL harness. [Default value = 1e-12]"
  echo "    --test-loop <int>                        OPTIONAL.number of test loops to run. [Default value = 1]"
  echo "    --u-panel-chunk-nbs <int>                OPTIONAL. U panel chunk size given in unit of NBs. [Default value = 8]"
  echo "    --call-dgemv-with-multiple-threads <int> OPTIONAL. Number of rows each host thread works on if calling dgemv with multiple threads. [Default value = 0 - only one thread to call dgemv]"
  echo "    --prioritize-trsm <int>                  OPTIONAL. Whether GEMMs wait for U TRSMs. [Default value = 0]"
  echo "    --prioritize-factorization <int>         OPTIONAL. Whether GEMMs wait for factorizations. [Default value = 1]"
  echo "    --use-separate-stream-for-gemm <int>     OPTIONAL. Using a separate stream for GEMMs. [Default value = 1]"
  echo "    --use-mpi-panel-broadcast <int>          OPTIONAL. Uing MPI for panel broadcasts: if not NCCL will be used. [Default value = 1]"
  echo "    --sloppy-type <int>                      OPTIONAL. Size of the sloppy type: 1 (FP8) or 2 (FP16). [Default value = 2]"
  echo "    --Anq-device <int>                       OPTIONAL. Number of columns of the FP64 matrix that should be placed on the device. [Default value = 0]"
  echo "    --cuda-host-register-step <int>          OPTIONAL. Number of columns of the FP64 matrix that are cudaHostRegister'd at a time. [Default value = 2048]"
  echo "    --mpi-use-mpi                            OPTIONAL. Fall back to use MPI_Bcast [Default value = 0]"
  echo "    --monitor-gpu <int>                      OPTIONAL. Monitoring GPUs during the run"
  echo "    --monitor-gpu-interval <float>           OPTIONAL. Time interval with which GPUs are monitored [seconds]"
  echo "    --monitor-gpu-clock-warning <int>        OPTIONAL. GPU clock below which warning is given [MHz]"
  echo "    --monitor-gpu-power-warning <int>        OPTIONAL. GPU power above which warning is given [W]"
  echo "    --monitor-gpu-temp-warning <int>         OPTIONAL. GPU temperature above which warning is given [C]"
  echo "    --monitor-gpu-pcie-width-warning <int>   OPTIONAL. PCIe width below which warning is given"
  echo "    --monitor-gpu-pcie-gen-warning <int>     OPTIONAL. PCIe gen below which warning is given"
  echo ""
}

info() {
  local msg=$*
  echo -e "INFO: ${msg}"
}

warning() {
  local msg=$*
  echo -e "WARNING: ${msg}"
}

error() {
  local msg=$*
  echo -e "ERROR: ${msg}"
  exit 1
}


# split the affinity string, e.g., '0:2:4:6' into an array,
# e.g., map[0]=0, map[1]=2, ...  The array index is the MPI rank.
read_gpu_affinity_map() {
    local affinity_string=$1
    readarray -t GPU_AFFINITY_MAP <<<"$(tr ':' '\n'<<<"$affinity_string")"
}

# split the affinity string, e.g., '0:2:4:6' into an array,
# e.g., map[0]=0, map[1]=2, ...  The array index is the MPI rank.
read_net_affinity_map() {
    local affinity_string=$1
    readarray -t NET_AFFINITY_MAP <<<"$(tr ':' '\n'<<<"$affinity_string")"
}

# split the affinity string, e.g., '0:2:4:6' into an array,
# e.g., map[0]=0, map[1]=2, ...  The array index is the MPI rank.
read_mem_affinity_map() {
    local affinity_string=$1
    readarray -t MEM_AFFINITY_MAP <<<"$(tr ':' '\n'<<<"$affinity_string")"
}

# split the affinity string, e.g., '0:2:4:6' into an array,
# e.g., map[0]=0, map[1]=2, ...  The array index is the MPI rank.
read_cpu_affinity_map() {
    local affinity_string=$1
    readarray -t CPU_AFFINITY_MAP <<<"$(tr ':' '\n'<<<"$affinity_string")"
}

# set PMIx client configuration to match the server
# enroot already handles this, so only do this under singularity
# https://github.com/NVIDIA/enroot/blob/master/conf/hooks/extra/50-slurm-pmi.sh
set_pmix() {
    if [ -d /.singularity.d ]; then
        if [ -n "${PMIX_PTL_MODULE-}" ] && [ -z "${PMIX_MCA_ptl-}" ]; then
            export PMIX_MCA_ptl=${PMIX_PTL_MODULE}
        fi
        if [ -n "${PMIX_SECURITY_MODE-}" ] && [ -z "${PMIX_MCA_psec-}" ]; then
            export PMIX_MCA_psec=${PMIX_SECURITY_MODE}
        fi
        if [ -n "${PMIX_GDS_MODULE-}" ] && [ -z "${PMIX_MCA_gds-}" ]; then
            export PMIX_MCA_gds=${PMIX_GDS_MODULE}
        fi
    fi
}

### main script starts here

HPL_MXP_PARAMS=""
# Read command line arguments
while [ "$1" != "" ]; do
  case $1 in
    --exec-name )
        XHPL=$2
        shift
        ;;
    --ucx-tls )
      if [ -n "$2" ]; then
        export UCX_TLS="$2"
      else
        usage
        exit 1
      fi
      shift
      ;;
    --ucx-affinity )
      if [ -n "$2" ]; then
        NET_AFFINITY="$2"
      else
        usage
        exit 1
      fi
      shift
      ;;
    --gpu-affinity )
      if [ -n "$2" ]; then
        GPU_AFFINITY="$2"
      else
        usage
        exit 1
      fi
      shift
      ;;
    --mem-affinity )
      if [ -n "$2" ]; then
        MEM_AFFINITY="$2"
      else
        usage
        exit 1
      fi
      shift
      ;;
    --cpu-affinity )
      if [ -n "$2" ]; then
        CPU_AFFINITY="$2"
      else
        usage
        exit 1
      fi
      shift
      ;;
    * )
      HPL_MXP_PARAMS+="$1 $2 "
      shift;
      ;;
  esac
  shift
done

if [[ -z "${GPU_AFFINITY}" ]]; then
    echo "List of GPUs is not defined"
    exit 1
fi

# Setup PMIx, if using
if [[ -z "${SLURM_MPI_TYPE-}" || "${SLURM_MPI_TYPE}" == pmix* ]]; then
  set_pmix
fi

read_rank() {
  # Global rank
  if [ -n "${OMPI_COMM_WORLD_RANK}" ]; then
    RANK=${OMPI_COMM_WORLD_RANK}
  elif [ -n "${PMIX_RANK}" ]; then
    RANK=${PMIX_RANK}
  elif [ -n "${PMI_RANK}" ]; then
    RANK=${PMI_RANK}
  elif [ -n "${SLURM_PROCID}" ]; then
    RANK=${SLURM_PROCID}
  else
    warning "could not determine rank"
  fi

  # Node local rank
  if [ -n "${OMPI_COMM_WORLD_LOCAL_RANK}" ]; then
    LOCAL_RANK=${OMPI_COMM_WORLD_LOCAL_RANK}
  elif [ -n "${SLURM_LOCALID}" ]; then
    LOCAL_RANK=${SLURM_LOCALID}
  elif [ -n "${MPI_LOCALRANKID}" ]; then
    LOCAL_RANK=${MPI_LOCALRANKID}
  else
    error "could not determine local rank"
  fi
}

if [[ -n "${NET_AFFINITY}" ]]; then
  read_rank
  read_net_affinity_map $NET_AFFINITY
  NET=${NET_AFFINITY_MAP[$LOCAL_RANK]}
  if [ -n "${NET}" ]; then
    export UCX_NET_DEVICES="$NET:1"
    export OMPI_MCA_btl_openib_if_include="$NET:1"
  fi
fi

if [[ -n "${GPU_AFFINITY}" ]]; then
  read_rank
  read_gpu_affinity_map $GPU_AFFINITY
  GPU=${GPU_AFFINITY_MAP[$LOCAL_RANK]}
  export CUDA_VISIBLE_DEVICES=${GPU}
fi

if [[ -n "${MEM_AFFINITY}" ]]; then
  read_rank
  read_mem_affinity_map $MEM_AFFINITY
  MEM=${MEM_AFFINITY_MAP[$LOCAL_RANK]}
  MEMBIND="--membind=${MEM}"
fi

if [[ -n "${CPU_AFFINITY}" ]]; then
  read_rank
  read_cpu_affinity_map $CPU_AFFINITY
  CPU=${CPU_AFFINITY_MAP[$LOCAL_RANK]}
  CPUBIND="--physcpubind=${CPU}"
fi

if [ -n "${MEMBIND}" ] || [ -n "${CPUBIND}" ]; then
  NUMCMD="numactl "
fi

${NUMCMD} ${CPUBIND} ${MEMBIND} ${XHPL} ${HPL_MXP_PARAMS}
```

