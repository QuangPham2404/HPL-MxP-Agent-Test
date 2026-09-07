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
    - First: launch script / MPI / NCCL / UCX settings AND CPU/MEM/NUMA binding issues (4/8 H200s are allocated randomly, cross numa node can lead to a very bad results)
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

#### 0. Sanity check — validate the tooling before measuring

**Goal:** Confirm the measurement infrastructure itself works, so that any later GDR-test failure can be attributed to the GDR path rather than to the launch machinery or a non-CUDA-aware MPI build. In short: test the tool before using the tool.

**Test:**

* Run host-native 2-node `osu_hello` / `osu_allreduce` through the exact launch path the later tests use (host `mpirun` + `rsh_pbsdsh.sh` PBS bridge: `plm_rsh_no_tree_spawn 1`, `plm_rsh_num_concurrent 1`, `routed direct`, `--bind-to none`). Only process spawn was validated previously; this confirms real cross-node message flow.
* Run `ompi_info --all | grep -i cuda` to confirm the host OpenMPI build is CUDA-aware, a prerequisite for the device-buffer (`D D`) OSU tests.

**Pass criteria:**

* Both OSU jobs run to completion across 2 nodes with normal output.
* `ompi_info` reports CUDA support.

**If it fails:** debug the launcher/bridge or MPI build first; do not trust or interpret later GDR bandwidth results.

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

---

### Phase 1 — Step 1: GPUDirect RDMA verification design (agreed 2026-09-07)

Executed in two phases, P2P first.

#### Phase A — P2P at 2 nodes × 1 GPU (single job, both runs on the same nodes)

Tests per run:

* `osu_bw` with all four buffer combos: `D D` (full GDR path, both ends — the HPL-MxP app pattern), `D H` (sender-side GDR only), `H D` (receiver-side GDR only), `H H` (fabric/CPU ceiling, no GPU involvement)
* `osu_latency` with `D D` and `H H`
* `ucx_perftest -m cuda` vs `-m host` cross-check (control run only)

Run conditions:

* Control run (default UCX) vs GDR-off run (`UCX_IB_GPU_DIRECT_RDMA=n`) in the same job on the same nodes and placement
* UCX tracing in both runs (`UCX_LOG_LEVEL=info`, `UCX_PROTO_INFO=y`); UCX_* variables explicitly forwarded with `-x` so both nodes provably see them
* No CPU binding (`--bind-to none`, matching real HPL-MxP runs); `nvidia-smi topo -m`, rank affinity, and `ucx_info -t` recorded as evidence only

Interpretation: healthy GDR ⇒ all four `osu_bw` combos near line rate; staged ⇒ `D D` < `D H`/`H D` < `H H`; one-sided fault ⇒ `D H` and `H D` diverge. `H H` is also the negative control: it must not change between the two runs.

#### Phase B — collectives (deferred until instructed)

`osu_bcast` and `osu_allreduce` with CUDA buffers (`-d cuda`, verified in-job with `H H` fallback) at 2x1 → 2x2 → 3x1 → 3x4, one job per topology, same control/GDR-off structure. With GDR off, only inter-node GPU-RDMA is disabled (intra-node NVLink IPC still works), so the A/B delta isolates the inter-node GPU path.

---

### Phase 1 — status and resume point (updated 2026-09-08)

**Completed:**

- **Step 0 (sanity): PASS** — host launch path (`mpirun` + `rsh_pbsdsh.sh` bridge)
  and CUDA-aware host MPI verified (`phase1_step0_sanity_v1`, job `59640.gaas`).
- **Step 1 Phase A (p2p GDR A/B at 2x1): PASS** — host GPUDirect RDMA works for
  p2p (zero-copy selected, clear A/B deltas, negative control clean)
  (`step1_p2p_2x1_v1`, job `59671.gaas`). CUDA p2p reaches ~57% of the fabric
  ceiling due to a 74/26 multi-rail split in the 1-GPU-per-node case.
- **Step 1 Phase B (collective GDR A/B ladder): COMPLETE — critical finding.**
  With default UCX (GDR enabled), CUDA collectives with ≥3 ranks are
  **pathologically slow (13-44× slower than staging**; e.g. 3x1 bcast @ 64 MiB:
  0.55 GB/s vs 24.2 GB/s staged). 2-rank collectives unaffected; H H negative
  controls clean. See `DEBUG_PROGRESS.md` Phase B section for full tables,
  protocol evidence, and analysis. Jobs `59931/59933/59934/59935.gaas`.
  - Rail/affinity resolved for 3x4: each GPU has its own PIX-paired NIC
    (rail-optimized 1:1 GPU:NIC) — Phase A's 74/26 was the 1-GPU-per-node
    artifact.

**Pending (user decision required):**

1. **Track 2.2 (decisive next step)**: minimal in-container HPL-MxP test on
   3x4 — default vs `UCX_IB_GPU_DIRECT_RDMA=n` exported into the container —
   plus an NCCL transport check (`NCCL_DEBUG=INFO`). Determines whether the
   app's slowness rides the host-side GDR-collective pathology found in
   Phase B or a separate container/NCCL issue (note: the 2026-09-03 probe
   found a gdrdrv/GDR gap inside the container).
2. **Optional mechanism follow-up**: registration-cache / fenced-write
   investigation of the ≥3-rank GDR collective pathology
   (`UCX_MEMTYPE_CACHE`, rndv thresholds, newer UCX).
3. **Optional**: verify UCX per-rank rail balance at 3x4 (each GPU now has a
   PIX NIC; the 74/26 question may be moot with the real 4-GPU mapping).
4. **Phase 1 test 2 — `nccl-tests` (NCCL path)**: still blocked on the missing
   host `libnccl.so.2` (recorded 2026-09-03); NCCL path verification may
   happen via Track 2.2 in-container instead.

**Resume point:** Phase 1 CUDA-aware-MPI GDR status is consolidated
(p2p works; collectives pathological at ≥3 ranks with GDR on). Awaiting user
instruction on pending item 1 (Track 2.2) and optional items 2-3. All results,
analysis, and evidence pointers are in `DEBUG_PROGRESS.md`; raw evidence in
`outputs/phase1-step0/` and `outputs/phase1-step1/`.



