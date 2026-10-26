#!/usr/bin/env bash
# no_prefetch.sh <command...>: run <command> with every core's hardware prefetchers disabled (Intel MSR 0x1a4 = 0x2f:
# L2 streamer, L2 adjacent line, DCU streamer, DCU IP and AMP off), then restore each core's previous value, also when
# the command fails. Needs root (sudo -n) and msr-tools (rdmsr / wrmsr). Prints MSR_1A4=<value> while disabled.
set -uo pipefail
sudo -n modprobe msr 2>/dev/null || true
mapfile -t saved < <(sudo -n rdmsr -a 0x1a4)
restore() { local c=0; for v in "${saved[@]}"; do sudo -n wrmsr -p "${c}" 0x1a4 "0x${v}"; c=$((c + 1)); done; }
trap restore EXIT
sudo -n wrmsr -a 0x1a4 0x2f
echo "MSR_1A4=$(sudo -n rdmsr -p 0 0x1a4)"
"$@"
