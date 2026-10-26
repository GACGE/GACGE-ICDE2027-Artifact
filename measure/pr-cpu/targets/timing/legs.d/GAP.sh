#!/usr/bin/env bash
# pr-cpu / GAP (cpu): GAP pr_spmv, 20 iterations, one thread per physical core (48), the pull chunk
# -c $(pr_chunk) (measure/common/datasets.sh: 1024, 64 on Hollywood; GAP's own 16384 until 2026-10-18);
# first run is the warm-up
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=cpu
LEG_DATASETS="${LEG_DATASETS:-paper syn}"
RUNS=(
  'timing|1|OMP_NUM_THREADS=$threads OMP_PLACES=threads OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/pr_spmv -i 20 -t 0 -c $(pr_chunk $ds) -n 11'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
