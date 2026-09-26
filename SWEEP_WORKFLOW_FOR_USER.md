# HPL-MxP Multinode Sweep Workflow for Users

This guide explains how a human user works with an agent to optimize NVIDIA
HPL-MxP on the 3-node × 4-GPU GAAS topology. It is a practical companion to
the formal rules in `workflow/`, the sweep method in
`planning/blueprint/HPL_MxP_Sweep_Blueprint.md`, and the dependency model in
`planning/dependency-graph/`.

The "agent" in this guide resolves into the Workflow v2 roles. The
**Strategic Analyst** designs bounded experiments, interprets results after
authorized analysis, runs the dependency checkpoint, and recommends exactly
one next action. You, the **Human Leader**, approve the specification, the
exact scope, and every final decision. **Codex** orchestrates only the
approved, synchronized execution, validates it operationally, and reports
facts in its Execution Report; **OpenCode workers** perform the substantive
execution. A conversation approval alone is never executable: execution
requires a synchronized `tasks/TASK-XXX.md` whose front matter records
`status: APPROVED` and `current_owner: codex`, and whose
`### 1.11 Authorization` records `status: APPROVED`, `approved_by: user`,
and the exact approved scope.

## Quick-start workflow

For every optimization direction, use this loop:

1. **Choose one phase or subgroup.** State the topology, current baseline,
   current retained configuration, and the tuning question.
2. **Ask the Strategic Analyst for a bounded proposal.** The Strategic
   Analyst should give the hypothesis, candidate values, fixed controls,
   resource request, exact command/script plan, correctness gates, repetition
   plan, stopping rule, and relevant dependency-graph edges.
3. **Review and authorize the specification.** Your approval covers the
   Strategic Specification and its exact scope. A conversation approval alone
   is not executable: the approved task must exist as a synchronized
   `tasks/TASK-XXX.md` with front matter `status: APPROVED` and
   `current_owner: codex`, and `### 1.11 Authorization` recording
   `status: APPROVED`, `approved_by: user`, and the exact approved scope.
   Codex must not submit jobs or start a new optimization direction from a
   recommendation alone.
4. **Let Codex orchestrate the approved execution.** Codex verifies the
   synchronized approved task, decomposes the approved scope, and delegates
   the substantive work—experiment record, script validation,
   synchronization, and sequential submission—to OpenCode workers.
5. **Let Codex operationally validate and preserve every attempt.** A run
   counts only if PBS output exists, normal HPL-MxP output is present, the
   residual is finite, and verification reports `PASSED`.
6. **Authorize analysis explicitly.** Use the `ANALYSE_RESULTS` form from
   `workflow/07-Workflow.md` before the Strategic Analyst creates or updates
   an analysis or `planning/PLANS.md`. Codex's part ends with its Execution
   Report and task status `EXECUTED`.
7. **Answer the dependency checkpoint.** After each authorized analysis of a
   phase or major subgroup, the Strategic Analyst asks:

   > Should I proceed with the dependency review for this checkpoint, or explicitly skip it?

   The Strategic Analyst either performs the review—recording whether earlier
   conclusions should be fully re-swept, lightly revalidated, kept closed, or
   investigated—or records the explicit skip and its scope. In both cases it
   recommends exactly one next action and waits for your decision; further
   experiments require a new approved, synchronized task.
8. **Decide on exactly one next action.** The Strategic Analyst recommends
   exactly one next action—refine, revalidate, investigate, close, or
   proceed—and waits for your decision. Further experiments require a new
   bounded task that you approve through the same specification and
   synchronization gates.
9. **End with a handoff.** After execution or incomplete execution, Codex
   records the operational handoff in `progress/`. After `ANALYSE_RESULTS`,
   the Strategic Analyst records analysis findings, the dependency-checkpoint
   outcome, human decision state, and recommended/approved next action
   according to `workflow/07-Workflow.md`.

Always compare candidates against both the exact same-protocol in-sweep
control and the immutable original baseline for the active topology. Treat
results within the measured noise floor as ties. Do not build a large
Cartesian product of parameters.

The rest of this document walks through a complete example using Phase 1.

## Phase 1 example: N/NB geometry sweep on 3 nodes × 4 GPUs

Assume Phase 0 has already passed: Codex has operationally verified the
3-node allocation, rank/GPU/NIC mapping, software environment, memory
headroom, and the immutable original baseline:

`3x4-baseline_v1`: `N=480000`, `NB=1024`, `3×4` grid, 12 ranks,
`4.0092e+04` GFLOP/s, `PASSED`.

The single-node value `baseline-sweep_v1` is only historical context.

