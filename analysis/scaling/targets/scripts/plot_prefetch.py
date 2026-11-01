"""The CPU prefetch switch as a figure (replacing tab_prefetch): per primitive the runtime with the hardware prefetchers
on (GAP / XB-GAP timing) and off (NoPrefetch timing; MSR 0x1a4 = 0x2f), eight graphs.
Runtime normalized to the prefetchers on (so the "on" bars are 1): bars geometric mean of T_off / T_on, whiskers its
minimum to maximum over the graphs, label the speedup from prefetching. Bars as Fig. 5 (plot_edge_throughput.py):
thin, the pair touching, a firm black frame.
  python3.12 analysis/scaling/targets/scripts/plot_prefetch.py -> analysis/scaling/outputs/
"""
import json
import math
import os
import statistics as st
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from matplotlib.ticker import MultipleLocator

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
sys.path.insert(0, f"{ROOT}/analysis/common")
from figsave import expect_matplotlib, save_cropped  # noqa: E402
expect_matplotlib("3.11.1")  # the paper's PNG
CPU = os.environ.get("CPU_MACHINE", "local")
M = f"{ROOT}/measure"; PNG = f"{ROOT}/analysis/scaling/outputs/plot_prefetch.png"
P = [("BFS", "bfs", "GAP"), ("SSSP", "sssp", "GAP"), ("XB", "xb", "XB-GAP"), ("PR", "pr", "GAP"), ("TC", "tc", "GAP")]
GR = ["Kron21", "Orkut", "UK2002", "Arabic", "Sinaweibo", "Amazon", "HiggsNets", "Youtube"]  # all eight graphs
if os.environ.get("GRAPHS") == "large":  # the five large graphs only (the paper until 2026-10-24)
    GR = GR[:5]
gm = lambda xs: math.exp(sum(math.log(x) for x in xs) / len(xs))


def t(u, leg, ds):
    x = json.load(open(f"{M}/{u}-cpu/outputs/{CPU}/json/timing/{leg}.json"))["datasets"][ds]
    return st.mean(x["runs"]["timing"]["samples"]["runtime_s"])


sp = {}
for name, u, cl in P:
    sp[name] = [t(u, "NoPrefetch", g) / t(u, cl, g) for g in GR]

ON, OFF = "#4B3F7A", "#17A3A3"  # the user's purple and teal


def hbar(ax, x, h, width, fill):
    ax.bar(x, h, width=width, color=fill, linewidth=0, zorder=2)
    ax.bar(x, h, width=width, color="none", edgecolor="black", linewidth=1.0, zorder=2.5)


plt.rcParams.update({"font.size": 7, "axes.linewidth": 0.8})
fig, ax = plt.subplots(figsize=(3.5, 1.6))
for i, (name, *_) in enumerate(P):
    v = sp[name]; g = gm(v)
    hbar(ax, i - 0.08, 1.0, 0.16, ON)
    hbar(ax, i + 0.08, g, 0.16, OFF)
    ax.errorbar(i + 0.08, g, yerr=[[g - min(v)], [max(v) - g]], fmt="none", ecolor="black", elinewidth=0.7, capsize=2.2,
                capthick=0.7, zorder=4)  # the min-max whisker
    ax.text(i + 0.22, g, f"{g:.2f}$\\times$", ha="left", va="center", fontsize=6.4, fontweight="bold", zorder=5)  # the GM speedup beside its bar's top, clear of the whisker
ax.set_ylim(0, 4.4)
ax.yaxis.set_major_locator(MultipleLocator(1))
ax.set_xticks(range(len(P)), [n for n, *_ in P])
ax.set_xlim(-0.5, len(P) - 0.28)  # room right of TC for its label
ax.set_ylabel("Normalized runtime", fontsize=7, fontweight="bold")
ax.grid(axis="y", which="major", linestyle=":", linewidth=0.4, zorder=0)
ax.legend([Patch(facecolor=ON, edgecolor="black", linewidth=1.0), Patch(facecolor=OFF, edgecolor="black", linewidth=1.0)],
          ["Prefetch on", "Prefetch off"], frameon=False, fontsize=6, loc="upper left", ncol=2, handlelength=1.4,
          borderaxespad=0.2, columnspacing=1.0)
fig.tight_layout(pad=0.3)
os.makedirs(os.path.dirname(PNG), exist_ok=True)
save_cropped(fig, PNG, top=5, bottom=20)  # the white bands above and below (figsave.py)
print(PNG)
for name, *_ in P:
    print(f"{name:4} T_off/T_on GM {gm(sp[name]):.2f} [{min(sp[name]):.2f}-{max(sp[name]):.2f}]")
