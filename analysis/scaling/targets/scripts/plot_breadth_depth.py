"""The scaling figure for the paper (Fig. 9): CPU and GPU in one panel per primitive, on a shared step axis.
Positions 0-3 = breadth (CPU 6/12/24/48 threads, one a core; GPU 8/24/64/188 SMs, one block each),
4 = two per core / SM (CPU 96 threads; GPU 376 blocks), 5-6 = GPU 4 and 11 blocks per SM.
y = speedup over the CPU at 6 threads (GM over the eight graphs, band min-max); each point labelled with it.
  CPU: measure/<algo>-cpu Threads timing leg; GPU: measure/<algo>-gpu Breadth-Depth timing leg (green-context SMs,
  capped grid). Writes analysis/scaling/outputs/plot_breadth_depth_merged.png (python3 plot_breadth_depth.py [out.png])."""
import math, os, sys
from collections import defaultdict
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../common"))
from units import leg_runs, mean_ms  # noqa: E402
from figsave import expect_matplotlib, save_cropped  # noqa: E402
expect_matplotlib("3.11.1")  # the paper's PNG
OUTDIR = f"{ROOT}/analysis/scaling/outputs"
GR = ["Kron21", "Orkut", "UK2002", "Arabic", "Sinaweibo", "Amazon", "HiggsNets", "Youtube"]  # all eight graphs
if os.environ.get("GRAPHS") == "large":  # the five large graphs only (the paper until 2026-10-24)
    GR = GR[:5]
BLUE, RED = "#1f5fa8", "#D9412F"  # CPU blue; GPU a deep coral (darker than plot_runtimes GPU_GM, 2026-10-25)
gm = lambda v: math.exp(sum(map(math.log, v)) / len(v))
UNITS = ["bfs", "sssp", "xb", "pr", "tc"]
FIG = sys.argv[1] if len(sys.argv) > 1 else f"{OUTDIR}/plot_breadth_depth_merged.png"
NAME = {"bfs": "BFS", "sssp": "SSSP", "xb": "XB", "pr": "PR", "tc": "TC"}

cpu = defaultdict(dict)
for u in NAME:
    for g, runs in leg_runs(f"{u}-cpu", "timing", "Threads").items():
        for t in (6, 12, 24, 48, 96):
            if f"t{t}" in runs:
                cpu[u, g][t] = mean_ms(runs[f"t{t}"])
gpu = defaultdict(dict)
for u in NAME:
    for g, runs in leg_runs(f"{u}-gpu", "timing", "Breadth-Depth").items():
        for sms, k in ((8, 1), (24, 1), (64, 1), (188, 1), (188, 2), (188, 4), (188, 11)):
            if f"s{sms}k{k}" in runs:
                gpu[u, g][sms * k] = mean_ms(runs[f"s{sms}k{k}"])

TICK_FS = 5.1  # both rows of tick labels (5.4 bold makes 752 and 2068 touch)
CPU_X = [6, 12, 24, 48, 96]
GPU_X = [8, 24, 64, 188, 376, 752, 2068]


def series(data, u, xs):
    g, lo, hi = [], [], []
    for x in xs:
        v = [cpu[u, gr][6] / data[u, gr][x] for gr in GR]
        g.append(gm(v)); lo.append(min(v)); hi.append(max(v))
    return g, lo, hi


