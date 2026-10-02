# TASK-2X8-017 — Pre-Submission Read-Only Provenance Identity Gate Evidence

- Task: `TASK-2X8-017` (Phase 5 — Final Scheduling 2^3 Factorial)
- Gate: Section 1.4A provenance identity check against the TASK-2X8-016 record,
  required before PBS submission
- Executed by: OpenCode execution worker (bounded objective delegated by the
  parent orchestrator under the unchanged approved Section 1.11 of
  TASK-2X8-017, `EXECUTING / codex`)
- Evidence window: 2026-10-02T16:26:12+08:00 through 2026-10-02T16:27:30+08:00
- Local repository HEAD at check: `4c81deb` (local `tasks/TASK-2X8-017.md`
  modified by the parent to `status: EXECUTING`)
- Remote: GAAS login node `hpc-gaas-hn2`, direct BatchMode SSH, read-only
  commands only
- Method (per Section 1.4A: no long investigation repeat): direct filesystem
  `stat` + `sha256sum` of the exact recorded SIF; read-only Apptainer
  inspection (`apptainer inspect` labels; `apptainer exec` running only
  `readlink`/`nvcc --version`/`strings`/`grep` inside the container, no GPU
  bind, no benchmark execution). No PBS submission, no HPL-MxP run, no tuning,
  no container modification. The installed-launcher support check for the
  three scheduling flags (Section 1.6B precondition) is included as item 5.

## Gate determination (summary)

| # | Required item | Result | Status |
|---|---------------|--------|--------|
| 1 | Exact recorded SIF path | `/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif` (exists; 5,307,924,480 bytes; mtime 2026-05-06 06:07:56.408241441 +0800 — identical size/mtime to the TASK-2X8-016 gate record) | PASS |
| 2 | SHA-256 digest of that exact image | `123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628` (freshly computed 2026-10-02T16:26:21–16:26:46+08:00; equals the TASK-2X8-016 gate digest and the independent TASK-2X8-015 phase4c compute-node record) | PASS |
| 3 | NVIDIA HPC Benchmarks release v26.02 | SIF label `org.label-schema.usage.singularity.deffile.from: nvcr.io/nvidia/hpc-benchmarks:26.02`; build-date label `Wednesday_6_May_2026_6:7:9_+08` matches the unchanged SIF mtime | PASS |
| 4 | `/usr/local/cuda` resolving to `/usr/local/cuda-13.1` | `/usr/local/cuda` → `/etc/alternatives/cuda` → `/usr/local/cuda-13.1`; `nvcc` reports `release 13.1, V13.1.115` (CUDA 13.1; identical resolution chain to the TASK-2X8-016 gate record) | PASS |
| 5 | Installed launcher supports the three explicit binary flags | binary strings contain `--prioritize-factorization`, `--prioritize-trsm`, `--use-separate-stream-for-gemm`; installed TUNING help lines: `--prioritize-trsm INT:NUMBER [0]`, `--prioritize-factorization INT:NUMBER [0]`, `--use-separate-stream-for-gemm INT:NUMBER [1]` (all three SUPPORTED as binary INT:NUMBER options, matching the recorded flag-check evidence `experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log` items 10-12) | PASS |

**Gate verdict: PASS** — all Section 1.4A identity values match the
TASK-2X8-016 record; the installed launcher supports all three authorized
binary scheduling flags. PBS submission of the nine-arm factorial is not
blocked by provenance.

## Commands run (all read-only) and verbatim evidence

### C1. Session start, remote repository state, SIF existence (2026-10-02T16:26:12+08:00)

Command (local → `ssh -o BatchMode=yes gaas`):

~~~text
date -Ins
hostname
git -C /home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test rev-parse HEAD
git -C .../HPL-MxP-Agent-Test status --short (first lines)
ls -la /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif
stat -c "size=%s bytes mtime=%y" .../hpc-benchmarks_26.02.sif
~~~

Verbatim output:

~~~text
2026-10-02T16:26:12,365416930+08:00
hpc-gaas-hn2
87fb61e829832a3bc07c2579d8472aa1be279f13
 M scripts/gaas-internode-coms-debug/debug-scripts/phase2-preflight/stage_osu_tmp.sh
 M scripts/gaas-internode-coms-debug/debug-scripts/phase2-stage2/fabric_capture.sh
?? .codex-worktrees/
?? experiments/2Nodes-8GPUs/hostfile
... (pre-existing untracked artifacts, unchanged from the TASK-2X8-015/016 records)
-rwxr-xr-x. 1 pham0094 1304617061 5307924480 May  6 06:07 /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif
size=5307924480 bytes mtime=2026-05-06 06:07:56.408241441 +0800
~~~

Informational for the parent orchestrator: the remote primary clone is at
`87fb61e829832a3bc07c2579d8472aa1be279f13` and is dirty (identical state to
the TASK-2X8-016 gate observation); Workflow 01 Mode B (isolated worktree)
applies for the remote execution tree. This gate performed no remote
repository writes.

### C2. SHA-256 digest of the exact SIF (2026-10-02T16:26:21–16:26:46+08:00)

Command: `sha256sum /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif`

Verbatim output:

