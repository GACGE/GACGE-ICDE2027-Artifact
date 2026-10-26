#!/usr/bin/env bash
# gunrock-naive-vs-ours / GPU: XB-Gunrock as a direct port would build it and
# as XB-Gunrock builds it, both with the paper's load balancing (-l gacge, as
# xb-gpu XB-Gunrock), 1 warm-up + 10 timed rounds on the paper's eight graphs:
#   naive  the segment path table, cycle materialisation and the original
#          blossom-base identification (both endpoint-to-root paths written out:
#          -T segment -M mat -B rootpath); its buffers sized from the measured
#          peaks (datasets.sh xb_naive_cycle_ratio / xb_seg_ratio / xb_mat_list_ratio).
#          scripts/naive_fit.sh raises -p and reruns whenever the cycle buffer
#          overflows, so a graph ends either with a result or with an OOM.
#   ours   the compact path table and cycle-free odd-vertex conversion
#          (-T compact -M nomat)
# Every round prints XBMemory (table_bytes, paths_used, blossom_buffer_peak,
# blossom_list_peak: what each variant keeps beyond the graph) and XBRound.
# Run through measure/common/run_leg.sh; see measure/common/leg_lib.sh.
set -uo pipefail
ARM=gpu
LEG_TIMEOUT="${LEG_TIMEOUT:-1800}"
LEG_DATASETS="${LEG_DATASETS:-paper}"
RUNS=(
  'naive|0|bash measure/gunrock-naive-vs-ours/targets/scripts/naive_fit.sh -- $GUNROCK/xblossom -m $gmtx -d $ds -l gacge -M mat -T segment -B rootpath -p $(xb_naive_cycle_ratio $ds) -q $(xb_seg_ratio $ds) -o $(xb_mat_list_ratio $ds) -w 1 -r 10'
  'ours|0|$GUNROCK/xblossom -m $gmtx -d $ds -l gacge -M nomat -T compact -o $(xb_nomat_list_ratio $ds) -w 1 -r 10'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
