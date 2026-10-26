#!/usr/bin/env bash
# perf_region.sh <events> <skip> <command...>: `perf stat` that counts only
# inside the program's trials. perf starts with the counters off (-D -1) and
# the program turns them on and off around each trial's kernel through perf's
# control FIFOs (GACGE_PERF_CTL / GACGE_PERF_ACK, src/gap/gapbs/src/gacge.h),
# leaving the first <skip> trials uncounted (warm-up). Graph reading, building,
# conversion and verification are outside the region. The counts are summed
# over the counted trials (perf -x, CSV on stderr, parsed by leg_json.py as
# perf.<event>). Uncore events (the memory controllers' uncore_imc/...) exist
# only machine-wide: with one, perf counts every CPU (-a), still only while the
# program has its counters on; the box runs nothing else during a leg.
set -euo pipefail
events="$1"; skip="$2"; shift 2
dir="$(mktemp -d)"; trap 'rm -rf "${dir}"' EXIT
mkfifo "${dir}/ctl" "${dir}/ack"; chmod 666 "${dir}/ctl" "${dir}/ack"
# sudo resets the environment: the OpenMP and GACGE settings are passed on
mapfile -t fwd < <(env | grep -E '^(OMP_|GACGE_)' || true)
scope=(); [[ "${events}" == *uncore* ]] && scope=(-a)
echo "LegPerf: events=${events} skip=${skip} scope=${scope[*]:-process} env=${fwd[*]:-}"
sudo -n perf stat "${scope[@]}" -x, -e "${events}" -D -1 --control "fifo:${dir}/ctl,${dir}/ack" -- \
  env "${fwd[@]}" GACGE_PERF_CTL="${dir}/ctl" GACGE_PERF_ACK="${dir}/ack" GACGE_PERF_SKIP="${skip}" "$@"
