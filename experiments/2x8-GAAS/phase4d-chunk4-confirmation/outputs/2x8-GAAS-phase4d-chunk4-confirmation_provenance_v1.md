# TASK-2X8-016 — Pre-Submission Read-Only Provenance Gate Evidence

- Task: `TASK-2X8-016` (Phase 4 Closure — Chunk-4 Confirmation Run)
- Gate: Section 1.4A provenance check, required before PBS submission
- Executed by: OpenCode execution worker (provenance-gate-only scope, delegated by the
  Codex orchestrator under the unchanged approved Section 1.11 of TASK-2X8-016)
- Evidence window: 2026-10-02T14:52:05+08:00 through 2026-10-02T14:56:40+08:00
- Local repository HEAD at check: `06ab29a4ea8b4745c6a7363d420918d186ad8195`
  (`tasks/TASK-2X8-016.md` locally modified by the parent to `status: EXECUTING`)
- Remote: GAAS login node `hpc-gaas-hn2`, direct BatchMode SSH, read-only commands only
- Method: direct filesystem stat + `sha256sum` of the exact recorded SIF; read-only
  Apptainer inspection (`apptainer inspect` labels; `apptainer exec` running only
  `ls`/`cat`/`readlink`/`readelf`/`ldd`/`nvcc --version` inside the container, no GPU
  bind, no benchmark execution). No PBS submission, no HPL-MxP run, no tuning, no
  container modification.

## Gate determination (summary)

| # | Required item | Result | Status |
|---|---------------|--------|--------|
| 1 | Exact recorded SIF path | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (exists; 5,307,924,480 bytes; mtime 2026-05-06 06:07:56.408241441 +0800) | PASS |
| 2 | SHA-256 digest of that exact image | `123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628` (freshly computed 2026-10-02T14:52:28–14:52:46+08:00; matches the independent TASK-2X8-015 phase4c record captured the same day on the compute node) | PASS |
| 3 | NVIDIA HPC Benchmarks release v26.02 | SIF label `org.label-schema.usage.singularity.deffile.from: nvcr.io/nvidia/hpc-benchmarks:26.02`; SIF build-date label matches the file mtime; retained run stdout banner `HPL-MxP-NVIDIA 26.2.0` | PASS |
| 4 | Exact CUDA subdirectory / package path selected by the HPL-MxP launcher, with read-only evidence of resolution | Launcher-selected CUDA library subdirectory: `/usr/local/cuda/lib64`, resolving `/usr/local/cuda` → `/etc/alternatives/cuda` → `/usr/local/cuda-13.1` (CUDA toolkit 13.1). Launcher-selected executable package path: `/workspace/hpl-mxp-linux-x86_64/xhpl_mxp`. Resolution chains shown verbatim below. | PASS |

**Gate verdict: PASS** — all four Section 1.4A items established unambiguously from
read-only evidence. PBS submission of the single chunk-4 confirmation arm is not
blocked by provenance.

## Established provenance values

~~~text
SIF path (exact recorded path, unchanged):
  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif

SIF file facts:
  size  = 5307924480 bytes
  mtime = 2026-05-06 06:07:56.408241441 +0800
  mode  = -rwxr-xr-x  owner pham0094

SIF SHA-256 (fresh, computed 2026-10-02T14:52:28+08:00 on hpc-gaas-hn2):
  123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628

Package release:
  NVIDIA HPC Benchmarks v26.02
  (SIF built from nvcr.io/nvidia/hpc-benchmarks:26.02; HPL-MxP-NVIDIA 26.2.0)

HPL-MxP launcher (inside image):
  /workspace/hpl-mxp.sh -> hpl-mxp-linux-x86_64/hpl-mxp.sh (symlink)
  readlink -f /workspace/hpl-mxp.sh = /workspace/hpl-mxp-linux-x86_64/hpl-mxp.sh
  SCRIPT_DIR = /workspace/hpl-mxp-linux-x86_64
  XHPL       = /workspace/hpl-mxp-linux-x86_64/xhpl_mxp   (single binary,
              5927592 bytes; no per-CUDA-version package subdirectories exist
              in this v26.02 image)

