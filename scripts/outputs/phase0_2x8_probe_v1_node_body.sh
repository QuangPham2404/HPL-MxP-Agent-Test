#!/bin/bash
# Per-node capture body for the 2x8 Phase-0 probe. Invoked on every allocated
# vnode by the PBS script via:
#     pbsdsh -- /bin/bash <this-body> <outdir> <attempt> <lock_base> <sif>
# Read-only observation: no configuration changes, no installs, no benchmarks.
set -u

OUTDIR="${1:?usage: node body <outdir> <attempt> <lock_base> <sif>}"
ATTEMPT="${2:?missing attempt}"
LOCK_BASE="${3:?missing lock_base}"
SIF="${4:?missing sif}"

NODE="$(hostname)"
mkdir -p "$LOCK_BASE" 2>/dev/null || true
LOCK_DIR="${LOCK_BASE}/${NODE}"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "PHASE0_NODE_CAPTURE SKIP ${NODE} (already captured)"
    exit 0
fi
OUT="${OUTDIR}/${ATTEMPT}_node_${NODE}.log"

run_optional() {
    local label="$1"
    shift
    echo
    echo "### ${label}"
    if command -v "$1" >/dev/null 2>&1; then
        echo "+ $*"
        "$@"
        echo "[exit_status=$?]"
    else
        echo "[unavailable: command '$1' was not found]"
    fi
}

