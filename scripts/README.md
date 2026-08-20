# Scripts

General reusable scripts belong here when they do not naturally belong under
builds, experiments, or results. Read-only probe output belongs in `outputs/`.

## Hardware probe attempts

- `compute_node_hardware_probe_v1`: submitted as PBS job `50473.gaas` on
  2026-08-20; collected CPU and NUMA evidence but failed at the NUMA node
  memory loop because of an outer-shell quoting defect. Raw evidence remains
  in `outputs/compute_node_hardware_probe_v1.{o,e}`.
- `compute_node_hardware_probe_v1.1`: corrected retry using new PBS output
  names; intended to collect the complete read-only hardware inventory.
