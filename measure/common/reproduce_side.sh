#!/usr/bin/env bash
# reproduce_side.sh <cpu|gpu> [ssh host] [setup|reproduce]: one side's setup (system packages, Python, programs,
# graphs: deps/targets/scripts/setup_machine.sh), followed for `reproduce` (the default) by every measurement of that
# side. Without a host it runs in this checkout. With one, this checkout's files are copied to ~/${REMOTE_DIR} on that
# host (graphs, builds and measurements already there are kept, so a rerun resumes), the same step runs there,
# and its measurements (measure/<unit>/outputs) are copied back into this checkout.
set -euo pipefail
SIDE="${1:?usage: reproduce_side.sh <cpu|gpu> [ssh host] [setup|reproduce]}"
HOST="${2:-}"
STEP="${3:-reproduce}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${REMOTE_DIR:-GACGE-ICDE2027-Artifact}"
cd "${ROOT}"
case "${SIDE}" in
  cpu) units=(bfs-cpu sssp-cpu pr-cpu tc-cpu xb-cpu) ;;
  gpu) units=(bfs-gpu sssp-gpu pr-gpu tc-gpu xb-gpu gunrock-stock gunrock-naive-vs-ours) ;;
  *) echo "usage: reproduce_side.sh <cpu|gpu> [ssh host] [setup|reproduce]" >&2; exit 2 ;;
esac
[[ "${STEP}" == setup || "${STEP}" == reproduce ]] || { echo "the step is setup or reproduce, not ${STEP}" >&2; exit 2; }

if [[ -z "${HOST}" ]]; then
  deps/targets/scripts/setup_machine.sh "${SIDE}"
  [[ "${STEP}" == reproduce ]] || exit 0
  if [[ "${SIDE}" == cpu ]]; then make measure-cpu CPU_MACHINE=local; else make measure-gpu GPU_MACHINE=local; fi
  exit 0
fi

git rev-parse --git-dir >/dev/null 2>&1 || { echo "a remote run copies the files git knows: clone the repository with git" >&2; exit 2; }
echo "[${STEP}-${SIDE}] copying this checkout to ${HOST}:~/${DIR}"
git ls-files -z --cached --others --exclude-standard | COPYFILE_DISABLE=1 tar --null -T - -cf - \
  | ssh "${HOST}" "mkdir -p ~/'${DIR}' && tar -xf - -C ~/'${DIR}'"
echo "[${STEP}-${SIDE}] running on ${HOST}"
rc=0
# bash, not make: a fresh machine has no make until the setup installs it
ssh -o ServerAliveInterval=60 "${HOST}" "cd ~/'${DIR}' && bash measure/common/reproduce_side.sh ${SIDE} '' ${STEP}" || rc=$?
[[ "${STEP}" == reproduce ]] || exit "${rc}"
echo "[${STEP}-${SIDE}] copying the measurements back from ${HOST}"
ssh "${HOST}" "cd ~/'${DIR}' && for u in ${units[*]}; do [ -d measure/\$u/outputs ] && echo measure/\$u/outputs; done | tar -cf - -T -" \
  | tar -xf -
exit "${rc}"
