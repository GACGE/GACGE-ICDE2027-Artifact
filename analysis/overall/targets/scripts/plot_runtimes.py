"""The paper's runtime figure (fig. plot:runtimes): CPU (GAP; XB-GAP) against
GPU (Gunrock, the same algorithms as GAP; XB-Gunrock) runtime per graph for the traversal primitives
X-Blossom, BFS and SSSP and the iterative PageRank (20 iterations) and Triangle
Counting, mean of the timed runs from the per-algorithm units
(measure/<algo>-<cpu|gpu>, timing leg), log scale, the CPU / GPU
speedup over each GPU bar (red where the GPU is slower), on the paper's eight
graphs. MSSP is measured but left out of the paper. Writes analysis/overall/outputs/plot_runtimes.png.
Needs matplotlib."""
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from matplotlib.ticker import FuncFormatter, LogLocator, NullFormatter  # noqa: E402

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../common"))
from units import *  # noqa: E402,F403
from figsave import expect_matplotlib, save_cropped  # noqa: E402
expect_matplotlib("3.11.1")  # the paper's PNG

OUT = os.path.join(ANALYSIS, "overall", "outputs", "plot_runtimes.png")
NAMES = {"Livejournal": "LiveJournal", "UK2002": "UK-2002"}
# the paper's eight graphs, by node count ascending (Table II)
DATASETS = ["Amazon", "HiggsNets", "Youtube", "Kron21", "Orkut", "UK2002", "Arabic", "Sinaweibo"]


def mean(unit, leg, ds):
    xs = times(load_unit(unit), leg, ds)
    return sum(xs) / len(xs) if xs else np.nan


# (row, CPU (unit, leg), GPU (unit, leg), CPU tick label): the GAP Benchmark Suite is
# the CPU side of every primitive (X-Blossom: XB-GAP, written on GAP); abbreviations in the figures
# rows in order of the GM speedup, ascending (the user's choice, 2026-10-20): SSSP, BFS, XB, PR, TC
ROWS = [("SSSP", ("sssp-cpu", "GAP"), ("sssp-gpu", "Gunrock"), "GAP"),
        ("BFS", ("bfs-cpu", "GAP"), ("bfs-gpu", "Gunrock"), "GAP"),
        ("XB", ("xb-cpu", "XB-GAP"), ("xb-gpu", "XB-Gunrock"), "GAP"),
        ("PR", ("pr-cpu", "GAP"), ("pr-gpu", "Gunrock"), "GAP"),
        ("TC", ("tc-cpu", "GAP"), ("tc-gpu", "Gunrock"), "GAP")]
# CPU blue, GPU red (Fig. 7 the same hues). The first column is the geometric mean over the eight graphs,
# solid and dark; after a gap the eight graphs follow, packed, lighter and hatched (RT-Benchmarks' layout,
# 2026-10-20).
CPU_GM, GPU_GM = "#5B9BD5", "#EF6F62"  # medium blue / coral, solid: the geometric means
CPU_DS, GPU_DS = ("#8CBBE4", ".....", "black"), ("#F5978C", "/////", "white")  # the graphs: a shade lighter, dense hatches (black dots: white ones vanished on the light blue)
from matplotlib.patches import Patch  # noqa: E402


EDGE_LW = 1.0  # a bar's black frame, as RT-Benchmarks' plot_style (the fill and its white hatch are drawn first)


def hbar(ax, x, h, width, fill, hatch=None, hatch_color="white"):
    ax.bar(x, h, width=width, color=fill, edgecolor=hatch_color, hatch=hatch, linewidth=0, zorder=2)
    ax.bar(x, h, width=width, color="none", edgecolor="black", linewidth=EDGE_LW, zorder=2.5)


gmean = lambda v: float(np.exp(np.log(v[np.isfinite(v) & (v > 0)]).mean()))
data = [(lab, np.array([mean(*c, d) for d in DATASETS]), np.array([mean(*g, d) for d in DATASETS]), tick)
        for lab, c, g, tick in ROWS]


def fmt(y, _):
    return f"{y:g}" if y > 0 and abs(np.log10(y) - round(np.log10(y))) < 1e-6 else ""


plt.rcParams.update({"font.size": 7, "axes.linewidth": 1.0, "hatch.linewidth": 0.5})
NCOL = len(DATASETS) + 2  # GM, a spacer, the graphs
fig, axes = plt.subplots(len(data), NCOL, figsize=(7.0, 0.925 * len(data)),
                         gridspec_kw={"width_ratios": [1.0, 0.45] + [1.0] * len(DATASETS), "wspace": 0.12, "hspace": 0.42})
