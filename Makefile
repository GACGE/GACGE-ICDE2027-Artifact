.PHONY: all help
.DEFAULT_GOAL := help

# Where each side runs: `local` (this machine, this checkout) or an ssh host whose checkout is ~/$(REMOTE_REPO_DIR).
# Measurement outputs land in measure/<unit>/outputs/<machine>/, and the analysis scripts read the same two names
# from the environment.
CPU_MACHINE ?= local
GPU_MACHINE ?= local

# Every Python script runs in the conda environment of make setup-python (deps/conda/envs/gacge) once it exists, and
# the GPU side uses the CUDA 13.2 toolkit in CUDA_HOME when it is there.
CONDA_DIR ?= $(CURDIR)/deps/conda
CUDA_HOME ?= /usr/local/cuda-13.2
export PATH := $(if $(wildcard $(CONDA_DIR)/envs/gacge/bin/python3),$(CONDA_DIR)/envs/gacge/bin:)$(if $(wildcard $(CUDA_HOME)/bin/nvcc),$(CUDA_HOME)/bin:)$(PATH)
export CPU_MACHINE GPU_MACHINE

# The root aggregates and does nothing else. Every target is defined by the
# directory that owns the work, in its own targets/Makefile.mk, and each of
# those keeps its implementation under targets/scripts/.
include deps/targets/Makefile.mk
include data/targets/Makefile.mk
include src/targets/Makefile.mk
# The src/ -> measure/ -> analysis/ tree: each measurement unit and each
# analysis owns its targets/Makefile.mk.
include measure/common/targets/algo_unit.mk
-include $(wildcard measure/*/targets/Makefile.mk)
-include $(wildcard analysis/*/targets/Makefile.mk)

# Targets document themselves with a `## name: summary` line directly above
# them; help lists those.
help:
	@echo "GACGE: graph primitives on the CPU and the GPU (ICDE 2027 artifact). Run make <target>."
	@echo
	@awk 'BEGIN { FS = ": " } \
	     /^## [a-zA-Z0-9_.%<>-]+:/ { \
	       sub(/^## /, "", $$0); \
	       split($$0, p, ": "); \
	       name = p[1]; $$0 = substr($$0, length(name) + 3); \
	       printf "  \033[1m%-44s\033[0m %s\n", name, $$0 }' \
	  $(MAKEFILE_LIST) | sort