CUDA subdirectory selected by the launcher:
  launcher line: export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  /usr/local/cuda      -> /etc/alternatives/cuda   (symlink)
  /etc/alternatives/cuda -> /usr/local/cuda-13.1   (alternatives target)
  /usr/local/cuda-13   -> /etc/alternatives/cuda-13 -> /usr/local/cuda-13.1
  resolved CUDA toolkit: /usr/local/cuda-13.1 (CUDA 13.1)
    nvcc: Cuda compilation tools, release 13.1, V13.1.115
    libcudart.so.13     -> libcudart.so.13.1.80
    libcublas.so.13     -> libcublas.so.13.2.1.1
    libcublasLt.so.13   -> libcublasLt.so.13.2.1.1
    libnvJitLink.so.13  -> libnvJitLink.so.13.1.115
  xhpl_mxp RUNPATH: /opt/hpcx/ompi/lib
  Under the replicated launcher environment, ldd resolves for xhpl_mxp:
    libcudart.so.13    => /usr/local/cuda/lib64/libcudart.so.13
    libcublas.so.13    => /usr/local/cuda/lib64/libcublas.so.13
    libcublasLt.so.13  => /usr/local/cuda/lib64/libcublasLt.so.13
    libcusolver.so.12  => /usr/local/cuda/lib64/libcusolver.so.12
    libcusparse.so.12  => /usr/local/cuda/lib64/libcusparse.so.12
    libnvJitLink.so.13 => /usr/local/cuda/lib64/libnvJitLink.so.13
    libnccl.so.2       => /lib/x86_64-linux-gnu/libnccl.so.2 (container system NCCL)
~~~

## Commands run (all read-only) and verbatim evidence

### C1. Session start, remote repository state, SIF existence (2026-10-02T14:52:05+08:00)

Command (local → `ssh -o BatchMode=yes gaas`):

~~~text
date -Ins
git -C /home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test rev-parse HEAD
git -C /home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test status --short (first lines)
ls -la /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif
stat -c "size=%s bytes mtime=%y" /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif
~~~

Verbatim output:

~~~text
=== remote date ===
2026-10-02T14:52:05,355842176+08:00
=== remote project root git ===
87fb61e829832a3bc07c2579d8472aa1be279f13
 M scripts/gaas-internode-coms-debug/debug-scripts/phase2-preflight/stage_osu_tmp.sh
 M scripts/gaas-internode-coms-debug/debug-scripts/phase2-stage2/fabric_capture.sh
?? .codex-worktrees/
?? experiments/2Nodes-8GPUs/hostfile
?? experiments/3x4-baseline/hostfile
?? experiments/3x4-baseline/outputs/3x4-baseline_RERUN_v1.e
?? experiments/3x4-baseline/outputs/3x4-baseline_RERUN_v1.o
?? experiments/3x4-smoketest/HPL_MXP_3x4_SMOKETEST.e57228
?? experiments/3x4-smoketest/HPL_MXP_3x4_SMOKETEST.o57228
?? experiments/3x4-smoketest/hostfile
=== SIF existence ===
-rwxr-xr-x. 1 pham0094 1304617061 5307924480 May  6 06:07 /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif
=== SIF stat ===
size=5307924480 bytes mtime=2026-05-06 06:07:56.408241441 +0800
~~~

Informational for the parent orchestrator: the remote primary clone is at
`87fb61e829832a3bc07c2579d8472aa1be279f13` (differs from local
`06ab29a4ea8b4745c6a7363d420918d186ad8195`) and is dirty; Workflow 01 Mode B
(isolated worktree) applies for any later remote execution-tree use. This gate
performed no remote repository writes.

