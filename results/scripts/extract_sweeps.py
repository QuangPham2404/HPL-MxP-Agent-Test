#!/usr/bin/env python3
"""Extract validated HPL-MxP sweep results into metrics.csv.

Expected working directory: repository root. Reads every experiment stdout
(.o) file under experiments/*/outputs/, parses the HPL-MxP settings block,
verification marker, and GFLOP/s result, and appends one unique row per
attempt while preserving existing rows. completion_time, runtime, and
exit_status are recorded as "unknown" when PBS accounting is not available;
pbs_state is inferred as F only when the run completed with final benchmark
output present.
"""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUTS = ROOT / "experiments"
METRICS = ROOT / "results/metrics.csv"

FIELDS = [
    "experiment_id",
    "attempt",
    "status",
    "pbs_job_id",
    "pbs_state",
    "exit_status",
    "submission_time",
    "completion_time",
    "allocated_node",
    "runtime",
    "queue",
    "resources",
    "container_image",
    "mpi_processes",
    "nprow",
    "npcol",
    "nporder",
    "n",
    "nb",
    "use_mpi_panel_broadcast",
    "u_panel_chunk_nbs",
    "prioritize_trsm",
    "prioritize_factorization",
    "use_separate_stream_for_gemm",
    "call_dgemv_with_multiple_threads",
    "gpu_affinity",
    "omp_num_threads",
    "omp_places",
    "omp_proc_bind",
    "verification",
    "stdout_path",
    "stderr_path",
    "gflops",
]

QUEUE = "gpu_as"
RESOURCES = "select=1:ngpus=8,walltime=00:45:00"
CONTAINER = "/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif"
GPU_AFFINITY = "0:1:2:3:4:5:6:7"
MPI_PROCESSES = "8"

# Directories renamed after their rows were recorded under the historical
# experiment_id: keep the recorded ID so rebuilds append to, not duplicate,
# the existing rows.
EXPERIMENT_ALIASES = {
    "2Nodes-8GPUs": "2x8-n-sweep",
}

SETTING = re.compile(r"^\s+--(\S+)\s+=\s+(\S+)\s*$")
JOB_ID = re.compile(r"^pbs_job_id=(\S+)$")
TIMESTAMP = re.compile(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})$")
NODE = re.compile(r"^hpc-gaas-g\d+$")
OMP_THREADS = re.compile(r"^omp_num_threads=(\S+)$")
OMP_PLACES = re.compile(r"^omp_places=(\S+)$")
OMP_BIND = re.compile(r"^omp_proc_bind=(\S+)$")
QUEUE_ECHO = re.compile(r"^queue=(\S+)$")
RESOURCES_ECHO = re.compile(r"^resources=(\S+)$")
RESIDUAL = re.compile(r"^\s+\|\|Ax-b\|\|_oo .*=\s+([0-9.Ee+-]+)\s+\.\.\.\.\.\.\s+(PASSED|FAILED)")
GFLOPS = re.compile(r"GFLOPS = ([0-9.eE+-]+), per GPU")


def stderr_for(stdout: Path) -> Path:
    """Resolve stderr evidence when a retained PBS stem was mistyped."""
    direct = stdout.with_suffix(".e")
    if direct.exists():
        return direct
    aliases = {
        "N-sweep_402_re": "N-sweep_402k_re",
        "n-resweep_399_": "n-resweep_399k_",
    }
    for source, target in aliases.items():
        if stdout.stem.startswith(source):
            candidate = stdout.with_name(stdout.stem.replace(source, target, 1) + ".e")
            if candidate.exists():
                return candidate
    return direct


