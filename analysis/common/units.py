"""Shared reading and table writing for analysis/<dir>/targets/scripts/*.py.

Every analysis dir has inputs -> ../../measure/<unit>/outputs, whose
<machine>/json/timing/<Leg>.json come from measure/common/leg_json.py. The
per-algorithm units (measure/<algo>-<cpu|gpu>, since 2026-10-15) are read
directly with load_unit(); load("runtime") gathers them under the leg names of
the former measure/runtime (RUNTIME_LEGS).
Values with a CI are (mean, half_width) tuples; mean_ci95 is Student t.
"""
import csv
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stats import mean_ci95  # noqa: E402

ANALYSIS = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATASETS = ["GPlus", "Twitch", "Amazon", "HiggsNets", "Youtube", "Hyperlink",
            "Wikipedia", "Stackoverflow", "Patent", "Livejournal"]
GPU_MACHINE = os.environ.get("GPU_MACHINE", "local")
CPU_MACHINE = os.environ.get("CPU_MACHINE", "local")


MEASURE = os.path.abspath(os.path.join(ANALYSIS, "..", "measure"))
# The former measure/runtime legs -> (per-algorithm unit, leg) since 2026-10-15
RUNTIME_LEGS = {
    "GAP-BFS": ("bfs-cpu", "GAP"), "GAP-SSSP": ("sssp-cpu", "GAP"),
    "GAP-PageRank": ("pr-cpu", "GAP"), "GAP-Triangle": ("tc-cpu", "GAP"),
    "Gunrock-BFS": ("bfs-gpu", "Gunrock"), "Gunrock-SSSP": ("sssp-gpu", "Gunrock"),
    "Gunrock-PageRank": ("pr-gpu", "Gunrock"), "Gunrock-Triangle": ("tc-gpu", "Gunrock"),
    "XB-Pro-Ligra": ("baselines", "XB-Ligra"), "XB++-Gunrock": ("xb-gpu", "XB-Gunrock"),
    "XB-GAP": ("xb-cpu", "XB-GAP"),
    "Ligra-MultiSSSP": ("mssp-cpu", "Ligra"), "Gunrock-MultiSSSP": ("mssp-gpu", "Gunrock"),
    "Ligra-BFS": ("baselines", "Ligra-BFS"), "Ligra-SSSP": ("baselines", "Ligra-SSSP"),
    "Ligra-PageRank": ("baselines", "Ligra-PageRank"), "Ligra-Triangle": ("baselines", "Ligra-Triangle"),
}


def load_unit(unit, kind="timing"):
    """{leg: report} of measure/<unit>/outputs on the CPU and GPU machine."""
    reps = {}
    for m in (CPU_MACHINE, GPU_MACHINE):
        for p in sorted(glob.glob(os.path.join(MEASURE, unit, "outputs", m, "json", kind, "*.json"))):
            rep = json.load(open(p))
            reps[rep["leg"]] = rep
    return reps


def load(adir):
    """{leg: report} for the CPU and GPU machine of analysis/<adir>/inputs;
    "runtime" reads the per-algorithm units under RUNTIME_LEGS' names."""
    if adir == "runtime":
        reps = {}
        for old, (unit, leg) in RUNTIME_LEGS.items():
            r = load_unit(unit).get(leg)
            if r is not None:
                reps[old] = r
        check_xb_opt(adir, reps)
        return reps
    reps = {}
    for m in (CPU_MACHINE, GPU_MACHINE):
        for p in sorted(glob.glob(os.path.join(ANALYSIS, adir, "inputs", m, "json", "timing", "*.json"))):
            rep = json.load(open(p))
            reps[rep["leg"]] = rep
    check_xb_opt(adir, reps)
    return reps


