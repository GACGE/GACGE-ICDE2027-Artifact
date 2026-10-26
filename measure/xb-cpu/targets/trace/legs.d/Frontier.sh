#!/usr/bin/env bash
# xb-cpu / Frontier (cpu): the frontier of every step of ONE run, no warm-up (Fig. 4/5): XBStep lines
# from GACGE_TRAVERSAL_TRACE=0 (src/gap/gapbs/src/gacge.h)
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=cpu
LEG_DATASETS="${LEG_DATASETS:-paper}"
RUNS=(
  'trace|0|GACGE_TRAVERSAL_TRACE=0 OMP_NUM_THREADS=$(cpu_hw_threads) OMP_PLACES=threads OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/xblossom -d $ds -n 1'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
