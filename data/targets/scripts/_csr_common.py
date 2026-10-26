"""Shared by the CSR -> Ligra / Gunrock converters: numpy readers and writers, and the edge weights."""
import sys
import numpy as np


def read_csr(row_file, col_file):
    row = np.loadtxt(row_file, dtype=np.int64)
    col = np.loadtxt(col_file, dtype=np.int64)
    return row, col


def write_ints(out, arr, chunk=5_000_000):
    """One integer per line; chunked str.join is several times faster than np.savetxt."""
    for i in range(0, len(arr), chunk):
        out.write("\n".join(map(str, arr[i:i + chunk].tolist())))
        out.write("\n")


WEIGHT_MAX = 64
WEIGHT_SEED = 1


def edge_weights(u, v, wmax=WEIGHT_MAX, seed=WEIGHT_SEED):
    """Random integer weights in [1, wmax] for the undirected edges (u, v), 0-based CSR ids:
    splitmix64 of (min(u, v), max(u, v)) and the seed, so both directions of an edge and the
    Gunrock and Ligra files carry the same weight, and every machine generates the same graph."""
    with np.errstate(over="ignore"):
        u, v = np.asarray(u, dtype=np.uint64), np.asarray(v, dtype=np.uint64)
        z = (np.minimum(u, v) << np.uint64(32)) | np.maximum(u, v)
        z = z + np.uint64(seed) * np.uint64(0x9E3779B97F4A7C15)
        z = (z ^ (z >> np.uint64(30))) * np.uint64(0xBF58476D1CE4E5B9)
        z = (z ^ (z >> np.uint64(27))) * np.uint64(0x94D049BB133111EB)
        z = z ^ (z >> np.uint64(31))
    return (z % np.uint64(wmax)).astype(np.int64) + 1
