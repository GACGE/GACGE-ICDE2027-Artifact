"""Sec. VI-B's parallelism figure, two panels, GM over the eight graphs:
  (a) active threads: per primitive the CPU's 96 hardware threads and the GPU's active threads (log scale, the pair
      touching), the GPU-to-CPU ratio written over them
  (b) small-step time: the share of the GPU's step time in steps of under a tenth of a wave (mean), a 100 % stack with
      the rest of the steps
The measures are analysis/common/parallelism_lib.py's; the speedup is CPU over GPU runtime of the timing legs.
Writes analysis/parallelism/outputs/plot_parallelism.png (also printed: the numbers behind it)."""
import math
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Patch  # noqa: E402
from matplotlib.ticker import FuncFormatter, LogLocator, NullFormatter  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../../../common"))
from parallelism_lib import gpu_threads, small_share, timing  # noqa: E402
from figsave import expect_matplotlib  # noqa: E402
expect_matplotlib("3.8.2")  # the paper's PNG

OUT = os.path.join(HERE, "../../outputs/plot_parallelism.png")
CPU_THREADS = 96  # every hardware thread of the 48 cores
GR = ["Youtube", "Kron21", "Orkut", "HiggsNets", "Amazon", "UK2002", "Arabic", "Sinaweibo"]
LEGS = {"bfs": ("GAP", "Gunrock"), "sssp": ("GAP", "Gunrock"), "pr": ("GAP", "Gunrock"), "tc": ("GAP", "Gunrock"),
        "xb": ("XB-GAP", "XB-Gunrock")}
gm = lambda v: math.exp(sum(map(math.log, v)) / len(v))
mean = lambda v: sum(v) / len(v)

rows = []
for name, u in [("SSSP", "sssp"), ("BFS", "bfs"), ("XB", "xb"), ("PR", "pr"), ("TC", "tc")]:
    tc, tg = timing(u, "cpu", LEGS[u][0]), timing(u, "gpu", LEGS[u][1])
    sp = gm([tc[d] / tg[d] for d in GR])
    g = gm([gpu_threads(u, d, tg[d])[0] for d in GR])
    ss = [s for s in (small_share(u, d) for d in GR) if s is not None]
    rows.append(dict(name=name, s=sp, c=CPU_THREADS, g=g, cr=g / CPU_THREADS, slow=g / CPU_THREADS / sp,
                     small=mean(ss) if ss else 0.0))

CPU_FILL, CPU_HATCH = "#7B7FD1", "\\\\\\\\\\\\"   # periwinkle, white back-diagonals
GPU_FILL, GPU_HATCH = "#E9748F", "xxxxx"       # rose, white crosses
SMALL_FILL, OTHER_FILL = "#C8553D", "#E6E6E6"  # the small steps: a solid rust, no hatch (the hatch hid the labels)
EDGE_LW = 1.0


def hbar(ax, x, h, width, fill, hatch=None, bottom=0):
    ax.bar(x, h, width=width, bottom=bottom, color=fill, edgecolor="white", hatch=hatch, linewidth=0, zorder=2)
    ax.bar(x, h, width=width, bottom=bottom, color="none", edgecolor="black", linewidth=EDGE_LW, zorder=2.5)


plt.rcParams.update({"font.size": 6.5, "axes.linewidth": 0.8, "hatch.linewidth": 0.5})
fig, (a, b) = plt.subplots(1, 2, figsize=(3.5, 1.9), gridspec_kw={"wspace": 0.45, "width_ratios": [1.15, 1.0]})
names = [r["name"] for r in rows]
x = list(range(len(rows)))

# (a) threads at work, the pair touching, the concurrency ratio over the GPU bar
for i, r in enumerate(rows):
    hbar(a, i - 0.16, r["c"], 0.32, CPU_FILL, CPU_HATCH)
    hbar(a, i + 0.16, r["g"], 0.32, GPU_FILL, GPU_HATCH)
    a.text(i + 0.12, r["g"] * 1.4, f"{r['cr']:,.0f}×", ha="center", va="bottom", fontsize=4.3, fontweight="bold")  # small, so neighbours do not collide
a.set_yscale("log")
a.set_ylim(10, 8e6)
a.yaxis.set_major_locator(LogLocator(base=10))
a.yaxis.set_major_formatter(FuncFormatter(lambda y, _: f"{y:g}" if y < 1e3 else f"{y / 1e3:g}K" if y < 1e6 else f"{y / 1e6:g}M"))
a.yaxis.set_minor_formatter(NullFormatter())
a.set_xticks(x, names)
a.set_ylabel("Thread count", fontsize=6.5, fontweight="bold", labelpad=1)
a.set_title("(a) Thread counts", fontsize=6.5, fontweight="bold", pad=3)
a.set_xlim(-0.6, len(rows) - 0.25)
a.grid(axis="y", which="major", linestyle=":", linewidth=0.4, zorder=0)
a.legend([Patch(facecolor=CPU_FILL, edgecolor="black", hatch=CPU_HATCH, linewidth=0.6),
          Patch(facecolor=GPU_FILL, edgecolor="black", hatch=GPU_HATCH, linewidth=0.6)], ["CPU workers", "GPU resident threads"],
         loc="upper left", frameon=False, fontsize=5.8, handlelength=1.4, borderaxespad=0.15, labelspacing=0.3)

# (b) small-step share of the GPU's step time
for i, r in enumerate(rows):
    s = r["small"]
    hbar(b, i, s, 0.56, SMALL_FILL, None)  # wide enough to hold the share written inside
    hbar(b, i, 100 - s, 0.56, OTHER_FILL, None, bottom=s)
    # the share written inside its segment: white on the rust, black on the grey when there is none
    if s >= 12:
        b.text(i, s / 2, f"{s:.0f}%", ha="center", va="center", fontsize=4.0, fontweight="bold", color="white")  # inside the bar, clear of its frame
    else:
        b.text(i, 6, f"{s:.0f}%", ha="center", va="center", fontsize=4.0, fontweight="bold", color="black")
b.set_ylim(0, 132)  # the band above 100 holds the legend
b.set_xlim(-0.6, len(rows) - 0.3)
b.set_yticks(range(0, 101, 20))
b.set_xticks(x, names)
b.set_ylabel("Share of GPU step time (%)", fontsize=6.5, fontweight="bold", labelpad=1)
b.grid(axis="y", which="major", linestyle=":", linewidth=0.4, zorder=0)
b.legend([Patch(facecolor=SMALL_FILL, edgecolor="black", linewidth=0.6),
          Patch(facecolor=OTHER_FILL, edgecolor="black", linewidth=0.6)], ["Steps < 0.1 wave", "Other steps"],
         loc="upper center", ncol=1, frameon=False, fontsize=5.4, handlelength=1.4,
         borderaxespad=0.1, labelspacing=0.2)  # in the band above 100 %: the bars fill the rest
b.set_title("(b) Small-step time share", fontsize=6.5, fontweight="bold", pad=3)
for ax in (a, b):
    ax.tick_params(labelsize=6, pad=1.5, length=2.5)
fig.subplots_adjust(left=0.13, right=0.985, top=0.9, bottom=0.13)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
fig.savefig(OUT, dpi=600, bbox_inches="tight", pad_inches=0.02)
print("->", os.path.abspath(OUT))
for r in rows:
    print(f"  {r['name']:5} speedup {r['s']:.2f}  GPU threads {r['g']:,.0f}  GPU/CPU {r['cr']:.0f}x  small steps {r['small']:.1f}%")
