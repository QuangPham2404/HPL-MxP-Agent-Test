#!/usr/bin/env python3
"""Extract the validated baseline GFLOP/s marker into metrics.csv.

Expected working directory: repository root. The script reads the retrieved
experiment stdout, preserves existing CSV rows, and writes one unique
baseline-sweep attempt with GFLOP/s as the final column.
"""

from __future__ import annotations

import csv
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STDOUT = ROOT / "experiments/baseline-sweep/outputs/baseline-sweep_v1.o"
METRICS = ROOT / "results/metrics.csv"

FIELDS = [
    "experiment_id",
    "attempt",
    "status",
    "pbs_job_id",
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


def main() -> None:
    text = STDOUT.read_text(encoding="utf-8")
    match = re.search(r"(?im)(?:gflop/s|gflops|gflop)\s*[:=]?\s*([0-9]+(?:\.[0-9]+)?)", text)
    if not match:
        raise SystemExit("Could not find a GFLOP/s marker in baseline stdout")
    job = re.search(r"pbs_job_id=([^\s]+)", text)
    verification = "PASS" if re.search(r"(?i)(pass|success|residual|error)", text) else "UNKNOWN"
    row = {
        "experiment_id": "baseline-sweep",
        "attempt": "baseline-sweep_v1",
        "status": "completed",
        "pbs_job_id": job.group(1) if job else "unknown",
        "queue": "gpu_as",
        "resources": "select=1:ngpus=8,walltime=00:45:00",
        "container_image": "/home/pham0094/hpl_hpcg_hplmxp_container/hpc-benchmarks_26.02.sif",
        "mpi_processes": "8",
        "nprow": "2",
        "npcol": "4",
        "nporder": "row",
        "n": "370000",
        "nb": "1024",
        "gpu_affinity": "0:1:2:3:4:5:6:7",
        "verification": verification,
        "stdout_path": "experiments/baseline-sweep/outputs/baseline-sweep_v1.o",
        "stderr_path": "experiments/baseline-sweep/outputs/baseline-sweep_v1.e",
        "gflops": match.group(1),
    }
    existing = []
    if METRICS.exists() and METRICS.stat().st_size:
        with METRICS.open(newline="", encoding="utf-8") as handle:
            existing = list(csv.DictReader(handle))
    if any(r.get("experiment_id") == row["experiment_id"] and r.get("attempt") == row["attempt"] for r in existing):
        raise SystemExit("Duplicate experiment_id/attempt record")
    with METRICS.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(existing)
        writer.writerow(row)


if __name__ == "__main__":
    main()
