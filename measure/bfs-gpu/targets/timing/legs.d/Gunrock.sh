#!/usr/bin/env bash
# bfs-gpu / Gunrock (gpu): Gunrock BFS, direction-optimized with GAP's rule; first run is the warm-up
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper syn}"
RUNS=(
  'timing|1|$GUNROCK/bfs -s $src -m $gmtx -n 11'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
