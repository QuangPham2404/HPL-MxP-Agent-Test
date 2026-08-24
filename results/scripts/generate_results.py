#!/usr/bin/env python3
"""Generate results/RESULTS.md from results/metrics.csv.

Expected working directory: repository root. Reads the structured source of
truth and writes a raw-results report table. The report records validated
result data only; no optimization analysis or ranking is added here.
"""

from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
METRICS = ROOT / "results/metrics.csv"
REPORT = ROOT / "results/RESULTS.md"


def main() -> None:
    with METRICS.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    lines = [
        "# Results Report",
        "",
        "This report records validated raw result data only. No optimization "
        "analysis or ranking is included.",
        "",
        "| Experiment | Attempt | N | NB | Pgrid | Order | THREADS | PLACES | BIND | Correctness | GFLOP/s | Stdout |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        pgrid = f"{r['nprow']}x{r['npcol']}"
        omp_t = r.get("omp_num_threads", "")
        omp_p = r.get("omp_places", "")
        omp_b = r.get("omp_proc_bind", "")
        lines.append(
            f"| {r['experiment_id']} | {r['attempt']} | {r['n']} | {r['nb']} "
            f"| {pgrid} | {r['nporder']} | {omp_t} | {omp_p} | {omp_b} "
            f"| {r['verification']} | {r['gflops']} | {r['stdout_path']} |"
        )
    lines += ["", "Source: `results/metrics.csv`.", ""]

    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {REPORT} with {len(rows)} rows.")


if __name__ == "__main__":
    main()