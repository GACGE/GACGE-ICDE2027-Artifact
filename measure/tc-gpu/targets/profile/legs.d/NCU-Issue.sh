#!/usr/bin/env bash
# tc-gpu / NCU-Issue (gpu): Table VI's GPU column on the synthetic graphs. Cycles with an instruction issued and
# active cycles of the profiled trial, summed over the schedulers and the trial's kernels.
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
# Table VI reads the two ends of each sweep only (size S18D16 -> S25D16, density S20D8 -> S20D256)
LEG_DATASETS="${LEG_DATASETS:-SynKronS18D16 SynKronS25D16 SynKronS20D8 SynKronS20D256}"
RUNS=(
  'profile|0|$NCU --profile-from-start off --cache-control none --clock-control none --print-units base --metrics smsp__issue_active.sum,smsp__cycles_active.sum --csv env GACGE_PROFILE_TRIAL=1 $GUNROCK/tc -m $gmtx -r -n 2'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
