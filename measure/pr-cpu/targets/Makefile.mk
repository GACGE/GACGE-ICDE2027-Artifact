# measure/pr-cpu: PageRank on the CPU (README.md)
## measure-pr-cpu: PageRank on the CPU: build on CPU_MACHINE, run its timing legs (also -build, -timing, -profile, -trace; LEG=, PARSE=1)
$(eval $(call algo_unit,pr-cpu,cpu))
