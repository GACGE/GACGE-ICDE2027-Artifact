# analysis/scaling: Figures 8-9 and Table V (breadth and depth scaling, prefetching, caches)
ANALYSIS_DIRS += scaling
.PHONY: analysis-scaling
## analysis-scaling: Figures 8-9 and Table V (breadth and depth scaling, prefetching, caches) -> analysis/scaling/outputs/
analysis-scaling:
	$(PY) analysis/scaling/targets/scripts/plot_breadth_depth.py
	$(PY) analysis/scaling/targets/scripts/plot_prefetch.py
	$(PY) analysis/scaling/targets/scripts/tab_depth_cache.py
