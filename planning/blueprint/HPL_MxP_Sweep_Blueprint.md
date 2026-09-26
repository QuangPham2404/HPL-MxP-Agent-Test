# HPL_MxP_Sweep_Blueprint

*General execution blueprint for new hardware topologies*

## 1. Purpose and Operating Principles

### Purpose

This is an execution blueprint for tuning NVIDIA HPL-MxP on a hardware
topology that has not yet been characterized. It tells the Human Leader and
Strategic Analyst which broad tuning domain to address next, which controls
belong to that domain, how to design the next bounded sweep, what evidence to
collect, and when to refine, investigate, close, or reopen work. Its sweep
procedures are design guidance for the Strategic Analyst; they become
executable only through a human-approved task that Codex orchestrates.

The immediate target is a competition system with three nodes and four H200
GPUs per node (12 GPUs total). The method also applies to other node counts,
GPU counts, interconnects, CPU/NUMA layouts, and network topologies.

This document is intentionally not a replacement for either the
[tuning-parameter guide](../../HPL_MxP_TuningParam_Guide.md) or the
[dependency graph](../dependency-graph/README.md). Consult those documents
for detailed flag definitions and dependency evidence. Use this blueprint to
decide and execute the next experiment.

### Relationship to the repository workflow

This blueprint supplies the optimization decision logic; it does not replace
the numbered repository workflow. Use `workflow/07-Workflow.md` for the
Step-1-to-Step-7 lifecycle, including the specification-to-task handoff,
`workflow/08-Workflow-Multinode-Tuning.md`
for the GAAS multinode launch contract, and the error/authorization files for
their respective boundaries. A sweep becomes executable only as a
human-approved, synchronized `tasks/TASK-XXX.md` meeting the front-matter and
`### 1.11 Authorization` gates defined in `workflow/07-Workflow.md`. The
Strategic Analyst designs sweeps from this blueprint and interprets the
dependency graph; Codex executes only the approved task scope and cannot
reopen closed conclusions or promote baselines on its own. A blueprint sweep
proposal is not permission to submit a job. Creating or updating analysis
conclusions still requires the general workflow's explicit `ANALYSE_RESULTS`
authorization.

### The non-transfer rule

Never transfer an optimum from the completed single-node 8×H200 work to a new
topology. This includes its `N`, `NB`, process grid, `nporder`, affinity,
OpenMP policy, residency settings, MPI/NCCL mix, chunk size, precision,
kernel, or scheduling choices.

An old value may be included as one candidate when it is supported and safe,
but it receives no privileged status. The reusable evidence is:

- what a flag changes;
- which phase or resource it can affect;
- which interactions and failure modes were observed;
- which measurements distinguish the competing explanations; and
- which conclusions are known to be conditional.

The new topology must establish its own control, safe operating region, noise
floor, and tuning conclusions.

The same non-transfer principle applies within one topology after a major
operating-regime change. A conclusion obtained at one materially different
`N`/`NB`/process-grid/FP64-residency regime is conditional on that tested
envelope; do not automatically carry it into another regime. A major upstream
change may reopen downstream conclusions through the dependency checkpoint.
This complements, and does not weaken, the rule that a new hardware topology
starts from Phase 0 rather than from any 8×H200 optimum.

### Two baselines, only one of which ranks the new system

- The old 8×H200 `baseline-sweep_v1` result is historical evidence only. Do
  not use its GFLOP/s as the percentage baseline for the new system.
- Phase 0 creates one identified **new-system original baseline run**. Preserve
  its attempt ID, configuration, and GFLOP/s unchanged for the whole campaign.
  Every later analysis table must include a
  `Percentage increase vs new-system original baseline` column.
- Each sweep also has an **in-sweep control**, normally the currently retained
  configuration. Report change against that control separately. It isolates
  the tested flag but never replaces the original-baseline column.
- A fastest single run is a candidate, not a new baseline. Promote a setting
  only after it passes correctness and the applicable repetition/noise test,
  and only through an explicit human decision.

### Campaign operating loop

For every phase or subgroup, the Strategic Analyst works interactively with
the Human Leader, and Codex executes only the approved task scope:

```text
Blueprint + dependency graph
        ↓
Strategic Analyst designs bounded specification
        ↓
Human reviews/modifies/approves
        ↓
Synchronized tasks/TASK-XXX.md
        ↓
Codex decomposition and OpenCode execution
        ↓
Codex evidence validation and Execution Report → EXECUTED
        ↓
Human explicit ANALYSE_RESULTS
        ↓
Strategic Analyst raw-evidence analysis
        ↓
Checkpoint: perform or explicitly skip dependency review
        ↓
Strategic Analyst recommends exactly ONE next action
        ↓
Human decision
        ↓
New approved task for further execution
```

Do not submit an entire phase as one predetermined experiment. Do not build a
large Cartesian product. Screen broadly, retain several plausible candidates,
test only the interactions needed to choose among them, and refine locally.

### What every sweep proposal must state

Before execution, the Strategic Analyst records for human review:

1. the decision question and mechanism-based hypothesis;
2. the original baseline, in-sweep control, candidates, and fixed controls;
3. why the candidate range is safe and broad enough;
4. which dependency-graph edges make this sweep necessary;
5. the allocation, rank count, launcher mapping, and exact command line;
6. correctness gates, metrics, repetition/bracketing plan, and stopping rule;
7. the action to take for a win, plateau, anomaly, or failure; and
8. the user-approved scope. A recommendation is not execution permission.

### Controls common to optimization runs

Follow the project workflow and preserve attempt-specific PBS stdout/stderr.
For optimization runs, use the required project controls:

```text
--skip-tests 0
--monitor-gpu 0
```

`--skip-tests 0` means that the package's internal test phase is enabled. The
tests provide a consistent pre-run initialization workload, but this blueprint
does not claim that NVIDIA formally defines them as a warm-up. Use the same
test behavior for the comparable original baseline, controls, and optimization
runs.

The benchmark's continuous GPU monitor is normally disabled for scored runs.
Establish hardware health in Phase 0 and use pre/post-run diagnostics or
targeted diagnostic experiments when needed. If continuous monitoring is
enabled for troubleshooting, label the attempt as a diagnostic condition; do
not silently rank it against monitor-off scored runs. Keep tolerance, test and
monitor behavior, package, executable, CUDA/MPI environment, and measurement
procedure constant unless the experiment explicitly studies one of them.
Never loosen tolerance to make an unstable precision setting pass.

Historical comparability: an original baseline recorded before this common
protocol was adopted remains immutable and is never recreated or replaced.
The 3-node × 4-GPU `3x4-baseline_v1`, for example, was recorded under the
earlier `--skip-tests 1` plus GPU-monitoring policy. When such a historical
baseline is used as a comparison denominator, disclose the protocol mismatch
and pair it with the appropriate same-protocol in-sweep control; never
silently treat monitor-on and monitor-off runs as interchangeable.

Every run must be classified by normal application output, a finite residual,
the documented tolerance, and `PASSED` verification—not process exit status
alone. Invalid, OOM, stalled-refinement, and incomplete attempts remain useful
boundary evidence but are never ranked as performance results.

### Common scorecard

Every phase-specific analysis starts with this minimum scorecard and adds the
metrics named in that phase:

| Evidence | Required interpretation |
|---|---|
| Overall HPL-MxP GFLOP/s or timed-phase duration | Primary end-to-end objective |
| Percentage increase vs new-system original baseline | Required campaign-wide comparison |
| Percentage change vs in-sweep control | Isolates the candidate's effect |
| LU GFLOP/s and/or LU time | Separates the factorization/update path |
| Iterative-solver/refinement time and iterations | Detects displaced cost from LU or precision changes |
| `IR/LU ratio = T_IR / T_LU` | Quantifies the iterative-refinement penalty relative to LU |
| Final residual, tolerance, and verification | Correctness gate before ranking |
| Run/node/job identity and repeated-control drift | Defines the actual resolution of the sweep |
| Maximum/worst-rank host and GPU memory use and headroom | Detects capacity and imbalance risks |
| Phase-0 or pre/post-run hardware-health evidence | Distinguishes topology/link/clock anomalies from flag effects without changing the scored protocol |

