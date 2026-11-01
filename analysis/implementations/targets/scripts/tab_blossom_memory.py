"""XB++-Gunrock as a direct port builds it (naive: the segment path table,
cycle materialisation and the original blossom-base identification that writes
both endpoint-to-root paths, -T segment -M mat -B rootpath) and as XB++ builds
it (ours: the triplet path table and cycle-free odd-vertex conversion), on the
paper's eight graphs:

  graph            the CSR on the device, the same for both: (|V|+1) offsets
                   and 2|E| column indices, 4 B each (the edge weights are
                   aliased to the column indices, xblossom never reads them)
  beyond the graph what each variant needs for the path table and blossom
                   handling at its peak, the most over 10 rounds:
                     naive: 20 B per vertex (offset-length, root distance)
                            + 4 B per segment entry written
                            + 4 B per cycle-buffer node (the step's peak)
                            + 28 B per closing-edge record (incl. its prefix sum)
                     ours:  12 B per vertex (the compact records)
                            + 20 B per odd-vertex task (the step's peak)
  runtime          the mean of 10 rounds (s), and the speedup naive / ours

Per-vertex arrays both variants keep (matching, labels, queues, locks) are
left out of both. A variant that did not run says why: OOM, its reservation
does not fit the GPU (naive_fit.sh raises -p and reruns on every cycle-buffer overflow
until the run succeeds or an allocation fails, so a graph ends with a result
or an OOM); overflow, a leftover from a run without that retry whose demand
would still fit the GPU.

Writes analysis/implementations/outputs/tab_blossom_memory{,_detail}.* (the paper's Table IV)."""
import math
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../common"))
from units import *  # noqa: E402,F403

ROOT = os.path.abspath(os.path.join(ANALYSIS, ".."))
PAPER = os.path.join(ANALYSIS, "implementations", "outputs", "tab_blossom_memory.tex")
# the paper's eight graphs, in Table II's order (|V| ascending; the other graphs measured are left out of the table)
ALL = ["Amazon", "HiggsNets", "Youtube", "Kron21", "Orkut", "UK2002", "Arabic", "Sinaweibo"]
NAMES = {"Stackoverflow": "StackOverflow", "Livejournal": "LiveJournal", "UK2002": "UK-2002"}
GPU_GB = int(os.environ.get("GPU_MEMORY_GB", "96"))  # the RTX PRO 6000

reps = load_unit("gunrock-naive-vs-ours")
need_gb = {}  # (dataset, tag) -> GB a naive run that overflowed would need for one step


def rec(ds, tag):
    try:
        return reps["GPU"]["datasets"][ds]["runs"][tag]
    except KeyError:
        return None


def ok(ds, tag):
    r = rec(ds, tag)
    return r if r and r["status"] == "ok" else None


def why(ds, tag):
    r = rec(ds, tag)
    if r is None:
        return "pending"
    if r["status"] == "ok":
        return None
    log = os.path.join(ROOT, r["provenance"].get("log", ""))
    text = open(log, errors="replace").read() if os.path.isfile(log) else ""
    if "out of memory" in text or "bad_alloc" in text:
        return "OOM"
    m = re.search(r"cycle buffer full: this step asked for (\d+) nodes", text)
    if m:
        # the cycle buffer overflowed: does what the step asked for fit the GPU at all, next to the
        # graph, the segment buffer (-q), the closing-edge list (-o) and the fixed 20 B per vertex?
        cfg = re.search(r"nodes=(\d+) edges=(\d+).*segment_buffer_ratio=(\d+) odd_node_ratio=(\d+)", text)
        n, e, q, o = map(int, cfg.groups())
        need = (((n + 1) + 2 * e) * 4 + 20 * n + 4 * q * n + 28 * o * n + 4 * int(m.group(1))) / 1e9
        need_gb[(ds, tag)] = need
        return "OOM" if need > GPU_GB else "overflow"
    if "buffer full" in text or "list full" in text or "Assert" in text:
        return "overflow"
    if "LegTimeout" in text:
        return "timeout"
    return r["status"]


def graph_gb(ds):
    r = ok(ds, "ours") or ok(ds, "naive") or rec(ds, "ours") or rec(ds, "naive")
    f = r["fields"] if r else {}
    n, e = f.get("config.nodes"), f.get("config.edges")
    return ((n + 1) + 2 * e) * 4 / 1e9 if n and e else None


def beyond_gb(ds, tag):
    r = ok(ds, tag)
    if not r:
        return None
    s, n = r["samples"], r["fields"]["config.nodes"]
    peak = lambda k: max(s.get(k, [0]))
    if tag == "naive":
        b = 20 * n + 4 * peak("memory.paths_used") + 4 * peak("memory.blossom_buffer_peak") \
            + 28 * peak("memory.blossom_list_peak")
    else:
        b = 12 * n + 20 * peak("memory.blossom_list_peak")
    return b / 1e9


def t(ds, tag):
    r = ok(ds, tag)
    return mci(r["samples"]["runtime_s"]) if r else None


def gm(xs):
    xs = [x for x in xs if x]
    return math.exp(sum(map(math.log, xs)) / len(xs)) if xs else None


