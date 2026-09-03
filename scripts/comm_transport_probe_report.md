# Communication-transport probe report (GAAS multi-node HPL-MxP)

## Purpose

Explain the inter-node communication bottleneck observed in the 3-node × 4-GPU
HPL-MxP baseline (`LU = 1634 s`, GPU utilization 0–26%, ~44× slower than
single-node 8×H200). This report identifies exactly which communication stack
components are present and working on GAAS, and which are missing or disabled,
so the cluster administrator can decide what to install/enable.

## Scope and method

Read-only observation only (no builds, no runs, no changes). Two PBS probe jobs
on GAAS compute nodes, covering both the host and the NVIDIA HPC-Benchmarks
container:

| Attempt | PBS job | Node | Raw evidence |
|---|---|---|---|
| `comm_transport_probe_v1` | `57431.gaas` | `hpc-gaas-g11` | `outputs/comm_transport_probe_v1.{o,e}` |
| `comm_transport_probe_v2` | `57456.gaas` | `hpc-gaas-g15` | `outputs/comm_transport_probe_v2.{o,e}` |

Probe scripts: `scripts/comm_transport_probe_v1.pbs`, `scripts/comm_transport_probe_v2.pbs`.

## Environment snapshot

| Item | Value |
|---|---|
| Nodes probed | `hpc-gaas-g11`, `hpc-gaas-g15` |
| Hardware | NVIDIA H200 SXM 141 GB, 8 GPUs/node (Intel Xeon Platinum 8570) |
| OS / kernel | Rocky Linux 9.7 / `5.14.0-611.36.1.el9_7.x86_64` |
| NVIDIA driver | `580.126.20` (CUDA 13.0/13.1 reported) |
| Scheduler | PBS Pro (Altair), queue `gpu_as`, project `hpc_admin` |
| Container runtime | Apptainer 1.4.1 |
| Benchmark container | `hpc-benchmarks_26.02.sif` (bundles HPC-X 2.25.1 → Open MPI 4.1.9a1, UCX 1.20.0) |
| Fabric | 8× ConnectX-7 (mlx5_0–5, mlx5_8, mlx5_9), 400 Gb, link up |

---

## 1. What is set up and working

### 1.1 InfiniBand fabric (host and container)

- `ibdev2netdev`/`ibstat` report **8 active ConnectX-7 HCA ports** (`mlx5_0`
  through `mlx5_5`, `mlx5_8`, `mlx5_9`), all `Up`, sampled rate 400.
- The same mlx5 devices are visible **inside the container**: container `ucx_info -d`
  enumerates memory domains `mlx5_0`–`mlx5_5`, `mlx5_8`, `mlx5_9`, each exposing
  transports `rc_verbs`, `ud_verbs`, `dc_mlx5`, `rc_mlx5`, `ud_mlx5`.

### 1.2 Host RDMA kernel stack (full)

`lsmod` shows the complete RDMA/Verbs stack loaded on the host:

```
mlx5_core, mlx5_ib (12 users), ib_core, ib_uverbs (75 refs),
rdma_ucm, rdma_cm, ib_cm, ib_ipoib, iw_cm, ib_umad, mlx5_fwctl
```

`ib_uverbs` reference list includes `nvidia_peermem, rdma_ucm, mlx5_ib`, i.e.
the peer-memory module is wired into the verbs stack.

### 1.3 Container MPI is CUDA-aware

Container `ompi_info` (Open MPI 4.1.9a1) confirms CUDA support is compiled in and
enabled:

```
opal_built_with_cuda_support = true
MCA coll: cuda        (GPU-accelerated collectives component present)
MCA btl:  smcuda      (GPU shared-memory BTL present)
MCA pml:  ucx
MCA osc:  ucx
Configure: --with-cuda=/hpc/local/oss/cuda13.0.2
```

### 1.4 Container UCX capabilities (compiled + visible)

Container UCX 1.20.0 (`/opt/hpcx/ucx`) exposes, at `ucx_info -d`:

- `self`, `sysv`, `posix` (shared-memory)
- `tcp` (devices `bond0.103`, `bond0.200`, `bond0.321`, `lo`)
- `mlx5_*` (rc/ud/dc verbs + mlx5-native transports)
- `cuda_cpy` (Transport `cuda_copy`)
- `cuda_ipc` (Transport `cuda_ipc`)

Configured with `--with-cuda=...`, `--with-gdrcopy`; container ships `libgdrapi.so.2.5`
and UCX component `libuct_cuda_gdrcopy.so`.

### 1.5 GPUDirect RDMA peer-memory module (kernel side)

`nvidia_peermem` (`580.126.20`, matching the driver) **is loaded**:

```
nvidia_peermem   20480  0
/sys/module/nvidia_peermem/version -> 580.126.20
```

`/dev/nvidia-caps/{cap0 (compute), cap1, cap2}` are present and exposed into the
container (`cap2` is the peer-to-peer/GDR capability node).

---

## 2. What is missing or disabled (the bottleneck)

