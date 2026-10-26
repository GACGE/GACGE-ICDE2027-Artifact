#!/usr/bin/env bash
# sssp-cpu / Threads (cpu): Fig. 8's CPU breadth and depth. The unit's GAP program at 6, 12, 24 and 48 threads, one a
# core (OMP_PLACES=cores), then 96, two a core (OMP_PLACES=threads); bd_trials runs (datasets.sh), the first a warm-up.
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=cpu
LEG_DATASETS="${LEG_DATASETS:-paper}"
RUNS=(
  't6|1|OMP_NUM_THREADS=6 OMP_PLACES=cores OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n $(bd_trials $ds)'
  't12|1|OMP_NUM_THREADS=12 OMP_PLACES=cores OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n $(bd_trials $ds)'
  't24|1|OMP_NUM_THREADS=24 OMP_PLACES=cores OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n $(bd_trials $ds)'
  't48|1|OMP_NUM_THREADS=48 OMP_PLACES=cores OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n $(bd_trials $ds)'
  't96|1|OMP_NUM_THREADS=96 OMP_PLACES=threads OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n $(bd_trials $ds)'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