Prefer same-allocation interleaving or bracketing controls when practical.
Differences below measured drift are ties, not winners.

## 2. Phase Overview

| Phase | Decision to establish | Main controls | Normal result |
|---|---|---|---|
| 0. Characterization and baseline | What resources and paths actually exist, and how noisy is an unchanged run? | Hardware/software inventory, launcher, rank map, correctness, original baseline | Trusted evidence envelope and new-system original baseline |
| 1A. N/residency operating regime | Which `N` region best balances credited cubic work, LU efficiency, FP64 residency, and IR cost? | `--n` with `--fill-device 1`; other tunables fixed | Several bounded operating-regime candidates around the residency transition |
| 1B. Block size within retained regime(s) | Which `NB` region best organizes LU work within the useful `N` regime(s), and does it change their ranking? | `--nb` at retained `N` controls | A verified `N`/`NB` region plus a dependency decision on targeted N reopening |
| 2A. Process grid/order | How should 12 or another number of ranks form logical rows/columns? | `--nprow`, `--npcol`, `--nporder` | Shortlist of useful logical decompositions |
| 2B. GPU placement | How should logical ranks map to local GPUs and node boundaries? | `--gpu-affinity`, launcher rank order | Verified rank↔GPU map for shortlisted grids |
| 2C. Remaining placement | Are NIC/rail and launcher placement controls materially relevant? | `--ucx-affinity` and site launcher mapping, conditionally | Minimal topology-aware placement policy |
| 3A. OpenMP runtime | What host-thread budget and runtime placement feed each GPU rank? | `OMP_NUM_THREADS`, `OMP_PLACES`, `OMP_PROC_BIND` | Stable host runtime region |
| 3B. CPU/memory affinity | Does explicit locality improve on the runtime policy without starving ranks? | `--cpu-affinity`, `--mem-affinity` | Coordinated CPU/NUMA policy or evidence to leave unset |
| 3C. Residency/buffering | How much FP64 data should stay on device with safe workspace headroom? | `--fill-device`, `--Anq-device`, `--fill-device-buffer-size` | Correct residency mode and safe headroom region |
| 3D. Remaining host/memory | Is remaining staging or solver-side host work important enough to tune? | `--cuda-host-register-step`, `--call-dgemv-with-multiple-threads`, supported related controls | Targeted decision or documented low priority |
| 4. Communication | Which inter-/intra-node path and panel cadence minimize the actual critical path? | MPI/NCCL mix, U-panel chunking, MPI fallbacks, UCX/NIC controls | One or more communication candidates; subgrouping may evolve |
| 5. Compute/precision/scheduling | Which valid numerical/compute path is fastest, and what scheduling best serves it? | Sloppy type, supported GEMM presets, factorization/TRSM priority, GEMM stream | Final-stack candidates; subgrouping may evolve |

Preserve this broad order unless measured evidence and the dependency graph
provide a concrete reason to change it. A hardware-specific adjustment must be
written as a hypothesis and approved; it must not silently inherit the old
campaign's order or settings.

## 3. Phase 0 — New-System Characterization and Baseline

### A. Mechanism and 8×H200 Prior Knowledge

HPL-MxP performance depends on the resources visible inside the scheduled
allocation, not the node datasheet alone. Node count and GPUs/node establish
rank count and node boundaries. GPU fabric, PCIe roots, CPU NUMA domains, and
GPU↔NIC locality determine the physical paths followed by logical process rows
and columns. Usable host memory, per-GPU VRAM, cpusets, communication
workspaces, and library versions bound later choices.

The 8×H200 campaign found an NVSwitch-connected node with two CPU/NUMA
domains and measurable node/run variability. Some apparent parameter dips
were actually low-free-memory node conditions. It also showed that effective
package defaults can differ from an online documentation snapshot, so the
captured launcher output and installed package help are authoritative for the
actual run.

For the 3×4 target, do not assume that each four-GPU node is one NVLink domain,
that GPU numbering is topology-contiguous, that all GPUs share one NIC path,
or that ranks receive the same CPU/memory budget as before.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

### B. Sweep Procedure

Phase 0 is characterization, not tuning:

1. **Inventory one real PBS allocation.** Record node model/count, four GPUs
   per target node (or the actual count), GPU model/VRAM, GPU-to-GPU topology,
   NVLink/NVSwitch domains or islands, PCIe roots, CPU sockets/cores/NUMA
   distances, the allocated cpuset, usable host memory, NICs/rails, link state,
   and GPU↔NIC/NUMA locality. Capture all three nodes because asymmetry matters.
2. **Freeze executable and software provenance.** Record the container image
   path and digest, HPL-MxP release, executable and effective launcher
   defaults, driver, CUDA, cuBLAS, MPI, NCCL, UCX, modules, and relevant
   environment. Confirm the exact supported spelling/range of every later
   candidate from the installed release.
3. **Validate the launcher and mapping.** Use one MPI rank per GPU unless the
   installed package explicitly requires otherwise. Prove the global rank,
   node, local rank, GPU ID/UUID, CPU affinity, NUMA visibility, and NIC chosen
   by each of the 12 ranks. Confirm CUDA-aware MPI/GPU-direct behavior rather
   than inferring it from an environment variable.
4. **Run initial correctness validation.** Choose conservative, provisional
   required values for `N`, `NB`, and a valid process grid from package/site
   guidance and the measured memory envelope. They are baseline inputs, not
   tuned winners. Require normal HPL-MxP output, a finite residual, and
   `PASSED`; keep the internal test phase enabled with `--skip-tests 0` for the
   comparable campaign protocol.
5. **Create the timed new-system original baseline.** Use the common scored-run
   protocol (`--skip-tests 0`, `--monitor-gpu 0`) after Phase-0 hardware-health
   validation. Designate the first valid comparable timed attempt as the
   immutable original baseline before tuning begins. Repeat that exact
   configuration enough times to estimate variability; three valid timed
   attempts are a useful minimum, and bracket longer sequences if drift is
   visible. Repeats define noise and confidence; they do not replace the
   identified baseline run as the percentage denominator. If a monitored
   diagnostic is needed, keep it separate from the scored baseline series.

Required evidence before Phase 1:

- a per-node topology/resource record with no unresolved placeholder;
- a verified rank↔node↔GPU↔CPU/NUMA↔NIC map;
- exact package/executable/software provenance and effective defaults;
- a reproducible command and resource request;
- one identified, fully valid original baseline run and repeated controls;
- the observed noise/drift estimate and known anomalous-node rule;
- host/GPU headroom for the conservative baseline; and
- a results schema that includes the original-baseline percentage column and
  the common scorecard fields.

### C. Metrics to Observe

Use the common scorecard. Also inspect:

- per-rank and per-node mapping consistency;
- per-node host-memory availability and worst-rank high-water marks;
- GPU VRAM, clocks, power, temperature, PCIe width/generation, and link health;
- NIC selection/link state and evidence that the intended GPU-direct path is
  active;
- baseline range, median, coefficient of variation or an equivalently simple
  noise summary, plus opening-to-closing control drift; and
- initialization/test output separately from the timed HPL-MxP phases.

### D. Closing Condition vs Investigation

Close Phase 0 only when the required evidence above is complete and repeated
baseline runs are valid enough to define a practical noise floor. A small
amount of noise is not a blocker if it is quantified and later sweeps are
designed to exceed or bracket it.

Investigate before Phase 1 if nodes differ materially, ranks see unexpected
GPUs/cpusets, a GPU or NIC link is degraded, CUDA-aware MPI is uncertain,
memory availability varies enough to move feasibility, baseline repetitions
disagree beyond the proposed resolution, or correctness is intermittent. Use
a targeted probe or trace only to answer the unresolved mapping, transport,
or timing question. Do not tune around a broken or unidentified platform.

## 4. Phase 1 — Core Problem Geometry

Primary controls: `--n` and `--nb`. They are coupled, but tune them
sequentially: discover the useful `N`/FP64-residency operating regime first,
then tune `NB`, review the dependency, and reopen only a bounded local `N`
region if the evidence requires it.

