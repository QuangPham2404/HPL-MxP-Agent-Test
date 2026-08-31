# Analysis: Effect of 100% MPI panel broadcast

## 1. Concise summary

This analysis examines the Nsight Systems run with
`--use-mpi-panel-broadcast 100`, which requests an all-MPI panel-broadcast
policy. It compares that run with the Nsight profile of the previous control
(`--use-mpi-panel-broadcast 50`) described in
[`optimization_plan_1.md`](optimization_plan_1.md), while keeping the fixed
best configuration unchanged.

The policy changes the communication mix in the expected direction: the
NCCL broadcast-kernel workload is substantially smaller and MPI point-to-point
traffic is larger. It does not remove NCCL broadcast activity entirely. The
communication reduction is exchanged for more MPI waits and synchronization,
while the dominant `nvjet` compute path is unchanged. The profiled 100% MPI
run reports a higher end-to-end score than the profiled 50% control, but that
difference is dominated by a much faster iterative-solver phase and is not a
reliable attribution to panel broadcast: the runs used different nodes and
only one profiled repetition each. The clean sweep evidence also classifies
the panel-broadcast policy as flat within run-to-run variation.

## 2. Scope and evaluation criteria

### Configuration and baseline

Both Nsight runs use HPL-MxP v26.02 with `N=491520`, `NB=3072`, an 8-rank
`2x4` row process grid, GPU affinity `0:1:2:3:4:5:6:7`,
`OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`,
`--preset-gemm-kernel 90`, `--u-panel-chunk-nbs 8`,
`--use-separate-stream-for-gemm 1`, FP16, fill-device enabled, a 2048 MB
fill buffer, and a 2048 host-register step. Both used `--skip-tests 1` and
GPU monitoring disabled (`--monitor-gpu 0`) so monitoring was not an added
variable.

The required original project baseline is `1.4432e+06` GFLOP/s. The clean
best configuration used by the optimization plan is `2.3920e+06` GFLOP/s
(approximately `+65.74%` versus that original baseline). The direct Nsight
control is the earlier `--use-mpi-panel-broadcast 50` profile at
`1.9668e+06` GFLOP/s; it is useful for mechanism comparison, but profiling is
known to reduce the clean score.

### Performance and correctness data

| Run | Panel policy | Node | GFLOP/s | % vs original baseline | % vs Nsight 50 control | % vs clean best | LU GFLOP/s | LU s | Solver s | Residual / verification |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| Original project baseline | package baseline | recorded in plan | `1.4432e+06` | `0.00%` | — | — | — | — | — | — |
| Clean best control | 50 reference | recorded in plan | `2.3920e+06` | `+65.74%` | — | `0.00%` | — | — | — | PASSED |
| Nsight 50 control | 50 | `hpc-gaas-g13` | `1.9668e+06` | `+36.28%` | `0.00%` | `-17.78%` | `3.8133e+06` | `20.76` | `19.49` | `4.836718e-14 / PASSED` |
| Nsight broadcast-100 | 100 | `hpc-gaas-g12` | `2.1585e+06` | `+49.56%` | `+9.75%` | `-9.76%` | `3.7914e+06` | `20.88` | `15.80` | `4.836718e-14 / PASSED` |
| Clean sweep `bc_100` | 100 | `hpc-gaas-g13` | `2.3251e+06` | `+61.11%` | — | `-2.80%` | — | — | — | PASSED |

The broadcast-100 log has the same three solver residuals as the control:
`3.35010242e-05`, `6.14018222e-11`, and `4.83671805e-14`, followed by a
finite residual and `PASSED`. It therefore meets the correctness criteria.
The clean `bc_100` row is included as context from the non-profiled
communication sweep; the two same-node 50% controls were `2.2771e+06` and
`2.3372e+06` GFLOP/s, so `bc_100` is within their observed variation rather
than a demonstrated clean improvement.

The Nsight mechanism comparison uses per-rank event durations. A duration
summed across ranks is cumulative rank time, not wall time. The main trace
window is defined consistently from the first `MPI_Wait` activity to the
last recorded MPI collective on each rank.

## 3. Data and analysis

