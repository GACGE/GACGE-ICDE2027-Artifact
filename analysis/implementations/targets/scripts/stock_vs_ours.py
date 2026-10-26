"""Gunrock's own implementations against the paper's GPU implementations on the RTX PRO 6000:
per primitive and graph, the mean runtime of the stock legs of measure/gunrock-stock
(Gunrock essentials 530f254, src/gunrock-stock: BFS and SSSP with the original block_mapped
advance, 11 runs with the first dropped; PageRank, 20 iterations; TC, one run) and of
the paper's timing leg Gunrock of measure/<algo>-gpu (GAP's algorithms on Gunrock,
src/gunrock), and the stock time over ours (> 1: ours is faster). TC: the stock example's
per-vertex counts sum to three times the triangles. A run that fails is listed as crashed.
Geometric means over the eight graphs. Writes outputs/stock_vs_ours{,_summary}.{csv,md,tex}."""
import json
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../common"))
from units import *  # noqa: E402,F403

MEASURE = os.path.join(ANALYSIS, "..", "measure")
# the paper's eight graphs (|V| ascending) on the RTX PRO 6000 (2026-10-21); the earlier set
# (Hollywood, Patent, LiveJournal for the three small graphs) is in git history with the L4 runs
DATASETS = ["Amazon", "HiggsNets", "Youtube", "Kron21", "Orkut", "UK2002", "Arabic", "Sinaweibo"]
NAME = {"Livejournal": "LiveJournal", "UK2002": "UK-2002"}
# (primitive, our unit, [(stock variant label, stock leg)])
ROWS = [("BFS", "bfs", [("Gunrock BFS, block_mapped", "BFS-Gunrock")]),
        ("SSSP", "sssp", [("Gunrock SSSP, block_mapped", "SSSP-Gunrock")]),
        ("PageRank", "pr", [("Gunrock PR (push), 20 iterations", "PR")]),
        ("TC", "tc", [("Gunrock TC, block_mapped", "TC")])]


def means(path):
    """dataset -> mean runtime (s) of an ok run, or None for a run that failed (crashed)"""
    if not os.path.isfile(path):
        return {}
    out = {}
    for ds, d in json.load(open(path))["datasets"].items():
        r = d.get("runs", {}).get("timing")
        if r and r.get("status") == "ok" and r["samples"].get("runtime_s"):
            v = r["samples"]["runtime_s"]
            out[ds] = sum(v) / len(v)
        elif r:
            out[ds] = None
    return out


def stock(legs):
    """a variant's runtimes over its legs (DAWN SSSP: the two largest graphs in a leg of their own)"""
    out = {}
    for leg in legs.split("+"):
        out.update(means(os.path.join(MEASURE, "gunrock-stock", "outputs", GPU_MACHINE, "json", "timing",
                                      f"{leg}.json")))
    return out


gm = lambda v: math.exp(sum(math.log(x) for x in v) / len(v)) if v else float("nan")
rows, summ = [], []
for prim, unit, variants in ROWS:
    ours = means(os.path.join(MEASURE, f"{unit}-gpu", "outputs", GPU_MACHINE, "json", "timing", "Gunrock.json"))
    for label, leg in variants:
        st = stock(leg)
        ratios = []
        for ds in DATASETS:
            o, s = ours.get(ds), st.get(ds)
            r = s / o if o and s else float("nan")
            if r == r:
                ratios.append(r)
            rows.append([prim, label, NAME.get(ds, ds), 1e3 * o if o else float("nan"),
                         "crashed" if ds in st and s is None else (1e3 * s if s else float("nan")), r])
        summ.append([prim, label, len(ratios), gm(ratios), min(ratios) if ratios else float("nan"),
                     max(ratios) if ratios else float("nan"),
                     ", ".join(NAME.get(ds, ds) for ds in DATASETS if ds in st and st[ds] is None) or "-"])
write_table("implementations", "stock_vs_ours", f"Gunrock's stock implementations vs ours ({GPU_MACHINE}): runtime (ms) and stock / "
            "ours", ["Primitive", "Stock variant", "Dataset", "Ours (ms)", "Stock (ms)", "Stock / ours"], rows)
write_table("implementations", "stock_vs_ours_summary", "Stock / ours, geometric mean and range over the graphs",
            ["Primitive", "Stock variant", "Graphs", "GM stock / ours", "Min", "Max", "Crashed on"], summ)
for r in summ:
    print(f"{r[0]:9s} {r[1]:34s} n={r[2]}  stock/ours GM {r[3]:7.2f}  [{r[4]:.2f}, {r[5]:.2f}]  crashed: {r[6]}")