This example illustrates only the NB-screen portion of Phase 1. Under the
current blueprint, Phase 1 discovers the useful `N`/FP64-residency operating
regime first (Phase 1A), then tunes `NB` within the retained regime (Phase
1B), then runs the dependency review with only a targeted local `N` resweep
if justified. The example below is therefore conditional on Phase 1A having
already completed and retained `N=480000` as a safe operating regime; it does
not redefine the blueprint's phase order.

`3x4-baseline_v1` is preserved unchanged as the campaign percentage
denominator. Its historical run protocol differs from the current scored-run
controls (see the fixed controls in the proposal below), so comparisons
against it keep it as the denominator and disclose that difference. It must
never be silently reused as the in-sweep control: each sweep measures its own
exact same-protocol control.

### 1. You start the Phase 1 request

You might say:

> Start Phase 1 for the 3-node × 4-GPU HPL-MxP campaign. Reopen the coupled N/NB geometry search according to the blueprint. Prepare the first bounded NB screen only.

The Strategic Analyst reads the required workflow and confirms the current
state. It responds with a proposal such as:

> Phase 1 decision question: which NB region improves end-to-end performance at a safe provisional N on the 3×4 topology?
>
> I will hold `N=480000` fixed initially and screen `NB` values such as `512, 1024, 2048, 3072, 4096`, subject to the measured memory reserve.
>
> Fixed controls:
>
> - 3 nodes × 4 GPUs, 12 ranks
> - verified rank/GPU mapping
> - current communication and launcher configuration
> - `--skip-tests 0`
> - `--monitor-gpu 0`
> - finite residual and `PASSED` verification
>
> I will report overall GFLOP/s, LU time, solver time, memory headroom, correctness, and change versus both the local control and `3x4-baseline_v1`.
>
> I will submit jobs sequentially, preserve every `.o`/`.e` file, and stop at invalidity, unsafe memory, repeated degradation, or a clear plateau.

At this point, nothing has been submitted. The Strategic Analyst is asking
for approval of a specific experiment.

Scored runs use `--skip-tests 0` and `--monitor-gpu 0`. Hardware health is
established in Phase 0 and checked with pre/post-run diagnostics; those are
part of an ordinary run. If continuous monitoring is ever enabled for
troubleshooting, the attempt is labeled a diagnostic condition, justified and
authorized separately, and never silently ranked against monitor-off scored
runs.

### 2. You approve the experiment

You reply:

> Approved. Run the NB screen exactly as proposed. You may prepare, synchronize, submit, and monitor the experiment.

Your approval authorizes the specification and its exact scope. The Strategic
Analyst writes the approved task directly as a synchronized
`tasks/TASK-XXX.md` only when its repository access is authorized; otherwise
you, or an approved mechanical fallback, materialize the exact approved
content under `workflow/07-Workflow.md`. Either way, the task's front matter
records `status: APPROVED` and `current_owner: codex` and its
`### 1.11 Authorization` records `status: APPROVED`, `approved_by: user`, and
the exact approved scope; the conversation approval alone is not executable.
Codex verifies that task file, then orchestrates the approved scope,
delegating the substantive work to OpenCode workers:

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

Codex does not submit all jobs concurrently because GAAS has known
multinode submission races.

### 3. Codex validates each result

For every candidate, Codex checks more than the exit code:

- PBS state and exit status;
- expected `.o` and `.e` files;
- normal HPL-MxP output;
- finite residual;
- `PASSED`;
- overall GFLOP/s;
- LU and solver timings;
- worst-rank memory/headroom;
- GPU health anomalies from Phase-0 or pre/post-run diagnostics;
- node allocation and mapping.

A successful result might be recorded like:

| NB | GFLOP/s | vs local control | vs original baseline | Result |
|---:|---:|---:|---:|---|
| 1024 | 40,092 | 0.00% | 0.00% | PASSED |
| 2048 | 43,800 | +9.25% | +9.25% | PASSED |
| 3072 | 44,100 | +9.99% | +9.99% | PASSED |
| 4096 | 43,700 | +9.00% | +9.00% | PASSED |

These numbers are illustrative, not predicted results.

Illustration caveat: the `NB=1024` row reuses the original-baseline score as
the local-control value for simplicity. A real sweep must measure its own
same-protocol in-sweep control; the original baseline is only the immutable
percentage denominator, its differing historical protocol must be disclosed,
and the two numbers are not blindly interchangeable.

If a candidate produces an OOM, failed residual, or non-finite result, it is
recorded as an invalid boundary. It is not ranked as a slow configuration.

