# TASK-2X8-018 — Pre-Submission Provenance and Support Gate

- Gate date: 2026-10-03 (GAAS local time, UTC+08:00)
- Method: read-only SSH inspection of the recorded SIF, package labels,
  launcher binary strings, installed TUNING guide, and CUDA resolution.
- Remote host: `hpc-gaas-hn2`
- SIF path: `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`

## Gate results

| Check | Observed | Result |
|---|---|---|
| Exact SIF identity | 5,307,924,480 bytes; mtime `2026-05-06 06:07:56.408241441 +0800` | PASS |
| SHA-256 | `123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628` | PASS; matches TASK-2X8-016/017 |
| Package release | Image labels identify `nvcr.io/nvidia/hpc-benchmarks:26.02` | PASS |
| CUDA resolution | `/usr/local/cuda` → `/etc/alternatives/cuda` → `/usr/local/cuda-13.1`; `nvcc` reports CUDA 13.1, V13.1.115 | PASS |
| Launcher support | Installed binary contains `--u-panel-chunk-nbs`, `--prioritize-factorization`, `--prioritize-trsm`, and `--use-separate-stream-for-gemm`; installed TUNING lists all four with supported integer arguments | PASS |
| Effective-value echo | Prior validated runs record application settings echoes and successful settings-echo checks; this task's script verifies requested/effective NB, chunk, and fixed 101 flags on every arm | PASS |

## Read-only observations

The remote primary project clone was at `87fb61e829832a3bc07c2579d8472aa1be279f13`
and had pre-existing tracked modifications and untracked artifacts. It remains
untouched; execution must use a clean isolated worktree under Workflow 01.
Existing task worktrees were observed, and no TASK-2X8-018 worktree was present
in the recorded list.

The package inspection emitted the known non-fatal Apptainer warning
`group: unknown groupid 1304617061`; all required identity and support checks
completed successfully.

## Verdict

**PASS.** The exact SIF digest, package release, CUDA toolkit, required CLI
support, and effective-value echo path match the approved TASK-2X8-018 gates.
No PBS submission is recorded in this evidence file.
