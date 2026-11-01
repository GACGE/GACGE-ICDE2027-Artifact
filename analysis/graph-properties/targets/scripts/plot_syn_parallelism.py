"""The graph-property figure (Fig. 11) in parallelism terms, two rows x five columns, double-column width: row 1 size
(SynKronS<18..25>D16, Kronecker with Graph500 parameters, edge factor 16; x = |V|), row 2 density (SynKronS20D<4..256>,
Kronecker at scale 20; x = the actual |E|/|V|). Every panel:
  bars   the GPU's active threads, resident on the GPU averaged over the run (parallelism_lib.gpu_threads: NCU-Concurrency,
         per kernel smsp__warps_active.sum / smsp__cycles_elapsed.avg x its duration, over the run's time, x 32), left
         axis, log, one range for every panel
  label  over each bar (BFS, SSSP, XB): the small-step time share, the GPU step time in steps of under a tenth of a wave
         (parallelism_lib.small_share, StepTimes); PR and TC sweep every edge in every step (0 %), not labelled
  line   the GPU speedup over the CPU (CPU time / GPU time, the timing legs), right axis, log, one range for every
         panel; dotted line at 1
  python3.12 analysis/graph-properties/targets/scripts/plot_syn_parallelism.py [out.png] -> analysis/graph-properties/outputs/
"""
import json
import os
import statistics as st
import sys

os.environ.setdefault("GPU_MACHINE", "local")
import matplotlib  # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import matplotlib.ticker  # noqa: E402
from matplotlib.lines import Line2D  # noqa: E402
from matplotlib.patches import Patch  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../../.."))
M = f"{ROOT}/measure"
GPU = os.environ["GPU_MACHINE"]
CPU = os.environ.get("CPU_MACHINE", "local")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "../../outputs/plot_syn_parallelism.png")
sys.path.insert(0, os.path.join(HERE, "../../../common"))
from graphs import graph_size  # noqa: E402
from parallelism_lib import gpu_threads, small_share  # noqa: E402
from figsave import expect_matplotlib, save_cropped  # noqa: E402
expect_matplotlib("3.11.1")  # the paper's PNG

P = [("BFS", "bfs", "GAP", "Gunrock"), ("SSSP", "sssp", "GAP", "Gunrock"), ("XB", "xb", "XB-GAP", "XB-Gunrock"),
     ("PR", "pr", "GAP", "Gunrock"), ("TC", "tc", "GAP", "Gunrock")]
FILL_COL, SMALL_COL, SP_COL = "#EF6F62", "#7F8FA6", "black"  # the GPU coral of plot_runtimes.py; slate
CPU_FAST, GPU_FAST = "#1F5FA8", "#C8352B"  # speedup labels: below 1 (CPU faster) blue, above red
MAX_THREADS = 188 * 1536  # the RTX PRO 6000: 188 SMs x 48 warps x 32
STYLE = os.environ.get("STYLE", "line")  # the paper: line  # line: speedup as a line on the right axis; label: as numbers over the bars
EDGE_LW = 0.6


def t(path, ds):
    if not os.path.exists(path):
        return None
    x = json.load(open(path))["datasets"].get(ds)
    if not x or x["status"] != "ok" or not x["runs"]["timing"]["samples"].get("runtime_s"):
        return None
    return st.mean(x["runs"]["timing"]["samples"]["runtime_s"])


def times(u, cl, gl, ds):
    c = t(f"{M}/tc-cpu/outputs/{CPU}/json/timing/GAP-N4.json", ds) if u == "tc" else None
    c = c or t(f"{M}/{u}-cpu/outputs/{CPU}/json/timing/{cl}.json", ds)
    return c, t(f"{M}/{u}-gpu/outputs/{GPU}/json/timing/{gl}.json", ds)


fmt_v = lambda v: f"{v / 1e6:.0f}M" if v >= 1e7 else f"{v / 1e6:.1f}M"
AXES = [
    ("Size", [f"SynKronS{s}D16" for s in (18, 20, 22, 24, 25)], lambda ds: fmt_v(graph_size(ds)[0]), "$|V|$"),
    ("Density", [f"SynKronS20D{k}" for k in (4, 8, 16, 32, 64, 128, 256)], lambda ds: f"{graph_size(ds)[1] / graph_size(ds)[0]:.0f}", "$|E|/|V|$"),
]
data = {}
for name, u, cl, gl in P:
    for row, (_, names, _, _) in enumerate(AXES):
        th, sp, sm = [], [], []
        for ds in names:
            c, g = times(u, cl, gl, ds)
            th.append(gpu_threads(u, ds, g)[0]); sp.append(c / g); sm.append(small_share(u, ds))
        data[u, row] = (th, sp, sm)