plt.rcParams.update({"font.size": 7, "axes.linewidth": 0.8})
n = len(UNITS)
fig, axes = plt.subplots(1, n, figsize=(1.6 * n + 0.85, 2.15), squeeze=False, gridspec_kw={"wspace": 0.12})
for ax, u in zip(axes[0], UNITS):
    vals = {}
    for data, col, xs, pos, nb in ((cpu, BLUE, CPU_X, [0, 1, 2, 3, 4], 4), (gpu, RED, GPU_X, [0, 1, 2, 3, 4, 5, 6], 4)):
        g, lo, hi = series(data, u, xs)
        ax.fill_between(pos, lo, hi, color=col, alpha=0.12, linewidth=0, zorder=1)
        ax.plot(pos[:nb], g[:nb], color=col, marker="o", markersize=3.2, linewidth=1.1, zorder=3)
        ax.plot(pos[nb - 1:], g[nb - 1:], color=col, linewidth=1.0, linestyle=(0, (4, 2.5)), zorder=2)
        ax.plot(pos[nb:], g[nb:], color=col, marker="^", markersize=3.8, markerfacecolor="white", markeredgewidth=0.9, linestyle="none", zorder=3)
        vals[col] = dict(zip(pos, g))
    # each point's speedup: at a position, the higher curve's value above its point, the lower one's below
    for col, other in ((BLUE, RED), (RED, BLUE)):
        for x, y in vals[col].items():
            above = x not in vals[other] or y >= vals[other][x]
            lab = f"{y:.0f}" if y >= 10 else f"{y:.1f}" if y >= 0.95 else f"{y:.2f}"
            ax.annotate(lab, (x, y), xytext=(0, 4.5 if above else -6.5), textcoords="offset points", ha="center",
                        va="bottom" if above else "top", fontsize=5.0, color=col, zorder=5)
    ax.axvline(3, color="black", linewidth=0.5, linestyle="--", zorder=0)
    ax.axhline(1, color="#777777", linewidth=0.5, linestyle=":", zorder=0)
    ax.set_yscale("log", base=2)
    ax.set_ylim(0.15, 140); ax.set_yticks([0.25, 1, 4, 16, 64]); ax.set_yticklabels(["0.25", "1", "4", "16", "64"])
    ax.tick_params(axis="y", which="minor", left=False)
    ax.set_xlim(-0.4, 6.4); ax.set_xticks(range(7)); ax.set_xticklabels([""] * 7)
    ax.tick_params(labelsize=6, length=2.5, pad=1.5)
    ax.grid(axis="y", color="#dddddd", linewidth=0.5)
    ax.set_title(NAME[u], fontsize=7, fontweight="bold", pad=3)
    for i in range(7):  # two-line tick labels, one size: GPU resident blocks above, CPU threads below
        ax.text(i, -0.04, str(GPU_X[i]), transform=ax.get_xaxis_transform(), ha="center", va="top", fontsize=TICK_FS, color=RED, fontweight="bold")
        if i < 5:
            ax.text(i, -0.13, str(CPU_X[i]), transform=ax.get_xaxis_transform(), ha="center", va="top", fontsize=TICK_FS, color=BLUE, fontweight="bold")
    if ax is not axes[0][0]:
        ax.tick_params(axis="y", labelleft=False)
axes[0][0].set_ylabel("Speedup over\nCPU at 6 threads", fontsize=6.4, fontweight="bold", labelpad=1)
axes[0][0].text(-0.02, -0.04, "GPU blocks", transform=axes[0][0].transAxes, ha="right", va="top", fontsize=TICK_FS, color=RED, fontweight="bold")
axes[0][0].text(-0.02, -0.13, "CPU threads", transform=axes[0][0].transAxes, ha="right", va="top", fontsize=TICK_FS, color=BLUE, fontweight="bold")
h = [Line2D([], [], color=BLUE, marker="o", markersize=3.2, linewidth=1.1), Line2D([], [], color=BLUE, marker="^", markersize=3.8, markerfacecolor="white", linestyle=(0, (4, 2.5)), linewidth=1.0),
     Line2D([], [], color=RED, marker="o", markersize=3.2, linewidth=1.1), Line2D([], [], color=RED, marker="^", markersize=3.8, markerfacecolor="white", linestyle=(0, (4, 2.5)), linewidth=1.0),
     Line2D([], [], color="black", linestyle="--", linewidth=0.5)]
axes[0][-1].legend(h, ["CPU breadth", "CPU depth", "GPU breadth", "GPU depth", "breadth | depth"], loc="center left", bbox_to_anchor=(1.03, 0.5),
                   fontsize=5.8, frameon=False, handlelength=1.8, labelspacing=0.35)
os.makedirs(os.path.dirname(FIG), exist_ok=True)
save_cropped(fig, FIG, top=9, bottom=18, bbox_inches="tight", pad_inches=0.03)  # the white bands above and below (figsave.py)
print(FIG)
