#!/usr/bin/env bash
# sssp-gpu / Breadth-Depth (gpu): Fig. 8's GPU breadth and depth with the paper's kernels. Breadth: 8, 24 and 64 SMs
# (GACGE_GPU_SMS, a CUDA green context; 188 = all) at one block an SM; depth: all 188 SMs at 2, 4 and 11 blocks an SM.
# Blocks an SM: GACGE_GPU_GRID_K caps the grid at k x SMs blocks, which loop over the work (no shared-memory pad).
# No MPS daemon may run (green contexts need a plain client). bd_trials / bd_rounds runs (datasets.sh).
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_DATASETS="${LEG_DATASETS:-paper}"
LEG_TIMEOUT="${LEG_TIMEOUT:-3600}"
RUNS=(
  's8k1|1|env GACGE_SSSP_DELTA=$(sssp_delta $ds) GACGE_GPU_GRID_K=1 GACGE_GPU_SMS=8 $GUNROCK/sssp -s $src -m $gmtx_w -n $(bd_trials $ds)'
  's24k1|1|env GACGE_SSSP_DELTA=$(sssp_delta $ds) GACGE_GPU_GRID_K=1 GACGE_GPU_SMS=24 $GUNROCK/sssp -s $src -m $gmtx_w -n $(bd_trials $ds)'
  's64k1|1|env GACGE_SSSP_DELTA=$(sssp_delta $ds) GACGE_GPU_GRID_K=1 GACGE_GPU_SMS=64 $GUNROCK/sssp -s $src -m $gmtx_w -n $(bd_trials $ds)'
  's188k1|1|env GACGE_SSSP_DELTA=$(sssp_delta $ds) GACGE_GPU_GRID_K=1 $GUNROCK/sssp -s $src -m $gmtx_w -n $(bd_trials $ds)'
  's188k2|1|env GACGE_SSSP_DELTA=$(sssp_delta $ds) GACGE_GPU_GRID_K=2 $GUNROCK/sssp -s $src -m $gmtx_w -n $(bd_trials $ds)'
  's188k4|1|env GACGE_SSSP_DELTA=$(sssp_delta $ds) GACGE_GPU_GRID_K=4 $GUNROCK/sssp -s $src -m $gmtx_w -n $(bd_trials $ds)'
  's188k11|1|env GACGE_SSSP_DELTA=$(sssp_delta $ds) GACGE_GPU_GRID_K=11 $GUNROCK/sssp -s $src -m $gmtx_w -n $(bd_trials $ds)'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
