# measure/common: every measurement of the paper, per side (measure/common/campaign.sh), and the one-step reproduction.
#   On each machine itself (CPU_MACHINE / GPU_MACHINE = local, the default).
.PHONY: measure-cpu measure-gpu reproduce-cpu reproduce-gpu import-outputs
## measure-cpu: build the CPU programs on CPU_MACHINE and run every CPU leg (timing, profile, trace)
measure-cpu:
	measure/common/campaign.sh cpu $(CPU_MACHINE)
## measure-gpu: build the GPU programs on GPU_MACHINE and run every GPU leg (timing, profile; stock and naive Gunrock)
measure-gpu:
	measure/common/campaign.sh gpu $(GPU_MACHINE)

## reproduce-cpu: on the CPU machine itself: fetch and generate the graphs, build, run every CPU leg
reproduce-cpu:
	$(MAKE) datasets datasets-syn
	$(MAKE) measure-cpu CPU_MACHINE=local
## reproduce-gpu: on the GPU machine itself: fetch and generate the graphs, build, run every GPU leg
reproduce-gpu:
	$(MAKE) datasets datasets-syn
	$(MAKE) measure-gpu GPU_MACHINE=local
## import-outputs: FROM=<[host:]path of the other machine's checkout>: copy its measurements here (measure/*/outputs)
import-outputs:
	@test -n "$(FROM)" || { echo "usage: make import-outputs FROM=<[host:]path to the other checkout>"; exit 2; }
	rsync -a --include='*/' --include='measure/*/outputs/**' --exclude='*' --prune-empty-dirs "$(FROM)/" ./
