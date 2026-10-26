#!/usr/bin/env bash
# naive_fit.sh -- <xblossom command with -p RATIO>
#
# Runs the naive variant and sizes its cycle buffer by trial: when the run ends
# with "cycle buffer full", -p is raised to 1.5x what the overflowing step asked
# for (the driver reports it) and the run is repeated; when an allocation fails
# (OOM) or anything else goes wrong, that is the result: the graph does not fit.
# Only the final attempt's output is kept in full; each earlier attempt leaves
# one XBFit line and its XBError line, so the log shows how -p was found.
set -uo pipefail
[[ "${1:-}" == -- ]] && shift
cmd=("$@")
pi=-1
for ((i = 0; i < ${#cmd[@]}; i++)); do [[ "${cmd[i]}" == -p ]] && pi=$((i + 1)); done
[[ ${pi} -ge 0 ]] || { echo "naive_fit.sh: no -p in the command" >&2; exit 2; }
tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT
for attempt in 1 2 3 4 5 6; do
  p="${cmd[pi]}"
  "${cmd[@]}" > "${tmp}" 2>&1; rc=$?
  if [[ ${rc} -eq 0 ]]; then
    echo "XBFit: attempt=${attempt} p=${p} status=ok"; cat "${tmp}"; exit 0
  fi
  if grep -aq "cycle buffer full" "${tmp}"; then
    asked="$(grep -ao 'asked for [0-9]*' "${tmp}" | grep -o '[0-9]*' | tail -1)"
    n="$(grep -ao 'nodes=[0-9]*' "${tmp}" | head -1 | cut -d= -f2)"
    echo "XBFit: attempt=${attempt} p=${p} status=overflow asked=${asked:-0}"
    grep -a "XBError" "${tmp}"
    if [[ -n "${asked}" && -n "${n}" ]]; then np=$(( asked * 15 / 10 / n + 1 )); else np=$(( p * 2 )); fi
    [[ ${np} -gt ${p} ]] || np=$(( p * 2 ))
    # never size past the GPU: the 1.5x margin is capped at 80% of the free device memory (4 B an entry), so a
    # request that fits is retried at the cap instead of overshooting into an OOM; past the cap it is a real OOM
    free_mib="$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1)"
    if [[ -n "${free_mib}" && -n "${n}" ]]; then
      cap=$(( free_mib * 1048576 * 8 / 10 / 4 / n ))
      [[ ${np} -gt ${cap} && ${cap} -gt ${p} ]] && np=${cap}
    fi
    cmd[pi]="${np}"
    continue
  fi
  echo "XBFit: attempt=${attempt} p=${p} status=failed rc=${rc}"; cat "${tmp}"; exit "${rc}"
done
echo "XBFit: attempt=${attempt} status=gave_up"; cat "${tmp}"; exit 5
