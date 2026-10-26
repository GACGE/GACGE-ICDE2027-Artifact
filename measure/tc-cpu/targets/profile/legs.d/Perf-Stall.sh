#!/usr/bin/env bash
# tc-cpu / Perf-Stall (cpu): cycles stalled (cycle_activity.stalls_total), stalled on an L3 miss (stalls_l3_miss) and
# bound on loads (exe_activity.bound_on_loads) of the second trial, the first a warm-up; user mode only
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=cpu
# Table VI reads the two ends of each sweep only (size S18D16 -> S25D16, density S20D8 -> S20D256)
LEG_DATASETS="${LEG_DATASETS:-SynKronS18D16 SynKronS25D16 SynKronS20D8 SynKronS20D256}"
RUNS=(
  'profile|0|OMP_NUM_THREADS=$(cpu_hw_threads) OMP_PLACES=threads OMP_PROC_BIND=spread measure/common/perf_region.sh cycles:u,cycle_activity.stalls_total:u,cycle_activity.stalls_l3_miss:u,exe_activity.bound_on_loads:u 1 src/gap/gap_on_bin.sh $ladj $GAP/tc -n 2'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