plt.rcParams.update({"font.size": 7, "axes.linewidth": 0.7})
fig, axs = plt.subplots(2, 5, figsize=(7.1, 3.0), gridspec_kw=dict(wspace=0.32, hspace=0.42, left=0.075, right=0.94, top=0.86, bottom=0.12))
SP_LIM, SP_TICKS = (0.35, 16), [0.5, 1, 2, 4, 8, 16]
for col, (name, u, cl, gl) in enumerate(P):
    for row, (rlab, names, lab, xq) in enumerate(AXES):
        ax = axs[row][col]
        th, sp, sm = data[u, row]
        fill = [100 * x / MAX_THREADS for x in th]
        xs = list(range(len(names))); w = 0.36
        ax.bar([x - w / 2 for x in xs], fill, w, color=FILL_COL, edgecolor="black", linewidth=EDGE_LW, zorder=3)
        ax.bar([x + w / 2 for x in xs], sm, w, color=SMALL_COL, edgecolor="black", linewidth=EDGE_LW, zorder=3)
        ax.set_ylim(0, 125 if STYLE == "label" else 100); ax.set_yticks([0, 25, 50, 75, 100])
        if STYLE == "line":
            ax2 = ax.twinx()
            ax2.plot(xs, sp, color=SP_COL, marker="o", markersize=2.6, linewidth=1.0, zorder=5)
            ax2.axhline(1, color=SP_COL, linewidth=0.8, linestyle=":", zorder=4)
            ax2.set_yscale("log"); ax2.set_ylim(*SP_LIM)
            ax2.set_yticks(SP_TICKS); ax2.set_yticklabels([f"{v:g}" for v in SP_TICKS])
            ax2.yaxis.set_minor_formatter(matplotlib.ticker.NullFormatter())
            ax2.tick_params(labelsize=6, length=2, pad=1, width=0.6)
            ax2.tick_params(axis="y", which="minor", right=False)
            if col != 4:
                ax2.tick_params(axis="y", labelright=False)
            else:
                ax2.set_ylabel("GPU speedup", fontsize=6.6, labelpad=2)
        else:  # the speedup over each pair, blue where the CPU is faster, red where the GPU is
            for x, f, s_, v in zip(xs, fill, sm, sp):
                ax.text(x, max(f, s_) + 3, f"{v:.2f}" if v < 1 else f"{v:.1f}", ha="center", va="bottom", fontsize=5.0,
                        fontweight="bold", color=CPU_FAST if v < 1 else GPU_FAST, zorder=6)
        ax.set_xticks(xs); ax.set_xticklabels([lab(ds) for ds in names], fontsize=5.6, rotation=45, ha="right", rotation_mode="anchor")
        ax.tick_params(labelsize=6, length=2, pad=1, width=0.6)
        ax.set_xlim(-0.6, len(xs) - 0.4)
        ax.grid(axis="y", color="#e3e3e3", linewidth=0.4, zorder=0)
        if col != 0:
            ax.tick_params(axis="y", labelleft=False)
        if row == 0:
            ax.set_title(name, fontsize=8, fontweight="bold", pad=3)
        if col == 0:
            ax.set_ylabel("Share (%)", fontsize=6.6, labelpad=1)
            ax.text(-0.5, 0.5, rlab, transform=ax.transAxes, rotation=90, ha="center", va="center", fontsize=8, fontweight="bold")
        if col == 4:
            ax.text(1.42 if STYLE == "line" else 1.05, -0.1, xq, transform=ax.transAxes, ha="left", va="top", fontsize=6.6)

h = [Patch(facecolor=FILL_COL, edgecolor="black", linewidth=EDGE_LW), Patch(facecolor=SMALL_COL, edgecolor="black", linewidth=EDGE_LW)]
lab_ = ["GPU resident threads (% of capacity)", "Small-step time (%)"]
if STYLE == "line":
    h += [Line2D([], [], color=SP_COL, marker="o", markersize=2.6, linewidth=1.0), Line2D([], [], color=SP_COL, linewidth=0.8, linestyle=":")]
    lab_ += ["GPU speedup over CPU (right axis)", "1$\\times$"]
else:
    h += [Line2D([], [], color=GPU_FAST, marker="$2.5$", markersize=8, linestyle="none"), Line2D([], [], color=CPU_FAST, marker="$0.7$", markersize=8, linestyle="none")]
    lab_ += ["GPU speedup over CPU: GPU faster", "CPU faster"]
fig.legend(h, lab_, loc="upper center", ncol=4, frameon=False, fontsize=6.6, handlelength=1.6, columnspacing=1.2,
           handletextpad=0.5, bbox_to_anchor=(0.5, 1.0))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
save_cropped(fig, OUT, top=23, bottom=13, bbox_inches="tight", pad_inches=0.02)  # the white bands above and below (figsave.py)
print(OUT)
for name, u, *_ in P:
    for row, (rlab, names, lab, _) in enumerate(AXES):
        th, sp, sm = data[u, row]
        print(f"{name:4} {rlab:7} " + "  ".join(f"{lab(ds)}: {100 * x / MAX_THREADS:.0f}% {s:.0f}% {v:.2f}x" for ds, x, v, s in zip(names, th, sp, sm)))