{
    echo "=== PHASE0_NODE_CAPTURE BEGIN ${NODE} attempt=${ATTEMPT} ==="
    echo "capture_start=$(date --iso-8601=seconds)"
    echo "pbs_job_id=${PBS_JOBID:-unset}"
    echo "node=${NODE}"

    echo
    echo "============================================================"
    echo "NODE SECTION 1: HOST IDENTITY AND OPERATING SYSTEM"
    echo "============================================================"
    run_optional "Kernel and architecture" uname -a
    run_optional "Operating-system release" bash -c "head -5 /etc/os-release"
    run_optional "Uptime and load" uptime

    echo
    echo "============================================================"
    echo "NODE SECTION 2: CPU TOPOLOGY AND FEATURES"
    echo "============================================================"
    run_optional "CPUs visible to this job task" nproc
    run_optional "All logical CPUs on the node" nproc --all
    run_optional "Detailed CPU topology" lscpu
    run_optional "CPU-to-core/socket/NUMA mapping" bash -c "lscpu -e=CPU,CORE,SOCKET,NODE,ONLINE"
    run_optional "CPU feature flags" bash -c "grep -m 1 '^flags' /proc/cpuinfo"

    echo
    echo "============================================================"
    echo "NODE SECTION 3: ALLOCATION-VISIBLE CPUSET AND AFFINITY"
    echo "============================================================"
    run_optional "Job-task cpuset and memory nodes" bash -c "grep -E 'Cpus_allowed_list|Mems_allowed_list' /proc/self/status"
    run_optional "Cpuset membership" bash -c "cat /proc/self/cpuset"
    run_optional "Task CPU affinity" taskset -cp "$$"

    echo
    echo "============================================================"
    echo "NODE SECTION 4: NUMA TOPOLOGY AND HOST MEMORY"
    echo "============================================================"
    run_optional "NUMA hardware summary" numactl -H
    run_optional "NUMA memory statistics" bash -c "numastat -m 2>&1 | head -30"
    run_optional "NUMA node memory files" bash -c 'for f in /sys/devices/system/node/node*/meminfo; do echo --- "$f"; head -4 "$f"; done'
    run_optional "Host memory summary" free -h
    run_optional "Key host-memory counters" bash -c "grep -E '^(MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo"

    echo
    echo "============================================================"
    echo "NODE SECTION 5: GPU INVENTORY, DRIVER, MEMORY, CLOCKS, POWER, PCIE"
    echo "============================================================"
    run_optional "GPU summary table (driver and CUDA banner)" bash -c "nvidia-smi 2>&1 | head -20"
    run_optional "GPU inventory" nvidia-smi -L
    run_optional "GPU state query (clocks, power, temperature, PCIe, VRAM)" nvidia-smi --query-gpu=index,name,uuid,pci.bus_id,driver_version,vbios_version,memory.total,memory.used,memory.free,pstate,temperature.gpu,fan.speed,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,clocks.max.graphics,clocks.max.memory,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max --format=csv
    run_optional "Detailed GPU information (full record)" nvidia-smi -q
    run_optional "GPU process accounting (probe-time contamination view)" nvidia-smi pmon -c 1
    run_optional "Compute processes using GPUs" nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv
    run_optional "Kernel NVIDIA driver record" bash -c "head -5 /proc/driver/nvidia/version"

    echo
    echo "============================================================"
    echo "NODE SECTION 6: GPU, PCIE, NVLINK, NVSWITCH, AND NIC TOPOLOGY"
    echo "============================================================"
    run_optional "GPU topology matrix (GPU/NIC/CPU/NUMA locality)" nvidia-smi topo -m
    run_optional "PCI devices relevant to GPU and fabric" bash -c "lspci -nn 2>/dev/null | grep -Ei 'NVIDIA|Mellanox|InfiniBand|Ethernet'"
    run_optional "Ethernet netdev NUMA locality" bash -c 'for d in /sys/class/net/*; do printf "%s numa_node=" "$(basename "$d")"; cat "$d/device/numa_node" 2>/dev/null || echo unknown; done'
    run_optional "InfiniBand device NUMA locality" bash -c 'for d in /sys/class/infiniband/*; do printf "%s numa_node=" "$(basename "$d")"; cat "$d/device/numa_node" 2>/dev/null || echo unknown; done'

    echo
    echo "============================================================"
    echo "NODE SECTION 7: INFINIBAND AND RDMA FABRIC STATE"
    echo "============================================================"
    run_optional "InfiniBand device-to-network mapping" ibdev2netdev
    run_optional "InfiniBand device and port status (state/link layer/rate)" ibstat
    run_optional "RDMA link inventory" rdma link
    run_optional "Network interfaces" ip -br link
    run_optional "InfiniBand class devices" bash -c "ls -la /sys/class/infiniband"

    echo
    echo "============================================================"
    echo "NODE SECTION 8: GPUDIRECT PEER-MEMORY AND GDR MODULE STATE"
    echo "============================================================"
    run_optional "Loaded GPU/RDMA kernel modules" bash -c "grep -iE 'nvidia_peermem|nv_peer_mem|gdrdrv|nv_rdma|mlx5_ib|mlx5_core|ib_uverbs|ib_core|rdma_ucm' /proc/modules || echo '[no matching modules loaded]'"
    run_optional "Peer-memory and GDR module sysfs state" bash -c "ls -d /sys/module/nvidia_peermem /sys/module/nv_peer_mem /sys/module/gdrdrv /sys/module/nv_rdma 2>&1"
    run_optional "nvidia_peermem version" bash -c "cat /sys/module/nvidia_peermem/version 2>&1"
    run_optional "NVIDIA peermem proc entry" bash -c "ls -la /proc/driver/nvidia/peermem 2>&1; cat /proc/driver/nvidia/peermem/version 2>&1"
    run_optional "GDR and NVIDIA capability devices" bash -c "ls -la /dev/gdrdrv 2>&1; ls -la /dev/nvidia-caps 2>&1"

    echo
    echo "============================================================"
    echo "NODE SECTION 9: CONTAINER RUNTIME AND STACK (THIS NODE)"
    echo "============================================================"
    if [ -x /usr/local/apptainer/1.4.1/bin/apptainer ]; then
        run_optional "Apptainer version (this node)" /usr/local/apptainer/1.4.1/bin/apptainer --version
    else
        run_optional "Apptainer version (this node)" apptainer --version
    fi
    run_optional "SIF image file (this node view)" bash -c "ls -la '$SIF' 2>&1; stat -c 'size=%s bytes mtime=%y' '$SIF' 2>&1"
    if [ -f "$SIF" ]; then
        # Same absolute-path preamble as the validated container bridge
        # (multi-node-test/rsh_pbsdsh_container.sh) so the encrypted-SIF
        # mount helpers are found without modules; bounded by timeout.
        export PATH="/usr/local/apptainer/1.4.1/bin:/usr/local/squashfuse/0.5.2/bin:/usr/local/gocryptfs/2.5.0/bin:${PATH}"
        export LD_LIBRARY_PATH="/usr/local/squashfuse/0.5.2/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
        echo
        echo "### Bounded in-container stack check (this node)"
        timeout 120 /usr/local/apptainer/1.4.1/bin/apptainer exec --nv "$SIF" bash -c '
            echo "container_hostname=$(hostname)"
            echo "--- container OS ---"
            head -3 /etc/os-release 2>/dev/null
            echo "--- container CUDA ---"
            head -8 /usr/local/cuda/version.json 2>/dev/null || cat /usr/local/cuda/version.txt 2>/dev/null || echo "[no cuda version file]"
            echo "--- container MPI ---"
            /usr/local/mpi/bin/mpirun --version 2>&1 | head -3
        '
        echo "[container_check_exit_status=$?]"
    else
        echo "[SIF not found from this node: $SIF]"
    fi

    echo
    echo "============================================================"
    echo "NODE SECTION 10: IN-JOB NODE STATE (CO-TENANT VIEW, BEST EFFORT)"
    echo "============================================================"
    run_optional "pbsnodes view of this node" bash -c "/opt/pbs/bin/pbsnodes '$NODE' 2>&1 | grep -E '^[[:space:]]*(state|np|gpus|jobs|resources_assigned\.(ncpus|ngpus|mem)|status) =' || echo '[pbsnodes fields unavailable]'"

    echo
    echo "capture_end=$(date --iso-8601=seconds)"
    echo "=== PHASE0_NODE_CAPTURE END ${NODE} ==="
} > "$OUT" 2>&1

echo "PHASE0_NODE_CAPTURE ${NODE} wrote ${OUT}"
