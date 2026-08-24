# Analysis: N-NB resweep (N aligned to NB=3072)

## 1. Concise summary

We tested whether HPL-MxP performance improves when the matrix size is an
exact multiple of the block size (`N % nb == 0`). With `nb = 3072` (the
2026-08-24 NB-sweep peak) fixed and all other tuning unchanged from the prior
sweeps (`2x4` row grid, `--nporder row`, `--gpu-affinity 0:1:2:3:4:5:6:7`,
8 GPUs), we swept N over multiples of 3072 starting at 488448 (= 3072 × 159)
and stepping +3072.

Performance is essentially **flat** across the aligned values that fit in
memory, peaking at **N = 491520 (2.1974e+06 GFLOP/s, +52.26% over the original
1.4432e+06 baseline)**. Compared to the unaligned N = 490000 / nb = 3072 point
(2.1726e+06) it is only **+1.14%** higher, within run-to-run/node noise
(~±1–2%). Two of the aligned values (488448 = −0.23%, 497664 = −0.95%) actually
fall *below* the unaligned reference. We therefore find **no meaningful gain
from N % NB == 0**. The sweep also confirms the memory wall: OOM at N = 506880
and 509952.

## 2. Scope and evaluation criteria

- **Source/package**: NVIDIA HPC Benchmarks v26.02 container
  (`hpc-benchmarks_26.02.sif`), HPL-MxP 26.2.0.
- **Environment**: `apptainer/1.4.1`, `nvhpc/26.3`, `squashfuse/0.5.2`,
  `gocryptfs/2.5.0`; `mpirun -np 8 --bind-to none` (one GPU per rank).
- **Hardware**: 1 node, 8x NVIDIA H200 (GH100 SXM, ~140 GB VRAM each),
  ~2 TB system RAM per node, `gpu_as` queue, 8 GPUs.
- **Workload**: fixed baseline tuning except for N —
  `--nb 3072`, `--nprow 2 --npcol 4 --nporder row`,
  `--gpu-affinity 0:1:2:3:4:5:6:7`, `--skip-tests 1` plus GPU monitoring.
- **Swept variable**: `--n` ∈ {488448, 491520, 494592, 497664, 500736, 503808,
  506880, 509952} (multiples of 3072).
- **Stopping rule**: two consecutive GFLOP/s degradations, or an OOM failure.
  Hit at N = 506880 (OOM; followed by 509952, also OOM).
- **Baseline for comparison**: original `baseline-sweep_v1` (n = 370000,
  nb = 1024, 1.4432e+06 GFLOP/s). Secondary reference: unaligned
  N = 490000 / nb = 3072 (2.1726e+06) from the NB sweep.
- **Correctness**: all six passing runs reported `PASSED` with a finite residual
  within the 1e-12 tolerance. The two OOM runs produced no result marker.
- **Metric**: the reported HPL-MxP GFLOP/s performance marker.

## 3. Data and analysis

### 3.1 Aligned-N trace (nb = 3072)

| N | 3072× | Node | GFLOP/s | % vs baseline (1.4432e6) | % vs 490000/nb3072 |
|---:|---:|---:|---:|---:|---:|
| 488448 | 159 | g15 | 2.1675e+06 | +50.19% | −0.23% |
| 491520 | 160 | g16 | 2.1974e+06 | **+52.26%** | **+1.14%** |
| 494592 | 161 | g17 | 2.1867e+06 | +51.52% | +0.65% |
| 497664 | 162 | g18 | 2.1520e+06 | +49.11% | −0.95% |
| 500736 | 163 | g16 | 2.1936e+06 | +52.00% | +0.97% |
| 503808 | 164 | g15 | 2.1708e+06 | +50.42% | −0.08% |
| 506880 | 165 | — | OOM | — | — |
| 509952 | 166 | — | OOM | — | — |

The six aligned values that fit in memory span a narrow band of
2.15–2.20e+06 GFLOP/s, i.e. a ~2% spread with no monotonic trend. The peak
(491520, 2.1974e+06) beats the unaligned 490000 reference by only +1.14%.

### 3.2 Alignment hypothesis — no meaningful effect

The nearest aligned N values on either side of 490000 give opposite signs:
488448 is −0.23% below the unaligned reference and 491520 is +1.14% above it.
Both differences are inside the ~±1–2% run/node noise observed across every
sweep in this project. The `497664` dip (−0.95%) co-occurs with node `g18`,
which also produced the two lowest NB-sweep values (2.1150e+06 at nb=4096 and
1.9785e+06 at nb=8192). There is no evidence that `N % NB == 0` improves
performance beyond noise.

### 3.3 Memory wall (OOM)

| N | device memory (max used / total) | outcome |
|---:|---:|---|
| 503808 | (passing) | PASSED 2.1708e+06 |
| 506880 | 134.604 / 139.80 GB | OOM (cgroup/OOM, exit 137) |
| 509952 | — | OOM (cgroup/OOM, exit 137) |

Both OOM runs were killed during **matrix generation** after the device memory
filled (available MIN 3.911 GB) and the per-process cgroup budget was exceeded.
The wall here (between 503808 and 506880) is marginally lower than the
nb = 1024 N-sweep wall (OOM at 510000), consistent with slightly larger panel
buffers at nb = 3072.

## 4. Insights gained

1. **Alignment does not help.** `N % NB == 0` confers no meaningful gain; the
   aligned points scatter ±~1% around the unaligned 490000/nb=3072 reference,
   entirely within noise.
2. **Best result to date on the 2x4-row grid**: N = 491520, nb = 3072 reaches
   2.1974e+06 GFLOP/s (+52.26% over baseline), marginally the best single run in
   this configuration family.
3. **The practical optimum is a broad region.** Any N from ~488k to ~504k with
   nb = 3072 yields ~2.15–2.20e+06; exact alignment choice is immaterial.
4. **Memory wall confirmed and slightly nb-dependent.** OOM occurs at
   N ≈ 506880 with nb = 3072 (vs ≈ 510000 with nb = 1024), i.e. a larger block
   size marginally reduces the maximum feasible N.
5. **Node noise persists.** `g18` again returned the lowest value; node-level
   variance (±1–2%) exceeds the alignment effect, reinforcing the need for
   repetitions at the margin.

## 5. Suggested next section

1. **Forget alignment as a lever**; instead combine the confirmed winners:
   N ≈ 491520 + nb = 3072 on the `4x2` column grid, adding the best
   matrix-placement settings (`--fill-device-buffer-size`, register step) that
   previously reached ~2.2e+06 at N = 399360.
2. **Repeat the peak candidates** (491520, 500736) a few times to quantify
   node noise and confirm the ~2.19e+06 plateau before selecting a shipping
   configuration.
3. **If a single repeatable optimum is required**, keep N = 491520 / nb = 3072
   and guard boundary runs with `allocated_node` + free-memory logging.

These are recommendations for review, not authorization to execute.

## 6. Provenance

- Source CSV: `results/metrics.csv` (90 rows; 8 new `N-nb-resweep` attempts).
- Experiment: `experiments/N-nb-resweep/` (`README.md`, `run_n_nb_resweep.pbs`,
  `outputs/N-nb-resweep_*{.o,.e}`).
- Baseline reference: `baseline-sweep_v1` (metrics.csv), 1.4432e+06 GFLOP/s.
- Secondary reference: `nb-sweep_3072_490k`, 2.1726e+06 GFLOP/s.
- PBS jobs: 52263–52270.
- Analysis date: 2026-08-24.