### 2.1 `gdrdrv` (NVIDIA GDR-Copy driver) is NOT installed/loaded

- `/dev/gdrdrv` → **not found**
- `/sys/module/gdrdrv` → **not found**
- `/proc/driver/gdrdrv` → **not found**
- `/sys/module/nv_rdma` → **not found**

The container bundles the gdrcopy *client* library but the host *kernel driver
it depends on* is absent. Consequence, visible in the container:

```
UCX_GDR_COPY_BW = get_dedicated:250.00MBps, put_shared:6911.00MBps
```

A working `gdrdrv`-backed GDR-copy path measures tens of GB/s; `get_dedicated:250 MB/s`
is the degraded fallback, confirming the driver is not active.

### 2.2 UCX default remote-GPU memory domain is `cuda_cpy` (staging copy)

Container UCX defaults:

```
UCX_SELECT_DISTANCE_MD = cuda_cpy
UCX_TLS                = all
UCX_NET_DEVICES        = all
```

`cuda_cpy` means that for GPU buffers destined for a *remote* rank, UCX stages
the data **GPU → CPU host memory → NIC → … → CPU → GPU**. This is the
non-GPUDirect path and is the direct cause of the observed 0–26 % GPU utilization
and the LU-phase dominance. (A GPUDirect-enabled path would select a `cuda` +
`rc_verbs`/`rc_mlx5` memory domain and DMA GPU→NIC directly.)

### 2.3 `nvidia_peermem` is loaded but unused

`nvidia_peermem` has `refcnt = 0`, i.e. no peer-memory registration is actually
happening during runs. This is consistent with §2.2 (UCX is staging through CPU
and never registers GPU memory with the HCA for direct RDMA). Even though the
peer-memory module is present, it is not being exercised.

### 2.4 No legacy `openib` BTL fallback

Container Open MPI BTLs are only `self, smcuda, tcp, vader` — there is **no
`openib` BTL**. This is not itself a defect (the stack uses `pml:ucx`), but it
means there is no alternative verbs path if UCX's RDMA path is not configured.

---

## 3. Interpretation

The inter-node communication path **mechanically works** — the fabric, the RDMA
kernel stack, CUDA-aware MPI, and a verbs-capable container UCX are all present.
The bottleneck is that **GPUDirect RDMA is effectively off**:

1. UCX defaults to the `cuda_cpy` staging transport for remote GPU buffers
   (§2.2), so cross-node GPU traffic round-trips through CPU host memory.
2. The GDR-Copy kernel driver (`gdrdrv`) is missing (§2.1), so the one available
   GPU-copy acceleration path is degraded to ~250 MB/s.

Together these explain the analysis finding (LU = 1634 s, GPU 0–26 %) and the
~44× gap versus single-node H200, whose intra-node traffic uses NVLINK
(`btl:smcuda` / `cuda_ipc`) and does not traverse the network.

---

## 4. Requests to the cluster admin (to enable GPUDirect RDMA)

1. **Install/load the NVIDIA `gdrdrv` GDR-Copy kernel module** (matching driver
   580.126.20) so `/dev/gdrdrv` exists. This is packaged as `gdrcopy` / the NVIDIA
   GDRCopy toolkit and requires the DKMS/ko build for the current kernel.
2. **Confirm `nvidia_peermem` is intended to be the (only) peer-memory provider**,
   and that peer-memory registration is permitted for the `gpu_as` jobs
   (`nvidia_peermem` is loaded with `refcnt=0`; the standard alternative
   `nv_peer_mem` from MLNX_OFED is absent).
3. **Confirm no policy blocks GPUDirect RDMA / peer-memory mapping** for HCA DMA
   into GPU BAR memory (e.g. `nvidia_peermem` parameters, IOMMU/SMMU settings, or
   `pci=nobnrp`/ACS restrictions).
4. **Optional:** advise the intended UCX device/transport policy for multi-node
   GPU jobs on GAAS (e.g. recommend a `UCX_TLS=rc,dc,gdr_copy,cuda_copy` /
   `UCX_NET_DEVICES=mlx5_*:1` selection) so containerized CUDA-aware MPI jobs can
   default to GDR rather than `cuda_cpy`.

Once `gdrdrv` is present (and peer-memory confirmed usable), the follow-up
diagnostic is a container UCX/MPI bandwidth microbenchmark to verify that GDR
(GPU→NIC direct) is selected and reaches expected H200 + 400 Gb throughput.

---

## 5. Provenance

- Probe scripts: `scripts/comm_transport_probe_v1.pbs`, `scripts/comm_transport_probe_v2.pbs`
- Raw evidence: `scripts/outputs/comm_transport_probe_v1.{o,e}`, `scripts/outputs/comm_transport_probe_v2.{o,e}`
- PBS jobs: `57431.gaas` (g11), `57456.gaas` (g15)
- Date: 2026-09-03
- Prior hardware baseline (driver/fabrics/CPU/NUMA): `scripts/probing_report.md`