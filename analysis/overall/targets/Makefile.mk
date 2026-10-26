# analysis/overall: Figure 4 (CPU and GPU runtimes)
ANALYSIS_DIRS += overall
.PHONY: analysis-overall
## analysis-overall: Figure 4 (CPU and GPU runtimes) -> analysis/overall/outputs/
analysis-overall:
	$(PY) analysis/overall/targets/scripts/plot_runtimes.py
