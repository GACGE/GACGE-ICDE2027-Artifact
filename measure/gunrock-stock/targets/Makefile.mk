# measure/gunrock-stock: Gunrock essentials' own BFS, SSSP, PageRank and TC (upstream 530f254,
# src/gunrock-stock) against the paper's Gunrock implementations (README.md)
## measure-gunrock-stock: build Gunrock's stock examples on GPU_MACHINE and run their timing legs (also -build, -timing; LEG=, PARSE=1)
.PHONY: measure-gunrock-stock measure-gunrock-stock-build measure-gunrock-stock-timing
measure-gunrock-stock: measure-gunrock-stock-build measure-gunrock-stock-timing
measure-gunrock-stock-build:
	measure/gunrock-stock/targets/scripts/build_stock.sh $(GPU_MACHINE)
measure-gunrock-stock-timing:
	measure/common/run_unit.sh gunrock-stock $(GPU_MACHINE) gpu timing
