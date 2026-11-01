# analysis/parallelism: Figures 5-7 (frontiers, active threads and small-step time)
# The paper's PNGs of Figures 5-7 were rendered with matplotlib 3.8.2, the others with 3.11.1: PY_MPL382 is a Python
# with matplotlib 3.8.2 (and numpy 1.26), for the same pixels; any other matplotlib draws the same data.
PY_MPL382 ?= $(PY)
ANALYSIS_DIRS += parallelism
.PHONY: analysis-parallelism
## analysis-parallelism: Figures 5-7 (frontiers, active threads and small-step time) -> analysis/parallelism/outputs/
analysis-parallelism:
	$(PY_MPL382) analysis/parallelism/targets/scripts/plot_frontier_cpu.py
	$(PY_MPL382) analysis/parallelism/targets/scripts/plot_frontier_xb_phase.py
	$(PY_MPL382) analysis/parallelism/targets/scripts/plot_parallelism.py
