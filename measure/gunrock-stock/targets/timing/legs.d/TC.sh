#!/usr/bin/env bash
# gunrock-stock / TC (gpu): Gunrock's per-vertex triangle count (block_mapped advance), its one run (README.md)
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_TIMEOUT="${LEG_TIMEOUT:-10800}"
LEG_DATASETS="${LEG_DATASETS:-paper}"
RUNS=(
  'timing|0|build/gunrock-stock/bin/tc -m $gmtx -r'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
