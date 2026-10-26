# analysis/parallelism: Figures 5-7 (frontiers, active threads and small-step time)
ANALYSIS_DIRS += parallelism
.PHONY: analysis-parallelism
## analysis-parallelism: Figures 5-7 (frontiers, active threads and small-step time) -> analysis/parallelism/outputs/
analysis-parallelism:
	$(PY) analysis/parallelism/targets/scripts/plot_frontier_cpu.py
	$(PY) analysis/parallelism/targets/scripts/plot_frontier_xb_phase.py
	$(PY) analysis/parallelism/targets/scripts/plot_parallelism.py
