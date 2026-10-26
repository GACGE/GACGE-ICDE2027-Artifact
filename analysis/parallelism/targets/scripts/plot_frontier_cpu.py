"""Fig. 4: frontier vertices of every step on the CPU (GAP, 96 threads) for
XB-GAP, BFS and SSSP, one panel per graph of the paper's eight, from the trace
leg Frontier of measure/{xb,bfs,sssp}-cpu (one run each, no warm-up; XBStep
lines from src/gap/gapbs/src/gacge.h; BFS: top-down push and bottom-up pull
steps, SSSP: delta-stepping bin iterations without stale entries, XB-GAP:
augment / expand / blossom steps).
PageRank and TC are drawn from their definition, not from a run: every vertex
is in the frontier of each of PageRank's 20 iterations and of TC's single step.
Both axes are logarithmic. Writes outputs/frontier_cpu.png (needs matplotlib); with
--slide, outputs/frontier_cpu_slide.png for the deck (no title, larger text,
one legend row on top)."""
import os
import re
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../common"))
from units import ANALYSIS, CPU_MACHINE  # noqa: E402

MEASURE = os.path.join(ANALYSIS, "..", "measure")
SLIDE = "--slide" in sys.argv
OUT = os.path.join(ANALYSIS, "parallelism", "outputs", "frontier_cpu_slide.png" if SLIDE else "frontier_cpu.png")
# the paper's eight graphs, by node count ascending (Table II)
DATASETS = ["Amazon", "HiggsNets", "Youtube", "Kron21", "Orkut", "UK2002", "Arabic", "Sinaweibo"]
NAME = {"Livejournal": "LiveJournal", "UK2002": "UK-2002"}
PR_ITERS = 20
# fixed categorical order (dataviz reference palette); XB-GAP first, in the deck's blue
SERIES = [("xb", "XB", "#2a78d6"), ("bfs", "BFS", "#eb6834"), ("sssp", "SSSP", "#1baf7a"),
          ("pr", "PR", "#eda100"), ("tc", "TC", "#8a5cc7")]  # abbreviations in the figures (2026-10-20)
# thin lines and small markers: the tails of XB and SSSP run hundreds of steps and would merge otherwise
# drawn at the printed size (\textwidth, 7 in) and 600 dpi, as the runtime figure, so it prints as crisp
STYLE = {"bfs": dict(lw=0.7, ls="-", marker="o", ms=1.8, filled=True, z=4),
         "sssp": dict(lw=0.7, ls="--", marker="s", ms=2.4, filled=False, z=3),
         "xb": dict(lw=0.7, ls="-", marker="o", ms=1.2, filled=True, z=5),
         "pr": dict(lw=0.8, ls=":", marker="^", ms=2.4, filled=False, z=2),
         "tc": dict(lw=0, ls="none", marker="D", ms=4.0, filled=False, z=6)}
STEP = re.compile(r"^XBStep: run=0 step=(\d+) phase=\S+ mode=\w+ frontier_v=(\d+) frontier_e=\d+")
TRAV = re.compile(r"^XBTraversal: run=0 .* nodes=(\d+)")
INK, MUTED, GRID = "#1f1f1e", "#6b6a63", "#e6e4dc"


def series(ds, tag):
    xs, ys, nodes = [], [], None
    raw = os.path.join(MEASURE, f"{tag}-cpu", "outputs", CPU_MACHINE, "raw", "trace", "Frontier", f"{ds}.trace.log")
    for ln in open(raw):
        m = STEP.match(ln)
        if m:
            xs.append(int(m.group(1)) + 1)
            ys.append(max(int(m.group(2)), 1))
        t = TRAV.match(ln)
        if t:
            nodes = int(t.group(1))
    return xs, ys, nodes


# black, 1 pt axes with a full box, as the runtime figure
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 12 if SLIDE else 6.5, "axes.edgecolor": "black",
                     "axes.linewidth": 1.0, "axes.labelcolor": INK, "xtick.color": "black", "ytick.color": "black"})
fig, axes = plt.subplots(2, 4, figsize=(14, 7.4) if SLIDE else (7.0, 3.3), sharey=True)
for ax, ds in zip(axes.flat, DATASETS):
    data, nodes = {}, None
    for tag in ("xb", "bfs", "sssp"):
        xs, ys, n = series(ds, tag)
        data[tag] = (xs, ys)
        nodes = nodes or n
    data["pr"] = (list(range(1, PR_ITERS + 1)), [nodes] * PR_ITERS)  # every vertex, every iteration
    data["tc"] = ([1], [nodes])                                       # every vertex, one step
    # PageRank below, then SSSP (dashed, large hollow squares) under BFS (small filled dots): their
    # first steps coincide (same source), and both stay visible there; XB-GAP, then TC's point on top
    for tag in ("pr", "sssp", "bfs", "xb", "tc"):
        label, color = next((l, c) for t, l, c in SERIES if t == tag)
        xs, ys = data[tag]
        style = STYLE[tag]
        ax.plot(xs, ys, color=color, lw=style["lw"], ls=style["ls"], marker=style["marker"], ms=style["ms"],
                mfc=color if style["filled"] else "white", mec=color, mew=1.4 if tag == "tc" else 1.0,
                label=label, zorder=style["z"])
    ax.set_xscale("log")  # tried linear on 2026-10-21: BFS's few steps vanished at the left; log it stays
    ax.set_yscale("log")
    ax.set_ylim(top=nodes * 2.2)  # PR and TC (every vertex) sit just under the top edge
    ax.set_title(NAME.get(ds, ds), fontsize=15 if SLIDE else 7, color=INK, fontweight="bold", pad=3)
    if SLIDE:  # the step counts, deck only (the paper's figure dropped them 2026-10-21)
        ax.text(0.0, 1.0, " · ".join(f"{l} {len(data[t][0])}" for t, l, _ in SERIES), transform=ax.transAxes,
                fontsize=10, color=MUTED, va="bottom", ha="left")
    ax.grid(True, which="major", color=GRID, lw=0.5)
    ax.tick_params(labelsize=6, pad=1.5)
for ax in axes[-1, :]:
    ax.set_xlabel("Step (log)", fontweight="bold")
for ax in axes[:, 0]:
    ax.set_ylabel("Frontier size (log)", fontweight="bold")
handles, labels = axes.flat[0].get_legend_handles_labels()
order = [labels.index(l) for _, l, _ in SERIES]
if SLIDE:
    fig.legend([handles[i] for i in order], [labels[i] for i in order], loc="upper center", ncol=len(order),
               frameon=False, fontsize=11.5, bbox_to_anchor=(0.5, 1.0), handlelength=1.8, columnspacing=1.2)
else:
    fig.legend([handles[i] for i in order], [labels[i] for i in order], loc="upper center", ncol=len(order),
               frameon=False, fontsize=7, bbox_to_anchor=(0.5, 1.0), columnspacing=2.0, handlelength=2.2)
fig.tight_layout(rect=(0, 0, 1, 0.955 if SLIDE else 0.94))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
fig.savefig(OUT, dpi=160 if SLIDE else 600, **({"bbox_inches": "tight", "pad_inches": 0.05} if SLIDE else {}))
print("->", os.path.normpath(OUT))
