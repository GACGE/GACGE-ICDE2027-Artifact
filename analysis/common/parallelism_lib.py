"""The two parallelism measures of Sec. VI-B and VI-D, shared by analysis/parallelism and analysis/graph-properties.

  timing(unit, side, leg)   {graph: mean runtime (s)} of a timing leg, read from its md summary
                            (measure/<unit>-<side>/outputs/<machine>/md/timing/<leg>.md)
  gpu_threads(u, ds, t)     the GPU's active threads: 32 x the warps resident on the GPU averaged over the run, per
                            kernel of the profiled trial smsp__warps_active.sum / smsp__cycles_elapsed.avg (the mean
                            resident warps while it runs) x its duration, summed, over the run's time t (gaps between
                            kernels count as zero); X-Blossom (racy): the profiled run's steps scale t
                            (measure/<u>-gpu NCU-Concurrency). Returns (threads, busy share, occupancy while busy).
  small_share(u, ds)        the share (%) of the GPU's step time in steps that launch fewer than a tenth of a wave of
                            128-thread blocks (measure/<u>-gpu StepTimes); PR and TC sweep every edge in every step: 0
Machines: CPU_MACHINE, GPU_MACHINE (environment; the root Makefile exports them)."""
import csv
import os
import re
import statistics as st

CPU_MACHINE = os.environ.get("CPU_MACHINE", "local")
GPU = os.environ.get("GPU_MACHINE", "local")
# SMs, resident 128-thread blocks per SM, resident warps per SM: the RTX PRO 6000 (Blackwell sm_120, 1536 threads an SM)
GPUSPEC = (188, 12, 48)
MAX_WARPS = GPUSPEC[0] * GPUSPEC[2]
SMALL = 0.1 * GPUSPEC[0] * GPUSPEC[1]  # a tenth of a wave of 128-thread blocks

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.."))
M = os.path.join(ROOT, "measure")
mean = lambda v: st.mean(v) if v else float("nan")


def timing(unit, side, leg):
    d = {}
    p = f"{M}/{unit}-{side}/outputs/{CPU_MACHINE if side == 'cpu' else GPU}/md/timing/{leg}.md"
    for ln in open(p):
        f = [x.strip() for x in ln.split("|")]
        if len(f) > 6 and f[2] == "timing" and f[3] == "ok":
            d[f[1]] = float(f[5])
    return d


def xb_steps(p):
    return [int(re.search(r"steps=(\d+)", l).group(1)) for l in open(p) if l.startswith("XBPhases:")]


def gpu_threads(u, ds, t_wall):
    p = f"{M}/{u}-gpu/outputs/{GPU}/raw/profile/NCU-Concurrency/{ds}.profile.log"
    if not os.path.exists(p):
        return None
    L = {}
    for r in csv.reader(open(p)):
        if len(r) > 14 and r[0].isdigit():
            try:
                L.setdefault(int(r[0]), {})[r[12]] = float(r[14].replace(",", ""))
            except ValueError:
                pass
    wd = sum(m["smsp__warps_active.sum"] / m["smsp__cycles_elapsed.avg"] * m["gpu__time_duration.sum"] for m in L.values()
             if m.get("smsp__cycles_elapsed.avg"))
    kd = sum(m.get("gpu__time_duration.sum", 0) for m in L.values()) * 1e-9
    if u == "xb":  # the profiled run's steps against the timed runs' mean
        tm = st.mean(xb_steps(f"{M}/xb-gpu/outputs/{GPU}/raw/timing/XB-Gunrock/{ds}.timing.log")[1:])
        t_wall *= xb_steps(p)[0] / tm
    return 32 * wd * 1e-9 / t_wall, kd / t_wall, wd / (kd * 1e9) / MAX_WARPS


def steps(p):
    runs = {}
    for ln in open(p):
        m = re.match(r"XBStepTime: run=(\d+) step=\d+ (.*) ms=([\d.]+)", ln)
        if m:
            d = dict(re.findall(r"(\w+)=(\S+)", m.group(2)))
            runs.setdefault(int(m.group(1)), []).append((d.get("kind"), int(d.get("blocks", 0)), float(m.group(3))))
    return runs


def small_share(u, ds):
    if u in ("pr", "tc"):
        return 0.0
    p = f"{M}/{u}-gpu/outputs/{GPU}/raw/profile/StepTimes/{ds}.steps.log"
    if not os.path.exists(p):
        return None
    r = steps(p)
    runs = [r[max(r)]] if u in ("bfs", "sssp") else [r[k] for k in r if k >= 1]
    v = []
    for run in runs:
        tot = sum(t for _, _, t in run)
        sm = sum(t for k, b, t in run if k != "init" and b < SMALL)
        v.append(100 * sm / tot)
    return mean(v)