If Codex encounters a hang, MPI failure, unexpected rank mapping, or
uncertain transport behavior, it stops and reports the issue instead of
automatically retrying.

### 4. Results are logged before interpretation

After the jobs finish, Codex updates:

- the experiment README;
- `results/metrics.csv`;
- `results/RESULTS.md`;
- the progress handoff.

At this point its operational handoff is factual evidence delivery, for
example:

> The NB screen is complete. All valid candidates are logged in
> `results/metrics.csv` with GFLOP/s, LU and solver timings, memory headroom,
> and `PASSED` verification; invalid attempts are recorded as boundary
> evidence. Every `.o`/`.e` file is preserved. No candidate has been ranked,
> interpreted, or promoted; that begins only after your `ANALYSE_RESULTS`
> authorization.

The general workflow intentionally separates result logging from analysis.
Codex's handoff stays factual; nothing rewrites `PLANS.md` or declares a
winner before you authorize `ANALYSE_RESULTS`.

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

This authorization comes after Codex completes its Execution Report and marks
the task `EXECUTED`; ownership then passes to the Strategic Analyst, who
analyzes only on your explicit `ANALYSE_RESULTS`.

The Strategic Analyst creates or updates:

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

With the authorized analysis complete, the Strategic Analyst pauses and asks
the exact checkpoint question:

> Should I proceed with the dependency review for this checkpoint, or explicitly skip it?

#### If you say “proceed”

The Strategic Analyst reads the relevant graph edges, likely including:

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

Then the Strategic Analyst recommends exactly one next action:

> Recommended next action: perform a bounded N bracket using the two retained NB candidates, while retaining `NB=1024` as the stable control.

It waits for your decision.

#### If you say “skip”

The Strategic Analyst records:

> Dependency review skipped for the current NB screen, scope: current session.

It still recommends exactly one next action and waits for your final
decision; any further experiment requires a new approved, synchronized task.
Skipping the review does not grant permission to start the next sweep
automatically.

### 7. The N portion of Phase 1

If you approve the recommended action, the Strategic Analyst drafts the
second bounded sweep as a new task; it becomes executable only after you
approve its exact scope and the task is synchronized under the same gates.

It does not test every `N × NB` combination. Instead, it might propose:

- retained `NB=2048`;
- retained `NB=3072`;
- stable control `NB=1024`;
- a small number of safe N values based on measured memory headroom.

The Strategic Analyst explicitly avoids blindly copying the single-node
`N=491520` result. It may say:

> The current memory evidence does not justify testing the upper boundary yet. I propose `N=420000`, `460000`, and `480000`, with a boundary probe only if the headroom remains sufficient.

Again, you approve the exact specification and scope before execution.

### 8. When Phase 1 closes

Phase 1 closes only when:

- a safe, correct N/NB region exists;
- neighboring candidates bound the useful region;
- leading candidates survive repetition or bracketing;
- memory behavior is understood;
- differences smaller than measured drift are treated as ties;
- the result is better than the original baseline or is a justified plateau;
- further geometry work has lower expected value than grid and placement work.

The Strategic Analyst may conclude:

> Phase 1 result: retain `N≈460000–480000` and `NB=2048–3072` as a tied geometry region. `NB=1024` remains the control. No unique NB winner is established above noise. The next recommended direction is Phase 2A process-grid/order screening.

It then updates the analysis records. Phase 2 does not start until you decide
and approve a new bounded task.

## In short

Your role (Human Leader) is to make the scientific and authorization
decisions:

1. approve or modify the proposed specification and exact scope;
2. authorize execution of the synchronized approved task;
3. authorize analysis with `ANALYSE_RESULTS`;
4. answer the dependency-review checkpoint;
5. decide on the single recommended next action and any new bounded task.

The Strategic Analyst's role is to:

1. translate the blueprint into a bounded experiment specification;
2. interpret results only after authorized `ANALYSE_RESULTS` analysis;
3. calculate comparisons and noise;
4. perform the dependency checkpoint and record the explicit skip or graph
   decisions;
5. recommend exactly one next action and wait for your decision.

Codex's role is to:

1. verify and orchestrate only the approved, synchronized
   `tasks/TASK-XXX.md`;
2. delegate substantive execution to OpenCode workers;
3. operationally validate correctness and preserve evidence;
4. complete the Codex Execution Report and the operational `progress/` handoff.

OpenCode workers perform the substantive execution—experiment records,
scripts, job submission, measurement extraction—only within the approved
scope.

That gives you a controlled collaboration loop rather than handing the agent
an entire optimization campaign to run unattended.
