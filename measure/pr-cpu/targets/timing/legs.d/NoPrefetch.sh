#!/usr/bin/env bash
# pr-cpu / NoPrefetch (cpu): the GAP timing run with the core's hardware prefetchers disabled (MSR 0x1a4, set and
# restored around each run by measure/common/no_prefetch.sh; the log records the register: 0x2f = L2 streamer, L2 adjacent line,
# DCU streamer, DCU IP and AMP off), one warm-up and three measured runs: how much of the thread's data movement is
# the prefetcher's (analysis/regime prefetch_ablation.py; 2026-10-22).
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=cpu
LEG_DATASETS="${LEG_DATASETS:-paper}"
RUNS=(
  'timing|1|measure/common/no_prefetch.sh env OMP_NUM_THREADS=$threads OMP_PLACES=threads OMP_PROC_BIND=spread src/gap/gap_on_bin.sh $ladj $GAP/pr_spmv -i 20 -t 0 -c $(pr_chunk $ds) -n 4'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