### A. Mechanism and 8×H200 Prior Knowledge

`N` is the global matrix dimension. Useful LU work grows approximately
cubically, while principal matrix storage grows quadratically. Larger problems
can improve GEMM efficiency and amortize panel, synchronization, and startup
costs, but increase FP64 refinement work and eventually cross host- or
device-memory limits.

For large `N`, the central scoring intuition is:

```text
R_MxP ≈ ((2/3) * N^3) / (T_LU + T_IR)
```

The exact benchmark work expression may include a lower-order `N^2` term, but
the cubic approximation is sufficient for operating-regime discovery at these
matrix sizes. An equivalent useful form is:

```text
R_MxP ≈ P_LU / (1 + T_IR / T_LU)
P_LU  ≈ ((2/3) * N^3) / T_LU
```

HPL-MxP tuning is therefore not purely an LU-throughput optimization problem.
The objective balances credited `N^3` work, LU efficiency, and
iterative-refinement (IR) time. A larger `N` can improve LU/GEMM efficiency but
lose overall when IR grows faster; a smaller `N` can lose LU efficiency and
still win when total solve time falls faster than credited work. Record
`IR/LU ratio = T_IR / T_LU` to show how strongly refinement discounts the LU
rate.

HPL-MxP retains the original FP64 matrix for residual and iterative-refinement
work. Greater device residency of that matrix can reduce host-device staging
during refinement, but consumes GPU memory also needed by low-precision
factors, panels, communication buffers, cuBLAS/runtime workspaces, and other
benchmark state. The raw FP64 matrix alone requires approximately `8*N^2`
bytes globally; that estimate is a candidate-generation aid, not a complete
memory model.

`NB` is the blocked-LU panel/tile size. It changes panel count and duration,
trailing-GEMM shapes, synchronization/communication frequency, available
parallelism, and workspace. At fixed `N`, it reorganizes work rather than
fundamentally adding useful mathematics.

On 8×H200, larger `N` improved amortization until an abrupt memory wall;
changing `NB` strongly changed LU time and also moved that wall. The best grid
later reversed between two `N` contexts. One specific non-aligned `N` produced
a repeatable pathology, but the later aligned sweep disproved exact
`N % NB == 0` as a general performance rule.

The earlier matrix-placement N resweep established a real residency mechanism:
under `--fill-device 1`, reducing `N` strongly reduced solver time as more of
the original FP64 matrix became device-resident. Under that experiment's fixed
`NB=3072`, `2x4` row grid, host runtime, and downstream controls, the gain was
cancelled by lower LU efficiency. That result was conditional on its tested
configuration; it does not establish that small `N` cannot win.

The later `SingleNode-resweep_v1.1` is the counterexample that changes the
blueprint's operating intuition. Its `N=356352`, `NB=3072`, `4x2` row bundle
reported approximately `2.7694e+06` HPL-MxP GFLOP/s, `4.0464e+06` LU GFLOP/s,
`7.46 s` LU, and `3.44 s` IR (`IR/LU ≈ 0.46`), with approximately
`135.7/138.6 GB` worst-rank device consumption and much lower host-memory use.
The previous large-`N` record at `N=491520`, `NB=3072`, `2x4` row reported
approximately `2.4203e+06` HPL-MxP GFLOP/s, `4.1396e+06` LU GFLOP/s,
`19.12 s` LU, and `13.58 s` IR (`IR/LU ≈ 0.71`). Thus the new bundle won
despite slightly lower LU throughput because its IR penalty fell sharply.

The two records are not a one-variable comparison: process grid, DGEMV
partition, factorization priority, MPI panel-broadcast policy, fill buffer,
and other context differ, and the newer run had no paired same-node control.
Do not attribute its gain to any one downstream flag. The transferable result
is the LU/IR balance and operating-regime insight:

> Small-N / high-residency regimes can become globally competitive if the surrounding configuration recovers enough LU efficiency.

Old values—including the previous `N`, `NB=3072`, and the old memory boundary—
are only optional safe-to-check hypotheses. They are not the center or endpoint
of the new sweep. Historical values such as `2x4` row, DGEMV `0`,
factorization priority `1`, or MPI panel broadcast `50` are conditional on the
tested N/NB/grid/residency/host-runtime regime. They are historical controls,
not transferable optima, and may reopen after a material upstream regime
change.

Relevant dependencies include E01, E05, E07–E10, E14–E16, E18, E22–E24,
E28, E34, and E36 in [edges.csv](../dependency-graph/edges.csv).

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

### B. Sweep Procedure

Use the following adaptive broad→refine sequence. Do not turn it into a large
`N×NB` Cartesian sweep.

#### Phase 1A — Initial N / FP64-residency sweep

1. **Derive a mechanism-based sweep center.** With one rank per GPU, calculate
   the heuristic residency pivot from the actual rank count and measured
   usable memory per GPU:

   ```text
   N_pivot = sqrt(ranks * GPU_memory_bytes * 0.85 / 8)
   ```

   This estimates where the distributed original FP64 matrix occupies roughly
   85% of aggregate GPU memory, leaving approximate device headroom for other
   benchmark/runtime state. The `0.85` factor is a heuristic sweep-center
   value, not a universal optimum. `N_pivot` is not an automatically selected
   winner, and a numerical pivot must never be transferred between hardware
   topologies. Recompute it from the actual new-system ranks and measured
   usable GPU memory.
2. **Freeze provisional controls.** Use `--fill-device 1` so that changing `N`
   exposes the FP64-residency transition directly. Hold every other tunable at
   a safe provisional value: `NB`; process grid and `nporder`; GPU/rank
   mapping; OpenMP policy; CPU/memory affinity; DGEMV partition; MPI/NCCL
   broadcast mix; U-panel chunk; factorization/TRSM priority; separate GEMM
   stream; precision; GEMM kernel; fill-device buffer; and other relevant
   controls. Do not use an `N`-dependent formula that simultaneously changes
   grid, DGEMV, `NB`, broadcast, or another downstream setting. An old value
   may serve only as a supported, safe provisional control under the
   non-transfer rule.
3. **Run a coarse 10%-step sweep.** Generate safe/legal `N` candidates near
   `70%`, `80%`, `90%`, `100%`, `110%`, and `120%` of `N_pivot`. Alignment can
   be a convenient clean candidate-generation rule, but do not encode
   `N % NB == 0` as a universal performance requirement. Truncate the upper
   range when Phase-0 memory evidence predicts that a candidate is unsafe;
   invalid or OOM evidence defines a boundary and is not a scored point.
4. **Interpret the operating regimes.** For every point, compare final score,
   LU efficiency, IR time and `IR/LU`, FP64 residency/staging evidence, and
   host/GPU headroom. Do not select the largest `N`, the fastest LU, or the
   largest single HPL-MxP number without explaining the LU-versus-IR balance.
5. **Refine at approximately 5% steps.** Refine around both (a) the best
   performing region and (b) any clear residency/IR transition if it lies
   elsewhere. For example, a coarse maximum near 100% suggests approximately
   95%, 100%, and 105%; a sharp IR change between 100% and 110% requires enough
   boundary points to understand that transition. Do not blindly refine one
   noisy maximum.
6. **Retain distinct regimes when justified.** Keep more than one `N` regime
   if final scores are close but residency, LU efficiency, IR cost, memory
   headroom, or communication/geometry behavior differs meaningfully. Repeat
   or bracket leading regions and a stable control before promoting one.

#### Phase 1B — NB tuning within retained N regime(s)

1. **Screen `NB` only after Phase 1A.** At a representative `N` from each
   retained, meaningfully distinct regime, include the installed default,
   values spanning smaller and larger panels, and optionally an old 8×H200
   value as a historical control. Keep all non-`NB` controls fixed. Use a
   bounded staged design rather than every `N×NB` pair.
2. **Retain useful `NB` regions.** Preserve plateaus or mechanism-distinct
   candidates, not just the numerical maximum. Stop extending a direction
   after repeated clear degradation, a safety threshold, or invalidity.
   Report any `NB`-dependent capacity boundary as part of the result.
