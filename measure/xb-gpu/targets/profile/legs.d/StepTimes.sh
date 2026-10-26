#!/usr/bin/env bash
# xb-gpu / StepTimes (gpu): one XBStepTime line per phase of every step (GACGE_STEP_TIMES, include/gunrock/
# algorithms/xblossom.hxx: frontier vertices, edges, merge-path blocks of 128 threads, time on the GPU timeline),
# one warm-up and three timed matchings, as the timing leg's settings: the share of GPU time in small steps,
# as analysis/step-times does for BFS and SSSP.
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper syn}"
LEG_TIMEOUT="${LEG_TIMEOUT:-7200}"
RUNS=(
  'steps|0|GACGE_STEP_TIMES=1 $GUNROCK/xblossom -m $gmtx -d $ds -l gacge -M nomat -T compact -o $(xb_nomat_list_ratio $ds) -w 1 -r 3'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
