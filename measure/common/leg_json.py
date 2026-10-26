#!/usr/bin/env python3
"""Parse one leg's raw logs (<ds>.<tag>.log, measure/common/leg_lib.sh) into
<Leg>.json (schema 1) and <Leg>.md.

JSON: {schema, unit, leg, machine, datasets: {<ds>: {status, flags,
       runs: {<tag>: {status, flags, fields, samples, provenance}}}}}

What a log may hold, and where it lands:
  X-Blossom   `XB<Tag>: k=v ...`   fields <tag>.<k>; XBRound -> samples.<k>,
              XBPhases -> samples.phases.<k>, XBMemory -> samples.memory.<k>,
              XBCounters -> samples.counters.<k>
  Ligra       `Running time : x`   samples.runtime_s
  Gunrock     `GPU Elapsed Time : x (ms)`   samples.runtime_s (seconds)
  GAP         `Trial Time: x`   samples.runtime_s
  *_Throughput `Average runtime: x`, `Number of Processed Edges: x`,
              `Processed Edges per Second: x`   fields tp.*
  perf stat -x,   `value,unit,event,...`   fields perf.<event> (summed)
  ncu --csv   kernel rows   fields ncu.<metric> (summed), ncu.kernels
A run with drop_first=1 loses its first runtime sample (the warm-up; kept as
fields warmup_runtime_s). A run is ok when it exited 0 and, if it printed an
XBResult, every round is valid and the matching size equals
data/expected_matching_size.tsv. A dataset is ok when all its runs are.
"""
import argparse
import csv
import io
import json
import os
import re

KV = re.compile(r"(\w+)=(\"[^\"]*\"|\S+)")
NUM = re.compile(r"^-?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$")
LIGRA_T = re.compile(r"^Running time\s*:\s*([0-9.eE+-]+)")
GUNROCK_T = re.compile(r"GPU Elapsed Time\s*:\s*([0-9.eE+-]+)\s*\(ms\)")
GAP_T = re.compile(r"^Trial Time:\s*([0-9.eE+-]+)")
TP = {"Average runtime": "tp.avg_runtime_s", "Number of Processed Edges": "tp.processed_edges",
      "Processed Edges per Second": "tp.edges_per_s"}


def value(v):
    v = v.strip('"').replace(",", "") if NUM.match(v.strip('"').replace(",", "")) else v.strip('"')
    if NUM.match(v):
        return float(v) if any(c in v for c in ".eE") else int(v)
    return v


def expected_sizes(repo):
    sizes = {}
    with open(os.path.join(repo, "data", "expected_matching_size.tsv")) as f:
        for line in f:
            if line.strip() and not line.startswith("#"):
                ds, n = line.split()
                sizes[ds] = int(n)
    return sizes


def parse_ncu(lines):
    """Sum each metric over the kernel rows of ncu --csv output."""
    out, start = {}, None
    for i, l in enumerate(lines):
        if l.startswith('"ID","Process ID"'):
            start = i
    if start is None:
        return out
    rows = csv.DictReader(io.StringIO("".join(l for l in lines[start:] if l.startswith('"'))))
    kernels = set()
    for r in rows:
        name, val = r.get("Metric Name"), r.get("Metric Value", "").replace(",", "")
        if not name or not NUM.match(val):
            continue
        kernels.add(r.get("ID"))
        out[f"ncu.{name}"] = out.get(f"ncu.{name}", 0) + float(val)
    out["ncu.kernels"] = len(kernels)
    return out


