# Scripts

General reusable scripts belong here when they do not naturally belong under
builds, experiments, or results. Read-only probe output belongs in `outputs/`.

## Hardware probe attempts

- `compute_node_hardware_probe_v1`: submitted as PBS job `50473.gaas` on
  2026-08-20; collected CPU and NUMA evidence but failed at the NUMA node
  memory loop because of an outer-shell quoting defect. Raw evidence remains
  in `outputs/compute_node_hardware_probe_v1.{o,e}`.
- `compute_node_hardware_probe_v1.1`: corrected retry using new PBS output
  names; PBS job `50474.gaas` completed successfully on `hpc-gaas-g11`. The
  report is in [`probing_report.md`](probing_report.md), with raw stdout and
  stderr in `outputs/compute_node_hardware_probe_v1.1.{o,e}`.

## Communication-transport probe attempts

- `comm_transport_probe_v1`: read-only host + container probe of the CUDA/IB/UCX
  communication stack. PBS job `57431.gaas` on `hpc-gaas-g11`. Raw evidence in
  `outputs/comm_transport_probe_v1.{o,e}`.
- `comm_transport_probe_v2`: focused follow-up pinning down GPUDirect-RDMA /
  peer-memory / gdrcopy status. PBS job `57456.gaas` on `hpc-gaas-g15`. Raw
  evidence in `outputs/comm_transport_probe_v2.{o,e}`.
- Report (with admin-facing findings): [`comm_transport_probe_report.md`](comm_transport_probe_report.md).