### C2. SHA-256 digest of the exact SIF (begin 2026-10-02T14:52:28+08:00, end 2026-10-02T14:52:46+08:00)

Command:

~~~text
time sha256sum /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif
~~~

Verbatim output:

~~~text
=== sha256 begin: 2026-10-02T14:52:28,225059513+08:00 ===
123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif
=== sha256 end: 2026-10-02T14:52:46,846109296+08:00 ===

real	0m18.620s
user	0m3.610s
sys	0m2.166s
~~~

Cross-reference (pre-existing TASK-2X8-015 evidence, captured on compute node
hpc-gaas-g14 the same day, before any 4C arm):
`experiments/2x8-GAAS/phase4c-ucx-transport-u-panel-chunk/outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_v1.o`
lines 90–92 record `container_image_size_bytes=5307924480`,
`container_image_mtime=2026-05-06 06:07:56.408241441 +0800`,
`container_image_sha256=123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628`
— identical size, mtime, and digest.

### C3. Apptainer availability (login node)

Command: `command -v apptainer; apptainer --version; hostname`

Verbatim output:

~~~text
=== command -v apptainer ===
=== apptainer --version (no module) ===
bash: line 1: apptainer: command not found
=== login node ===
hpc-gaas-hn2
~~~

Apptainer is not on the default login-node PATH. The recorded module set used by
every validated run (`apptainer/1.4.1`, `squashfuse/0.5.2`, `gocryptfs/2.5.0`) was
loaded transiently per SSH session for the read-only inspection commands below
(`bash -lc "module load apptainer/1.4.1 squashfuse/0.5.2 gocryptfs/2.5.0 && ..."`).
No persistent module or environment change was made; `nvhpc/26.3` was not needed
and not loaded.

~~~text
/usr/local/apptainer/1.4.1/bin/apptainer
apptainer version 1.4.1
~~~

### C4. SIF labels — release provenance (read-only `apptainer inspect`)

Command: `apptainer inspect /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`

Verbatim output (complete label set):

~~~text
com.nvidia.build.id: {NVIDIA_BUILD_ID:-}
com.nvidia.build.ref: [empty]
com.nvidia.cublas.version: 13.2.1.1
com.nvidia.cublasmp.version: 0.7.0.125
com.nvidia.cuda.version: 9.0
com.nvidia.cudla.version: 13.1.1.006
com.nvidia.cudnn.version: 9.17.1.4
com.nvidia.cufft.version: 12.1.0.78
com.nvidia.curand.version: 10.4.1.81
com.nvidia.cusolver.version: 12.0.9.81
com.nvidia.cusparse.version: 12.7.3.1
com.nvidia.cusparselt.version: 0.8.1.1
com.nvidia.nccl.version: 2.29.stable.20260109
com.nvidia.npp.version: 13.0.3.3
com.nvidia.nsightcompute.version: 2025.4.1.2
com.nvidia.nsightsystems.version: 2025.6.1.190
com.nvidia.nvjpeg.version: 13.0.3.75
com.nvidia.nvvm.version: 13.1.115
com.nvidia.tensorrt.version: 10.14.1.48+cuda13.0
com.nvidia.tensorrtoss.version: [empty]
com.nvidia.volumes.needed: nvidia_driver
org.label-schema.build-arch: amd64
org.label-schema.build-date: Wednesday_6_May_2026_6:7:9_+08
org.label-schema.schema-version: 1.0
org.label-schema.usage.apptainer.version: 1.4.1
org.label-schema.usage.singularity.deffile.bootstrap: docker
org.label-schema.usage.singularity.deffile.from: nvcr.io/nvidia/hpc-benchmarks:26.02
org.opencontainers.image.ref.name: ubuntu
org.opencontainers.image.version: 24.04
~~~

Release evidence:
- `org.label-schema.usage.singularity.deffile.from: nvcr.io/nvidia/hpc-benchmarks:26.02`
  — the SIF was built from the official NVIDIA HPC Benchmarks **26.02** container.
