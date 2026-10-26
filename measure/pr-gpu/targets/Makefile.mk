# measure/pr-gpu: PageRank on the GPU (README.md)
## measure-pr-gpu: PageRank on the GPU: build on GPU_MACHINE, run its timing legs (also -build, -timing, -profile, -trace; LEG=, PARSE=1)
$(eval $(call algo_unit,pr-gpu,gpu))
