#!/usr/bin/env bash
# bfs-cpu / GAP (cpu): GAP bfs, direction-optimizing; first run is the warm-up
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
# Threads: one per physical core (48 on the paper's Xeon Platinum 8488C, xb_cpu_threads; NUM_THREADS overrides), as PageRank,
# since 2026-10-20; the 96-hardware-thread runs before are in git history.
set -uo pipefail
ARM=cpu
LEG_DATASETS="${LEG_DATASETS:-paper syn}"
RUNS=(
  'timing|1|OMP_NUM_THREADS=$threads OMP_PLACES=threads OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/bfs -r $src -n 11'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
