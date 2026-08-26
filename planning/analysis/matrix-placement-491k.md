# Analysis: Matrix-placement control at N=491520 (fill-device / buffer / register-step)

## 1. Concise summary

Re-ran the FP64 matrix-placement levers — `--fill-device`,
`--fill-device-buffer-size`, and `--cuda-host-register-step` — on the current
shipping workload (N = 491520, NB = 3072, 2x4 row, `OMP_NUM_THREADS=8` +
`OMP_PLACES=sockets` + `OMP_PROC_BIND=TRUE`), which the `omp-sweep` analysis had
pushed to 2.3204e+06 with `fill-device=0`. Three findings:

1. `--fill-device 1` is a **confirmed win** (fill-on 2.3745e+06 vs the
   fill-off reference), consistent with the earlier N=399360 result.
2. The buffer has a **broad flat optimum at 1024–2048** (~+0.7% over the
   3048 default) and a **hard cliff at ≤512**, where the run collapses to
   ~1.0–1.2e+06 and **fails verification** (residual stuck ~1.0e0). Above 2048
   performance drifts gently down.
3. `--cuda-host-register-step` is a **weak, sub-noise lever** (all values within
   ~±1.5% of the 2048 default), matching the prior N=399360 conclusion.

Best single result: `buffer=1024`, `register-step=1536` = 2.3974e+06 (+3.32%
over the pre-experiment shipping config, +66.12% over the original 1.4432e+06
baseline), but the register-step edge is not resolvable from node noise.

## 2. Scope and evaluation criteria

- Analysis ID: `matrix-placement-491k`
- Analysis date: 2026-08-26
- Source: [`results/metrics.csv`](../../results/metrics.csv)
- Workload (fixed): N = 491520, NB = 3072, `--nprow 2 --npcol 4 --nporder row`,
  `--gpu-affinity 0:1:2:3:4:5:6:7`, no CPU/memory affinity,
  `OMP_NUM_THREADS=8`, `OMP_PLACES=sockets`, `OMP_PROC_BIND=TRUE`,
  `--skip-tests 1` + GPU monitoring.
- Container: `hpc-benchmarks_26.02.sif`, `mpirun -np 8 --bind-to none`.
- References:
  - Original project baseline `baseline-sweep_v1` = **1.4432e+06** (n=370000,
    nb=1024, 2x4 row) — the performance baseline for every "% vs baseline" column.
  - Pre-experiment best (`omp-sweep` `omp_t8_sockets_true`) = **2.3204e+06**
    (same workload, `fill-device=0`) — the immediate control.
- Correctness gate: `verification=PASSED` and finite residual. `buf_512` and
  `buf_256` fail this gate and are excluded from performance ranking.
- Metric: reported HPL-MxP GFLOP/s (`GFLOPS = <x>, per GPU` marker).
- Post-hoc note: the fill-off control landed on node `hpc-gaas-g10`, which
  returned a clearly anomalous low value (2.1512e+06, −7.3% vs the g17-recorded
  2.3204e+06), so the first (go/no-go) table is node-confounded; the buffer and
  register tables additionally follow node-matched readings where available.

## 3. Data and analysis

### 3.1 Task 1 — `--fill-device 1` go/no-go

| Attempt | fill-device | GFLOP/s | vs baseline (1.4432e6) | vs prev best (2.3204e6) | Verification | Node |
|---|---|---:|---:|---:|---|---|
| `491k_fill_off` | 0 | 2.1512e+06 | +49.06% | −7.29% | PASSED | g10 |
| `491k_fill_on`  | 1 | 2.3745e+06 | +64.53% | +2.33% | PASSED | g16 |

`491k_fill_on` (buffer 3048) is +2.33% over the pre-experiment best and +10.4%
over the node-matched-relabeled `491k_fill_off`. The weak link is node
assignment: `fill_off` landed on g10 and returned 2.1512e+06, well under the
2.3204e+06 the same `fill-device=0` config returned on g17 in the omp-sweep.
Taken with the omp reference (g17, 2.3204e+06), the fill-device gain is ~+2.3%;
the raw +10.4% against the g10 fill-off overstates it. Direction is
unambiguous, so the experiment proceeds to Task 2.

### 3.2 Task 2 — `--fill-device-buffer-size` (default 3048; lower = more VRAM)

| Buffer (MB) | GFLOP/s | vs baseline (1.4432e6) | vs buffer-3048 (2.3745e6) | Verification | Node |
|---:|---:|---:|---:|---|---|
| 256  | 1.2268e+06 | −14.99% | −48.33% | FAILED | g18 |
| 512  | 1.0488e+06 | −27.33% | −55.83% | FAILED | g17 |
| 1024 | 2.3902e+06 | +65.62% | +0.66% | PASSED | g16 |
| 2048 | 2.3920e+06 | +65.74% | +0.74% | PASSED | g10 |
| 3048 | 2.3745e+06 | +64.53% | 0.00% | PASSED | g16 |
| 4096 | 2.3663e+06 | +63.96% | −0.35% | PASSED | g10 |
| 6144 | 2.3722e+06 | +64.37% | −0.10% | PASSED | g16 |
| 8192 | 2.3420e+06 | +62.28% | −1.37% | PASSED | g17 |