def check_xb_opt(adir, reps):
    """Warn about X-Blossom-on-Ligra runs not from the current default build
    (XBlossomPro_cilk: XBP_OPT=1 and XBP_TRIPLET=1, printed as opt=1 triplet=1
    in XBConfig, from 2026-10-13): such data used XB-Pro's mutex design or its
    vector path table and is due for a rerun. The design comparisons
    (measure/xb-cpu-opt, xb-llc, xb-ligra-triplet) run the older designs on
    purpose and are not checked."""
    if adir in ("xb-cpu-opt", "xb-llc", "xb-ligra-triplet"):
        return
    stale = {}
    for leg, rep in reps.items():
        for ds, d in rep.get("datasets", {}).items():
            for tag, r in d.get("runs", {}).items():
                f = r.get("fields", {})
                v = str(f.get("config.variant", ""))
                if f.get("config.arm") == "ligra" and v in ("xb-pro-ligra", "xb-ligra") and (f.get("config.opt") != 1 or f.get("config.triplet") != 1):
                    stale.setdefault(leg, set()).add(ds)
    for leg, dss in sorted(stale.items()):
        print(f"WARNING {adir}/{leg}: {len(dss)} graph(s) not from the current XB-Ligra build "
              f"(no opt=1 triplet=1 in XBConfig): {', '.join(sorted(dss))}; rerun the leg", file=sys.stderr)
    check_mssp_sources(adir, reps)


def check_mssp_sources(adir, reps):
    """Warn about Ligra MultiSSSP runs from before 2026-10-13, which parsed
    their --src-file inside every Compute() (a serial parse of 5% of the
    vertices in each timed round). The fixed build reads it once per process
    and prints XBSources: file_once=1."""
    stale = {}
    for leg, rep in reps.items():
        for ds, d in rep.get("datasets", {}).items():
            for tag, r in d.get("runs", {}).items():
                f = r.get("fields", {})
                cmd = str(f.get("cmd", ""))
                if "MultiSSSP_" in cmd and "--src-file" in cmd and f.get("sources.file_once") != 1:
                    stale.setdefault(leg, set()).add(ds)
    for leg, dss in sorted(stale.items()):
        print(f"WARNING {adir}/{leg}: {len(dss)} graph(s) of Ligra MultiSSSP runs from before the source file was "
              f"read once (no XBSources line): {', '.join(sorted(dss))}; rerun the leg", file=sys.stderr)


def run(reps, leg, ds, tag):
    """The run record if it exists and is ok, else None."""
    try:
        r = reps[leg]["datasets"][ds]["runs"][tag]
    except KeyError:
        return None
    return r if r["status"] == "ok" else None


def times(reps, leg, ds, tag="timing"):
    r = run(reps, leg, ds, tag)
    return r["samples"].get("runtime_s") if r else None


def mci(xs):
    return mean_ci95(xs) if xs else None


def per_round(reps, leg, ds, field, a, b, rounds):
    """(b - a) / rounds of a profiled field: the work of `rounds` extra rounds."""
    ra, rb = run(reps, leg, ds, a), run(reps, leg, ds, b)
    if not ra or not rb or field not in ra["fields"] or field not in rb["fields"]:
        return None
    return (rb["fields"][field] - ra["fields"][field]) / rounds


def rate(amount, ts, scale=1.0):
    """amount per round over each timed round, as (mean, ci)."""
    if amount is None or not ts:
        return None
    return mean_ci95([amount / t / scale for t in ts])


def ratio(a, b):
    a = a[0] if isinstance(a, tuple) else a
    b = b[0] if isinstance(b, tuple) else b
    return a / b if a is not None and b else None


def _num(x):
    if x is None:
        return "-"
    if isinstance(x, str):
        return x
    if isinstance(x, int):
        return f"{x:,}"
    return f"{x:.4g}"


def cell(x, tex=False):
    if isinstance(x, tuple):
        m, h = x
        if h is None:
            return _num(m)
        return f"{_num(m)} {{\\tiny $\\pm$ {_num(h)}}}" if tex else f"{_num(m)} ± {_num(h)}"
    return _num(x)


