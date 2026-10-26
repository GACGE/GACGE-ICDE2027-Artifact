#!/usr/bin/env bash
# pr-gpu / Gunrock (gpu): Gunrock PageRank (neighborreduce), 20 iterations; first run is the warm-up
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper syn}"
RUNS=(
  'timing|1|env GACGE_PR_ITERS=20 $GUNROCK/pr -m $gmtx -n 11'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