- `org.label-schema.build-date: Wednesday_6_May_2026_6:7:9_+08` matches the SIF file
  mtime `2026-05-06 06:07:56 +0800` (the SIF was created at build time and has not
  been modified since).
- Retained TASK-2X8-015 run stdout banner (e.g.
  `experiments/2x8-GAAS/phase4c-ucx-transport-u-panel-chunk/outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_k4-chunk4_v1.out`
  line 3): `HPL-MxP-NVIDIA 26.2.0` — the HPL-MxP component version inside v26.02.

### C5. Image workspace layout (read-only `apptainer exec ... ls`)

Command: `apptainer exec $SIF ls -la /workspace`

Verbatim output:

~~~text
total 2
-rw-r--r--.  1 pham0094 1304617061  813 Feb 28  2026 hpc-benchmarks-gpu-env.sh
drwxr-xr-x.  4 pham0094 1304617061    0 Feb 28  2026 hpcg-linux-x86_64
lrwxrwxrwx.  1 pham0094 1304617061   25 Feb 28  2026 hpcg.sh -> hpcg-linux-x86_64/hpcg.sh
drwxr-xr-x.  4 pham0094 1304617061    0 Feb 28  2026 hpl-linux-x86_64
drwxr-xr-x.  3 pham0094 1304617061    0 Feb 28  2026 hpl-mxp-linux-x86_64
lrwxrwxrwx.  1 pham0094 1304617061   31 Feb 28  2026 hpl-mxp.sh -> hpl-mxp-linux-x86_64/hpl-mxp.sh
lrwxrwxrwx.  1 pham0094 1304617061   23 Feb 28  2026 hpl.sh -> hpl-linux-x86_64/hpl.sh
drwxr-xr-x.  4 pham0094 1304617061    0 Feb 28  2026 lib
-rw-r--r--.  1 pham0094 1304617061  467 Jan 10  2026 license.txt
drwxr-xr-x.  6 pham0094 1304617061    0 Feb 28  2026 microbenchmarks
drwxr-xr-x. 11 pham0094 1304617061    0 Feb 28  2026 source_code
drwxr-xr-x.  2 pham0094 1304617061    0 Feb 28  2026 stream-gpu-linux-x86_64
lrwxrwxrwx.  1 pham0094 1304617061   42 Feb 28  2026 stream-gpu-test.sh -> stream-gpu-linux-x86_64/stream-gpu-test.sh
-rw-r--r--.  1 pham0094 1304617061 1064 Feb 28  2026 third-party.txt
~~~

Command: `apptainer exec $SIF ls -la /workspace/hpl-mxp-linux-x86_64/`

Verbatim output:

~~~text
total 5804
-rw-r--r--. 1 pham0094 1304617061     1587 Feb 27  2026 COPYRIGHT-CLI11
-rw-r--r--. 1 pham0094 1304617061      892 Feb 27  2026 README
-rw-r--r--. 1 pham0094 1304617061     1429 Feb 27  2026 RUNNING
-rw-r--r--. 1 pham0094 1304617061     3748 Feb 27  2026 TUNING
-rwxr-xr-x. 1 pham0094 1304617061     9099 Feb 27  2026 hpl-mxp.sh
drwxr-xr-x.  2 pham0094 1304617061        0 Feb 27  2026 sample-slurm
-rwxr-xr-x. 1 pham0094 1304617061  5927592 Feb 28  2026 xhpl_mxp
~~~

The v26.02 HPL-MxP package contains exactly one x86_64 package directory
(`/workspace/hpl-mxp-linux-x86_64`) and exactly one `xhpl_mxp` binary. There are no
CUDA-versioned package subdirectories to choose between in this release; the CUDA
selection enters through the launcher's library path (C7/C8 below).

### C6. Launcher source — how the executable and library paths are resolved (read-only `cat`)