3. **Perform the mandatory dependency review.** Ask whether `NB` materially
   changed the ranking, residency boundary, LU/IR balance, or feasibility of
   the retained `N` regimes. If not, keep `N` closed. If it did, run only a
   targeted/local N resweep—normally the old control, the affected boundary,
   and a few neighboring 5–10% candidates—under the retained `NB`. Do not
   restart a full joint matrix.
4. **Verify the retained geometry.** Repeat or bracket the leading `N`/`NB`
   region, its meaningful neighbors, and a stable control. Confirm that the
   result is not allocation drift, test-protocol drift, or memory pressure.

The intended flow is `N discovery → NB sweep → dependency review → targeted N
resweep if justified`. Do not select the largest fitting `N` if its headroom
is unreliable or its IR penalty places it on a lower end-to-end plateau.

### C. Metrics to Observe

Use the common scorecard, emphasizing:

- `N` and `N` as a percentage of `N_pivot`;
- HPL-MxP GFLOP/s;
- LU time and LU GFLOP/s;
- iterative-refinement/solver time and `T_IR / T_LU`;
- refinement iteration count and residual trajectory where available;
- verification status, finite residual, and tolerance;
- maximum/worst-rank GPU-memory consumption and minimum GPU headroom;
- host-memory consumption and evidence of host-resident or staged FP64 data
  when exposed;
- run/node/job identity and control drift/noise information;
- allocation/OOM point and the phase in which failure occurs;
- panel-count/GEMM-shape clues exposed by normal output;
- any N- or NB-specific discontinuity; and
- correctness/residual behavior near the memory boundary.

The Phase-1 analysis must explain performance through both LU and IR. A table
that ranks only HPL-MxP GFLOP/s without phase attribution is incomplete.

### D. Closing Condition vs Investigation

Close Phase 1 when Phase 1A has bounded the useful N/residency regime(s), Phase
1B has established an `NB` region within them, the dependency review has
either kept N closed or completed its targeted reopening, and a valid, safely
feasible winner or plateau survives control/repetition. Neighboring points
must bound the retained region, and further geometry search must have lower
expected payoff than untested decomposition and placement.

Do not require a unique one-value optimum when a plateau is real. Retain more
than one geometry candidate for Phase 2 if their performance is
indistinguishable but their panel counts, memory headroom, or communication
characteristics differ.

Investigate rather than close when performance changes discontinuously without
matching residency/memory evidence, a valid point is roughly isolated from its
neighbors, ranks use memory asymmetrically, refinement changes unexpectedly,
or the boundary moves contrary to the `N`/`NB` workspace mechanism. First
repeat the point and inspect ordinary logs. Trace only a specific unresolved
question such as whether an anomalous `NB` changes the LU critical path or why
an IR transition does not match the observed FP64-residency evidence.

## 5. Phase 2 — Parallel Decomposition and Placement

### Subgroup 2A — Process Grid and Order

Key controls: `--nprow`, `--npcol`, `--nporder`.

#### A. Mechanism and 8×H200 Prior Knowledge

`nprow × npcol` must equal the MPI rank count. The shape changes panel-column
cooperation, row broadcasts, local matrix shapes, communicator sizes, message
fan-out, and update concurrency. `nporder` changes which global ranks occupy
those logical rows and columns, so it can change which traffic crosses node,
GPU-fabric, NUMA, and NIC boundaries without changing the abstract grid.

The old grid preference reversed when `N` changed: around `N=399360`, the
earlier study favored a `4x2` grid, while at `N=491520` the later study favored
`2x4` row, with the latter spread close to the noise floor. The new
`N=356352` record used `4x2` row, but also changed several other controls, so
it is not isolated causal evidence for that grid. Together these results are
direct evidence against transferring a grid conclusion outside its tested
N/NB/residency regime. For 12 ranks, valid shapes include `1×12`, `2×6`,
`3×4`, `4×3`, `6×2`, and `12×1`. A `3×4` or `4×3` shape may align naturally
with three nodes or four GPUs/node under a particular rank order, but that is
only a candidate mechanism, never a presumed winner.

Relevant dependencies include E02, E09–E12, E24, and E29.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

#### B. Sweep Procedure

1. Hold the retained Phase 1 geometry candidate(s) fixed and begin with one
   explicit, verified rank order/mapping. Do not merge grid testing into the
   initial Phase-1 N sweep.
2. Screen process-grid **shapes** first. Include balanced/topology-aligned
   candidates and at least one meaningfully different shape if safe. Skinny
   extremes are diagnostic rather than mandatory when they obviously create
   poor panel parallelism or communication.
3. Retain several shapes based on end-to-end performance, phase balance,
   headroom, and rank symmetry.
4. Compare `row` versus `column` order only for the retained shapes. Do not run
   every shape×order×affinity combination at once.
5. Refine/repeat the leading shape/order pairs with bracketing controls. If two
   geometries remain tied, carry both to 2B because physical mapping may break
   the tie.

If materially different Phase 1 N/residency regimes remain close, test the
leading grids on enough representative regimes to detect an N×grid
interaction, but only on those distinct regions; do not create a full
N×NB×grid matrix. After selecting a materially different grid, perform the
normal dependency review. If the grid changes the LU/IR balance or reverses
the N ranking, reopen N with a small targeted resweep around the affected
regime rather than launching a full joint search.

#### C. Metrics to Observe

Use the common scorecard, emphasizing LU time/rate, per-rank timing or arrival
imbalance if available, initialization and communication symptoms, worst-rank
memory ownership, and whether logical row/column groups cross nodes. Record
the exact global/local rank map for every order.

#### D. Closing Condition vs Investigation

Close 2A when a small set of useful grid/order candidates is repeatable, its
neighbors or contrasting shapes establish the trend, and differences below
noise are represented as a tie.

Investigate when a topology-aligned candidate is unexpectedly poor, rank
asymmetry is large, row/column order changes performance much more than
expected, or scaling is inconsistent with the logical communicator layout.
First verify the actual rank map. A trace is justified only to answer which
communicator/rank arrives late or which node boundary dominates.

### Subgroup 2B — GPU Affinity / Rank-to-GPU Placement

Key control: `--gpu-affinity`, together with global/local rank ordering from
the site MPI launcher.

#### A. Mechanism and 8×H200 Prior Knowledge

GPU affinity maps each local MPI rank to a physical GPU. Combined with the
chosen grid and order, it decides whether logical row/column traffic follows
fast NVLink/NVSwitch paths, crosses PCIe roots, or approaches a network adapter
through a remote NUMA path.

The 8×H200 work always used an identity affinity list. No alternative mapping
was tested, so there is no old affinity winner to transfer. On a multi-node
run, the list is normally interpreted per local rank; never invent a global
`0:...:11` mapping without confirming launcher semantics.

Relevant dependencies include E03, E11, and E13.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

#### B. Sweep Procedure

1. For each serious 2A grid candidate, draw its logical process rows/columns
   over the verified global-rank/node layout.
2. Establish a correct local-rank→GPU map on every node and prove it from run
   output. Start with the topology-contiguous mapping suggested by Phase 0, not
   with the old identity list by habit.
3. Test only a few mechanism-distinct alternatives: for example, a mapping
   that keeps a critical communicator within a GPU fabric domain, one that
   favors GPU↔NIC locality, or a deliberate permutation that distinguishes
   those hypotheses. Do not permute all four GPUs exhaustively.
4. Retain multiple mappings if the best logical grid depends on physical
   placement. Repeat the candidate/control whose separation exceeds or
   approaches noise.

#### C. Metrics to Observe

Use the common scorecard, plus the verified per-rank GPU UUID/PCI address,
GPU-fabric and PCIe path taken by logical neighbors, rank imbalance, LU time,
communication wait symptoms, GPU-direct/NIC counters when available without
profiling, and per-GPU utilization/memory asymmetry.

#### D. Closing Condition vs Investigation

Close 2B when the mapping is correct on every node and either a topology-aware
mapping wins repeatably or all meaningful mappings form a noise-level plateau.

