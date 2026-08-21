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
    "gpu_affinity",
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

SETTING = re.compile(r"^\s+--(\S+)\s+=\s+(\S+)\s*$")
JOB_ID = re.compile(r"^pbs_job_id=(\S+)$")
TIMESTAMP = re.compile(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})$")
NODE = re.compile(r"^hpc-gaas-g\d+$")
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
        rm = RESIDUAL.match(line)
        if rm:
            verification = rm.group(2)
            residual = rm.group(1)
        gm = GFLOPS.search(line)
        if gm and gflops == "unknown":
            gflops = gm.group(1)
    return {**settings, "pbs_job_id": pbs_job_id, "submission_time": submission_time,
            "node": node, "verification": verification, "residual": residual,
            "gflops": gflops}


def build_rows() -> list[dict]:
    rows: list[dict] = []
    for stdout in sorted(OUTPUTS.glob("*/outputs/*.o")):
        experiment = stdout.parents[1].name
        attempt = stdout.stem
        stderr = stderr_for(stdout)
        data = parse_stdout(stdout.read_text(encoding="utf-8"))
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
            "queue": QUEUE,
            "resources": RESOURCES,
            "container_image": CONTAINER,
            "mpi_processes": MPI_PROCESSES,
            "nprow": data.get("nprow", "unknown"),
            "npcol": data.get("npcol", "unknown"),
            "nporder": data.get("order", "unknown"),
            "n": data.get("n", "unknown"),
            "nb": data.get("nb", "unknown"),
            "gpu_affinity": GPU_AFFINITY,
            "verification": data["verification"],
            "stdout_path": str(stdout.relative_to(ROOT)),
            "stderr_path": str(stderr.relative_to(ROOT)),
            "gflops": data["gflops"],
        }
        rows.append(row)
    return rows


ACCOUNTING_FIELDS = ("pbs_state", "exit_status", "completion_time", "runtime")


def merge_with_existing(row: dict, existing: dict) -> dict:
    """Keep manually recorded PBS-accounting metadata from an existing row.

    Values parsed from raw stdout replace parser-known fields; the four
    accounting fields are preserved when the existing row records them
    (they are not present in the .o files).
    """
    for field in ACCOUNTING_FIELDS:
        if existing.get(field) and existing.get(field) not in ("unknown", ""):
            row[field] = existing[field]
    return row


def main() -> None:
    existing: list[dict] = []
    if METRICS.exists() and METRICS.stat().st_size:
        with METRICS.open(newline="", encoding="utf-8") as handle:
            existing = list(csv.DictReader(handle))
    existing_by_key = {(r.get("experiment_id"), r.get("attempt")): r for r in existing}

    new_rows = build_rows()
    final_rows: list[dict] = []
    seen_keys: set[tuple[str, str]] = set()
    for row in new_rows:
        key = (row["experiment_id"], row["attempt"])
        if key in existing_by_key:
            row = merge_with_existing(row, existing_by_key[key])
        final_rows.append(row)
        seen_keys.add(key)

    # Preserve existing rows whose raw-evidence files are no longer present so
    # they would otherwise be dropped by the rebuild-from-.o pass. This keeps
    # historical records while appending newly extracted attempts.
    for row in existing:
        key = (row.get("experiment_id"), row.get("attempt"))
        if key not in seen_keys:
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
