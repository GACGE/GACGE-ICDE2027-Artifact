#!/usr/bin/env bash
# tc-cpu / GAP-N4 (cpu): GAP tc; first run is the warm-up
# GAP-N4: the GAP timing leg with one warm-up and three measured runs, for the synthetic graphs (the dense ones take minutes a run; 2026-10-22)
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
# Threads: one per physical core (48 on the paper's Xeon Platinum 8488C, xb_cpu_threads; NUM_THREADS overrides), as PageRank,
# since 2026-10-20; the 96-hardware-thread runs before are in git history.
set -uo pipefail
ARM=cpu
LEG_DATASETS="${LEG_DATASETS:-syn}"
RUNS=(
  'timing|1|OMP_NUM_THREADS=$threads OMP_PLACES=threads OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/tc -n 4'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
