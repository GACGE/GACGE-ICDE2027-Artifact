#!/usr/bin/env bash
# sssp-gpu / Gunrock (gpu): Gunrock SSSP, delta-stepping with sssp-cpu's width per graph; first run is the warm-up
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper syn}"
RUNS=(
  'timing|1|GACGE_SSSP_DELTA=$(sssp_delta $ds) $GUNROCK/sssp -s $src -m $gmtx_w -n 11'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