The valid region (1024–8192) is a broad plateau centered near 1024–2048, with a
gentle decline toward 8192 (matches the prior N=399360 monotonic-up-buffer
regression). The critical feature is the **cliff below 1024**: at 512 and 256 the
small reserve leaves the device-resident FP64 matrix overflowing VRAM, the
preconditioner degrades (GMRES residual stalls at ~1.0), and verification
**FAILED**. On the shared node g16, buffer 1024 (2.3902e+06) beats the 3048
default (2.3745e+06) by +0.66%. Chosen best buffer for Task 3: **1024**
(node-matched peak, safely above the cliff).

### 3.3 Task 3 — `--cuda-host-register-step` (default 2048, multiples of 512; buffer 1024)

| Register step | GFLOP/s | vs baseline (1.4432e6) | vs step-2048 (2.3902e6) | Verification | Node |
|---:|---:|---:|---:|---|---|
| 512  | 2.3656e+06 | +63.91% | −1.03% | PASSED | g17 |
| 1024 | 2.3912e+06 | +65.69% | +0.04% | PASSED | g16 |
| 1536 | 2.3974e+06 | +66.12% | +0.30% | PASSED | g10 |
| 2048 | 2.3902e+06 | +65.62% | 0.00% | PASSED | g16 |
| 2560 | 2.3886e+06 | +65.51% | −0.07% | PASSED | g18 |
| 3072 | 2.3722e+06 | +64.37% | −0.76% | PASSED | g17 |
| 3584 | 2.3691e+06 | +64.16% | −0.88% | PASSED | g16 |
| 4096 | 2.3742e+06 | +64.51% | −0.67% | PASSED | g10 |
| 4608 | 2.3549e+06 | +63.17% | −1.48% | PASSED | g18 |
| 5120 | 2.3536e+06 | +63.08% | −1.53% | PASSED | g17 |

Every value sits within ~±1.5% of the 2048 default, and the ordering is
dominated by node assignment (g10 ≈ g16 > g17 ≈ g18 in adjacent rows). The raw
peak (1536, 2.3974e+06) is on g10; on the shared node g16, step 1024 (2.3912)
and the 2048 default (2.3902) are indistinguishable. No stable optimum is
resolvable — confirm the weak-lever finding from N=399360.

## 4. Insights gained

- **`--fill-device 1` is a real, repeatable win** at N=491520 (directionally
  consistent with the +18% seen at N=399360), but the exact magnitude (~+2.3%
  over the fill-off shipping config) is bounded by node noise.
- **`--fill-device-buffer-size` is a safety/cliff lever, not a fine tuning knob.**
  The useful range is ~1024–2048 (≈ flat, +0.7% over 3048); below 1024 the run
  **fails validation** (residual ~1.0e0), and above 2048 it drifts gently down.
- **`--cuda-host-register-step` is not worth tuning** at this workload: sub-noise
  for all tested multiples of 512 (512–5120).
- **Node noise is the dominant error bar** (±3–7% across g10/g16/g17/g18; e.g.
  fill-off 2.15 on g10 vs 2.32 on g17 for the identical config). Any decision
  below ~2% is not reproducible from single runs.
- Best valid result: `fill-device 1`, `buffer 1024`, `register-step 1536` =
  **2.3974e+06** (+66.1% over the original baseline); within noise of
  buffer 1024/2048 at any register step.

## 5. Suggested next section

Adopt `--fill-device 1 --fill-device-buffer-size 1024` (2048 equally valid)
with `--cuda-host-register-step` left at the 2048 default, layered on the
shipping workload (N=491520, NB=3072, 2x4 row, OMP 8/sockets/TRUE). This is a
~+3% lift over the pre-experiment config. Because the top buffer (1024 vs 2048)
and register-step (1024/1536/2048) candidates differ by <1%, pin them with a
small node-matched repetition (3 candidates × 2 nodes) before finalizing.
Remaining orthogonal levers for separate experiments: `--preset-gemm-kernel`
/ `--sloppy-type` (precision/compute) and `--Anq-device` (partial residency,
only if a full-fill OOM path is ever needed). The scheduling and
panel-broadcast flags remain untested at this N.

This suggestion does not authorize a new experiment.

## 6. Provenance

- Structured source: [`results/metrics.csv`](../../results/metrics.csv)
- Validated report: [`results/RESULTS.md`](../../results/RESULTS.md)
- Experiment metadata: [`experiments/matrix-placement-control/README.md`](../../experiments/matrix-placement-control/README.md)
- Run script: [`experiments/matrix-placement-control/run_matrix_placement.pbs`](../../experiments/matrix-placement-control/run_matrix_placement.pbs)
- Raw evidence: `experiments/matrix-placement-control/outputs/491k_*.{o,e}`
  (18 new attempts).
- PBS jobs: 53159–53160 (Task 1), 53163–53169 (Task 2 buffer),
  53171–53179 (Task 3 register).
- Analysis date: 2026-08-26.