### 3.1 HPL phase timing

| Metric | Nsight 50 control | Nsight broadcast-100 | Change |
|---|---:|---:|---:|
| Matrix generation, s | `158.81` | `217.18` | `+36.75%` |
| LU time, s | `20.76` | `20.88` | `+0.58%` |
| LU GFLOP/s | `3.8133e+06` | `3.7914e+06` | `-0.57%` |
| Iterative solver time, s | `19.49` | `15.80` | `-18.93%` |
| Reported end-to-end GFLOP/s | `1.9668e+06` | `2.1585e+06` | `+9.75%` |

The panel policy does not improve the LU phase in this direct profiled
comparison: LU is `0.12 s` slower and its reported rate is `0.57%` lower.
The end-to-end score increase comes mainly from the solver being `3.69 s`
shorter. Matrix generation is also much slower in the broadcast-100 run.
Both phases are outside the narrow attribution that this experiment was meant
to test, and the runs were on `g13` and `g12`, respectively. Consequently,
the score and setup timing differences should not be treated as a measured
benefit or cost of the panel policy.

### 3.2 Rank-level GPU and synchronization behavior

The following values are means across the eight rank traces; ranges are
included where they help show rank asymmetry.

| Trace metric | Nsight 50 control | Nsight broadcast-100 | Change |
|---|---:|---:|---:|
| Main trace window, s | `44.578` (`44.357–44.904`) | `40.831` (`40.619–41.146`) | `-8.41%` |
| GPU kernel time in window, s | `19.159` | `17.669` | `-7.78%` |
| Dominant `nvjet` kernel time, s | `14.849` | `14.818` | `-0.21%` |
| NCCL broadcast-kernel time, s | `3.394` (`1.870–4.941`) | `1.929` (`0.376–3.545`) | `-43.16%` |
| `MPI_Wait` time, s | `10.192` (`6.979–13.202`) | `12.494` (`8.347–16.391`) | `+22.59%` |
| CUDA stream-wait synchronization, s | `7.204` (`5.533–9.096`) | `8.588` (`6.656–10.611`) | `+19.21%` |
| `MPI_Allreduce` time, s | `8.376` | `11.853` | `+41.51%` |

The key result is that the setting changes where time is spent rather than
removing the critical-path problem. The dominant `nvjet_sm90` work is flat,
so the policy does not alter the main compute kernel. NCCL kernel time falls
strongly, but host-visible waits and stream synchronization increase. The
rank asymmetry also remains: the high-wait ranks are roughly `12.7–13.2 s`
at policy 50 and `15.6–16.4 s` at policy 100, while the lower-wait ranks are
roughly `7.0–7.9 s` and `8.3–9.7 s`, respectively.

The allreduce result is particularly important as a limitation. Its
rank-time average rises from `8.376 s` to `11.853 s`, but separate rank
databases cannot establish a wall-time causal chain or prove that every
allreduce is part of panel broadcast. It is evidence of increased or shifted
synchronization pressure, not proof that the panel flag alone caused every
collective delay.

### 3.3 Communication mix

The Nsight event counts show a concrete transport substitution:

| Communication evidence, per rank | Nsight 50 control | Nsight broadcast-100 | Effect |
|---|---:|---:|---:|
| NCCL `ncclBroadcast` ranges | `1526–1535` | `1195–1196` | about `-22%` |
| NCCL broadcast GPU kernels | `1526–1535` | `1195–1196` | about `-22%` calls |
| MPI `MPI_Wait` ranges | `42,780–43,430` | `56,760–58,060` | about `+34%` calls |
| `MPI_P2P_EVENTS` total, rank 0 | `540` / `2.265 GB` | `1080` / `4.530 GB` | `2.0x` calls and payload |

The NCCL broadcast ranges and kernels do not disappear at an effective
application setting of `100`; approximately 1,195–1,196 broadcasts remain
visible per rank. The setting therefore selects an MPI-heavy policy for the
panel path, but the complete trace still contains NCCL broadcast activity,
which may include residual panel work or other internal collective work. The
trace alone does not justify calling this a literal zero-NCCL execution.

