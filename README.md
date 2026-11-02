# GACGE: Graph Algorithms on CPUs and GPUs, an Evaluation

This repository is the artifact of the ICDE 2027 Experiment, Analysis, and Benchmark paper *Performance Insights and
Architectural Implications of Graph Data Processing*. It holds five graph primitives (BFS, SSSP, PageRank, triangle
counting and X-Blossom maximum matching), each implemented on the CPU (OpenMP, GAP Benchmark Suite) and on the GPU
(CUDA, Gunrock), the harness that measures them, and the analysis that turns the measurements into every figure and
table of the paper's evaluation.

## Requirements

The paper compares a CPU machine and a GPU machine. Install these yourself; the setup installs everything else.

- **The machine you type the commands on** (it can be one of the two below): `git`, `make`, `bash`, `ssh`, `tar`,
  and `wget` or `curl`.
- **CPU machine** (paper: AWS `m7i.metal-24xl`, Intel Xeon Platinum 8488C, 48 cores, 96 hardware threads): Ubuntu
  24.04, bare-metal Intel (the profiling reads hardware counters, and Fig. 9 switches the hardware prefetchers off and
  on), `sudo` without a password, internet access, and about 80 GB of free disk.
- **GPU machine** (paper: AWS `g7e.8xlarge`, NVIDIA RTX PRO 6000 Blackwell Server Edition): Ubuntu 24.04, an NVIDIA
  driver that supports CUDA 13.2 (595 or newer; the paper used 595.71.05), `sudo` without a password, internet access,
  about 80 GB of free disk, and no other work on the GPU.

The setup installs the rest: the system packages (compilers, `make`, `perf`, `msr-tools`), CMake 4.3.1, the CUDA 13.2
toolkit if it is absent, Miniforge with the Python environments in `deps/conda` (every Python script runs there),
Gunrock's dependencies, the programs, and the graphs.

## Reproducing the paper

One command, from any machine that reaches both by ssh (keys, no password prompt):

```bash
make reproduce CPU=<user@cpu-host> GPU=<user@gpu-host>
```

It copies the repository to `~/GACGE-ICDE2027-Artifact` on each machine, sets both machines up, runs every measurement
on both at once, copies the measurements back, and writes every figure and table into `results/`. It took about 3
hours on the paper's machines. On a single machine with both the CPU and the GPU, `make reproduce` alone does the same
there, one side after the other.

Step by step (leave out `CPU=` / `GPU=` to run that step on the machine you are on):

```bash
make setup-cpu CPU=<user@cpu-host>       # packages, Python, build, graphs
make setup-gpu GPU=<user@gpu-host>       # the same, plus CUDA 13.2 if missing
make reproduce-cpu CPU=<user@cpu-host>   # setup (already done, so quick), then every CPU measurement
make reproduce-gpu GPU=<user@gpu-host>
make results                             # every figure and table into results/
```

Runs are resumable: if a run stops, the same command continues where it stopped.

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

The raw measurements are under `measure/<primitive>-<cpu|gpu>/outputs/`.

## License

Our code is under the Apache License 2.0 (`LICENSE`); the GAP Benchmark Suite, Gunrock and the other third-party code
keep their own licenses.
