# GACGE: Graph Algorithms on CPUs and GPUs, an Evaluation

This repository is the artifact of the ICDE 2027 Experiment, Analysis, and
Benchmark paper *Performance Insights and Architectural Implications of Graph
Data Processing*. It holds five graph primitives, each implemented on the CPU
and on the GPU, the measurement harness that runs them, and the analysis that
turns the measurements into every figure and table of the paper's evaluation.

| Primitive | CPU (OpenMP) | GPU (CUDA) |
|---|---|---|
| BFS, direction-optimizing | GAP Benchmark Suite | Gunrock, GAP's algorithm |
| SSSP, delta-stepping | GAP | Gunrock, GAP's algorithm |
| PageRank (PR), 20 iterations | GAP | Gunrock |
| Triangle counting (TC) | GAP | Gunrock, GAP's algorithm |
| X-Blossom maximum matching (XB) | XB-GAP | XB-Gunrock |

Everything is driven by `make`:

| Target | What it does |
|---|---|
| `make reproduce-cpu` | on the CPU machine: fetches and generates the graphs, builds the CPU programs, runs every CPU measurement |
| `make reproduce-gpu` | on the GPU machine: the same for the GPU programs, plus stock Gunrock and the naive XB-Gunrock |
| `make import-outputs FROM=<[host:]path>` | copies the other machine's measurements into this checkout |
| `make results` | every figure and table of the paper from the measurements, into `results/` |

`make help` lists every documented target.

## One-button reproduction

The paper compares two machines, so the measurements run on both. Clone this
repository on each of them, then:

```bash
# on the CPU machine
make reproduce-cpu

# on the GPU machine
make reproduce-gpu
make import-outputs FROM=<cpu-host>:<path to the clone there>
make results
```

`results/` then holds the paper's figures and tables, named by their number
in the paper; `results/MANIFEST.tsv` lists each file and the analysis output
it was copied from.

| `results/` | Paper |
|---|---|
| `tables/tab03_graph_metrics.tex` | Table III, the eight graphs |
| `tables/tab04_blossom_memory.tex` | Table IV, naive and optimized XB-Gunrock |
| `text/sec5_stock_gunrock.md` | Sec. V, stock Gunrock against our GPU implementations |
| `figures/fig04_runtimes.png` | Fig. 4, CPU and GPU runtimes |
| `figures/fig05_frontier_cpu.png` | Fig. 5, frontier sizes per step |
| `figures/fig06_frontier_xb_phase.png` | Fig. 6, the phases of one X-Blossom search |
| `figures/fig07_parallelism.png` | Fig. 7, GPU resident threads and small-step time |
| `tables/tab05_depth_cache.tex` | Table V, the caches under depth scaling |
| `figures/fig08_breadth_depth.png` | Fig. 8, breadth and depth scaling |
| `figures/fig09_prefetch.png` | Fig. 9, the CPU's hardware prefetchers |
| `tables/tab06_syn_evidence.tex` | Table VI, stalls and speedup on the synthetic graphs |
| `figures/fig10_graph_properties.png` | Fig. 10, graph size and density |

`make results` alone redoes the analysis from the measurements already in the
checkout; it needs only `python3` with `matplotlib`, `numpy` and `pillow`. The
paper's PNGs of Figs. 5–7 were rendered with matplotlib 3.8.2 and numpy 1.26.4,
the others with matplotlib 3.11.1 and numpy 2.5.2; other versions draw the same
data with slightly different text layout. To get the paper's pixels, point
`PY_MPL382` at a Python with matplotlib 3.8.2 (it defaults to `PY`):

```bash
make results PY=python3 PY_MPL382=/path/to/python-with-matplotlib-3.8.2
```

## Requirements

The paper's machines were two AWS instances running Ubuntu 24.04.

**CPU machine** (paper: `m7i.metal-24xl`, Intel Xeon Platinum 8488C, 48 cores,
96 hardware threads, 384 GB). A bare-metal Intel machine: the profiling reads
hardware counters with `perf`, and the prefetcher experiment (Fig. 9) turns the
hardware prefetchers off through MSR 0x1a4 and restores them afterwards.
Software: `g++` with OpenMP, CMake 3.16 or newer, `git`, `wget`, `zstd`,
`python3`, `perf` (`linux-tools`), `msr-tools`, and `sudo` without a password
(for `perf` and the MSR).

**GPU machine** (paper: `g7e.8xlarge`, NVIDIA RTX PRO 6000 Blackwell Server
Edition, 188 SMs, 96 GB). Software: an NVIDIA driver for CUDA 13.2, the CUDA
toolkit 13.2 (`nvcc` and Nsight Compute `ncu` on `PATH`), `g++`, CMake 3.24
or newer, `git` (CMake fetches CCCL, moderngpu and a few header libraries at
build time), `wget`, `zstd`, `python3`, and `sudo` without a password (for
`ncu`). No MPS daemon may run; the harness stops one it finds.

Each machine needs about 80 GB of free disk: the real graphs come as an 11 GB
archive (deleted once unpacked) holding 37 GB of binary CSR files, the eleven
synthetic graphs take 20 GB, and the build with its fetched dependencies
1.3 GB.

