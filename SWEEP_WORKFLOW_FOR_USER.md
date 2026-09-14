# HPL-MxP Multinode Sweep Workflow for Users

This guide explains how a human user works with an agent to optimize NVIDIA
HPL-MxP on the 3-node × 4-GPU GAAS topology. It is a practical companion to
the formal rules in `workflow/`, the sweep method in
`planning/blueprint/HPL_MxP_Sweep_Blueprint.md`, and the dependency model in
`planning/dependency-graph/`.

## Quick-start workflow

For every optimization direction, use this loop:

1. **Choose one phase or subgroup.** State the topology, current baseline,
   current retained configuration, and the tuning question.
2. **Ask the agent for a bounded proposal.** The agent should give the
   hypothesis, candidate values, fixed controls, resource request, exact
   command/script plan, correctness gates, repetition plan, stopping rule, and
   relevant dependency-graph edges.
3. **Review and authorize the proposal.** The agent must not submit jobs or
   start a new optimization direction from a recommendation alone.
4. **Let the agent prepare and validate locally.** It creates the experiment
   record, validates scripts, synchronizes the approved files to GAAS, and
   submits jobs sequentially.
5. **Let the agent validate and preserve every attempt.** A run counts only if
   PBS output exists, normal HPL-MxP output is present, the residual is finite,
   and verification reports `PASSED`.
6. **Authorize analysis explicitly.** Use the `ANALYSE_RESULTS` form from
   `workflow/07-Workflow.md` before the agent creates or updates an analysis or
   `planning/PLANS.md`.
7. **Answer the dependency checkpoint.** After each phase or major subgroup,
   the agent asks:

   > Should I proceed with the dependency review for this checkpoint, or explicitly skip it?

   The agent then records whether earlier conclusions should be fully
   re-swept, lightly revalidated, kept closed, or investigated.
8. **Approve exactly one next action.** The agent recommends refine,
   revalidate, investigate, close, or proceed. It waits for your confirmation
   before continuing.
9. **End with a handoff.** The agent records the current step, attempts, PBS
   jobs, evidence, decisions, blockers, and exact resume action in `progress/`.

Always compare candidates against both the exact in-sweep control and the
immutable original baseline for the active topology. Treat results within the
measured noise floor as ties. Do not build a large Cartesian product of
parameters.

The rest of this document walks through a complete example using Phase 1.

## Phase 1 example: N/NB geometry sweep on 3 nodes × 4 GPUs

Assume Phase 0 has already passed: the agent has verified the 3-node
allocation, rank/GPU/NIC mapping, software environment, memory headroom, and
the immutable original baseline:

`3x4-baseline_v1`: `N=480000`, `NB=1024`, `3×4` grid, 12 ranks,
`4.0092e+04` GFLOP/s, `PASSED`.

The single-node value `baseline-sweep_v1` is only historical context.

### 1. You start the Phase 1 request

You might say:

> Start Phase 1 for the 3-node × 4-GPU HPL-MxP campaign. Reopen the coupled N/NB geometry search according to the blueprint. Prepare the first bounded NB screen only.

The agent reads the required workflow and confirms the current state. It
responds with a proposal such as:

> Phase 1 decision question: which NB region improves end-to-end performance at a safe provisional N on the 3×4 topology?
>
> I will hold `N=480000` fixed initially and screen `NB` values such as `512, 1024, 2048, 3072, 4096`, subject to the measured memory reserve.
>
> Fixed controls:
>
> - 3 nodes × 4 GPUs, 12 ranks
> - verified rank/GPU mapping
> - current communication and launcher configuration
> - `--skip-tests 1`
> - required GPU monitoring flags
> - finite residual and `PASSED` verification
>
> I will report overall GFLOP/s, LU time, solver time, memory headroom, correctness, and change versus both the local control and `3x4-baseline_v1`.
>
> I will submit jobs sequentially, preserve every `.o`/`.e` file, and stop at invalidity, unsafe memory, repeated degradation, or a clear plateau.

At this point, the agent has not submitted anything. It is asking for
approval of a specific experiment.

### 2. You approve the experiment

You reply:

> Approved. Run the NB screen exactly as proposed. You may prepare, synchronize, submit, and monitor the experiment.

The agent then:

1. Creates a run directory such as:

   `experiments/3Nodes-4GPUs/nb-screen-v1/`

2. Writes the README and PBS script with:
   - hypothesis;
   - fixed and varying parameters;
   - baseline and control;
   - resource request;
   - exact launcher;
   - expected output markers;
   - stopping criteria.

3. Runs local validation such as `bash -n` and `git diff --check`.

4. Commits/pushes and synchronizes with GAAS if that scope was authorized.

5. Submits one job at a time.

You would see progress messages like:

> Prepared `nb-screen-v1`. Syntax validation passed. The script uses the container MPI launcher, `pbsdsh` bridge, `place=scatter`, no `mpiprocs`, and a de-duplicated hostfile.
>
> Variant `NB=512` submitted as attempt `nb-screen-v1_512_v1`, PBS job `<id>`.
>
> The job completed. Verification passed. I am preserving its stdout/stderr and will submit the next variant only after recording the result.

The agent does not submit all jobs concurrently because GAAS has known
multinode submission races.

### 3. The agent validates each result

For every candidate, it checks more than the exit code:

- PBS state and exit status;
- expected `.o` and `.e` files;
- normal HPL-MxP output;
- finite residual;
- `PASSED`;
- overall GFLOP/s;
- LU and solver timings;
- worst-rank memory/headroom;
- GPU monitoring warnings;
- node allocation and mapping.