rows, g = [], {"mem": [], "t": []}
for ds in ALL:
    gg, mn, mo = graph_gb(ds), beyond_gb(ds, "naive"), beyond_gb(ds, "ours")
    tn, to = t(ds, "naive"), t(ds, "ours")
    rm, rt = ratio(mn, mo), ratio(tn, to)  # memory saved, speedup
    g["mem"].append(rm)
    g["t"].append(rt)
    rows.append(dict(ds=ds, g=gg, mn=mn, mo=mo, rm=rm, tn=tn, to=to, rt=rt, wn=why(ds, "naive"), wo=why(ds, "ours")))
G = {k: gm(v) for k, v in g.items()}

write_table("implementations", "tab_blossom_memory_detail",
            f"XB-Gunrock naive vs ours ({GPU_MACHINE})",
            ["Dataset", "graph (GB)", "naive beyond graph (GB)", "ours beyond graph (GB)", "memory: naive / ours",
             "naive time (s)", "ours time (s)", "speedup: naive / ours"],
            [[r["ds"], r["g"], r["mn"] if r["mn"] is not None else r["wn"], r["mo"] if r["mo"] is not None else r["wo"],
              r["rm"], r["tn"] if r["tn"] is not None else r["wn"], r["to"] if r["to"] is not None else r["wo"], r["rt"]]
             for r in rows] + [["GM", None, None, None, G["mem"], None, None, G["t"]]],
            note="Beyond the graph: the path table and blossom handling at their peak (see the script's docstring).")


def f_note(note):
    """A run that did not finish: OOM in bold red, so it stands out in the table."""
    if note == "OOM":
        return r"\textbf{\textcolor{red}{OOM}}"
    return note or "--"


def f_gb(x, note=None):
    if x is None:
        return f_note(note)
    if x >= 10:
        return f"{x:.1f}"
    if x >= 0.01:
        return f"{x:.2f}"
    return f"{x:.3f}"


def f_t(v, note=None):
    if v is None:
        return f_note(note)
    m, h = v
    return f"{m:.3f} {{\\tiny $\\pm$ {h:.3f}}}"


def f_x(x):
    if x is None:
        return "--"
    return f"{x:,.0f}$\\times$" if x >= 10 else f"{x:.1f}$\\times$"


def f_r(x):
    return "--" if x is None else f"{x:.2f}$\\times$"


def f_s(v, note=None):
    """Mean runtime only: the single-column table has no room for the CI."""
    if v is None:
        return f_note(note)
    return f"{v[0]:.3f}"


lines = [" & ".join([NAMES.get(r["ds"], r["ds"]), f_gb(r["mn"], r["wn"]), f_gb(r["mo"], r["wo"]), f_x(r["rm"]),
                     f_s(r["tn"], r["wn"]), f_s(r["to"], r["wo"]), f_r(r["rt"])]) + " \\\\" for r in rows]
gm_line = " & ".join([r"\textbf{GM}", r"\textbf{--}", r"\textbf{--}", rf"\textbf{{{f_x(G['mem'])}}}", r"\textbf{--}",
                      r"\textbf{--}", rf"\textbf{{{f_r(G['t'])}}}"]) + " \\\\"
tex = r"""% generated by analysis/implementations/targets/scripts/tab_blossom_memory.py (""" + GPU_MACHINE + r""")
% Direct: -T segment -M mat -B rootpath; Ours: -T compact -M nomat; both -l gacge, 1 warm-up + 10 rounds.
% Auxiliary memory: the path table and blossom handling beyond the graph at their peak (the script's docstring).
\begin{table}[!t]
 \centering
 \caption{Memory Usage and Runtime of Direct and Optimized GPU Implementations of XB.}
 \label{tab:blossom-memory}
 \scriptsize
 \setlength{\tabcolsep}{2pt}
 \renewcommand{\arraystretch}{1.0}
 \begin{tabular*}{0.95\columnwidth}{@{\extracolsep{\fill}}lrrrrrr@{}}
 \toprule
 & \multicolumn{3}{c}{\textbf{Auxiliary memory (GB)}} & \multicolumn{3}{c}{\textbf{Runtime (s)}} \\
 \cmidrule(lr){2-4}\cmidrule(l){5-7}
 \textbf{Graph} & \textbf{Direct} & \textbf{Ours} & \textbf{Direct/Ours} & \textbf{Direct} & \textbf{Ours} & \textbf{Direct/Ours} \\
 \midrule
""" + "\n".join(" " + l for l in lines) + "\n \\midrule\n " + gm_line + r"""
 \bottomrule
 \end{tabular*}
\end{table}
"""
os.makedirs(os.path.dirname(PAPER), exist_ok=True)
open(PAPER, "w").write(tex)
print(f"{len(lines)} rows -> {PAPER}")
for r in rows:
    print(f"{r['ds']:14} graph {f_gb(r['g']):>6}  beyond naive {f_gb(r['mn'], r['wn']):>7} ours {f_gb(r['mo'], r['wo']):>7}  "
          f"time naive {f_t(r['tn'], r['wn'])[:6]:>7} ours {f_t(r['to'], r['wo'])[:6]:>7}")
print("GM", {k: (round(v, 2) if v else v) for k, v in G.items()})
for (ds, tag), gb in sorted(need_gb.items()):
    print(f"{ds:14} {tag} would need {gb:.1f} GB for one step's cycle buffer plus the rest (GPU: {GPU_GB} GB)")
