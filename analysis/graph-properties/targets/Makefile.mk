# analysis/graph-properties: Figure 10 and Table VI (graph size and density)
ANALYSIS_DIRS += graph-properties
.PHONY: analysis-graph-properties
## analysis-graph-properties: Figure 10 and Table VI (graph size and density) -> analysis/graph-properties/outputs/
analysis-graph-properties:
	$(PY) analysis/graph-properties/targets/scripts/plot_syn_parallelism.py
	$(PY) analysis/graph-properties/targets/scripts/tab_syn_evidence.py