Command: `apptainer exec $SIF cat /workspace/hpl-mxp.sh`

Verbatim key excerpts (full script captured in the session; 9099 bytes):

~~~bash
SCRIPT_DIR=$( cd -- "$( dirname -- "$( readlink -f "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )
XHPL="$SCRIPT_DIR/xhpl_mxp"

if [[ -r "$SCRIPT_DIR/../hpc-benchmarks-gpu-env.sh" ]]; then
  source "$SCRIPT_DIR/../hpc-benchmarks-gpu-env.sh"
fi

# FIXME - workaround for Singularity
export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
...
    --exec-name )
        XHPL=$2
        shift
        ;;
...
${NUMCMD} ${CPUBIND} ${MEMBIND} ${XHPL} ${HPL_MXP_PARAMS}
~~~

Resolution semantics: the GAAS launch invokes `/workspace/hpl-mxp.sh`; the launcher
resolves its own real path (`readlink -f`), so `SCRIPT_DIR=/workspace/hpl-mxp-linux-x86_64`
and the executed binary is `/workspace/hpl-mxp-linux-x86_64/xhpl_mxp` unless
`--exec-name` overrides it (the retained configuration does not use `--exec-name`).

Command: `apptainer exec $SIF cat /workspace/hpc-benchmarks-gpu-env.sh`

Verbatim output:

~~~bash
#!/usr/bin/env bash

ENV_SCRIPT_DIR="$( cd -- "$( dirname -- "$( readlink -f "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"

export LD_LIBRARY_PATH="${NCCL_PATH:-$ENV_SCRIPT_DIR/lib/nccl}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${NVSHMEM_PATH:-$ENV_SCRIPT_DIR/lib/nvshmem}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${NVPL_BLAS_PATH:-$ENV_SCRIPT_DIR/lib/nvpl_blas}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${NVPL_LAPACK_PATH:-$ENV_SCRIPT_DIR/lib/nvpl_lapack}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${NVPL_SPARSE_PATH:-$ENV_SCRIPT_DIR/lib/nvpl_sparse}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${OMP_PATH:-$ENV_SCRIPT_DIR/lib/omp}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

export OMPI_MCA_coll_hcoll_enable=0
~~~

Command: `apptainer exec $SIF ls -la /workspace/lib/`

Verbatim output:

~~~text
total 0
drwxr-xr-x.  2 pham0094 1304617061    0 Feb 28  2026 nvshmem
drwxr-xr-x.  2 pham0094 1304617061    0 Feb 28  2026 omp
~~~

Only `nvshmem` and `omp` exist under `/workspace/lib`; the `nccl`/`nvpl_*` entries
in the environment wrapper point at non-existent directories (NCCL resolves from
the container system path; see C8).

### C7. CUDA subdirectory resolution chain (read-only `readlink`, `nvcc --version`, `ls`)

Command:
`apptainer exec $SIF bash -c 'readlink -f /workspace/hpl-mxp.sh; readlink /usr/local/cuda; readlink /etc/alternatives/cuda; readlink -f /usr/local/cuda'`

Verbatim output:

~~~text
/workspace/hpl-mxp-linux-x86_64/hpl-mxp.sh
/etc/alternatives/cuda
/usr/local/cuda-13.1
/usr/local/cuda-13.1
~~~

Command: `apptainer exec $SIF ls -la /usr/local/ | grep -i cuda`

Verbatim output:

~~~text
lrwxrwxrwx.  1 pham0094 1304617061   22 Jan  9  2026 cuda -> /etc/alternatives/cuda
lrwxrwxrwx.  1 pham0094 1304617061   25 Jan  9  2026 cuda-13 -> /etc/alternatives/cuda-13
drwxr-xr-x. 14 pham0094 1304617061    0 Jan 10  2026 cuda-13.1
~~~

`cuda-13.1` is the only CUDA toolkit directory in the image, so the alternatives
selection is unambiguous.

Command: `apptainer exec $SIF /usr/local/cuda/bin/nvcc --version`

Verbatim output:

~~~text
Copyright (c) 2005-2025 NVIDIA Corporation
Built on Tue_Dec_16_07:23:41_PM_PST_2025
Cuda compilation tools, release 13.1, V13.1.115
Build cuda_13.1.r13.1/compiler.37061995_0
~~~

Command (2026-10-02T14:56:01+08:00):
`apptainer exec $SIF readlink /usr/local/cuda-13; apptainer exec $SIF readlink /etc/alternatives/cuda-13; apptainer exec $SIF ls -la /usr/local/cuda-13.1/lib64/ | grep -E "libcudart|libcublas.so|libcublasLt.so|libnvJitLink.so"`

Verbatim output:

~~~text
/etc/alternatives/cuda-13
/usr/local/cuda-13.1
lrwxrwxrwx. 1 pham0094 1304617061        15 Dec 19  2025 libcublas.so -> libcublas.so.13
lrwxrwxrwx. 1 pham0094 1304617061        21 Dec 19  2025 libcublas.so.13 -> libcublas.so.13.2.1.1
-rw-r--r--. 1 pham0094 1304617061 54190264 Dec 19  2025 libcublas.so.13.2.1.1
lrwxrwxrwx. 1 pham0094 1304617061        17 Dec 19  2025 libcublasLt.so -> libcublasLt.so.13
lrwxrwxrwx. 1 pham0094 1304617061        23 Dec 19  2025 libcublasLt.so.13 -> libcublasLt.so.13.2.1.1
-rw-r--r--. 1 pham0094 1304617061 502605048 Dec 19  2025 libcublasLt.so.13.2.1.1
lrwxrwxrwx. 1 pham0094 1304617061        15 Nov  8  2025 libcudart.so -> libcudart.so.13
lrwxrwxrwx. 1 pham0094 1304617061        20 Nov  8  2025 libcudart.so.13 -> libcudart.so.13.1.80
-rw-r--r--. 1 pham0094 1304617061   757536 Nov  8  2025 libcudart.so.13.1.80
-rw-r--r--. 1 pham0094 1304617061 1458254  Nov  8  2025 libcudart_static.a
lrwxrwxrwx. 1 pham0094 1304617061        18 Dec 17  2025 libnvJitLink.so -> libnvJitLink.so.13
lrwxrwxrwx. 1 pham0094 1304617061        24 Dec 17  2025 libnvJitLink.so.13 -> libnvJitLink.so.13.1.115
-rw-r--r--. 1 pham0094 1304617061 99286096 Dec 17  2025 libnvJitLink.so.13.1.115
~~~

Library versions match the SIF labels (`com.nvidia.cublas.version: 13.2.1.1`,
`com.nvidia.nvvm.version: 13.1.115`).

### C8. Executable dynamic resolution under the replicated launcher environment (read-only `readelf`/`ldd`)

Command: `apptainer exec $SIF readelf -d /workspace/hpl-mxp-linux-x86_64/xhpl_mxp | grep -iE "rpath|runpath"`

Verbatim output:

~~~text
 0x000000000000001d (RUNPATH)            Library runpath: [/opt/hpcx/ompi/lib]
~~~

Command: replicate the launcher's exact library-path construction (source
`/workspace/hpc-benchmarks-gpu-env.sh`, then prepend `/usr/local/cuda/lib64`
exactly as `hpl-mxp.sh` does), then `ldd` the executable:

~~~text
LD_LIBRARY_PATH=/usr/local/cuda/lib64:/workspace/lib/omp:/workspace/lib/nvpl_sparse:/workspace/lib/nvpl_lapack:/workspace/lib/nvpl_blas:/workspace/lib/nvshmem:/workspace/lib/nccl:/usr/local/cuda/compat/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/.singularity.d/libs
~~~

(The trailing `/usr/local/cuda/compat/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/.singularity.d/libs`
entries are injected by Apptainer's container environment.)

`ldd /workspace/hpl-mxp-linux-x86_64/xhpl_mxp | grep -iE "cuda|cublas|nccl|nvshmem|not found"` —
verbatim output:

~~~text
	libnccl.so.2 => /lib/x86_64-linux-gnu/libnccl.so.2 (0x00007facbec35000)
	libcudart.so.13 => /usr/local/cuda/lib64/libcudart.so.13 (0x00007facbe800000)
	libcusolver.so.12 => /usr/local/cuda/lib64/libcusolver.so.12 (0x00007facb5e000000)
	libcublas.so.13 => /usr/local/cuda/lib64/libcublas.so.13 (0x00007facb2800000)
	libcublasLt.so.13 => /usr/local/cuda/lib64/libcublasLt.so.13 (0x00007fac8ee000000)
	libnvJitLink.so.13 => /usr/local/cuda/lib64/libnvJitLink.so.13 (0x00007fac88e3a000)
	libnvidia-ml.so.1 => not found
	libcusparse.so.12 => /usr/local/cuda/lib64/libcusparse.so.12 (0x00007fac7e000000)
~~~

All CUDA user-space libraries resolve from the launcher-selected
`/usr/local/cuda/lib64` → `/usr/local/cuda-13.1/lib64`. `libnvidia-ml.so.1` is
"not found" only because this inspection ran on the GPU-less login node without
`--nv`; at execution time Apptainer `--nv` bind-mounts the host driver library
(the GAAS 580-series driver, CUDA 13.x capable, as already exercised by every
validated GAAS run, including all TASK-2X8-015 arms). This is the standard
container GPU driver model, not a provenance gap.

## Notes and caveats

1. The container-internal package README
   (`/workspace/hpl-mxp-linux-x86_64/README`) still carries an old internal
   version string (`HPL-MxP-NVIDIA 24.03.0`); it is a stale upstream README file.
   The authoritative version evidence is the SIF label
   (`nvcr.io/nvidia/hpc-benchmarks:26.02`) and the executable banner
   (`HPL-MxP-NVIDIA 26.2.0`, as printed in every retained run stdout).
2. `/workspace/lib/` contains only `nvshmem` and `omp`; the wrapper's
   `nccl`/`nvpl_*` library paths point at non-existent directories and NCCL
   resolves from the container system path (`/lib/x86_64-linux-gnu/libnccl.so.2`).
3. The remote primary clone is dirty and behind the local approved revision;
   the parent orchestrator must apply Workflow 01 Mode B before any remote
   execution-tree use. No remote writes were performed by this gate.
4. No PBS job was submitted or prepared, no HPL-MxP execution or tuning was
   performed, and no file outside the task-scoped experiment directory was
   modified. Local evidence file created fresh; no pre-existing files were
   touched (the directory `experiments/2x8-GAAS/phase4d-chunk4-confirmation/`
   did not previously exist).

## Evidence file provenance

- This file: `experiments/2x8-GAAS/phase4d-chunk4-confirmation/outputs/2x8-GAAS-phase4d-chunk4-confirmation_provenance_v1.md`
- Written: 2026-10-02 (~14:57 +08:00 local), from the verbatim session transcripts
  of the read-only SSH commands listed above.
- Pre-existing cross-reference evidence (read, not modified):
  - `experiments/2x8-GAAS/phase4c-ucx-transport-u-panel-chunk/outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_v1.o` (lines 90–92: digest/size/mtime)
  - `experiments/2x8-GAAS/phase4c-ucx-transport-u-panel-chunk/outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_k4-chunk4_v1.out` (banner line 3)
  - `experiments/2x8-GAAS/phase4c-ucx-transport-u-panel-chunk/outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_ucxpreflight_v1.log` (launcher `--ucx-tls` grep lines)