def parse_stdout(text: str) -> dict:
    settings: dict[str, str] = {}
    pbs_job_id = "unknown"
    submission_time = "unknown"
    node = "unknown"
    verification = "UNKNOWN"
    residual = "unknown"
    gflops = "unknown"
    omp_num_threads = "unset"
    omp_places = "unset"
    omp_proc_bind = "unset"
    queue_echo = None
    resources_echo = None
    for line in text.splitlines():
        m = SETTING.match(line)
        if m:
            settings[m.group(1)] = m.group(2)
        if pbs_job_id == "unknown":
            jm = JOB_ID.match(line)
            if jm:
                pbs_job_id = jm.group(1)
        if submission_time == "unknown":
            tm = TIMESTAMP.match(line)
            if tm:
                submission_time = tm.group(1)
        if node == "unknown":
            nm = NODE.match(line.strip())
            if nm:
                node = nm.group(0)
        ot = OMP_THREADS.match(line)
        if ot:
            omp_num_threads = ot.group(1)
        op = OMP_PLACES.match(line)
        if op:
            omp_places = op.group(1)
        ob = OMP_BIND.match(line)
        if ob:
            omp_proc_bind = ob.group(1)
        qm = QUEUE_ECHO.match(line)
        if qm and queue_echo is None:
            queue_echo = qm.group(1)
        rm = RESOURCES_ECHO.match(line)
        if rm and resources_echo is None:
            resources_echo = rm.group(1)
        rm2 = RESIDUAL.match(line)
        if rm2:
            verification = rm2.group(2)
            residual = rm2.group(1)
        gm = GFLOPS.search(line)
        if gm and gflops == "unknown":
            gflops = gm.group(1)
    return {**settings, "pbs_job_id": pbs_job_id, "submission_time": submission_time,
            "node": node, "verification": verification, "residual": residual,
            "gflops": gflops, "omp_num_threads": omp_num_threads,
            "omp_places": omp_places, "omp_proc_bind": omp_proc_bind,
            "queue_echo": queue_echo, "resources_echo": resources_echo}


def build_rows() -> list[dict]:
    rows: list[dict] = []
    for stdout in sorted(OUTPUTS.glob("*/outputs/*.o")):
        experiment = EXPERIMENT_ALIASES.get(stdout.parents[1].name, stdout.parents[1].name)
        attempt = stdout.stem
        if attempt.startswith("hpl_mxp_"):
            continue
        stderr = stderr_for(stdout)
        data = parse_stdout(stdout.read_text(encoding="utf-8"))
        # Rank count is observed truth when the grid parses: P x Q ranks.
        mpi_processes = MPI_PROCESSES
        try:
            mpi_processes = str(int(data.get("nprow", "")) * int(data.get("npcol", "")))
        except ValueError:
            pass
        # Queue/resources are observed when the run script echoes them
        # (e.g. `queue=${PBS_O_QUEUE}`); otherwise fall back to the
        # single-node sweep defaults. The *_echo markers are stripped
        # before writing and used by merge_with_existing to decide whether
        # the value is observed or a default.
        row = {
            "experiment_id": experiment,
            "attempt": attempt,
            "status": "completed" if data["verification"] == "PASSED" else "failed",
            "pbs_job_id": data["pbs_job_id"],
            "pbs_state": "F" if data["verification"] == "PASSED" else "unknown",
            "exit_status": "unknown",
            "submission_time": data["submission_time"],
            "completion_time": "unknown",
            "allocated_node": data["node"],
            "runtime": "unknown",
            "queue": data["queue_echo"] or QUEUE,
            "resources": data["resources_echo"] or RESOURCES,
            "queue_echo": data["queue_echo"],
            "resources_echo": data["resources_echo"],
            "container_image": CONTAINER,
            "mpi_processes": mpi_processes,
            "nprow": data.get("nprow", "unknown"),
            "npcol": data.get("npcol", "unknown"),
            "nporder": data.get("order", "unknown"),
            "n": data.get("n", "unknown"),
            "nb": data.get("nb", "unknown"),
            "use_mpi_panel_broadcast": data.get("use-mpi-panel-broadcast", "unknown"),
            "u_panel_chunk_nbs": data.get("u-panel-chunk-nbs", "unknown"),
            "prioritize_trsm": data.get("prioritize-trsm", "unknown"),
            "prioritize_factorization": data.get("prioritize-factorization", "unknown"),
            "use_separate_stream_for_gemm": data.get("use-separate-stream-for-gemm", "unknown"),
            "call_dgemv_with_multiple_threads": data.get("call-dgemv-with-multiple-threads", "unknown"),
            "gpu_affinity": GPU_AFFINITY,
            "omp_num_threads": data.get("omp_num_threads", "unset"),
            "omp_places": data.get("omp_places", "unset"),
            "omp_proc_bind": data.get("omp_proc_bind", "unset"),
            "verification": data["verification"],
            "stdout_path": str(stdout.relative_to(ROOT)),
            "stderr_path": str(stderr.relative_to(ROOT)),
            "gflops": data["gflops"],
        }
        rows.append(row)
    return rows


