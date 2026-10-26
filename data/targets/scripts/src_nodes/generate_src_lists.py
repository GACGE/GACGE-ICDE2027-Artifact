#!/usr/bin/env python3
"""CSR -> the largest connected component's size distribution (<base>_analysis.txt)
and a sorted random sample of source nodes from the LCC (<base>_src_nodes.txt).
scipy's connected_components when available, a numpy BFS otherwise.

  generate_src_lists.py --row <rowOffsets> --col <colIndices> --base-out <dir/Name> --num-samples N [--seed S]"""
import argparse
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from _csr_common import read_csr  # noqa: E402


def components(n, row, col):
    try:
        import scipy.sparse as sp
        import scipy.sparse.csgraph as csg
        g = sp.csr_matrix((np.ones(len(col), dtype=np.int8), col, row), shape=(n, n))
        _, labels = csg.connected_components(g, directed=False)
        return labels
    except ImportError:
        labels = np.full(n, -1, dtype=np.int64)
        nxt = 0
        for s in range(n):
            if labels[s] >= 0:
                continue
            labels[s] = nxt
            frontier = np.array([s])
            while len(frontier):
                nb = np.concatenate([col[row[v]:row[v + 1]] for v in frontier]) if len(frontier) else np.array([])
                nb = np.unique(nb[labels[nb] < 0])
                labels[nb] = nxt
                frontier = nb
            nxt += 1
        return labels


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--row", required=True)
    ap.add_argument("--col", required=True)
    ap.add_argument("--base-out", required=True)
    ap.add_argument("--num-samples", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=None, help="seed the sample (synthetic graphs: the same list on every machine)")
    a = ap.parse_args()
    if a.seed is not None:
        random.seed(a.seed)
    row, col = read_csr(a.row, a.col)
    n, m = len(row) - 1, len(col)
    labels = components(n, row, col)
    sizes = np.bincount(labels)
    lcc = int(sizes.argmax())
    lcc_nodes = np.nonzero(labels == lcc)[0]
    k = min(a.num_samples, len(lcc_nodes))
    sample = sorted(random.sample(list(lcc_nodes.tolist()), k))
    name = os.path.basename(a.base_out)
    os.makedirs(os.path.dirname(a.base_out) or ".", exist_ok=True)
    counts = {}
    for s in sizes:
        counts[int(s)] = counts.get(int(s), 0) + 1
    with open(a.base_out + "_analysis.txt", "w") as out:
        out.write("--- Graph Connectivity Analysis ---\n")
        out.write(f"Source Row File: {a.row}\nSource Col File: {a.col}\n")
        out.write(f"Total Vertices (N): {n}\nTotal Edges (M): {m}\n")
        out.write(f"Total Connected Components: {len(sizes)}\nLCC Size: {len(lcc_nodes)}\n")
        out.write("--- Component Size Distribution (Size, Count) ---\n")
        for s, c in sorted(counts.items(), reverse=True):
            out.write(f"{s}, {c}\n")
    with open(a.base_out + "_src_nodes.txt", "w") as out:
        out.write(f"# {k} Random Source Nodes (0-indexed) from LCC of {name}\n")
        out.write(f"# Requested Source Nodes: {a.num_samples}\n# LCC Size: {len(lcc_nodes)}\n")
        for v in sample:
            out.write(f"{v}\n")
    print(f"{name}: n={n:,} m={m:,} components={len(sizes):,} lcc={len(lcc_nodes):,} sampled={k}", flush=True)


if __name__ == "__main__":
    main()
