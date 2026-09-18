# Staged host OSU-CUDA binaries (Phase 2, option (a))

Self-contained home for the staged copy of the host nvhpc HPC-X
`osu-micro-benchmarks-cuda` test suite, used by the Phase 2 in-container GDR
verification (Track 2.2) after the Stage 1 preflight
(`phase2_preflight_v3`, job `67795.gaas`) proved the HPL-MxP container ships
**no CUDA-capable OSU** (its `osu_mpi_tests` package is OMB v7.5,
host-buffer-only) while nccl-tests is complete.

- Source (read-only host install): `/usr/local/nvhpc/Linux_x86_64/26.3/
  comm_libs/13.1/hpcx/hpcx-2.25.1/ompi/tests/osu-micro-benchmarks-cuda`
  — the same CUDA-enabled OSU package validated on the host in Phase 1
  Step 1 (`D D` positional buffer args; `-d cuda` collectives).
- `osu-micro-benchmarks-cuda/` — the copied tree (flat layout, ~64 entries,
  ~26 MB; not tracked — ignored via the root `.gitignore`). Staging happens
  in-job (first Phase 2 smoke job) via a guarded `rsync`; provenance (file
  count, size, sha256 of `osu_bw`) is recorded in that job's evidence under
  `../outputs/phase2-preflight/`.
- Why stage under the project path: the project lives under `/home`, which
  apptainer binds into every container instance **by default** — including
  the bridge-spawned remote `orted` containers, which ignore custom `-B`
  flags (`rsh_pbsdsh_container.sh` hardcodes its `apptainer exec`). This
  makes the staged tree visible to all ranks with no bridge changes.
- ABI policy: the staged binaries' host RPATH (`$ORIGIN/../../lib`) does not
  exist at the stage location, so `libmpi.so.40` resolves to the container's
  `/opt/hpcx/ompi/lib` (same HPC-X 2.25.1 OMPI 4.1.9a1 family) — the tests
  exercise the container MPI/UCX stack. Run wrappers prepend
  `/opt/hpcx/ompi/lib:/opt/hpcx/ucx/lib` to `LD_LIBRARY_PATH`, scoped to the
  osu processes, to make the resolution deterministic. In-container `ldd`
  validation is recorded in every smoke job (`*_osu_abi.log`).
- Fallback if the default `/home` bind assumption ever fails for rank
  containers: export `APPTAINER_BINDPATH` in the job environment (apptainer
  applies it to every `apptainer exec`, including the bridge's remote ones)
  — no bridge edit required.

Experiments that use the staged binaries live in
`../debug-scripts/phase2-preflight/` with evidence in
`../outputs/phase2-preflight/`. Do not place OSU copies or build artifacts
in any outer directory.
