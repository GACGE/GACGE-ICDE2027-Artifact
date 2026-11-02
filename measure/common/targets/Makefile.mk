# measure/common: every measurement of the paper, per side (measure/common/campaign.sh), and the one-step reproduction.
#   CPU= / GPU= name the ssh host of each side; empty runs that side on this machine.
.PHONY: measure-cpu measure-gpu setup-python setup-cpu setup-gpu reproduce-cpu reproduce-gpu reproduce
## measure-cpu: build the CPU programs on CPU_MACHINE and run every CPU leg (timing, profile, trace)
measure-cpu:
	measure/common/campaign.sh cpu $(CPU_MACHINE)
## measure-gpu: build the GPU programs on GPU_MACHINE and run every GPU leg (timing, profile; stock and naive Gunrock)
measure-gpu:
	measure/common/campaign.sh gpu $(GPU_MACHINE)

## setup-python: Miniforge into deps/conda and the Python environments every script runs in
setup-python:
	deps/targets/scripts/setup_python.sh
## setup-cpu: [CPU=<ssh host>] system packages, Python, the CPU programs and the graphs, here or on CPU
setup-cpu:
	measure/common/reproduce_side.sh cpu "$(CPU)" setup
## setup-gpu: [GPU=<ssh host>] system packages, CUDA 13.2, Python, the GPU programs and the graphs, here or on GPU
setup-gpu:
	measure/common/reproduce_side.sh gpu "$(GPU)" setup
## reproduce-cpu: [CPU=<ssh host>] setup-cpu, then every CPU measurement, here or on CPU
reproduce-cpu:
	measure/common/reproduce_side.sh cpu "$(CPU)" reproduce
## reproduce-gpu: [GPU=<ssh host>] setup-gpu, then every GPU measurement, here or on GPU
reproduce-gpu:
	measure/common/reproduce_side.sh gpu "$(GPU)" reproduce
## reproduce: [CPU=<ssh host>] [GPU=<ssh host>] everything: setup and measure both sides (at once on two machines), then results/
reproduce:
	$(MAKE) setup-python
	$(MAKE) $(if $(filter-out x$(CPU),x$(GPU)),-j2) reproduce-cpu reproduce-gpu
	$(MAKE) results
