#!/usr/bin/env bash
# xb-gpu / NCU-Concurrency (gpu): how many warps are resident at once in the second trial, the first a warm-up: per kernel smsp__warps_active.sum / smsp__cycles_elapsed.avg (the GPU's mean resident warps while it runs) and its gpu__time_duration; the clocks left unlocked (--clock-control none) so the durations are the timed run's. Resident warps averaged over the run = sum(warps x duration) / the run's time.
# ncu profiles only the kernels between cudaProfilerStart / Stop, which Gunrock calls around trial
# GACGE_PROFILE_TRIAL's timed region (src/gunrock include/gunrock/gacge_profile.hxx); metrics summed over those kernels.
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper syn}"
LEG_TIMEOUT="${LEG_TIMEOUT:-14400}"
RUNS=(
  'profile|0|$NCU --profile-from-start off --cache-control none --clock-control none --metrics smsp__warps_active.sum,smsp__cycles_elapsed.avg,gpu__time_duration.sum --csv env GACGE_PROFILE_TRIAL=1 $GUNROCK/xblossom -m $gmtx -d $ds -l gacge -M nomat -T compact -o $(xb_nomat_list_ratio $ds) -w 1 -r 1'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
