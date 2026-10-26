# analysis/datasets: Table III (the evaluated graphs)
ANALYSIS_DIRS += datasets
.PHONY: analysis-datasets
## analysis-datasets: Table III (the evaluated graphs) -> analysis/datasets/outputs/
analysis-datasets:
	$(PY) analysis/datasets/targets/scripts/tab_graph_metrics.py
