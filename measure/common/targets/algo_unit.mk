# The make targets of a per-algorithm unit measure/<algo>-<cpu|gpu> (one
# algorithm, one implementation, one side). Each such unit holds
#   README.md                   the implementation, its version and parameters, how it is built and run
#   hook/targets                the CMake targets it needs (measure/common/build_unit.sh)
#   targets/Makefile.mk         `$(eval $(call algo_unit,<unit>,<cpu|gpu>))` and its help line
#   targets/<kind>/legs.d/*.sh  timing (runtime), profile (perf / ncu), trace (instrumented runs)
#   outputs/<machine>/{raw,json,md}/<kind>/<Leg>
# and gets
#   make measure-<unit>            build on its machine, then every timing leg
#   make measure-<unit>-build      build only
#   make measure-<unit>-timing | -profile | -trace
#                                  every leg of that kind; LEG=<Leg> for one,
#                                  PARSE=1 to re-parse the raws already here
# (measure/common/run_unit.sh). CPU units run on CPU_MACHINE, GPU units on
# GPU_MACHINE; their timing legs join the campaign (make measure-cpu / -gpu).
# Included by the root Makefile before the units.
define algo_unit
.PHONY: measure-$(1) measure-$(1)-build measure-$(1)-timing measure-$(1)-profile measure-$(1)-trace
measure-$(1):
	measure/common/run_unit.sh $(1) $$(if $$(filter cpu,$(2)),$$(CPU_MACHINE),$$(GPU_MACHINE)) $(2) build timing
measure-$(1)-build measure-$(1)-timing measure-$(1)-profile measure-$(1)-trace:
	measure/common/run_unit.sh $(1) $$(if $$(filter cpu,$(2)),$$(CPU_MACHINE),$$(GPU_MACHINE)) $(2) $$(patsubst measure-$(1)-%,%,$$@)
MEASURE_UNITS += $(1)
$(if $(filter cpu,$(2)),MEASURE_CPU_PAIRS,MEASURE_GPU_PAIRS) += $(addprefix $(1):,$(notdir $(basename $(wildcard measure/$(1)/targets/timing/legs.d/*.sh))))
endef