The software the paper's runs used:

| | CPU machine | GPU machine |
|---|---|---|
| OS | Ubuntu 24.04.4, Linux 7.0 (AWS) | Ubuntu 24.04.4, Linux 7.0 (AWS) |
| Compiler | GCC 13.3.0 | GCC 13.3.0, CUDA 13.2 (`nvcc` 13.2.78) |
| CMake | 4.3.1 | 4.3.1 |
| Profiler | `perf` 7.0.14, `msr-tools` 1.3 | Nsight Compute 2026.1.1, driver 595.71.05 |
| Python | 3.13 | 3.13 |

The scaling experiments follow the paper's machines: the CPU sweeps 6 to 96
threads, the GPU 8 to 188 SMs through CUDA green contexts. On other hardware
the harness still runs, but those sweeps and the analysis (which assumes 188
SMs and 96 threads) describe the paper's machines. `CUDA_ARCH` (default 89)
sets the CUDA architecture of the build.

## What a run takes

On the paper's machines the measurements took about 1.2 hours on the CPU and
2.4 hours on the GPU. Before them, fetching and generating the graphs took
about 12 minutes and the build about 8 minutes on the GPU machine (the CPU
build takes under a minute). Runs are resumable: a
measurement whose log already ends successfully is skipped, so an interrupted
`reproduce-*` continues where it stopped (`FORCE=1` reruns everything).

## What a run does

1. **Graphs** (`data/`). `make datasets` downloads the eight real graphs
   (binary CSR) and their source vertices, checksummed
   (`data/targets/scripts/r2-manifest.json`); `make datasets-syn` generates
   the synthetic Kronecker graphs of Sec. VI with GAP's generator and fixed
   seeds, so both machines hold the same graphs.
2. **Build** (`src/`). GAP and XB-GAP into `build/gap/bin`; Gunrock and
   XB-Gunrock into `build/gunrock/bin`; stock Gunrock into
   `build/gunrock-stock`.
3. **Measure** (`measure/`). One unit per primitive and side,
   `measure/<primitive>-<cpu|gpu>`, plus `gunrock-stock` and
   `gunrock-naive-vs-ours`. A unit's legs (`targets/<kind>/legs.d/*.sh`) list
   the runs on each graph:
   - `timing`: runtimes, 1 warm-up and 10 timed runs; the thread and SM sweeps
     run 1 warm-up and 3 timed runs on the five largest graphs;
   - `profile`: `perf stat` counters on the CPU, `ncu` metrics on the GPU,
     one counter pass per run, over the timed region only;
   - `trace`: the frontier of every step.

   Each run's log goes to `measure/<unit>/outputs/local/raw/`, parsed into
   `json/` and `md/` next to it. X-Blossom runs are checked against the known
   maximum matching sizes (`data/expected_matching_size.tsv`).
4. **Analyze** (`analysis/`). One directory per part of the evaluation, each
   writing to its own `outputs/`; `make results` runs them all and copies the
   paper's figures and tables into `results/`.

## Layout

```
data/      graph download and generation (data/targets)
deps/      Gunrock's build dependencies (deps/targets)
src/       gap/              GAP and XB-GAP (gapbs/ the suite with our kernels)
           gunrock/          Gunrock with our GPU implementations and XB-Gunrock
           gunrock-stock/    Gunrock as released, for Sec. V
           loops/            gunrock/loops, the load-balancing schedules
measure/   <primitive>-cpu, <primitive>-gpu   one unit per primitive and side
           gunrock-stock, gunrock-naive-vs-ours
           common/           the harness (campaign, legs, parsing)
analysis/  datasets/ implementations/ overall/ parallelism/ scaling/
           graph-properties/ (one per part of the evaluation), common/
results/   the paper's figures and tables (written by make results)
```

## Third-party code

- `src/gap/gapbs`: the GAP Benchmark Suite (Beamer et al., BSD license,
  `sbeamer/gapbs` 941462c), with our X-Blossom kernel (`xblossom.cc`) and our
  reworked BFS, SSSP and TC kernels; GAP's own versions remain selectable by
  environment variables documented in the kernels.
- `src/gunrock`: Gunrock essentials (Apache License 2.0) with our GPU
  implementations of GAP's algorithms and XB-Gunrock
  (`include/gunrock/algorithms/xblossom`).
- `src/gunrock-stock`: Gunrock essentials 530f254 as released; one
  environment switch in `tc.hxx` selects another load balancer and is off by
  default.
- `src/loops`: gunrock/loops (Apache License 2.0).
- Fetched at build time: NVIDIA CCCL, moderngpu (a fork with a fix for graphs
  of more than 2^30 edges), cxxopts, nlohmann/json, cmake-modules.

Each keeps the license file its upstream ships.

## License

Our code (XB-GAP, XB-Gunrock, our GAP and Gunrock kernels, the harness and the
analysis) is under the Apache License 2.0 (`LICENSE`). The third-party code
above keeps its own license.
