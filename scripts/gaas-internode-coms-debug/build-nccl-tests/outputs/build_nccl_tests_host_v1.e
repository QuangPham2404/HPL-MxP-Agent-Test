cuda/13.1: compile with -arch=sm_XX (e.g. sm_90 on H200); default builds fail to launch on the 580 driver.

Loading nvhpc/26.3
  Loading requirement: gnu/gcc-12.3 cuda/13.1
Makefile:177: Skipping GIN device API performance tests: NCCL version code 22903 is older than 23007
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
"../verifiable/verifiable.cu", line 1071: warning: statement is unreachable [code_is_unreachable]
  case ncclSum:  if (rank_n == 1) { return prepareInput1(elts, elt_n, elt_ty, ReduceNil(), rank_n, rank_me, seed, elt_ix0, stream); } else { return prepareInput1(elts, elt_n, elt_ty, ReduceSum(), rank_n, rank_me, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                                ^

Remark: individual warnings can be suppressed with "--diag_suppress <warning-name>"

"../verifiable/verifiable.cu", line 1072: warning: statement is unreachable [code_is_unreachable]
  case ncclMin:  if (rank_n == 1) { return prepareInput1(elts, elt_n, elt_ty, ReduceNil(), rank_n, rank_me, seed, elt_ix0, stream); } else { return prepareInput1(elts, elt_n, elt_ty, ReduceMin(), rank_n, rank_me, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                                ^

"../verifiable/verifiable.cu", line 1073: warning: statement is unreachable [code_is_unreachable]
  case ncclMax:  if (rank_n == 1) { return prepareInput1(elts, elt_n, elt_ty, ReduceNil(), rank_n, rank_me, seed, elt_ix0, stream); } else { return prepareInput1(elts, elt_n, elt_ty, ReduceMax(), rank_n, rank_me, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                                ^

"../verifiable/verifiable.cu", line 1074: warning: statement is unreachable [code_is_unreachable]
  case ncclProd:  if (rank_n == 1) { return prepareInput1(elts, elt_n, elt_ty, ReduceNil(), rank_n, rank_me, seed, elt_ix0, stream); } else { return prepareInput1(elts, elt_n, elt_ty, ReduceProd(), rank_n, rank_me, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                                  ^

"../verifiable/verifiable.cu", line 1076: warning: statement is unreachable [code_is_unreachable]
  case ncclAvg:  if (rank_n == 1) { return prepareInput1(elts, elt_n, elt_ty, ReduceNil(), rank_n, rank_me, seed, elt_ix0, stream); } else { return prepareInput1(elts, elt_n, elt_ty, ReduceAvg{rank_n}, rank_n, rank_me, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                                      ^

"../verifiable/verifiable.cu", line 1079: warning: statement is unreachable [code_is_unreachable]
  default:  if (rank_n == 1) { return prepareInput1(elts, elt_n, elt_ty, ReduceNil(), rank_n, rank_me, seed, elt_ix0, stream); } else { return prepareInput1(elts, elt_n, elt_ty, ReducePreMulSum(), rank_n, rank_me, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                                 ^

"../verifiable/verifiable.cu", line 1154: warning: statement is unreachable [code_is_unreachable]
  case ncclSum:  if (rank_n == 1) { return prepareExpected1(elts, elt_n, elt_ty, ReduceNil(), rank_n, seed, elt_ix0, stream); } else { return prepareExpected1(elts, elt_n, elt_ty, ReduceSum(), rank_n, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                    ^

"../verifiable/verifiable.cu", line 1155: warning: statement is unreachable [code_is_unreachable]
  case ncclMin:  if (rank_n == 1) { return prepareExpected1(elts, elt_n, elt_ty, ReduceNil(), rank_n, seed, elt_ix0, stream); } else { return prepareExpected1(elts, elt_n, elt_ty, ReduceMin(), rank_n, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                    ^

"../verifiable/verifiable.cu", line 1156: warning: statement is unreachable [code_is_unreachable]
  case ncclMax:  if (rank_n == 1) { return prepareExpected1(elts, elt_n, elt_ty, ReduceNil(), rank_n, seed, elt_ix0, stream); } else { return prepareExpected1(elts, elt_n, elt_ty, ReduceMax(), rank_n, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                    ^

"../verifiable/verifiable.cu", line 1157: warning: statement is unreachable [code_is_unreachable]
  case ncclProd:  if (rank_n == 1) { return prepareExpected1(elts, elt_n, elt_ty, ReduceNil(), rank_n, seed, elt_ix0, stream); } else { return prepareExpected1(elts, elt_n, elt_ty, ReduceProd(), rank_n, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                      ^

"../verifiable/verifiable.cu", line 1159: warning: statement is unreachable [code_is_unreachable]
  case ncclAvg:  if (rank_n == 1) { return prepareExpected1(elts, elt_n, elt_ty, ReduceNil(), rank_n, seed, elt_ix0, stream); } else { return prepareExpected1(elts, elt_n, elt_ty, ReduceAvg{rank_n}, rank_n, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                          ^

"../verifiable/verifiable.cu", line 1162: warning: statement is unreachable [code_is_unreachable]
  default:  if (rank_n == 1) { return prepareExpected1(elts, elt_n, elt_ty, ReduceNil(), rank_n, seed, elt_ix0, stream); } else { return prepareExpected1(elts, elt_n, elt_ty, ReducePreMulSum(), rank_n, seed, elt_ix0, stream); }  break; 
                                                                                                                                                                                                                                     ^

"../verifiable/verifiable.cu", line 1343: warning: statement is unreachable [code_is_unreachable]
  case ncclInt8:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(int8_t), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< signed char, unsigned char> ((const int8_t *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                                  ^

"../verifiable/verifiable.cu", line 1344: warning: statement is unreachable [code_is_unreachable]
  case ncclUint8:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(uint8_t), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< unsigned char, unsigned char> ((const uint8_t *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                                       ^

"../verifiable/verifiable.cu", line 1345: warning: statement is unreachable [code_is_unreachable]
  case ncclInt32:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(int32_t), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< signed int, unsigned> ((const int32_t *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                               ^

"../verifiable/verifiable.cu", line 1346: warning: statement is unreachable [code_is_unreachable]
  case ncclUint32:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(uint32_t), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< unsigned, unsigned> ((const uint32_t *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                                ^

"../verifiable/verifiable.cu", line 1347: warning: statement is unreachable [code_is_unreachable]
  case ncclInt64:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(int64_t), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< signed long, unsigned long> ((const int64_t *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                                     ^

"../verifiable/verifiable.cu", line 1348: warning: statement is unreachable [code_is_unreachable]
  case ncclUint64:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(uint64_t), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< unsigned long, unsigned long> ((const uint64_t *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                                          ^

"../verifiable/verifiable.cu", line 1349: warning: statement is unreachable [code_is_unreachable]
  case ncclFloat16:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(half), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< __half, unsigned short> ((const half *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                             ^

"../verifiable/verifiable.cu", line 1351: warning: statement is unreachable [code_is_unreachable]
  case ncclFloat8e4m3:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(__nv_fp8_e4m3), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< __nv_fp8_e4m3, unsigned char> ((const __nv_fp8_e4m3 *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                                                        ^

"../verifiable/verifiable.cu", line 1352: warning: statement is unreachable [code_is_unreachable]
  case ncclFloat8e5m2:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(__nv_fp8_e5m2), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< __nv_fp8_e5m2, unsigned char> ((const __nv_fp8_e5m2 *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                                                        ^

"../verifiable/verifiable.cu", line 1355: warning: statement is unreachable [code_is_unreachable]
  case ncclBfloat16:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(__nv_bfloat16), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< __nv_bfloat16, unsigned short> ((const __nv_bfloat16 *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                                                       ^

"../verifiable/verifiable.cu", line 1357: warning: statement is unreachable [code_is_unreachable]
  case ncclFloat32:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(float), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< float, unsigned> ((const float *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                        ^

"../verifiable/verifiable.cu", line 1358: warning: statement is unreachable [code_is_unreachable]
  case ncclFloat64:  { if (expected != (nullptr)) { return verifyPrepared1(sizeof(double), results, expected, elt_n, tolerance, bad_elt_n, stream, block_n); } else { return verifyInline1< double, unsigned long> ((const double *)results, elt_n, red_op, rank_n, seed, elt_ix0, tolerance, bad_elt_n, stream, block_n); }  } break; 
                                                                                                                                                                                                                                                                                                                                ^

nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
nvlink warning : Skipping incompatible '/lib64/librt.a' when searching for -lrt
=>> PBS: job killed: walltime 1888 exceeded limit 1800