# Metadata fields preserved from an existing row when the existing value is
# informative. The .o corpus for multinode or renamed-directory experiments
# does not always expose these (multi-node host lists, per-node gpu-affinity
# strings, manually verified submission timestamps), so a rebuild must not
# clobber reviewed values. Queue/resources still defer to an explicit .o
# echo, which is observed truth.
PRESERVED_FIELDS = ("pbs_state", "exit_status", "completion_time", "runtime",
                    "submission_time", "allocated_node", "gpu_affinity",
                    "queue", "resources")


def merge_with_existing(row: dict, existing: dict) -> dict:
    """Keep reviewed metadata from an existing row; observed values win.

    Values parsed from raw stdout fill or replace parser-known fields unless
    the existing row already records an informative value for a preserved
    metadata field. Queue/resources parsed from an explicit .o echo
    (`queue=` / `resources=` echoes) always win over the existing row. A
    reviewed verification verdict (PASSED/FAILED) also survives when the
    rebuild can only parse UNKNOWN (e.g. the run died before the residual
    marker, but the failure was confirmed from evidence).
    """
    for field in PRESERVED_FIELDS:
        if field in ("queue", "resources") and row.get(f"{field}_echo"):
            continue
        if existing.get(field) and existing.get(field) not in ("unknown", ""):
            row[field] = existing[field]
    if row.get("verification") == "UNKNOWN" and existing.get("verification") in ("PASSED", "FAILED"):
        row["verification"] = existing["verification"]
        row["status"] = "completed" if existing["verification"] == "PASSED" else "failed"
    return row


def main() -> None:
    existing: list[dict] = []
    if METRICS.exists() and METRICS.stat().st_size:
        with METRICS.open(newline="", encoding="utf-8") as handle:
            existing = list(csv.DictReader(handle))
    existing_by_key = {(r.get("experiment_id"), r.get("attempt")): r for r in existing}

    new_rows = build_rows()
    new_by_key: dict[tuple[str, str], dict] = {}
    for row in new_rows:
        key = (row["experiment_id"], row["attempt"])
        if key not in new_by_key:
            new_by_key[key] = row

    # Keep existing rows in their recorded order, updated with freshly
    # parsed values, so a rebuild never reorders or drops the ledger.
    final_rows: list[dict] = []
    for row in existing:
        key = (row.get("experiment_id"), row.get("attempt"))
        if key in new_by_key:
            merged = merge_with_existing(new_by_key[key], row)
            merged.pop("queue_echo", None)
            merged.pop("resources_echo", None)
            final_rows.append(merged)
        else:
            # Preserve existing rows whose raw-evidence files are no longer
            # present so they would otherwise be dropped by the
            # rebuild-from-.o pass. This keeps historical records.
            final_rows.append(row)

    # Append genuinely new attempts (no existing row) in glob order.
    for key, row in new_by_key.items():
        if key not in existing_by_key:
            row.pop("queue_echo", None)
            row.pop("resources_echo", None)
            final_rows.append(row)

    with METRICS.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(final_rows)

    print(f"Reconciled {len(final_rows)} rows in metrics.csv.")
    for row in final_rows:
        print(f"  {row['experiment_id']}/{row['attempt']}: n={row['n']} nb={row['nb']} "
              f"{row['nprow']}x{row['npcol']} {row['nporder']} -> {row['gflops']} "
              f"[{row['verification']}]")


if __name__ == "__main__":
    main()
