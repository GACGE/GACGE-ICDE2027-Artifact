#!/usr/bin/env bash
# gunrock-stock / SSSP-Gunrock (gpu): Gunrock's original SSSP (block_mapped advance, filter), 11 runs, the first dropped (README.md)
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper}"
RUNS=(
  'timing|1|GACGE_STOCK_ALGO=gunrock build/gunrock-stock/bin/sssp -s $src -m $gmtx_w -n 11'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
