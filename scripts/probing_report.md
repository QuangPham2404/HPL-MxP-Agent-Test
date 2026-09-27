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

## 2x8 Phase-0 supplement (2026-09-27)

This section is an append-only supplement to the 2026-08-20 single-node
report above, written from the completed read-only 2x8 Phase-0 probe
(TASK-000 deliverable A). It records only facts that are new, current, or
corrective relative to the historical body; the historical body above is
unchanged.

### Supplement probe identity and scheduler result

- Attempt: phase0_2x8_probe_v1 ([phase0_2x8_probe_v1.pbs](phase0_2x8_probe_v1.pbs))
- PBS job: 72591.gaas
- Queue: gpu_as; project: hpc_ebslee
- Resource request: `select=host=hpc-gaas-g12:ngpus=8:ncpus=96:mem=2000GB+host=hpc-gaas-g15:ngpus=8:ncpus=96:mem=2000GB`, `place=scatter`, walltime 00:30:00, no mpiprocs. The in-script `select=2:ngpus=8` was overridden by the host-pinned qsub command line.
- Allocated nodes: hpc-gaas-g12 + hpc-gaas-g15 exactly
  (`exec_vnode = (hpc-gaas-g12:ngpus=8:ncpus=96:mem=2097152000kb)+(hpc-gaas-g15:ngpus=8:ncpus=96:mem=2097152000kb)`,
  `exec_host = hpc-gaas-g12/0*96+hpc-gaas-g15/0*96`)
- Job totals: Resource_List.ncpus = 192, ngpus = 16, mem = 4000gb, nodect = 2
- Result: Exit_status = 0, job_state = F, substate = 92,
  resources_used.walltime = 00:00:34;
  probe_end_time=2026-09-27T08:01:31+08:00 (PBS obittime Sun Sep 27
  08:01:33 2026)
