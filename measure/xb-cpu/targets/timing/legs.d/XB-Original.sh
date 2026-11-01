#!/usr/bin/env bash
# xb-cpu / XB-Original (cpu): the original X-Blossom CPU implementation (src/xb-original, Fan et al., PVLDB 2025)
# against XB-GAP in the same session, on the paper's eight graphs. 11 runs each, the first a warm-up.
#   orig96 / orig48  the original at 96 and 48 std::threads (runtime_s = its own "computation time": the three
#                    search phases; total_s per round = the whole run)
#   gap96            XB-GAP as in the XB-GAP leg (every hardware thread)
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=cpu
LEG_DATASETS="${LEG_DATASETS:-paper}"
RUNS=(
  'orig96|1|XB_ORIG_ROUNDS=11 $GAP/xblossom_orig $ladj - 1 96'
  'orig48|1|XB_ORIG_ROUNDS=11 $GAP/xblossom_orig $ladj - 1 48'
  'gap96|1|OMP_NUM_THREADS=$threads OMP_PLACES=threads OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/xblossom -d $ds -n 11'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
