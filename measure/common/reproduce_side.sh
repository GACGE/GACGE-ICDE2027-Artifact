#!/usr/bin/env bash
# reproduce_side.sh <cpu|gpu> [ssh host]: one side's whole reproduction: fetch and generate the graphs, build, run
# every measurement of that side. Without a host it runs in this checkout. With one, this checkout's files are copied
# to ~/${REMOTE_DIR} on that host (graphs, builds and measurements already there are kept, so a rerun resumes), the
# side runs there, and its measurements (measure/<unit>/outputs) are copied back into this checkout.
set -euo pipefail
SIDE="${1:?usage: reproduce_side.sh <cpu|gpu> [ssh host]}"
HOST="${2:-}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${REMOTE_DIR:-GACGE-ICDE2027-Artifact}"
cd "${ROOT}"
case "${SIDE}" in
  cpu) units=(bfs-cpu sssp-cpu pr-cpu tc-cpu xb-cpu) ;;
  gpu) units=(bfs-gpu sssp-gpu pr-gpu tc-gpu xb-gpu gunrock-stock gunrock-naive-vs-ours) ;;
  *) echo "usage: reproduce_side.sh <cpu|gpu> [ssh host]" >&2; exit 2 ;;
esac

if [[ -z "${HOST}" ]]; then
  make datasets datasets-syn
  if [[ "${SIDE}" == cpu ]]; then make measure-cpu CPU_MACHINE=local; else make measure-gpu GPU_MACHINE=local; fi
  exit 0
fi

git rev-parse --git-dir >/dev/null 2>&1 || { echo "a remote run copies the files git knows: clone the repository with git" >&2; exit 2; }
echo "[reproduce-${SIDE}] copying this checkout to ${HOST}:~/${DIR}"
git ls-files -z --cached --others --exclude-standard | COPYFILE_DISABLE=1 tar --null -T - -cf - \
  | ssh "${HOST}" "mkdir -p ~/'${DIR}' && tar -xf - -C ~/'${DIR}'"
echo "[reproduce-${SIDE}] running on ${HOST}"
rc=0
ssh -o ServerAliveInterval=60 "${HOST}" "cd ~/'${DIR}' && make reproduce-${SIDE}" || rc=$?
echo "[reproduce-${SIDE}] copying the measurements back from ${HOST}"
ssh "${HOST}" "cd ~/'${DIR}' && for u in ${units[*]}; do [ -d measure/\$u/outputs ] && echo measure/\$u/outputs; done | tar -cf - -T -" \
  | tar -xf -
exit "${rc}"