- Prior never-ran attempts preserved as evidence: 72556.gaas (gpu_ded,
  cancelled while queued) and 72590.gaas (gpu_ded, never ran; job_state F /
  substate 91 after user-authorized qdel; comment "Insufficient amount of
  resource: Qlist")
- Raw stdout: [outputs/phase0_2x8_probe_v1.o](outputs/phase0_2x8_probe_v1.o)
- Raw stderr: [outputs/phase0_2x8_probe_v1.e](outputs/phase0_2x8_probe_v1.e)
- Per-node captures (via the pbsdsh node body
  [outputs/phase0_2x8_probe_v1_node_body.sh](outputs/phase0_2x8_probe_v1_node_body.sh)):
  [outputs/phase0_2x8_probe_v1_node_hpc-gaas-g12.log](outputs/phase0_2x8_probe_v1_node_hpc-gaas-g12.log)
  and
  [outputs/phase0_2x8_probe_v1_node_hpc-gaas-g15.log](outputs/phase0_2x8_probe_v1_node_hpc-gaas-g15.log)
- Submission and bounded-monitoring evidence:
  [outputs/phase0_2x8_probe_v1_job_pinned_g12_g15_submission.log](outputs/phase0_2x8_probe_v1_job_pinned_g12_g15_submission.log)
  and
  [outputs/phase0_2x8_probe_v1_job72591_qstat_monitor.log](outputs/phase0_2x8_probe_v1_job72591_qstat_monitor.log)

### Cross-node consistency: hpc-gaas-g12 vs hpc-gaas-g15

Mechanical comparison of the two per-node capture logs (2809 lines each):

| Compared dimension | Verdict | Values (identical on both nodes unless stated) |
| --- | --- | --- |
| Kernel / OS | match | Linux 5.14.0-611.36.1.el9_7.x86_64; Rocky Linux 9.7 (Blue Onyx) |
| CPU model and topology | match | INTEL(R) XEON(R) PLATINUM 8570; 112 logical CPUs; 2 sockets; 56 cores per socket; 1 thread per core; NUMA node 0 CPUs 0-55, node 1 CPUs 56-111; NUMA distance local 10 / remote 21 |
| Allocation-visible CPUs | match | nproc 96; nproc --all 112; Cpus_allowed_list 0-49,56-101; Mems_allowed_list 0-1 |
| GPU count / model / VRAM | match | 8x NVIDIA H200; 143771 MiB total, 0 MiB used, 143156 MiB free per GPU |
| GPU VBIOS / driver / CUDA banner | match | VBIOS 96.00.DA.00.16; driver 580.126.20; nvidia-smi CUDA Version 13.0 |
| Kernel driver record | match | NVRM 580.126.20, Wed Feb 18 05:56:34 UTC 2026, built with GCC 11.5.0 |
| GPU-CPU-NUMA affinity pattern | match | GPUs 0-3: CPU affinity 0-49, NUMA node 0; GPUs 4-7: 56-101, NUMA node 1; every GPU-GPU path NV18 |
| GPU-NIC topology matrix | match | identical PIX/NODE/SYS pattern; NIC0-NIC3 (mlx5_0-mlx5_3) PIX to GPUs 0-3; NIC4-NIC7 (mlx5_4, mlx5_5, mlx5_8, mlx5_9) PIX to GPUs 4-7; NIC8 (mlx5_bond_0) PIX to GPU5 and NIC5 |
| PCI inventory | match | eight GH100 [H200 SXM 141GB] devices, four GH100 NVSwitch bridges, eight ConnectX-7 MT2910 adapters, BlueField-3 MT43244 |
| NIC/IB inventory and NUMA locality | match | mlx5_0, mlx5_1, mlx5_2, mlx5_3 on NUMA node 0; mlx5_4, mlx5_5, mlx5_8, mlx5_9, mlx5_bond_0 on NUMA node 1; identical sysfs PCI paths |
| IB port/link state | match | each ConnectX-7 adapter: 1 port, CA type MT4129, firmware 28.46.3048, State Active, Physical state LinkUp, Rate 400, Link layer InfiniBand, SM lid 23; mlx5_bond_0: CA type MT41692, firmware 32.43.2402, State Active, LinkUp, Rate 200, Link layer Ethernet |
| peermem / kernel module state | match | nvidia_peermem 580.126.20 loaded; mlx5_ib, mlx5_core, ib_uverbs, ib_core, rdma_ucm loaded; nv_peer_mem, gdrdrv, nv_rdma absent; /dev/gdrdrv absent; /dev/nvidia-caps contains nvidia-cap0, nvidia-cap1, nvidia-cap2 |
| Container runtime and image | match | apptainer 1.4.1 (/usr/local/apptainer/1.4.1/bin/apptainer); same SIF file: size 5307924480 bytes, mtime 2026-05-06 06:07:56.408241441 +0800 |
| In-container stack | match | Ubuntu 24.04.3 LTS; mpirun (Open MPI) 4.1.9a1; [no cuda version file] |
| PBS assigned resources | match | resources_assigned.ncpus = 96, ngpus = 8, mem = 2097152000kb on each node; each node state = free with only 72591.gaas assigned |

Values that differ between the two nodes (all per-device identity or
point-in-time runtime state; no hardware or topology asymmetry observed):

- Hostname and uptime/load: g12 up 10 days, 12 min, load average 12.88,
  13.07, 13.09; g15 up 10 days, 1:40, load average 12.90, 13.02, 13.02.
- GPU UUIDs, serial numbers, and GPU PDIs: all eight distinct per node
  (full lists in the per-node logs).
- IB Node/System image/Port GUIDs and base LIDs: per-adapter identity
  (for example, mlx5_0 base lid 150 on g12 vs 212 on g15).
- NIC MAC addresses (bond0/enp188s0f* and ibp* MACs differ per node).
- Host memory free at probe time: g12 node 0 free 44256 MB / node 1 free
  36033 MB, MemAvailable 1991827708 kB; g15 node 0 free 556193 MB / node 1
  free 515451 MB, MemAvailable 2011959304 kB. NUMA node totals differ
  marginally: g12 1031576 MB / 1032171 MB vs g15 1031621 MB / 1032125 MB
  (combined 2063747.20 MB vs 2063747.19 MB). Swap 8.0Gi total on both,
  effectively fully used (SwapFree 0 kB on g12, 100 kB on g15).
- GPU instantaneous power draw and temperature at probe time: g12
  74.88-78.50 W / 29-30 C; g15 74.31-79.08 W / 29-31 C (power limit
  700.00 W, pstate P0, and clocks identical on both).
- ECC/telemetry runtime counters (for example Replays Since Reset, SW
  Power Capping cumulative microseconds).

### Facts new or corrected relative to the 2026-08-20 report

Correction (software environment):

- The 2026-08-20 report stated that mpirun, apptainer, and nvc were not
  available and that no modulefiles were loaded in the unmodified probe
  environment. With the validated module set loaded
  (apptainer/1.4.1, gnu/gcc-12.3, cuda/13.1, nvhpc/26.3, squashfuse/0.5.2,
  gocryptfs/2.5.0; gnu/gcc-12.3 and cuda/13.1 are auto-loaded requirements
  of nvhpc/26.3), this probe found apptainer 1.4.1 and mpirun
  (Open MPI 4.1.9a1, nvhpc HPC-X) available on the mother superior and on
  both allocated nodes. nvc availability was not re-tested by this probe.

New facts (both nodes unless stated):

- Allocation-visible cpuset: the PBS chunk exposes 96 of 112 logical CPUs
  per node; Cpus_allowed_list 0-49,56-101 (50 CPUs per NUMA node) and
  Mems_allowed_list 0-1. The 2026-08-20 report recorded the 96-CPU
  allocation but not the cpuset composition.
- Per-chunk allocation values: 96 ncpus, 8 ngpus, 2097152000kb mem per
  node; job totals 192 ncpus / 16 ngpus / 4000gb.
- GPU power, clocks, and PCIe state at probe time: power limit 700.00 W
  per GPU; pstate P0; current graphics clock 345 MHz / max graphics clock
  1980 MHz; current and max memory clock 3201 MHz; PCIe link gen 5
  (current and max) at width 16 (current and max); persistence mode On; no
  compute processes using any GPU (empty nvidia-smi pmon and
  query-compute-apps output).
- Full per-adapter IB state: all eight ConnectX-7 ports Active/LinkUp at
  Rate 400 with Link layer InfiniBand (CA type MT4129, firmware 28.46.3048,
  SM lid 23), and mlx5_bond_0 Active/LinkUp at Rate 200 with Link layer
  Ethernet (CA type MT41692, firmware 32.43.2402). The 2026-08-20 report
  had recorded rate 400 only "for the sampled adapters". Per-adapter base
  LIDs and GUIDs are recorded in the per-node logs.
- NIC NUMA locality and GPU-NIC PIX pairing (values in the consistency
  table above); the 2026-08-20 report described the PIX/NODE/SYS pattern
  but not the mlx5_bond_0 (NIC8) PIX pairing to GPU5 and NIC5.
- nvidia_peermem version 580.126.20 loaded; nv_peer_mem, gdrdrv, and
  nv_rdma modules absent; /dev/gdrdrv absent; /dev/nvidia-caps present.
- Container identity: SIF at
  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif;
  size 5307924480 bytes; mtime 2026-05-06 06:07:56.408241441 +0800;
  sha256 123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628;
  base image label
  org.label-schema.usage.singularity.deffile.from: nvcr.io/nvidia/hpc-benchmarks:26.02;
  build date label Wednesday_6_May_2026_6:7:9_+08.
- Container software stack: Ubuntu 24.04.3 LTS; Open MPI 4.1.9a1
  (ompi_info "Open MPI v4.1.9a1"); CUDA-aware MPI evidence
  "MCA btl: smcuda (MCA v2.1.0, API v3.1.0, Component v4.1.9)"; UCX 1.20.0
  (library at /opt/hpcx/ucx, git revision be940c1, configured with
  --with-cuda=/hpc/local/oss/cuda13.0.2 --with-gdrcopy
  --with-xpmem=/hpc/local/oss/xpmem/v2.7.1, build tree
  hpcx-v2.25.1-gcc-inbox-ubuntu24.04-cuda13-x86_64); NCCL 2.29.2
  (libnccl.so.2.29.2; image label com.nvidia.nccl.version
  2.29.stable.20260109; libnccl_wrapper.so and libnccl-tuner-ofi.so also
  present); CUDA toolkit 13.1.115 in the container (nvcc "Cuda compilation
  tools, release 13.1, V13.1.115"; label com.nvidia.nvvm.version 13.1.115).
  Note: /usr/local/cuda/version.json is absent in the container
  ("[no cuda version file]"); the 13.1.115 value comes from nvcc and image
  labels.
- Host module set used by the probe: apptainer/1.4.1, gnu/gcc-12.3
  (auto-loaded), cuda/13.1 (auto-loaded), nvhpc/26.3, squashfuse/0.5.2,
  gocryptfs/2.5.0.
- Current driver/CUDA confirmation: driver 580.126.20 and nvidia-smi CUDA
  Version 13.0 on both g12 and g15, identical to the values recorded on
  hpc-gaas-g11 on 2026-08-20 (confirmation of currency, not a change).
- Host memory availability at probe time: both nodes 2.0Ti total; g12
  MemAvailable 1991827708 kB, g15 MemAvailable 2011959304 kB (per-NUMA-node
  free values in the differing-values list above).
- Installed container benchmark layout: /workspace contains
  hpl-mxp-linux-x86_64 (xhpl_mxp, 5927592 bytes, dated Feb 28 2026;
  hpl-mxp.sh, 9099 bytes, dated Feb 27 2026) plus hpl, hpcg, stream-gpu,
  microbenchmarks, source_code, and license.txt; hpl-mxp.sh is a symlink
  target for the top-level launcher.

### HPL-MxP help-attempt note

- The probe's usage-only attempt to run `hpl-mxp.sh --help` in the
  container printed "List of GPUs is not defined" and the help pipeline
  exited nonzero (help_pipeline_status=1); the release-layout checks
  succeeded (hplmxp_release_exit_status=0). This shows the installed
  hpl-mxp.sh expects a GPU-affinity argument before printing help. A
  separate mechanical flag check against the installed release follows
  outside this supplement.

### Supplement evidence limitations

- GPU memory, power, temperature, and host-memory free values are
  point-in-time readings captured 2026-09-27T08:00:58+08:00 through
  2026-09-27T08:01:08+08:00, not peak usage.
- The unsupported nvidia-smi forms noted in the 2026-08-20 report
  (`-q -d PCI`, `nvlink --status`) were not re-attempted; the NV18 topology
  matrix remains the available NVLink evidence.
- nvc, lstopo-no-graphics, and mst availability were not re-tested by this
  probe.
- This probe is a read-only per-node inventory; no inter-node bandwidth or
  latency measurement was performed.
- PBS resources_used.mem (33800kb) and resources_used.vmem (12742932kb)
  describe the small probe process, not total node memory consumption.
- Raw evidence: [outputs/phase0_2x8_probe_v1.o](outputs/phase0_2x8_probe_v1.o),
  [outputs/phase0_2x8_probe_v1.e](outputs/phase0_2x8_probe_v1.e),
  [outputs/phase0_2x8_probe_v1_node_hpc-gaas-g12.log](outputs/phase0_2x8_probe_v1_node_hpc-gaas-g12.log),
  [outputs/phase0_2x8_probe_v1_node_hpc-gaas-g15.log](outputs/phase0_2x8_probe_v1_node_hpc-gaas-g15.log).