def parse_log(path, expected):
    lines = open(path, errors="replace").readlines()
    fields, samples, flags = {}, {}, []
    exit_rc, timeout, result, drop = None, False, None, 0
    fw_times = []  # the framework's own per-round times (Ligra "Running time", Gunrock "GPU Elapsed Time", GAP "Trial Time")
    for raw in lines:
        line = raw.rstrip("\n")
        m = re.match(r"^((?:XB|Leg)\w+): (.*)$", line)
        if m:
            tag, rest = m.group(1), m.group(2)
            if tag == "LegCmd":
                fields["cmd"] = rest
                continue
            kv = {k: value(v) for k, v in KV.findall(rest)}
            name = tag[2:].lower() if tag.startswith("XB") else tag[3:].lower()
            if tag == "XBRound":
                for k, v in kv.items():
                    if k != "index":
                        samples.setdefault(k, []).append(v)
                continue
            if tag in ("XBCounters", "XBPhases", "XBMemory", "XBTraversal"):
                prefix = {"XBCounters": "counters", "XBPhases": "phases", "XBMemory": "memory",
                          "XBTraversal": "traversal"}[tag]
                for k, v in kv.items():
                    if k != "index":
                        samples.setdefault(f"{prefix}.{k}", []).append(v)
                continue
            if tag == "LegExit":
                exit_rc = kv.get("rc")
            elif tag == "LegTimeout":
                timeout = True
            elif tag == "LegRun":
                drop = kv.get("drop_first", 0)
            elif tag == "XBResult":
                result = kv
            for k, v in kv.items():
                fields[f"{name}.{k}"] = v
            continue
        m = LIGRA_T.match(line) or GUNROCK_T.search(line) or GAP_T.match(line)
        if m:
            t = float(m.group(1))
            fw_times.append(t / 1e3 if m.re is GUNROCK_T else t)
            continue
        for label, key in TP.items():
            m = re.match(rf"^{label}\s*:\s*([0-9.eE+-]+)", line)
            if m:
                fields[key] = float(m.group(1))
        parts = line.split(",")
        if len(parts) >= 3 and NUM.match(parts[0].strip()) and re.match(r"^[\w/.:-]+$", parts[2] or "-"):
            ev = parts[2].replace("cpu_core/", "").rstrip("/")
            fields[f"perf.{ev}"] = fields.get(f"perf.{ev}", 0) + float(parts[0])
    fields.update(parse_ncu(lines))
    # A program that prints XBRound lines (X-Blossom, also on Ligra/Gunrock) is
    # timed by them; the framework's own round times then include the matching
    # check and the warm-up, so they are kept only as a field.
    if "runtime_s" in samples:
        if fw_times:
            fields["framework_round_times_s"] = len(fw_times)
    elif fw_times:
        samples["runtime_s"] = fw_times
    if drop and samples.get("runtime_s"):
        fields["warmup_runtime_s"] = samples["runtime_s"].pop(0)
    if timeout:
        return "timeout", fields, samples, flags
    if exit_rc != 0:
        return ("crash" if exit_rc is not None else "unfinished"), fields, samples, flags
    if result is not None:
        if result.get("status") != "ok":
            flags.append(str(result.get("status")))
        size = result.get("matching_size")
        if expected is None:
            flags.append("no_expected_matching_size")
        elif size != expected:
            flags.append(f"matching_size {size} != expected {expected}")
    return ("ok" if not flags else "invalid"), fields, samples, flags


def main():
    ap = argparse.ArgumentParser()
    for a in ("unit", "leg", "machine", "raws", "json", "md", "repo", "datasets", "tags"):
        ap.add_argument("--" + a, required=True)
    args = ap.parse_args()
    expected = expected_sizes(args.repo)
    tags = [t for t in args.tags.split(",") if t]
    out = {"schema": 1, "unit": args.unit, "leg": args.leg, "machine": args.machine, "datasets": {}}
    for ds in args.datasets.split(","):
        runs = {}
        for tag in tags:
            log = os.path.join(args.raws, f"{ds}.{tag}.log")
            rec = {"provenance": {"log": os.path.relpath(log, args.repo)}}
            if not os.path.exists(log):
                rec.update(status="no log", flags=[], fields={}, samples={})
            else:
                status, fields, samples, flags = parse_log(log, expected.get(ds))
                rec.update(status=status, flags=flags, fields=fields, samples=samples)
                for k in ("host", "git", "xb"):
                    if f"run.{k}" in fields:
                        rec["provenance"][k] = fields[f"run.{k}"]
            runs[tag] = rec
        bad = [f"{t}: {r['status']}" for t, r in runs.items() if r["status"] != "ok"]
        out["datasets"][ds] = {"status": "ok" if not bad else "incomplete", "flags": bad, "runs": runs}

    os.makedirs(os.path.dirname(args.json), exist_ok=True)
    os.makedirs(os.path.dirname(args.md), exist_ok=True)
    with open(args.json, "w") as f:
        json.dump(out, f, indent=1)
    with open(args.md, "w") as f:
        f.write(f"## {args.leg} — {args.unit} on {args.machine}\n\n")
        f.write(f"Raw logs in {os.path.relpath(args.raws, args.repo)}/<ds>.<run>.log.\n\n")
        f.write("| dataset | run | status | samples | mean runtime (s) | matching size | flags |\n")
        f.write("|---|---|---|---|---|---|---|\n")
        for ds, d in out["datasets"].items():
            for tag, r in d["runs"].items():
                xs = r.get("samples", {}).get("runtime_s", [])
                mean = f"{sum(xs) / len(xs):.6g}" if xs else "-"
                f.write(f"| {ds} | {tag} | {r['status']} | {len(xs)} | {mean} | "
                        f"{r['fields'].get('result.matching_size', '-')} | {'; '.join(r['flags']) or '-'} |\n")
    ok = sum(1 for r in out["datasets"].values() if r["status"] == "ok")
    print(f"[{args.leg}] {args.unit}: {ok}/{len(out['datasets'])} datasets ok -> {args.json}, {args.md}")


if __name__ == "__main__":
    main()
