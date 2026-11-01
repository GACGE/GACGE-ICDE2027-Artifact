# analysis/implementations: Table IV (XB's GPU memory, direct vs optimized) and Sec. V's stock-Gunrock comparison
ANALYSIS_DIRS += implementations
.PHONY: analysis-implementations
## analysis-implementations: Table IV (XB's GPU memory, direct vs optimized) and Sec. V's stock-Gunrock comparison -> analysis/implementations/outputs/
analysis-implementations:
	$(PY) analysis/implementations/targets/scripts/tab_blossom_memory.py
	$(PY) analysis/implementations/targets/scripts/stock_vs_ours.py
	$(PY) analysis/implementations/targets/scripts/tab_xb_original.py
