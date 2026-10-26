#!/usr/bin/env bash
# sssp-gpu / StepTimes (gpu): one XBStepTime line per step of Gunrock's delta-stepping SSSP
# (GACGE_STEP_TIMES=1, src/gunrock: the step's kind, frontier vertices and edges, launched blocks and its
# time on the GPU timeline), 1 warm-up + 1 timed run on the paper's eight graphs; the analysis takes the
# last run. Before 2026-10-20 these logs were collected ad hoc on the L4 (analysis/step-times/inputs8).
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper syn}"
LEG_TIMEOUT="${LEG_TIMEOUT:-7200}"
RUNS=(
  'steps|0|GACGE_STEP_TIMES=1 GACGE_SSSP_DELTA=$(sssp_delta $ds) $GUNROCK/sssp -s $src -m $gmtx_w -n 2'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
