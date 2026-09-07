# GAAS INTERNODE COMMUNICATION SET UP DEBUG

## Debug plan overview:

Initial observation: HPL-MxP is extremely slow for the baseline N=490k, 3 nodes x 4 gpus run. This indicate a high possiblity of a set up problem for inter-node communication on the cluster. However, keep in mind that it may be of some other problems, such as affinity issues, rank allocation, etc. However, comms still stands as the most probable cause.

Debug plan overview is as follows:
1. Test GPUDirect RDMA on the host first.
    - This establishes whether the cluster itself can do GPU↔NIC↔GPU direct communication.
2. Branch immediately:
    - Host GDRDMA fails → Track 2.1: go downward into RDMA/GPU-memory/driver/hardware layers.
    - Host GDRDMA works → Track 2.2: test the same capability inside the HPL-MxP container.
3. Track 2.1 — Host stack failure
    - Find the first broken layer: GPU memory registration → RDMA stack → NIC/fabric/topology.
    - Container is irrelevant until host capability works.
4. Track 2.2 — Container integration
    - Host works, container fails → likely container/userspace ↔ host-driver integration problem.   
    - Host works, container works → communication infrastructure is fundamentally healthy, so move upward into HPL-MxP/NCCL/MPI behavior.
5. If both host and container GDRDMA are healthy, investigate application/configuration causes next:
    - First: launch script / MPI / NCCL / UCX settings.
    - Second: GPU↔NIC / NUMA / rank affinity and multi-rail usage.
    - Then: synchronization / HPL-MxP-specific communication behavior.

## Debug plan details

### Phase 1: Test GPUDirect RDMA on the host first

HPL-MxP uses both **CUDA-aware MPI** and **NCCL**, so test GPUDirect RDMA through both paths.

Start simple:

```text id="h11vwe"
2 nodes × 1 GPU per node
```

---

#### 1. `osu-cuda` — CUDA-aware MPI

**Goal:** Check whether MPI/UCX can move GPU buffers directly over InfiniBand using GPUDirect RDMA.

**Test:**

* Run OSU GPU-to-GPU bandwidth test across 2 nodes.
* Enable UCX debug logging.
* Compare:

  * normal/default run
  * GPUDirect RDMA deliberately disabled

**Record:**

* Bandwidth
* UCX-selected transport/HCA
* GPU-memory/GDR-related log messages
* Difference between default and GDR-disabled runs

**GDRDMA likely working if:**

* UCX uses mlx5/InfiniBand RDMA
* logs indicate GPU memory is used through the RDMA path
* bandwidth is high
* disabling GDR causes a clear path/performance change

**GDRDMA likely not working if:**

* GPU buffers are staged through host memory
* UCX falls back from the GPU-RDMA path
* disabling GDR causes little/no difference

---

#### 2. `nccl-tests` — NCCL

**Goal:** Check whether NCCL uses GPUDirect RDMA for inter-node GPU communication.

**Test:**

* Run `sendrecv` first on 2 nodes × 1 GPU.
* Optionally test broadcast afterward because HPL-MxP uses panel broadcasts.
* Enable NCCL network/topology debug logs.
* Compare:

  * normal/default run
  * GDR deliberately disabled

**Record:**

* Bandwidth
* NCCL network backend
* selected HCA
* GDR-related log messages
* Difference between default and GDR-disabled runs

**GDRDMA likely working if:**

* NCCL uses InfiniBand
* logs show a GPU↔NIC GDR path
* bandwidth is high
* disabling GDR causes a clear degradation/change

**GDRDMA likely not working if:**

* NCCL falls back to Socket/TCP
* InfiniBand is used but GPU data is host-staged
* NCCL reports GDR unavailable/disabled
* disabling GDR makes little/no difference

---

#### Phase 1 decision

| OSU  | NCCL | Conclusion                                        |
| ---- | ---- | ------------------------------------------------- |
| Pass | Pass | Host GDRDMA works → test inside HPL-MxP container |
| Fail | Fail | Go down the host RDMA/GPU-memory stack            |
| Pass | Fail | Investigate NCCL path                             |
| Fail | Pass | Investigate MPI/UCX path                          |