fig.subplots_adjust(left=0.065, right=0.955, bottom=0.03, top=0.90)
for r, (lab, cpu, gpu, tick) in enumerate(data):
    vals = np.concatenate([cpu, gpu])
    vals = vals[np.isfinite(vals) & (vals > 0)]
    lo = vals.min() * 0.8
    hi = vals.max() * (vals.max() / lo) ** 0.3  # room for the speedup label over the tallest GPU bar
    axes[r, 1].axis("off")  # the gap between the GM and the graphs
    cols = [("GM", gmean(cpu), gmean(gpu), True)] + [(NAMES.get(d, d), cpu[c], gpu[c], False) for c, d in enumerate(DATASETS)]
    for k, (title, vc, vg, is_gm) in enumerate(cols):
        ax = axes[r, 0 if is_gm else k + 1]
        if is_gm:
            hbar(ax, -0.3, vc, 0.22, CPU_GM)
            hbar(ax, 0.3, vg, 0.22, GPU_GM)
        else:
            hbar(ax, -0.3, vc, 0.22, *CPU_DS)
            hbar(ax, 0.3, vg, 0.22, *GPU_DS)
        if np.isfinite(vc) and np.isfinite(vg) and vg > 0:
            sp = vc / vg
            lab_s = f"{sp:.2f}x" if 0.95 <= sp < 1.05 else f"{sp:.2g}x"  # 0.99 would print as a red "1x"
            ax.text(0.3, vg * 1.35, lab_s, ha="center", va="bottom", fontsize=6 if is_gm else 5.5,
                    color="red" if sp < 1 else "black", fontweight="bold" if sp < 1 or is_gm else "normal")
        if r == 0:
            ax.set_title(title, fontsize=7, fontweight="bold" if is_gm else "normal", pad=3)
        ax.set_xticks([])
        ax.set_xlim(-0.6, 0.6)
        ax.set_yscale("log")
        ax.set_ylim(lo, hi)
        ax.yaxis.set_major_locator(LogLocator(base=10))
        ax.yaxis.set_major_formatter(FuncFormatter(fmt))
        ax.yaxis.set_minor_formatter(NullFormatter())
        if is_gm:
            ax.set_ylabel("Runtime (s)", fontsize=6, fontweight="bold")
            ax.yaxis.set_label_coords(-0.62, 0.5)  # one column for every row, whatever its tick labels' width
            ax.tick_params(axis="y", labelsize=6, pad=1)
        else:
            ax.set_yticklabels([])
            ax.tick_params(axis="y", length=2)
        ax.grid(axis="y", which="major", linestyle=":", linewidth=0.4)
    b = axes[r, -1].get_position()
    fig.text(0.975, (b.y0 + b.y1) / 2, lab, rotation=90, va="center", ha="left", fontsize=8, fontweight="bold")
from matplotlib.legend_handler import HandlerTuple  # noqa: E402
frame = lambda: Patch(facecolor="none", edgecolor="black", linewidth=EDGE_LW)
# a legend key with a hatch in one colour and a frame in another is two patches drawn over each other
fig.legend([Patch(facecolor=CPU_GM, edgecolor="black", linewidth=EDGE_LW), Patch(facecolor=GPU_GM, edgecolor="black", linewidth=EDGE_LW),
            (Patch(facecolor=CPU_DS[0], edgecolor=CPU_DS[2], hatch=CPU_DS[1], linewidth=0), frame()),
            (Patch(facecolor=GPU_DS[0], edgecolor=GPU_DS[2], hatch=GPU_DS[1], linewidth=0), frame())],
           ["CPU (GM)", "GPU (GM)", "CPU (per graph)", "GPU (per graph)"], loc="upper center", ncol=4, frameon=False,
           fontsize=7, bbox_to_anchor=(0.5, 0.985), handlelength=1.6, columnspacing=1.6,
           handler_map={tuple: HandlerTuple(ndivide=1, pad=0)})
os.makedirs(os.path.dirname(OUT), exist_ok=True)
save_cropped(fig, OUT, top=71, bottom=61, bbox_inches="tight")  # the white bands above and below (figsave.py)
print("->", os.path.abspath(OUT))
for lab, cpu, gpu, _ in data:
    s = cpu / gpu
    s = s[np.isfinite(s)]
    print(f"{lab:10} speedup CPU/GPU: GM {np.exp(np.log(s).mean()):.2f}  range {s.min():.2f}-{s.max():.2f}" if len(s) else lab)
