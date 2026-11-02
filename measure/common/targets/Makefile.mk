# measure/common: every measurement of the paper, per side (measure/common/campaign.sh), and the one-step reproduction.
#   CPU= / GPU= name the ssh host of each side; empty runs that side on this machine.
.PHONY: measure-cpu measure-gpu reproduce-cpu reproduce-gpu reproduce
## measure-cpu: build the CPU programs on CPU_MACHINE and run every CPU leg (timing, profile, trace)
measure-cpu:
	measure/common/campaign.sh cpu $(CPU_MACHINE)
## measure-gpu: build the GPU programs on GPU_MACHINE and run every GPU leg (timing, profile; stock and naive Gunrock)
measure-gpu:
	measure/common/campaign.sh gpu $(GPU_MACHINE)

## reproduce-cpu: [CPU=<ssh host>] graphs, build and every CPU measurement, on this machine or on CPU
reproduce-cpu:
	measure/common/reproduce_side.sh cpu "$(CPU)"
## reproduce-gpu: [GPU=<ssh host>] graphs, build and every GPU measurement, on this machine or on GPU
reproduce-gpu:
	measure/common/reproduce_side.sh gpu "$(GPU)"
## reproduce: [CPU=<ssh host>] [GPU=<ssh host>] both sides (at once on two machines), then results/
reproduce:
	$(MAKE) $(if $(filter-out x$(CPU),x$(GPU)),-j2) reproduce-cpu reproduce-gpu
	$(MAKE) results
