cuda/13.1: compile with -arch=sm_XX (e.g. sm_90 on H200); default builds fail to launch on the 580 driver.

Loading nvhpc/26.3
  Loading requirement: gnu/gcc-12.3 cuda/13.1
WARNING: group: unknown groupid 1304617061
--preset-gemm-kernel: 90 not in {0,80}
Run with --help for more information.
--preset-gemm-kernel: 90 not in {0,80}
Run with --help for more information.
--preset-gemm-kernel: 90 not in {0,80}
Run with --help for more information.
--preset-gemm-kernel: 90 not in {0,80}
Run with --help for more information.
--preset-gemm-kernel: 90 not in {0,80}
Run with --help for more information.
--preset-gemm-kernel: 90 not in {0,80}
Run with --help for more information.
--preset-gemm-kernel: 90 not in {0,80}
Run with --help for more information.
--preset-gemm-kernel: 90 not in {0,80}
Run with --help for more information.
--------------------------------------------------------------------------
Primary job  terminated normally, but 1 process returned
a non-zero exit code. Per user-direction, the job has been aborted.
--------------------------------------------------------------------------
--------------------------------------------------------------------------
mpirun detected that one or more processes exited with non-zero status, thus causing
the job to be terminated. The first process to do so was:

  Process name: [[11158,1],7]
  Exit code:    105
--------------------------------------------------------------------------
