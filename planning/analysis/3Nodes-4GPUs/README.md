# 3Nodes-4GPUs analysis area

Store topology-specific HPL-MxP analyses here. Each analysis must follow the
six-section analysis contract in `workflow/07-Workflow.md`, use
`results/metrics.csv` as numeric truth, retain experiment/attempt provenance,
and include the immutable 3-node × 4-GPU original baseline plus a percentage
increase versus that baseline in every comparison table.

The historical original baseline is documented in
`3x4-baseline.md` as `3x4-baseline_v1` (`N=480000`, `NB=1024`, `3×4` row,
12 ranks, `4.0092e+04` GFLOP/s, PASSED). The single-node baseline is context
only and is not the denominator for this topology.