def write_table(adir, name, title, head, rows, note=""):
    """outputs/<name>.csv (a CI column after every tuple column), .md, .tex (rows only)."""
    out = os.path.join(ANALYSIS, adir, "outputs")
    os.makedirs(out, exist_ok=True)
    tuple_cols = {i for r in rows for i, c in enumerate(r) if isinstance(c, tuple)}
    chead = []
    for i, h in enumerate(head):
        chead += [h, h + "_ci95"] if i in tuple_cols else [h]
    with open(os.path.join(out, name + ".csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(chead)
        for r in rows:
            line = []
            for i, c in enumerate(r):
                if i in tuple_cols:
                    line += list(c) if isinstance(c, tuple) else [c, ""]
                else:
                    line.append("" if c is None else c)
            w.writerow(line)
    with open(os.path.join(out, name + ".md"), "w") as f:
        f.write(f"## {title}\n\n{note}\n\n" if note else f"## {title}\n\n")
        f.write("| " + " | ".join(head) + " |\n|" + "---|" * len(head) + "\n")
        for r in rows:
            f.write("| " + " | ".join(cell(c) for c in r) + " |\n")
    with open(os.path.join(out, name + ".tex"), "w") as f:
        f.write(f"% {title} -- generated by analysis/{adir}; columns: " + " & ".join(head) + "\n")
        for r in rows:
            f.write(" & ".join(cell(c, tex=True) for c in r) + " \\\\\n")
    print(f"{adir}: {len(rows)} rows -> {out}/{name}.{{csv,md,tex}}")


def write_paper_table(template, out, rows, fmt, avg=True, renames=None, note=None):
    """Rewrite the data rows of a paper table that keeps its header and footer.
    template: the existing .tex (its lines before the first data row and from the
    \\bottomrule on are kept, with `renames` applied to the header); rows: lists
    [name, v1, v2, ...] (None prints --); fmt(i, v) formats column i; avg adds the
    arithmetic-mean row; note is appended to the caption's first line."""
    lines = open(template).read().split("\n")
    first = next(i for i, l in enumerate(lines) if l.strip().startswith("\\midrule")) + 1
    bottom = next(i for i, l in enumerate(lines) if l.strip().startswith("\\bottomrule"))
    head = "\n".join(lines[:first])
    for a, b in (renames or {}).items():
        head = head.replace(a, b)
    def line(name, vals):
        return f"{name:<13} & " + " & ".join("--" if v is None else fmt(i, v) for i, v in enumerate(vals)) + " \\\\"
    body = [line(r[0], r[1:]) for r in rows]
    if avg:
        cols = list(zip(*[r[1:] for r in rows]))
        mean = [sum(x for x in c if x is not None) / len([x for x in c if x is not None]) if any(x is not None for x in c) else None
                for c in cols]
        body += ["\\midrule", line("Average", mean)]
    foot = "\n".join(lines[bottom:])
    if note:
        foot = "\n".join(l for l in foot.split("\n") if not l.startswith("CPU: 48 workers"))  # a note from an earlier run
        foot = foot.replace("\\caption{\n", "\\caption{\n" + note + "\n", 1)
    open(out, "w").write(head + "\n" + "\n".join(body) + "\n" + foot)
    print("->", out)


def leg_runs(unit, kind, leg):
    """{graph: {tag: run}} of the ok runs of a leg (measure/<unit>/outputs/<machine>/json/<kind>/<leg>.json), on
    CPU_MACHINE for a CPU unit and GPU_MACHINE otherwise; a run is the parsed record of one command (samples, fields)."""
    m = CPU_MACHINE if unit.endswith("-cpu") else GPU_MACHINE
    p = os.path.join(MEASURE, unit, "outputs", m, "json", kind, f"{leg}.json")
    out = {}
    for ds, d in json.load(open(p))["datasets"].items():
        runs = {t: r for t, r in d.get("runs", {}).items() if r.get("status") == "ok"}
        if runs:
            out[ds] = runs
    return out


def mean_ms(run):
    """the mean timed runtime of a run, in ms"""
    v = run["samples"]["runtime_s"]
    return 1e3 * sum(v) / len(v)
