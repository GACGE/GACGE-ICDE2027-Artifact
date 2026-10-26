.PHONY: deps-gpu

# GAP needs only g++ with OpenMP; Gunrock fetches its sources (moderngpu, ...) here.
## deps-gpu: prepare Gunrock's dependencies (deps/gunrock)
deps-gpu:
	./deps/targets/scripts/gunrock/install.sh

