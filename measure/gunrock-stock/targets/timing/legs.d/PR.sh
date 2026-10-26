#!/usr/bin/env bash
# gunrock-stock / PR (gpu): Gunrock's push PageRank, exactly 20 iterations, 11 runs, the first dropped (README.md)
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper}"
RUNS=(
  'timing|1|GACGE_PR_ITERS=20 build/gunrock-stock/bin/pr -m $gmtx -n 11'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
