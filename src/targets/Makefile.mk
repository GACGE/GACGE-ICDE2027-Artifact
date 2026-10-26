.PHONY: build-cpu build-gpu

## build-cpu: build the CPU implementations (GAP, XB-GAP) into build/gap/bin
build-cpu:
	./src/targets/scripts/build_cpu

## build-gpu: build the GPU implementations (Gunrock, XB-Gunrock) into build/gunrock/bin
build-gpu: deps-gpu
	./src/targets/scripts/build_gpu

