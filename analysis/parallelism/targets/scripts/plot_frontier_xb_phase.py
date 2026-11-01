"""Fig. 5: the searches in the middle of an XB-GAP run on the CPU, read off the
frontier trace: UK-2002's frontier vertices per step (measure/xb-cpu's Frontier
trace leg, one run, 96 threads) on linear axes, a window of 12 steps from the
middle of the run (the sawtooth of Fig. 4), one search's steps (287-291 in the 48-thread trace; found by its phases in a rerun) circled and named
after the operation each runs (src/gap/gapbs xblossom.cc SearchPhase): augment
and expand over the roots and retained even vertices (the same frontier),
blossom over the new even vertices (fewer), augment over the vertices the
blossoms made even (few; paths found: the search ends), and the next search's
augment over the roots and retained even vertices again. No title: the caption
names the graph and the steps. Writes outputs/frontier_xb_phase.png."""
import os
import re
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../common"))
from units import ANALYSIS, CPU_MACHINE  # noqa: E402
from figsave import expect_matplotlib  # noqa: E402
expect_matplotlib("3.8.2")  # the paper's PNG

DATASET = "UK2002"
RAW = os.path.join(ANALYSIS, "..", "measure", "xb-cpu", "outputs", CPU_MACHINE, "raw", "trace", "Frontier",
                   f"{DATASET}.trace.log")
OUT = os.path.join(ANALYSIS, "parallelism", "outputs", "frontier_xb_phase.png")
STEP = re.compile(r"^XBStep: run=0 step=(\d+) phase=(\S+) mode=\w+ frontier_v=(\d+) frontier_e=\d+")
BLUE, RED, INK, MUTED, GRID = "#2a78d6", "#1f1f1e", "#1f1f1e", "#6b6a63", "#e6e4dc"  # RED: the marks, now ink
# step -> (label, text position in data coordinates); arrows lead from the text to the point
# labels in ink, not red; the search's first three steps named above the curve, blossom handling and the
# augmentation that finds the paths below it (the axes extend below zero to hold them)
MARK = {287: ("Augment", (285.2, 13.6)), 288: ("Expand", (288.4, 15.9)), 289: ("Blossom", (286.9, -2.4)),
        290: ("Augment\n(paths found)", (290.6, -2.2)), 291: ("Augment\n(search restart)", (292.1, 15.6))}
FIRST, STEPS = 285, 296  # the window, steps FIRST..STEPS (1-based): three searches

steps = {}  # step (1-based) -> (phase, frontier vertices in millions)
for ln in open(RAW):
    m = STEP.match(ln)
    if m:
        steps[int(m.group(1)) + 1] = (m.group(2), int(m.group(3)) / 1e6)
# the step numbers above are those of the 48-thread trace; a rerun's races can shift the searches by a step or two,
# so the window follows the search (augment, expand, blossom, augment, augment) that starts nearest step 287
SEARCH = ("augment", "expand", "blossom", "augment", "augment")
first = min((s for s in steps if tuple(steps.get(s + i, ("",))[0] for i in range(5)) == SEARCH),
            key=lambda s: abs(s - 287))
shift = first - 287
MARK = {s + shift: (label, (x + shift, y)) for s, (label, (x, y)) in MARK.items()}
FIRST, STEPS = FIRST + shift, STEPS + shift
xs = [s for s in sorted(steps) if FIRST <= s <= STEPS]
ys = [steps[s][1] for s in xs]

# drawn at the printed size (0.72 columnwidth, about 2.5 in) and 600 dpi, a little larger than one of Fig. 6's panels
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 6.5, "axes.edgecolor": "black", "axes.linewidth": 0.8,
                     "xtick.color": "black", "ytick.color": "black", "axes.labelcolor": INK})  # a black box, as Fig. 6
fig, ax = plt.subplots(figsize=(2.6, 1.95))
ax.plot(xs, ys, color=BLUE, lw=1.1, marker="o", ms=2.2, zorder=2)
for s, (label, pos) in MARK.items():
    y = ys[xs.index(s)]
    ax.plot([s], [y], marker="o", ms=6.5, mfc="none", mec=RED, mew=0.9, zorder=3)
    ax.annotate(label, (s, y), xytext=pos, fontsize=5.8, color=RED, fontweight="bold", ha="left", va="center",
                arrowprops=dict(arrowstyle="-", color=RED, lw=0.6, shrinkA=1.5, shrinkB=4))
ax.set_xlim(FIRST - 1.0, STEPS + 1.0)  # air on both sides: the curve sits in the middle
ax.set_ylim(-4.2, 17.5)  # room under the curve for two labels; the zero line is not the frame
ax.set_xticks(range(FIRST, STEPS + 1, 2))
ax.tick_params(labelsize=6, pad=1.5, length=2.5)
ax.set_yticks(range(0, 17, 4))
ax.set_xlabel("Step", fontsize=6.5, labelpad=1, fontweight="bold")
ax.set_ylabel("Frontier size (M)", fontsize=6.5, labelpad=1, fontweight="bold")
# the window is a cut from the middle of the run: break marks and ellipses at both ends of the step axis
for x0 in (0.0, 1.0):
    for d in (-0.012, 0.012):
        ax.plot([x0 + d - 0.008, x0 + d + 0.008], [-0.03, 0.03], transform=ax.transAxes, color="black", lw=0.8,
                clip_on=False, zorder=5)
    ax.text(x0 + (0.035 if x0 == 0 else -0.035), -0.08, "\u22ef", transform=ax.transAxes, ha="center", va="top", fontsize=7)
fig.tight_layout(pad=0.3)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
fig.savefig(OUT, dpi=600)
print("->", os.path.normpath(OUT))