Investigate wrong-device access, uneven GPU work, large late-rank behavior,
or a reversal that cannot be explained by the drawn logical/physical map.
Trace a small paired comparison only if it can identify whether GPU-fabric,
PCIe, or network locality is responsible.

### Subgroup 2C — Remaining Relevant Decomposition / Placement Controls

Conditional controls: `--ucx-affinity` for NIC/device association and site
MPI launcher mapping controls that determine global rank, local rank, socket,
and NIC placement. Treat `--ucx-tls` as a Phase 4 transport choice, not a
placement sweep here.

#### A. Mechanism and 8×H200 Prior Knowledge

When a node has multiple NICs or rails, NIC/device affinity determines whether
a GPU's inter-node traffic takes a local or remote CPU/PCIe path. MPI launcher
mapping can also alter global rank order or crowd ranks onto a socket even when
HPL-MxP's grid and GPU affinity are unchanged.

These controls were not swept in the single-node work. Their absence from old
results is not evidence that they are flat. They matter on the 3-node target
only if the Phase 0 topology and installed MPI/UCX path make them relevant.

Relevant dependencies include E03, E11–E13, and E26.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

#### B. Sweep Procedure

1. Decide from Phase 0 whether multiple NIC paths, rails, or launcher mappings
   create a real placement choice. If not, document why and close the subgroup
   without synthetic experiments.
2. If relevant, hold the best 2A/2B candidate fixed and compare a verified
   automatic policy with one or two topology-aligned alternatives.
3. Change device association or rank placement here, not the UCX transport
   family. Carry useful placements to Phase 4, where transport behavior is
   tested.

#### C. Metrics to Observe

Use the common scorecard, plus NIC/rail selected per rank, traffic balance
across rails, GPU↔NIC locality, rank arrival imbalance, and any NUMA or CPU
contention introduced by the launcher.

#### D. Closing Condition vs Investigation

Close 2C when no relevant choice exists or a minimal placement policy is
correct, repeatable, and free of strong rank/rail imbalance. Investigate rail
collapse, traffic on a remote NIC, unexplained per-node skew, or launcher
mapping that changes between attempts. Do not tune transport around a mapping
that is not stable.

## 6. Phase 3 — Host Runtime and Memory / Residency

### Subgroup 3A — OpenMP Runtime

Key controls: `OMP_NUM_THREADS`, `OMP_PLACES`, `OMP_PROC_BIND`.

#### A. Mechanism and 8×H200 Prior Knowledge

Host threads feed GPU launches, panel/auxiliary work, data movement,
refinement, and possibly MPI progress. Too few threads can starve the GPU
pipeline; too many or badly bound threads can oversubscribe cores and compete
with local ranks. `OMP_PLACES` and `OMP_PROC_BIND` are meaningful only relative
to the cpuset and MPI launcher's own binding.

On 8×H200, a moderate thread count reached a plateau, while one/two threads
were poor. Socket-level placement was useful, but `OMP_PLACES=cores` with
binding made all ranks crowd low-numbered cores and collapsed performance.
That failure mode is transferable as a check, not as a reason to transfer the
old thread count or socket policy. Four ranks/node gives a different core
budget and MPI-progress regime.

Relevant dependencies include E04, E18–E20.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

#### B. Sweep Procedure

1. Read the allocated cpuset and reserve any cores needed by the MPI/UCX
   progress model. Define a legal per-rank budget for four local ranks (or the
   actual ranks/node).
2. With explicit HPL CPU/memory affinity unset or at a verified neutral policy,
   broadly sweep thread count from clearly underprovisioned through expected
   saturation. Use coarse counts derived from available cores/rank, not the old
   count.
3. Retain two or three counts from the first useful plateau. At those counts,
   test only meaningful `PLACES`×`PROC_BIND` combinations whose actual place
   lists have been verified.
4. Refine/repeat the strongest runtime families. If placement differences are
   below noise, choose the simpler/safer policy and retain the tie evidence.

#### C. Metrics to Observe

Use the common scorecard, emphasizing CPU utilization and oversubscription,
actual thread/place maps, LU versus solver timing, MPI progress symptoms,
context switching if cheaply available, and GPU gaps correlated with host
starvation.

#### D. Closing Condition vs Investigation

Close 3A when a thread-count plateau and a legal, repeatable placement policy
are established and neighboring counts show low expected payoff.

Investigate catastrophic placement loss, good GPU utilization paired with a
large solver regression, non-monotonic results outside measured noise, or
different policies on nominally identical nodes. Verify the effective place
list and MPI binding before profiling. Trace only to answer whether host
submission/progress is creating specific GPU gaps.

### Subgroup 3B — CPU / Memory Affinity

Key controls: `--cpu-affinity`, `--mem-affinity`, coordinated with the retained
OpenMP and launcher policies.

#### A. Mechanism and 8×H200 Prior Knowledge

CPU affinity controls which cores serve each local rank; memory affinity
controls the NUMA domain of host allocation. They can improve GPU/NUMA/NIC
locality, but overly narrow binding starves launch/progress/refinement threads.
They overlap directly with OpenMP placement and MPI binding, so separately
chosen settings cannot simply be stacked.

On 8×H200, explicit HPL affinity did not improve the tested control and small
core slices were disastrous. The combined OpenMP×HPL-affinity space was never
cleanly tested, so the conclusion is conditional. The new cpuset, four ranks
per node, and NIC topology fully reopen this group.

Relevant dependencies include E03, E04, E13, and especially E19–E20.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

#### B. Sweep Procedure

1. Use the 3A runtime as the control and verify every proposed CPU range lies
   within the scheduled cpuset.
2. Compare no explicit HPL affinity with one broad topology-aligned CPU policy.
   Never begin with a narrow cores/rank allocation.
3. If CPU placement is helpful or materially changes behavior, compare the
   corresponding local versus alternative memory-affinity policy.
4. Run a small interaction check with the best one or two OpenMP policies;
   this is required before combining an affinity winner with an independently
   selected OpenMP winner.
5. Stop if affinity is flat or negative and the mapping is already correct.

#### C. Metrics to Observe

Use the common scorecard, plus effective CPU mask and NUMA policy per rank,
cores/rank, CPU/memory/NIC locality to the assigned GPU, CPU utilization,
host-memory bandwidth/remote-access symptoms when available, and LU/solver
phase attribution.

#### D. Closing Condition vs Investigation

Close 3B when an explicit coordinated policy repeatably wins, or no-affinity
is shown to be a safe plateau under the retained launcher/OpenMP control.

Investigate launch errors, out-of-range cpusets, severe loss under binding,
uneven CPU load, remote-memory behavior, or disagreement between affinity and
OpenMP results. These are mapping questions first; trace only if a verified
mapping still produces an unexplained host/GPU critical-path delay.

### Subgroup 3C — Device Residency and Buffering

Key controls: `--fill-device`, `--Anq-device`,
`--fill-device-buffer-size`.

#### A. Mechanism and 8×H200 Prior Knowledge

HPL-MxP retains the original FP64 matrix for residual/refinement work. Greater
device residency can reduce host↔device staging during IR but consumes VRAM
needed by low-precision factors, panels, communication buffers, cuBLAS, and
runtime workspaces. `--fill-device 1` is the automatic/full-fill policy and
overrides `--Anq-device`; partial `Anq-device` values are meaningful only with
`--fill-device 0`. The fill buffer reserves VRAM headroom and is primarily a
safety/residency boundary, not guaranteed to be a smooth performance knob.
Phase 1 discovers the broad N/residency operating regime; this subgroup tunes
residency details within the retained geometry rather than repeating a broad
N sweep.

On 8×H200, fill-device produced a modest defensible gain, but its direct pair
was node-confounded. A broad buffer region was flat, and smaller reserves
caused refinement to stall and verification to fail. The exact old MB
threshold cannot be transferred because `N`, `NB`, ownership, communication
workspaces, package, and topology have changed. The old small-N study showed
that higher FP64 residency can sharply reduce IR; the later bundled record
shows such a regime can win globally when enough LU efficiency is recovered.
Neither result identifies a universal `N` or buffer setting.