A successful result might be recorded like:

| NB | GFLOP/s | vs local control | vs original baseline | Result |
|---:|---:|---:|---:|---|
| 1024 | 40,092 | 0.00% | 0.00% | PASSED |
| 2048 | 43,800 | +9.25% | +9.25% | PASSED |
| 3072 | 44,100 | +9.99% | +9.99% | PASSED |
| 4096 | 43,700 | +9.00% | +9.00% | PASSED |

These numbers are illustrative, not predicted results.

If a candidate produces an OOM, failed residual, or non-finite result, it is
recorded as an invalid boundary. It is not ranked as a slow configuration.

If the agent encounters a hang, MPI failure, unexpected rank mapping, or
uncertain transport behavior, it stops and reports the issue instead of
automatically retrying.

### 4. Results are logged before interpretation

After the jobs finish, the agent updates:

- the experiment README;
- `results/metrics.csv`;
- `results/RESULTS.md`;
- the progress handoff.

At this point it may say:

> The NB screen is complete and all valid candidates have been logged. `NB=2048` and `NB=3072` form a possible plateau, but the separation is close to observed run-to-run drift. I have not promoted either value as the new retained control.

The general workflow intentionally separates result logging from analysis. The
agent does not silently rewrite `PLANS.md` or declare a winner.

### 5. You authorize analysis

You then explicitly authorize the analysis:

```text
ANALYSE_RESULTS
analysis_id: 3x4-nb-screen
source: results/metrics.csv
include: nb-screen-v1 and 3x4-baseline_v1
grouping: NB at fixed N=480000
scope: current session
restrictions: include LU, solver, memory, correctness, and both baseline comparisons
```

The agent creates or updates:

`planning/analysis/3Nodes-4GPUs/3x4-nb-screen.md`

The analysis includes:

- the original baseline;
- the in-sweep control;
- all valid and invalid attempts;
- percentage increase versus `3x4-baseline_v1`;
- percentage change versus the local control;
- noise/drift limitations;
- recommendation for the next bounded action.

For example:

> `NB=3072` is numerically fastest, but its advantage over `NB=2048` is within measured drift. The evidence supports retaining both as candidates rather than declaring a unique winner.

### 6. The dependency checkpoint occurs

Now the agent pauses and asks the exact checkpoint question:

> Should I proceed with the dependency review for this checkpoint, or explicitly skip it?

#### If you say “proceed”

The agent reads the relevant graph edges, likely including:

- `E07`: N → NB;
- `E08`: NB → safe N/memory boundary;
- `E09/E10`: geometry → grid/order;
- `E22/E23/E24`: NB → communication and chunking;
- `E28`: NB → scheduling;
- `E34`: NB → GEMM kernel.

It then produces a short decision record:

| Earlier decision | Edge | Material change? | Action | Reason |
|---|---|---|---|---|
| Safe N boundary | E08 | Yes | Recheck N/headroom | Larger NB may consume more workspace |
| Process grid | E10 | Possibly | Light revalidation | NB changes local block and communication shape |
| U-panel chunk | E23/E24 | Yes | Recalculate validity | Chunk semantics depend on N, NB, and npcol |
| Scheduling | E28 | Possibly | Light revalidation | NB changes panel/update balance |

Then it recommends exactly one next action:

> Recommended next action: perform a bounded N bracket using the two retained NB candidates, while retaining `NB=1024` as the stable control.

It waits for your confirmation.

#### If you say “skip”

The agent records:

> Dependency review skipped for the current NB screen, scope: current session.

It still waits for your final decision before proceeding. Skipping the review
does not grant permission to start the next sweep automatically.

### 7. The N portion of Phase 1

If you approve the recommended action, the agent proposes a second bounded
sweep.

It does not test every `N × NB` combination. Instead, it might propose:

- retained `NB=2048`;
- retained `NB=3072`;
- stable control `NB=1024`;
- a small number of safe N values based on measured memory headroom.

The agent explicitly avoids blindly copying the single-node `N=491520`
result. It may say:

> The current memory evidence does not justify testing the upper boundary yet. I propose `N=420000`, `460000`, and `480000`, with a boundary probe only if the headroom remains sufficient.

Again, you approve the exact proposal before execution.

### 8. When Phase 1 closes

Phase 1 closes only when:

- a safe, correct N/NB region exists;
- neighboring candidates bound the useful region;
- leading candidates survive repetition or bracketing;
- memory behavior is understood;
- differences smaller than measured drift are treated as ties;
- the result is better than the original baseline or is a justified plateau;
- further geometry work has lower expected value than grid and placement work.

The agent may conclude:

> Phase 1 result: retain `N≈460000–480000` and `NB=2048–3072` as a tied geometry region. `NB=1024` remains the control. No unique NB winner is established above noise. The next recommended direction is Phase 2A process-grid/order screening.

It then updates the analysis and progress records, but does not start Phase 2
until you authorize it.

## In short

Your role is to make the scientific and authorization decisions:

1. approve or modify the proposed sweep;
2. approve execution;
3. authorize analysis with `ANALYSE_RESULTS`;
4. answer the dependency-review checkpoint;
5. approve exactly one next action.

The agent’s role is to:

1. translate the blueprint into a bounded experiment;
2. prepare and validate the files;
3. synchronize and execute only within the approved scope;
4. preserve evidence;
5. validate correctness;
6. calculate comparisons and noise;
7. perform the dependency review;
8. recommend the next action;
9. pause for you before continuing.

That gives you a controlled collaboration loop rather than handing the agent
an entire optimization campaign to run unattended.
