cuda/13.1: compile with -arch=sm_XX (e.g. sm_90 on H200); default builds fail to launch on the 580 driver.

Loading nvhpc/26.3
  Loading requirement: gnu/gcc-12.3 cuda/13.1
WARNING: group: unknown groupid 1304617061
rsh_pbsdsh_container: HOST=hpc-gaas-g22 idx=1 cmd=[    OPAL_PREFIX=/opt/hpcx/ompi ; export OPAL_PREFIX;    PATH=/usr/local/mpi/bin:$PATH ; export PATH ; LD_LIBRARY_PATH=/usr/local/mpi/lib:${LD_LIBRARY_PATH:-} ; export LD_LIBRARY_PATH ; DYLD_LIBRARY_PATH=/usr/local/mpi/lib:${DYLD_LIBRARY_PATH:-} ; export DYLD_LIBRARY_PATH ;   /usr/local/mpi/bin/orted -mca ess "env" -mca ess_base_jobid "3556376576" -mca ess_base_vpid 1 -mca ess_base_num_procs "2" -mca orte_node_regex "hpc-gaas-g[2:1,22]@0(2)" -mca orte_hnp_uri "3556376576.0;tcp://10.20.0.27,172.16.2.129,192.168.230.7,172.17.0.1:57857" --mca plm_rsh_agent "/home/pham0094/hpl_hpcg_hplmxp_container/HPL-MxP-Manual-Test/HPL-MxP-Agent-Test/multi-node-test/rsh_pbsdsh_container.sh" --mca plm_rsh_no_tree_spawn "1" --mca plm_rsh_num_concurrent "1" --mca routed "direct" -mca plm "rsh" -mca coll_hcoll_enable "0" -mca pml "ucx" -mca hwloc_base_binding_policy "none" -mca pmix "^s1,s2,cray,isolated"]
WARNING: group: unknown groupid 1304617061
 CUDART (6->hpc-gaas-g01): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
--------------------------------------------------------------------------
MPI_ABORT was invoked on rank 6 in communicator MPI_COMM_WORLD
with errorcode 102.

NOTE: invoking MPI_ABORT causes Open MPI to kill all MPI processes.
You may or may not see output from other processes, depending on
exactly when Open MPI kills them.
--------------------------------------------------------------------------
 CUDART (2->hpc-gaas-g01): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (0->hpc-gaas-g01): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (4->hpc-gaas-g01): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (7->hpc-gaas-g01): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (3->hpc-gaas-g01): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (1->hpc-gaas-g01): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (5->hpc-gaas-g01): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (10->hpc-gaas-g22): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (15->hpc-gaas-g22): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (8->hpc-gaas-g22): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (12->hpc-gaas-g22): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (9->hpc-gaas-g22): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (11->hpc-gaas-g22): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (14->hpc-gaas-g22): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
 CUDART (13->hpc-gaas-g22): cudaMalloc(&_mat_sp_dev, mat_sp_bytes) = 2 (out of memory) at (src/matrix.cpp:298), process will now exit
[hpc-gaas-g01:22393] 15 more processes have sent help message help-mpi-api.txt / mpi-abort
[hpc-gaas-g01:22393] Set MCA parameter "orte_base_help_aggregate" to 0 to see all help / error messages
INFO:    Terminating squashfuse_ll after timeout
INFO:    Timeouts can be caused by a running background process
INFO:    Terminating squashfuse_ll after timeout
INFO:    Timeouts can be caused by a running background process
