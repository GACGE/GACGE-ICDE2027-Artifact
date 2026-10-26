# measure/gunrock-naive-vs-ours: XB++-Gunrock, naive (segment path table + cycle materialisation) vs ours (compact path table + cycle-free conversion), all 18 graphs, on GPU_MACHINE.
#   make measure-gunrock-naive-vs-ours-GPU         measure (remote), pull raws, parse
#   make measure-gunrock-naive-vs-ours-GPU-parse   re-parse the raws already here
.PHONY: measure-gunrock-naive-vs-ours-GPU measure-gunrock-naive-vs-ours-GPU-parse
## measure-gunrock-naive-vs-ours-GPU: XB++-Gunrock naive vs ours: device memory beyond the graph and runtime (GPU_MACHINE)
measure-gunrock-naive-vs-ours-GPU:
	measure/common/run_leg.sh gunrock-naive-vs-ours GPU $(GPU_MACHINE) measure timing
measure-gunrock-naive-vs-ours-GPU-parse:
	measure/common/run_leg.sh gunrock-naive-vs-ours GPU $(GPU_MACHINE) parse timing