~~~text
=== sha256 begin: 2026-10-02T16:26:21,224413898+08:00 ===
123f2a3c2dc9450d2e8bdd748134be7dc5359637fbfe69ff83677b42f4df0628  /home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif
=== sha256 end: 2026-10-02T16:26:46,606090599+08:00 ===
~~~

Matches the TASK-2X8-016 gate digest exactly (Section 1.4A expected value).

### C3. Release label (read-only `apptainer inspect`; modules loaded transiently per SSH session)

Command: `apptainer inspect <SIF> | grep -E "deffile.from|build-date"`

Verbatim output:

~~~text
org.label-schema.build-date: Wednesday_6_May_2026_6:7:9_+08
org.label-schema.usage.singularity.deffile.from: nvcr.io/nvidia/hpc-benchmarks:26.02
~~~

(`apptainer version 1.4.1` via `module load apptainer/1.4.1 squashfuse/0.5.2
gocryptfs/2.5.0`, transient per session, no persistent change; the known
`WARNING: group: unknown groupid 1304617061` Apptainer messages on the login
node are cosmetic and did not affect any read-only result.)

### C4. CUDA subdirectory resolution (read-only `readlink` / `nvcc --version`)

Commands: `apptainer exec <SIF> readlink /usr/local/cuda`;
`apptainer exec <SIF> readlink -f /usr/local/cuda`;
`apptainer exec <SIF> /usr/local/cuda/bin/nvcc --version | tail -2`

Verbatim output:

~~~text
/etc/alternatives/cuda
/usr/local/cuda-13.1
Cuda compilation tools, release 13.1, V13.1.115
Build cuda_13.1.r13.1/compiler.37061995_0
~~~

Identical to the TASK-2X8-016 gate record (`/usr/local/cuda` →
`/etc/alternatives/cuda` → `/usr/local/cuda-13.1`, CUDA 13.1).

### C5. Installed-launcher support for the three scheduling flags (read-only `strings` / TUNING `grep`)

Commands: `apptainer exec <SIF> strings /workspace/hpl-mxp-linux-x86_64/xhpl_mxp | grep -E "^--(prioritize-factorization|prioritize-trsm|use-separate-stream-for-gemm)$"`;
`apptainer exec <SIF> grep -E "prioritize-factorization|prioritize-trsm|use-separate-stream-for-gemm" /workspace/hpl-mxp-linux-x86_64/TUNING`;
launcher pass-through confirmation:
`apptainer exec <SIF> grep -nE "HPL_MXP_PARAMS|while|esac" /workspace/hpl-mxp-linux-x86_64/hpl-mxp.sh | head -8`

Verbatim output:

~~~text
--prioritize-factorization
--prioritize-trsm
--use-separate-stream-for-gemm

  --prioritize-trsm INT:NUMBER [0]
  --prioritize-factorization INT:NUMBER [0]
  --use-separate-stream-for-gemm INT:NUMBER [1]

129:HPL_MXP_PARAMS=""
131:while [ "$1" != "" ]; do
183:      HPL_MXP_PARAMS+="$1 $2 "
186:  esac
261:${NUMCMD} ${CPUBIND} ${MEMBIND} ${XHPL} ${HPL_MXP_PARAMS}
~~~

All three flags are supported by the installed v26.02 binary as binary
INT:NUMBER options (defaults 0/0/1), the wrapper passes them through to
`xhpl_mxp`, and the values match the recorded flag-check evidence
(`experiments/2x8-GAAS/baseline/outputs/hplmxp_v2602_flag_check_v1.log`
items 10-12). Prior CLI acceptance evidence for all three values also exists
in every retained 2x8-GAAS run (e.g. the phase4d echo records
`--prioritize-trsm 0 --prioritize-factorization 0 --use-separate-stream-for-gemm 1`).

## Notes

1. No PBS job was submitted or prepared, no HPL-MxP execution or tuning was
   performed, and no file outside the task-scoped experiment directory was
   modified. This evidence file was created fresh locally; no pre-existing
   files were touched (the directory
   `experiments/2x8-GAAS/phase5-scheduling-factorial/` did not previously
   exist in the repository).
2. The run script re-records the in-job container image identity (size,
   mtime, one-shot sha256) and hard-stops before any arm if the computed
   digest differs from the gate digest above (image-substitution guard;
   Section 1.7 rule 9).
3. Cross-reference (read, not modified): the TASK-2X8-016 gate record
   `experiments/2x8-GAAS/phase4d-chunk4-confirmation/outputs/2x8-GAAS-phase4d-chunk4-confirmation_provenance_v1.md`
   and the TASK-2X8-015 phase4c compute-node digest record
   `experiments/2x8-GAAS/phase4c-ucx-transport-u-panel-chunk/outputs/2x8-GAAS-phase4c-ucx-transport-u-panel-chunk_v1.o`
   (lines 90-92).

## Evidence file provenance

- This file: `experiments/2x8-GAAS/phase5-scheduling-factorial/outputs/2x8-GAAS-phase5-scheduling-factorial_provenance_v1.md`
- Written: 2026-10-02 (~16:30 +08:00 local), from the verbatim session
  transcripts of the read-only SSH commands listed above.