Relevant dependencies include E05, E14–E17, E21, and E36.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

#### B. Sweep Procedure

1. Measure the current no-fill/default-residency control with full memory and
   phase telemetry.
2. If Phase 0/1 headroom supports it, test `--fill-device 1` with a conservative
   reserve. If it is unsafe, skip full fill and test partial residency.
3. Test `--Anq-device` only with `--fill-device 0`, using a few safe column
   counts that span materially different residency levels. Do not place fill
   and `Anq-device` in a meaningless Cartesian product.
4. Retain the better residency mode(s). For fill-device only, sweep the buffer
   from conservative toward greater residency in bounded steps, watching the
   worst GPU. Stop before the measured safety reserve is exhausted; an invalid
   point is a boundary, not a slow candidate.
5. Repeat the selected mode/buffer against the no-fill control. Recheck the
   Phase 1 N boundary lightly if residency materially changes headroom.

#### C. Metrics to Observe

Use the common scorecard, emphasizing maximum device memory/minimum headroom
per GPU, host-memory displacement, LU time, solver/refinement time and share,
iteration/residual trajectory, allocation warnings, data-transfer symptoms,
and whether a phase improvement survives end-to-end scoring.

#### D. Closing Condition vs Investigation

Close 3C when the residency mode and a safe buffer/headroom region are valid,
repeatable, and no neighboring safe point offers meaningful gain. A broad safe
plateau is a sufficient result.

Investigate any stalled or increased refinement iterations, non-finite or
failed residual, abrupt solver-time cliff, unexpected per-rank VRAM asymmetry,
or LU loss that cancels a solver gain. Do not squeeze the reserve after a
correctness failure. Trace only a concrete staging or synchronization question
that ordinary phase/memory data cannot answer.

### Subgroup 3D — Remaining Host / Memory Controls

Conditional controls include `--cuda-host-register-step`,
`--call-dgemv-with-multiple-threads`, and other installed-release host/memory
controls supported by an observed bottleneck.

#### A. Mechanism and 8×H200 Prior Knowledge

Host registration batches pinning of host-resident FP64 columns, trading
registration/setup overhead against transfer efficiency and pinned-memory
pressure. It matters mainly when a meaningful FP64 fraction is host-resident.
The DGEMV control partitions rows per host thread in refinement; nonzero values
can add synchronization, cache/NUMA traffic, and contention with MPI progress.

On 8×H200, register-step sweeps were below the noise floor in two residency
contexts. Every tested nonzero DGEMV partition slowed only the solver under one
specific large-N OpenMP/residency/precision regime. The later small-N record
used a much larger nonzero partition but changed several controls at once, so
it neither proves a DGEMV benefit nor preserves `0` as a universal optimum.
These results are conditional priors because ranks/node, N/residency, and the
host/refinement balance can change.

Relevant dependencies include E17 and E20–E21; precision later invokes E35.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

#### B. Sweep Procedure

1. Use normal phase and memory evidence to decide whether a control is
   relevant. If FP64 data is almost entirely device-resident, do not spend a
   sweep on host registration. If solver time is small and stable, do not tune
   DGEMV partitioning.
2. For a relevant control, compare the installed default with a few
   mechanism-distinct values. Change one host/memory mechanism at a time.
3. Retain several values only when a clear region appears; then refine and
   repeat with the current OpenMP/affinity/residency control.
4. Reopen DGEMV after Phase 5 precision, or after any later material
   N/residency/host-runtime change, only if refinement work changes
   materially; otherwise preserve the Phase 3 conclusion within its tested
   operating regime.

#### C. Metrics to Observe

Use the common scorecard, plus registration/startup time if visible,
host-resident data volume, pinned-memory pressure, host↔device transfer time or
symptoms, solver time/iterations, CPU utilization, NUMA traffic, and MPI
progress interference.

#### D. Closing Condition vs Investigation

Close 3D when the default is within noise, a stable winner is verified, or the
mechanism is demonstrably irrelevant under the current residency/solver split.

Investigate only when ordinary results show substantial solver or transfer
time, a non-monotonic response larger than noise, or phase movement without an
end-to-end explanation. Trace a named transfer, DGEMV, or progress question;
do not profile merely because these flags remain available.

## 7. Phase 4 — Communication

Important controls include:

- `--use-mpi-panel-broadcast`;
- `--u-panel-chunk-nbs`;
- `--mpi-use-mpi`;
- `--use-host-mpi`;
- `--ucx-tls` and `--ucx-affinity` or site-specific transport/NIC controls;
- MPI/NCCL/UCX environment controls that are documented, supported, and
  relevant to the installed GAAS stack.

Do not permanently fix the subgrouping now. Split this phase later according
to whether the observed bottleneck is transport selection, NIC/rail mapping,
panel policy, progress, or chunk/readiness behavior.

### A. Mechanism and 8×H200 Prior Knowledge

`--use-mpi-panel-broadcast` assigns a percentage of panel steps to the
CUDA-aware MPI path rather than the NCCL panel path; it is a schedule policy,
not a continuous bandwidth dial. `--u-panel-chunk-nbs` changes U-panel
granularity in units of `NB`, trading earlier readiness/overlap against more
launches, collectives, and synchronization. Its documented validity/usefulness
depends on `N`, `NB`, and `npcol`.

`--mpi-use-mpi` enables an MPI_Bcast fallback. `--use-host-mpi` disables the
CUDA-aware path and normally adds staging, so both are initially diagnostic
or compatibility controls rather than presumed performance winners.
UCX/NIC settings select the actual inter-node device and transport; changing
them can change GPU-direct behavior, MPI progress, rail balance, and latency.

On the single NVSwitch-connected 8×H200 node, broadcast and chunk clean scores
were inside measured drift. Traces still proved that they changed execution:
MPI-heavy broadcast reduced NCCL work but increased MPI/stream waits, and a
smaller chunk increased launch count without shortening the critical path.
The later small-N record used broadcast `100` rather than the historical `50`,
but changed multiple controls simultaneously; it does not isolate a broadcast
effect. `50` is therefore only a historical control conditional on the old
N/NB/grid/residency regime, not a generally optimal percentage.
Crossing two network boundaries on the 3-node target fully reopens all of
these conclusions. Single-node flatness must never be projected onto
multinode scaling.

Relevant dependencies include E06, E12–E13, E22–E29, and E32.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

### B. Sweep Procedure

Use this as a logical initial strategy, then restructure the phase from data:

1. **Validate the intended fast path.** Confirm the selected NIC/rail,
   CUDA-aware MPI/GPU-direct operation, UCX transport, and rank mapping. Compare
   a site-recommended policy with an alternative only when Phase 0 shows a real
   device/rail choice.
2. **Screen panel-broadcast policy.** With geometry/grid/placement fixed,
   compare mechanism-distinct endpoints and one or more intermediate policies,
   including the effective package default. Use bracketing controls. Do not
   infer that the numerical percentage interpolates linearly.
3. **Retain several policies.** Keep candidates that differ in LU time,
   scaling, or rank balance even when end-to-end values initially tie; they may
   interact differently with chunking.
4. **Test U-panel granularity selectively.** Recalculate the installed
   release's constraint using the current `N`, `NB`, and `npcol`. Sweep a small
   coarse set at only the retained broadcast/transport policies. Avoid a full
   broadcast×chunk product.
5. **Use fallbacks diagnostically.** Test `--mpi-use-mpi` or `--use-host-mpi`
   when the fast path is unavailable, unstable, or a host-staging comparison
   answers a concrete question. Do not make fallback exploration mandatory on
   a healthy CUDA-aware path.
6. **Refine and verify.** Repeat winning candidates and a stable control. If a
   transport or chunk change is material, expect Phase 5 scheduling to reopen.

Possible later splits include transport/NIC, broadcast policy, chunk/readiness,
or progress/fallback subgroups. Choose the split only after the first sweep and
dependency review.

### C. Metrics to Observe

Use the common scorecard, emphasizing:

- LU time/rate and end-to-end multinode scaling efficiency;
- per-rank/per-node arrival or runtime imbalance;
- panel/collective time and wait symptoms available from normal logs;
- NIC/rail traffic balance, link rate, retransmission/error indicators, and
  GPU-direct versus host-staged behavior;
- MPI, NCCL, and UCX warnings or fallback messages;
- message/chunk cadence and the calculated chunk constraint; and
- solver/refinement time, because multinode collectives may also affect it.

Do not require Nsight Systems for ordinary communication sweeps.

### D. Closing Condition vs Investigation

Close Phase 4 when a communication policy or useful plateau is repeatable,
correct, mapping-stable, and scaling is understandable; neighboring or
mechanism-distinct controls bound the conclusion; and further refinement is
below noise or lower value than compute/precision work.

Do not close when scaling is unexpectedly poor, one node/rank arrives late,
rail use is asymmetric, endpoints behave anomalously, a flag clearly changes
LU structure but not the score for unexplained reasons, or repetitions
disagree materially. In those cases, pose a concrete trace question such as
"which ranks wait at the panel broadcast and on which network path?" or "did
smaller chunks expose useful work but add more synchronization than they
hide?" Then profile only the paired candidates needed to answer it.

## 8. Phase 5 — Compute, Precision, Dependency Scheduling, and Overlap

Key controls that must be covered when supported and relevant:

- `--sloppy-type`;
- `--preset-gemm-kernel`;
- `--prioritize-factorization`;
- `--prioritize-trsm`;
- `--use-separate-stream-for-gemm`;
- any additional installed-release compute/scheduling control that targets an
  observed bottleneck and is documented for the target GPU.

Do not permanently define the subgroups now. The eventual split must follow
earlier results, supported option combinations, dependency relationships, and
targeted traces when necessary.

### A. Mechanism and 8×H200 Prior Knowledge

`--sloppy-type` selects the low-precision LU/preconditioner path. A more
aggressive type can increase tensor-core throughput and reduce data movement,
but can require more iterative-refinement work or fail convergence. The
primary objective remains time to a valid FP64-quality solution, not LU or
kernel throughput alone.

`--preset-gemm-kernel` selects a package-supported GEMM implementation. Kernel
support and value meanings are release/architecture specific; do not infer a
preset number from "SM90" or copy one from another release. `NB` determines
important GEMM shapes, so a kernel conclusion is conditional on geometry.

Factorization/TRSM priorities delay otherwise-ready GEMMs so dependency-
producing panel work can advance. A separate GEMM stream exposes concurrency;
priority determines how that concurrency serves the critical path. These
controls form an interaction group.

On 8×H200, factorization priority shortened LU in a same-job 2×2 factorial
test, TRSM priority was neutral, and disabling the separate GEMM stream
regressed LU. However, the stream×priority interaction was not fully crossed.
All scored work used FP16, and the effective SM90 kernel was observed rather
than compared against alternatives. The later small-N record used
factorization priority `0` as part of a multi-parameter bundle, so it does not
isolate a reversal or establish `0` as the winner. Therefore there is no old
precision or kernel winner, and every scheduling result is conditional on its
N/NB/grid/residency, host-runtime, communication, and precision regime.

Relevant dependencies include E28–E36. In particular, precision is upstream of
communication, residency, refinement, and scheduling; kernel selection is
upstream of final scheduling. This is why compute/precision screening should
precede the final scheduling/overlap decision.

> These observations are prior knowledge and hypotheses only. The target topology must be evaluated independently.

### B. Sweep Procedure

Use the following initial logic, adapting the subgroup boundaries after each
result:

1. **Enumerate only supported choices.** Read installed `--help`, package
   tuning/release files, and captured effective defaults. Reject undocumented
   presets or unsupported precision strings before experimentation.
2. **Screen sloppy precision.** Compare the effective default/control with
   supported precision modes one at a time. Use a fixed supported kernel and
   stable communication/scheduling control. Correctness, residual trajectory,
   refinement iterations, and total time decide the result.
3. **Screen GEMM kernels where a real choice exists.** For the retained
   precision candidate(s), compare only presets documented for the target H200
   and package. If the package exposes no supported alternative, document that
   and close this control without inventing a test.
4. **Review upstream consequences.** After a precision change, recheck VRAM
   headroom, safe residency/buffer, N feasibility, solver/DGEMV behavior, and
   the important Phase 4 communication candidates. After a kernel change,
   lightly revalidate its interaction with `NB`.
5. **Tune final scheduling/overlap.** With the intended precision/kernel and
   communication policy fixed, screen stream on/off and factorization/TRSM
   priority through small, targeted factorial or staged comparisons. Start
   with individual main effects, then test only combinations needed to
   distinguish synergy or redundancy.
6. **Refine and verify the final stack.** Repeat the leading full-stack
   candidate against the original retained control, then lightly revalidate
   the most dependency-sensitive earlier choices rather than reopening every
   phase.

Possible later splits include precision/correctness, kernel/geometry, or
dependency scheduling/overlap. Decide them from the data; do not encode them
as permanent subgroups in advance.

Measurement-only controls such as tolerance, `--skip-tests`, monitoring, and
`--gemm-iterations` are not scoring knobs. Keep them fixed except in a clearly
labeled diagnostic.

### C. Metrics to Observe

Use the common scorecard, emphasizing:

- total HPL-MxP GFLOP/s/time and LU GFLOP/s/time;
- solver/refinement time, iteration count, and residual trajectory;
- final residual, non-finite values, overflow, convergence warnings, and
  `PASSED`;
- dominant kernel duration, achieved compute rate, GPU utilization, and gaps
  when ordinary output or a targeted profile exposes them;
- panel critical-path behavior, stream overlap, synchronization delay, and
  rank imbalance;
- VRAM/workspace/headroom changes by precision or kernel; and
- change against both the new-system original baseline and the exact
  in-sweep/full-stack control.

### D. Closing Condition vs Investigation

Close Phase 5 when all supported high-value controls have either a verified
winner/plateau or a documented reason they are inapplicable; the final-stack
candidate repeats above noise; residual/correctness is valid; and targeted
revalidation finds no material regression in reopened upstream decisions.

Investigate when lower precision accelerates LU but slows or breaks
refinement, a kernel changes internal behavior without end-to-end benefit,
priority results reverse across ranks or transport policies, GPU gaps remain
large, or repetitions disagree. Trace only a concrete question such as why a
precision wins LU but loses refinement, whether GEMMs starve factorization, or
which synchronization prevents separate streams from overlapping.

## 9. Mandatory Dependency Review After Every Phase/Subgroup

The checkpoint is mandatory after Phase 0, after Phase 1B (covering the Phase
1A→1B sequence), each of 2A/2B/2C, each of 3A/3B/3C/3D, and each major sweep
or later-created subgroup in Phases 4 and 5. It is not a separate final phase.
The checkpoint is strategic analysis: it occurs after the
`workflow/07-Workflow.md` `EXECUTED` handoff and explicit human
`ANALYSE_RESULTS` authorization, not during Codex execution.

At the checkpoint, the Strategic Analyst must pause and ask the user:

> Should I proceed with the dependency review for this checkpoint, or explicitly skip it?

The checkpoint must not be silently omitted. If the user chooses to skip,
record that choice and its scope in the experiment/analysis handoff, and the
Strategic Analyst still recommends exactly one next action before the
human's final decision; nothing executes automatically. If the user chooses
to proceed:

1. Read the relevant entries in the
   [dependency-graph README](../dependency-graph/README.md) and
   [edges.csv](../dependency-graph/edges.csv). The Strategic Analyst need not
   reproduce or manually restate every edge.
2. Ask and answer:

   - Did the newly selected setting materially change an upstream variable
     that affects an earlier tuning conclusion?
   - Does the graph indicate that an earlier parameter should be fully
     re-swept, lightly revalidated, or kept closed?
   - Did the sweep expose an interaction that should change the structure of
     the next phase?
   - Was an earlier assumption invalidated?
   - Does the evidence justify a trace or deeper investigation?
