.PHONY: datasets datasets-syn

# Every measurement reads the binary CSR in data/bin (measure/common/datasets.sh). The eight real graphs and their
# source-node lists come from Cloudflare R2 (data/targets/scripts/r2-manifest.json, checksummed); the synthetic graphs
# of Sec. VI-D are generated with GAP's Kronecker generator and fixed seeds, so every machine makes the same graphs.
BIN_FETCH = ./data/targets/scripts/bin/download_datasets.sh && ./data/targets/scripts/src_nodes/download_datasets.sh
SYN_GRAPHS = $(shell bash -c 'source measure/common/datasets.sh && echo $$SYN_DATASETS')

## datasets: fetch the binary graphs and the source-node lists from R2 into data/bin, data/src_nodes
datasets:
	$(BIN_FETCH)

## datasets-syn: generate the synthetic size and density graphs (SYN_DATASETS) into data/bin
datasets-syn:
	./data/targets/scripts/synthetic/make_synthetic.sh $(SYN_GRAPHS)

