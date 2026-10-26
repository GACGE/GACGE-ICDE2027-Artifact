#!/usr/bin/env bash
# xb-gpu / NCU-Depth (gpu): Table V's GPU rows. All 188 SMs at 1 and 11 blocks an SM (Table V's two ends) (GACGE_GPU_GRID_K), the
# profiled trial (GACGE_PROFILE_TRIAL): a = L1 hit / miss sectors of global loads, active cycles and warps, L2 hits;
# b = warps stalled on a long scoreboard, L2 misses (each group one ncu pass), summed over the trial's kernels.
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper}"
LEG_TIMEOUT="${LEG_TIMEOUT:-3600}"
RUNS=(
  'k1-a|0|$NCU --profile-from-start off --cache-control none --clock-control none --print-units base --metrics l1tex__t_sectors_pipe_lsu_mem_global_op_ld_lookup_hit.sum,l1tex__t_sectors_pipe_lsu_mem_global_op_ld_lookup_miss.sum,smsp__cycles_active.sum,smsp__warps_active.sum,lts__t_sectors_lookup_hit.sum --csv env GACGE_GPU_GRID_K=1 GACGE_PROFILE_TRIAL=1 $GUNROCK/xblossom -m $gmtx -d $ds -l gacge -M nomat -T compact -o $(xb_nomat_list_ratio $ds) -w 1 -r 1'
  'k1-b|0|$NCU --profile-from-start off --cache-control none --clock-control none --print-units base --metrics smsp__warps_issue_stalled_long_scoreboard.sum,lts__t_sectors_lookup_miss.sum --csv env GACGE_GPU_GRID_K=1 GACGE_PROFILE_TRIAL=1 $GUNROCK/xblossom -m $gmtx -d $ds -l gacge -M nomat -T compact -o $(xb_nomat_list_ratio $ds) -w 1 -r 1'
  'k11-a|0|$NCU --profile-from-start off --cache-control none --clock-control none --print-units base --metrics l1tex__t_sectors_pipe_lsu_mem_global_op_ld_lookup_hit.sum,l1tex__t_sectors_pipe_lsu_mem_global_op_ld_lookup_miss.sum,smsp__cycles_active.sum,smsp__warps_active.sum,lts__t_sectors_lookup_hit.sum --csv env GACGE_GPU_GRID_K=11 GACGE_PROFILE_TRIAL=1 $GUNROCK/xblossom -m $gmtx -d $ds -l gacge -M nomat -T compact -o $(xb_nomat_list_ratio $ds) -w 1 -r 1'
  'k11-b|0|$NCU --profile-from-start off --cache-control none --clock-control none --print-units base --metrics smsp__warps_issue_stalled_long_scoreboard.sum,lts__t_sectors_lookup_miss.sum --csv env GACGE_GPU_GRID_K=11 GACGE_PROFILE_TRIAL=1 $GUNROCK/xblossom -m $gmtx -d $ds -l gacge -M nomat -T compact -o $(xb_nomat_list_ratio $ds) -w 1 -r 1'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
