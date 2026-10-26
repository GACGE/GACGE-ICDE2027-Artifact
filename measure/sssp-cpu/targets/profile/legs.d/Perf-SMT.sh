#!/usr/bin/env bash
# sssp-cpu / Perf-SMT (cpu): Table V's CPU rows. The second trial (the first a warm-up; perf_region.sh) at 48 threads,
# one a core, and at 96, two a core: l1 (loads, L1 and fill-buffer hits), mem (L2 and L3 misses), ipc (cycles, L1D
# misses outstanding, the PAUSE cycles of libgomp's spin-wait); user mode.
# Run through measure/common/run_unit.sh (or run_leg.sh); see measure/common/leg_lib.sh.
set -uo pipefail
ARM=cpu
LEG_DATASETS="${LEG_DATASETS:-paper}"
RUNS=(
  'l1-48|0|OMP_NUM_THREADS=48 OMP_PLACES=cores OMP_PROC_BIND=spread measure/common/perf_region.sh mem_inst_retired.all_loads:u,mem_load_retired.l1_hit:u,mem_load_retired.fb_hit:u,cpu_clk_unhalted.pause_inst:u 1 src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n 2'
  'mem-48|0|OMP_NUM_THREADS=48 OMP_PLACES=cores OMP_PROC_BIND=spread measure/common/perf_region.sh mem_inst_retired.all_loads:u,mem_load_retired.l2_miss:u,mem_load_retired.l3_miss:u,cpu_clk_unhalted.pause_inst:u 1 src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n 2'
  'ipc-48|0|OMP_NUM_THREADS=48 OMP_PLACES=cores OMP_PROC_BIND=spread measure/common/perf_region.sh cycles:u,instructions:u,l1d_pend_miss.pending:u,cpu_clk_unhalted.pause:u 1 src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n 2'
  'l1-96|0|OMP_NUM_THREADS=96 OMP_PLACES=threads OMP_PROC_BIND=spread measure/common/perf_region.sh mem_inst_retired.all_loads:u,mem_load_retired.l1_hit:u,mem_load_retired.fb_hit:u,cpu_clk_unhalted.pause_inst:u 1 src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n 2'
  'mem-96|0|OMP_NUM_THREADS=96 OMP_PLACES=threads OMP_PROC_BIND=spread measure/common/perf_region.sh mem_inst_retired.all_loads:u,mem_load_retired.l2_miss:u,mem_load_retired.l3_miss:u,cpu_clk_unhalted.pause_inst:u 1 src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n 2'
  'ipc-96|0|OMP_NUM_THREADS=96 OMP_PLACES=threads OMP_PROC_BIND=spread measure/common/perf_region.sh cycles:u,instructions:u,l1d_pend_miss.pending:u,cpu_clk_unhalted.pause:u 1 src/gap/gap_on_bin.sh $ladj $GAP/sssp -r $src -d $(sssp_delta $ds) -n 2'
)
source "${MEASURE_COMMON}/leg_lib.sh"
leg_main "$@"
