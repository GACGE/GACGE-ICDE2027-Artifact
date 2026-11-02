# GACGE: Graph Algorithms on CPUs and GPUs, an Evaluation

This repository is the artifact of the ICDE 2027 Experiment, Analysis, and Benchmark paper *Performance Insights and
Architectural Implications of Graph Data Processing*. It holds five graph primitives (BFS, SSSP, PageRank, triangle
counting and X-Blossom maximum matching), each implemented on the CPU (OpenMP, GAP Benchmark Suite) and on the GPU
(CUDA, Gunrock), the harness that measures them, and the analysis that turns the measurements into every figure and
table of the paper's evaluation.

## Requirements

The paper compares a CPU machine and a GPU machine, both running Ubuntu 24.04 with about 80 GB of free disk.

- **CPU machine** (paper: AWS `m7i.metal-24xl`, Intel Xeon Platinum 8488C, 48 cores, 96 hardware threads). Bare
  metal Intel, because the profiling reads hardware counters and Fig. 9 switches the hardware prefetchers off and on.
  `g++` with OpenMP, CMake 3.16+, `git`, `wget`, `zstd`, `python3`, `perf`, `msr-tools`, and `sudo` without a password.
- **GPU machine** (paper: AWS `g7e.8xlarge`, NVIDIA RTX PRO 6000 Blackwell Server Edition). CUDA 13.2 (`nvcc` and
  Nsight Compute `ncu` on `PATH`), `g++`, CMake 3.24+, `git`, `wget`, `zstd`, `python3`, and `sudo` without a
  password. The GPU must be otherwise idle.
- To make the figures: `python3` with `matplotlib`, `numpy` and `pillow`.

## Reproducing the paper

From any machine that reaches both by ssh (keys, no password prompt):

```bash
make reproduce CPU=<user@cpu-host> GPU=<user@gpu-host>
```

This copies the repository to `~/GACGE-ICDE2027-Artifact` on each machine, downloads and generates the graphs, builds
and runs every measurement on both machines at once, copies the measurements back, and writes every figure and table
into `results/`. It took about 3 hours on the paper's machines.

One machine at a time:

```bash
make reproduce-cpu CPU=<user@cpu-host>
make reproduce-gpu GPU=<user@gpu-host>
make results
```

Without `CPU=` or `GPU=`, that side runs on the machine you type it on; on a machine with both the CPU and the GPU,
`make reproduce` alone does everything there, one side after the other. Runs are resumable: if a run stops, the same
command continues where it stopped.

## Results

`results/` holds the paper's figures and tables, named by their number in the paper:

| Paper | `results/` |
|---|---|
| Table III, the eight graphs | `tables/tab03_graph_metrics.tex` |
| Table IV, naive and optimized XB-Gunrock | `tables/tab04_blossom_memory.tex` |
| Sec. V, stock Gunrock vs. our GPU implementations | `text/sec5_stock_gunrock.md` |
| Fig. 4, CPU and GPU runtimes | `figures/fig04_runtimes.png` |
| Fig. 5, frontier sizes per step | `figures/fig05_frontier_cpu.png` |
| Fig. 6, the phases of one X-Blossom search | `figures/fig06_frontier_xb_phase.png` |
| Fig. 7, GPU resident threads and small-step time | `figures/fig07_parallelism.png` |
| Table V, the caches under depth scaling | `tables/tab05_depth_cache.tex` |
| Fig. 8, breadth and depth scaling | `figures/fig08_breadth_depth.png` |
| Fig. 9, the CPU's hardware prefetchers | `figures/fig09_prefetch.png` |
| Table VI, stalls and speedup on the synthetic graphs | `tables/tab06_syn_evidence.tex` |
| Fig. 10, graph size and density | `figures/fig10_graph_properties.png` |

The raw measurements are under `measure/<primitive>-<cpu|gpu>/outputs/`. The paper's Figs. 5-7 were drawn with
matplotlib 3.8.2, the others with 3.11.1; other versions draw the same data with slightly different text layout.

## License

Our code is under the Apache License 2.0 (`LICENSE`); the GAP Benchmark Suite, Gunrock and the other third-party code
keep their own licenses.
