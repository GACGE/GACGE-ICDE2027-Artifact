#!/usr/bin/env bash
# xb-gpu / XB-Gunrock (gpu): XB-Gunrock (block_mapped, triplet path table, cycle-free), 1 warm-up + 10 timed matchings; warm-up and timed rounds in XBRound lines
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper syn}"
RUNS=(
  'timing|0|$GUNROCK/xblossom -m $gmtx -d $ds -l gacge -M nomat -T compact -o $(xb_nomat_list_ratio $ds) -w 1 -r 10'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