3. Produce a short decision record:

   | Earlier decision | Relevant edge(s) | Material upstream change? | Action | Evidence/question |
   |---|---|---|---|---|
   | `<parameter/group>` | `E##` | Yes/No | Full re-sweep / light revalidation / keep closed | `<why>` |

4. Recommend exactly one next action: refine the current sweep, run a bounded
   revalidation, investigate a named anomaly, close the subgroup, or proceed
   to the next subgroup.
5. Present the record for human final review. The recommendation is the
   Strategic Analyst's. Codex may execute an explicitly prespecified approved
   revalidation, never one derived automatically from graph edges. The next
   action is executable only through a materialized, synchronized,
   human-approved task; a conversation recommendation alone authorizes
   nothing.

Use these interpretations:

- **Full re-sweep:** the prior conclusion is outside its tested envelope or a
  strong dependency has materially changed. Re-establish the broad region.
- **Light revalidation:** repeat the old control and a few representative or
  boundary candidates; do not recreate the whole sweep.
- **Keep closed:** the upstream change is immaterial, the edge is conditional
  and inactive, or expected payoff is below noise and unexplored work.

Do not automatically reopen everything. Examples that justify reopening
include a major `N`/`NB` change, a grid crossing node boundaries differently,
a new rank/GPU/NIC map, a residency mode that moves the memory boundary, a
multinode transport change, or a precision/kernel change that shifts LU versus
refinement. In particular, a grid change that materially shifts LU/IR balance
or reverses the N ranking calls for a bounded targeted N resweep, not a full
N×grid matrix. A small numerical winner inside noise does not by itself justify
a campaign-wide reset.

## 10. Tracing / Investigation Decision Rules

Tracing is a diagnostic branch, never a completion ritual. Ordinary sweeps use
normal HPL-MxP phase output, correctness, monitoring, memory telemetry, and
repeated controls first.

Open a trace branch only when all of the following are true:

1. an ordinary result is repeatable or materially anomalous;
2. at least two plausible mechanisms would lead to different next actions;
3. a trace can distinguish those mechanisms; and
4. the trace has a written decision question and a paired control/candidate.

Suitable questions include:

- Why does one grid produce late ranks despite similar compute time?
- Which ranks and path dominate a multinode panel-broadcast collapse?
- Did a smaller U-panel chunk expose useful overlap or merely add launches and
  synchronization?
- Did a precision change improve LU but add refinement iterations or staging?
- Is a factorization delayed behind long GEMMs, and does priority move the
  critical path?
- Why is observed three-node scaling below the model implied by clean
  single-node/intra-node work?

For Nsight Systems or another profiler, capture the smallest representative
interval and rank set that answers the question, while retaining enough ranks
to see imbalance. Compare the same allocation and fixed controls when
possible. Report cumulative per-rank quantities as such; do not add them and
call the result wall-clock time.

After tracing, the result must change a decision: refine a range, fix mapping,
split/reorder a phase, revalidate a dependency, close a false lead, or propose
a separately authorized system correction. A trace that produces no decision
should not be expanded into broader tracing.

## 11. Compact End-to-End Workflow

| Stage | Next bounded action | Move-on condition |
|---|---|---|
| 0. Characterize | Inventory every node/fabric/CPU/NUMA/NIC/cpuset; freeze software; prove rank↔GPU↔NIC mapping; validate and repeat one conservative run. | New-system original baseline, noise floor, valid mapping, and safe headroom exist. |
| 1A. N/residency | Derive `N_pivot`; with `--fill-device 1` and fixed provisional controls, sweep about 70–120% in 10% steps; refine the best and IR-transition regions in about 5% steps. | One or more correct, safe N/residency regimes survive LU/IR attribution and noise checks. |
| 1B. NB within regime(s) | Broad-screen `NB` at representative retained N controls; review whether NB changes N ranking; run only a targeted local N resweep if justified. | A correct, safe, bounded N/NB region or plateau survives noise and its dependency review. |
| 2A. Grid/order | Screen grid shapes under one verified map; test order only for retained shapes. | A repeatable shortlist exists; sub-noise candidates remain tied. |
| 2B. GPU placement | Overlay shortlisted grids on node/GPU fabric; test only mechanism-distinct maps. | Every rank uses the intended GPU and useful maps are bounded. |
| 2C. Other placement | If NIC/rail or launcher placement creates a real choice, compare a few verified policies; otherwise close as inapplicable. | Mapping is stable and has no unexplained node/rail skew. |
| 3A. OpenMP | Derive counts from new cores/rank; broad-screen to a plateau; test legal place/bind policies at retained counts. | Stable thread/runtime region established. |
| 3B. CPU/NUMA | Compare unset with broad topology-aware affinity; cross only enough OpenMP choices to resolve interaction. | Coordinated affinity wins, or leaving it unset is a verified plateau. |
| 3C. Residency | Compare no-fill with safe fill; use `Anq-device` only with fill off; find a safe buffer region; recheck `N` headroom if moved. | Valid residency/headroom region survives repeated control. |
| 3D. Host/memory | Tune registration only with material staging and DGEMV only with material solver cost. | Winner/default established, or mechanism documented irrelevant. |
| 4. Communication | Verify UCX/NIC/GPU-direct; screen panel policy; test valid chunks only on retained policies; use fallbacks diagnostically. | Mapping-stable communication policy/plateau and scaling are understood. |
| 5. Compute/final scheduling | Screen supported precision by valid end-to-end time; screen supported kernels; then test stream/priorities with a small interaction design. | Correct, repeatable final stack passes targeted dependency revalidation. |

After Phase 0, after the combined 1A→1B sequence, after every subsequent table
row, and after every later-created subgroup in Phases 4/5, ask the user whether
to perform or explicitly skip the dependency review, record the decision, and
obtain human review before continuing. The Strategic Analyst owns the
checkpoint record and the single next-action recommendation; Codex executes
only explicitly approved follow-up work. At any stage, treat invalid/OOM/
non-finite runs as boundaries, differences inside measured drift as ties, and
traces as hypothesis tests rather than routine data collection.

The campaign rule remains: do not solve dependencies by brute-force Cartesian
search. Solve them with sequential phase sweeps, explicit dependency review,
and bounded targeted resweeps.

The campaign is complete when the final configuration is correct, repeatable,
above noise, compared against the unchanged new-system original baseline, and
supported by targeted revalidation of every earlier decision that a material
dependency change reopened. The outcome is topology-specific; the next
machine starts again at Phase 0 with this method, not with these values.

## Evidence Base

This blueprint synthesizes the completed planning record while keeping old
measurements separate from new-topology decisions:

- [Optimization plans](../PLANS.md)
- [First consolidation](../consolidate_1.md)
- [Mechanism consolidation](../consolidate_m1.md)
- [Communication/scheduling consolidation](../consolidate_m2.md)
- Geometry analyses: [N](../analysis/n-sweep-370k-510k.md),
  [NB](../analysis/nb-sweep.md), and
  [coupled N/NB](../analysis/N-NB-resweep.md)
- Decomposition and host analyses: [grid/order](../analysis/np-sweep.md),
  [affinity](../analysis/affinity-491k.md), and
  [OpenMP](../analysis/omp-sweep.md)
- Residency analyses:
  [fill/buffer/register](../analysis/matrix-placement-491k.md) and
  [N/residency interaction](../analysis/matrix-placement-N-resweep.md)
- New bundled operating-regime evidence:
  [`SingleNode-resweep_v1.1`](../../experiments/SingleNode-resweep/README.md)
- Communication and scheduling analyses:
  [MPI/NCCL and chunking](../analysis/mpi-nccl-coms-sweep.md),
  [factorization/TRSM priority](../analysis/factorization-priority.md),
  [separate GEMM stream](../analysis/separate-stream-for-gemm.md), and
  [DGEMV host threading](../analysis/dgemv-with-multiple-threads.md)
- [Dependency model](../dependency-graph/README.md)
- [Machine-readable dependency edges](../dependency-graph/edges.csv)
- [HPL-MxP tuning-parameter guide](../../HPL_MxP_TuningParam_Guide.md)
