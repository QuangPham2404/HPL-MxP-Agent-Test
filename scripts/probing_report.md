# Compute-node hardware probing report

## Probe identity and scheduler result

- Probe script: [compute_node_hardware_probe_v1.pbs](compute_node_hardware_probe_v1.pbs)
- Successful attempt: compute_node_hardware_probe_v1.1
- PBS job: 50474.gaas
- Allocated node: hpc-gaas-g11
- Allocation: 1 node, 96 CPUs, 8 GPUs, 2000 GB memory, 10-minute walltime
- Runtime: 4 seconds
- PBS exit status: 0 (job_state=F)
- Raw stdout: [compute_node_hardware_probe_v1.1.o](outputs/compute_node_hardware_probe_v1.1.o)
- Raw stderr: [compute_node_hardware_probe_v1.1.e](outputs/compute_node_hardware_probe_v1.1.e)

The first attempt, PBS job 50473.gaas, failed at the NUMA node-memory loop
because of an outer-shell quoting defect. Its raw evidence is preserved as
[compute_node_hardware_probe_v1.o](outputs/compute_node_hardware_probe_v1.o)
and [compute_node_hardware_probe_v1.e](outputs/compute_node_hardware_probe_v1.e).
The corrected retry completed the full probe.

## CPU

- Architecture: x86_64
- CPU: Intel Xeon Platinum 8570
- Logical CPUs: 112
- Sockets: 2
- Cores per socket: 56
- Threads per core: 1
- CPU frequency range reported: 800–4000 MHz
- GPU topology affinity:
  - GPUs 0–3: CPUs 0-49, NUMA node 0
  - GPUs 4–7: CPUs 56-101, NUMA node 1
- Relevant reported features include AVX2, AVX-512, AVX-VNNI, BF16, FP16,
  AMX-BF16, and AMX-INT8.

## NUMA and host memory

- NUMA nodes: 2
- Node 0 CPUs: 0-55
- Node 1 CPUs: 56-111
- NUMA distance: local 10, remote 21
- Node 0 memory: approximately 1,031,576 MB total and 920,346 MB free
- Node 1 memory: approximately 1,032,171 MB total and 757,177 MB free
- Combined memory: approximately 2,063,747 MB total and 1,677,523 MB free
- lstopo-no-graphics was unavailable. numactl, numastat, lscpu, and sysfs
  NUMA data were available.

## GPUs and VRAM

- GPU count: 8
- GPU model: NVIDIA H200, all eight devices
- GPU memory per device: 143771 MiB total
- Initial memory query: 0 MiB used and 143156 MiB free per GPU
- Driver: 580.126.20
- CUDA version reported by nvidia-smi: 13.0
- VBIOS: 96.00.DA.00.16
- Initial temperatures: 29–32 C
- Initial graphics clock: 345 MHz
- Initial memory clock: 3201 MHz
- GPU topology reports every GPU-to-GPU path as NV18.

## GPU, CPU, NUMA, and fabric topology

The nvidia-smi topo -m matrix reports:

- GPUs 0–3 are associated with CPU affinity 0-49 and NUMA node 0.
- GPUs 4–7 are associated with CPU affinity 56-101 and NUMA node 1.
- GPU pairs are connected through NV18 paths.
- NIC locality differs by GPU group: GPUs 0–3 show local PIX/NODE paths
  to NICs 0–3 and SYS paths to the other NIC group; GPUs 4–7 show the
  complementary pattern.
- PCI inventory identifies eight NVIDIA GH100 H200 SXM devices and an
  NVIDIA GH100 NVSwitch device.

The explicit nvidia-smi -q -d PCI command was not accepted by the installed
nvidia-smi syntax and returned exit status 2. The topology matrix and PCI
inventory were still collected successfully. The explicit per-GPU nvidia-smi
nvlink --status form was also unsupported and returned exit status 255 for
all GPUs; the NV18 matrix is the available NVLink evidence.

## Network and InfiniBand fabric

- Eight active ConnectX-7 InfiniBand ports were mapped by ibdev2netdev:
  mlx5_0 through mlx5_5, mlx5_8, and mlx5_9.
- Each mapped InfiniBand port reported Up.
- ibstat reported active/link-up ports at rate 400 for the sampled adapters.
- An active mlx5_bond_0 link was also reported.
- The node exposes bond0, VLAN interfaces, two active Ethernet slaves, and
  the eight active InfiniBand interfaces.
- mst status was unavailable to the non-root probe and returned exit status 1.

## Software and scheduler environment

- Kernel: 5.14.0-611.36.1.el9_7.x86_64
- OS: Rocky Linux 9.7
- nvidia-smi was available and reported the driver/CUDA versions above.
- mpirun, apptainer, and nvc were not available in the unmodified probe
  environment.
- No modulefiles were loaded for the probe.
- PBS allocated 96 CPUs, 8 GPUs, and 2000 GB memory on hpc-gaas-g11.

## Evidence limitations

- This was a read-only observation job, not an application run; PBS
  resources_used.mem and resources_used.vmem describe the small probe process,
  not total node memory consumption.
- GPU memory values are an initial point-in-time inventory, not peak usage
  during HPL-MxP.
- The probe did not load the application module environment, so MPI/container
  availability reflects the base batch environment.
- The raw output contains complete command results and optional-tool statuses.

## Provenance

- Probe script: [compute_node_hardware_probe_v1.pbs](compute_node_hardware_probe_v1.pbs)
- Successful raw outputs: [outputs/](outputs/)
- Failed attempt record: [README.md](README.md)
- Successful PBS job: 50474.gaas
- Probe node: hpc-gaas-g11
- Probe completion timestamp: 2026-08-20T17:00:12+08:00
