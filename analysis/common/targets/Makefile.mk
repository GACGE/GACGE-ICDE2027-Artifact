# analysis/common: every analysis, and copying its figures and tables (analysis/common/targets/floats.tsv) to results/. Each analysis/<dir>/targets/Makefile.mk adds analysis-<dir> to ANALYSIS_DIRS.
PY ?= python3
.PHONY: analysis results
## analysis: every figure and table of the paper from the measured data, into analysis/<dir>/outputs/
analysis:
	@for d in $(ANALYSIS_DIRS); do $(MAKE) -s --no-print-directory analysis-$$d || exit 1; done
## results: run analysis, then copy the paper's figures and tables into results/ (named by paper number)
results: analysis
	analysis/common/targets/scripts/collect.sh results