The MPI point-to-point records show the expected cost of the MPI-heavy path:
rank 0 changes from 360 `MPI_Isend` and 180 `MPI_Irecv` records, totaling
`2.265 GB`, to 720 sends and 360 receives, totaling `4.530 GB`. The larger
traffic volume is not free; it is accompanied by the increased wait and
stream-wait totals above.

### 3.4 Relation to the optimization plan

`optimization_plan_1.md` identified long waits, substantial NCCL work, and
rank asymmetry as the reason to sweep `--use-mpi-panel-broadcast`. The
broadcast-100 profile validates the mechanism behind that hypothesis:

- MPI traffic increases and NCCL broadcast-kernel time decreases.
- The dominant GEMM-like `nvjet` compute path does not change.
- MPI and CUDA synchronization become more expensive in cumulative rank time.
- LU performance does not improve in the profiled pair.

This agrees with the subsequent clean 0/25/50/75/100 sweep: the clean
end-to-end results are within the same-node control spread, and the small
policy differences are not repeatable enough to retain 100% MPI as a winning
configuration.

## 4. Insights gained

- The `100` policy is an MPI-heavy communication trade-off, not a general
  compute optimization. It reduces NCCL GPU work but adds MPI traffic and
  synchronization pressure.
- The main compute kernel is insensitive to this policy. Any useful gain
  would have to come from critical-path scheduling or arrival behavior, not
  from faster arithmetic.
- The profiled end-to-end improvement (`+9.75%` versus the profiled 50%
  control) is not attributable to panel broadcast. LU is slightly worse, the
  solver is much faster, matrix generation is much slower, and the runs use
  different nodes.
- Correctness is preserved: all three solver iterations converge to the same
  finite final residual and the run reports `PASSED`.
- The remaining NCCL ranges mean that `--use-mpi-panel-broadcast 100` should
  not be interpreted as a trace with no NCCL activity.
- The clean sweep is the performance decision point. It shows no repeatable
  advantage for 100% MPI over the 50% default/control, so the default `50`
  remains the safer setting for this single-node NVSwitch workload.

## 5. Suggested next section

For this workload, retain `--use-mpi-panel-broadcast 50` and
`--u-panel-chunk-nbs 8` unless a future matched-node study specifically
targets communication behavior. The next orthogonal direction from
`optimization_plan_1.md` should be the dependency-priority controls:
`--prioritize-factorization` and `--prioritize-trsm`.

The hypothesis is that these controls can reduce the MPI-wait and stream-wait
tails by making panel readiness or U-side triangular-solve work available
earlier, without changing the MPI/NCCL transport mix. Test control, TRSM-only,
factorization-only, and both with the communication policy fixed at 50.
Require repeated clean runs, finite residuals, `PASSED` verification, and
end-to-end GFLOP/s improvement over the matched clean control. Record LU and
solver times, MPI-wait tails, and any GPU monitoring warnings. This is a
recommendation for review, not authorization to start those runs.

## 6. Provenance

- Analysis plan: [`optimization_plan_1.md`](optimization_plan_1.md).
- Nsight experiment metadata and attempt table:
  [`experiments/nsight-systems/README.md`](../experiments/nsight-systems/README.md).
- Nsight 50 control stdout:
  [`hpl_stdout.log`](../experiments/nsight-systems/outputs/nsys-trace/hpl_stdout.log).
- Broadcast-100 stdout:
  [`hpl_stdout.log`](../experiments/nsight-systems/outputs/nsys-trace-broadcast-100/hpl_stdout.log).
- Clean sweep data: [`results/metrics.csv`](../results/metrics.csv), rows
  `mpi-nccl-coms-sweep/bc_100`, `bc_baseline_a`, and `bc_baseline_b`.
- Nsight 50 raw rank reports on GAAS:
  `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test/experiments/nsight-systems/outputs/nsys-trace/hpl_mxp_rank_*.nsys-rep`.
- Broadcast-100 raw rank SQLite exports on GAAS:
  `/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test/experiments/nsight-systems/outputs/nsys-trace-broadcast-100/hpl_mxp_rank_*.sqlite`.
- Analysis date: `2026-08-31`.
