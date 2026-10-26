#!/usr/bin/env bash
# campaign.sh <cpu|gpu> <machine>: every measurement of the paper on one side. Builds the programs, then runs every leg
# (timing, profile, trace) of every unit of that side through run_unit.sh: measure/<algo>-<cpu|gpu>, and on the GPU
# side also measure/gunrock-stock and measure/gunrock-naive-vs-ours. <machine> is an ssh host, or `local` to run on
# this machine in this checkout. Finished runs are skipped (FORCE=1 reruns them); a failed leg does not stop the others,
# and the script fails at the end. Graphs: make datasets datasets-syn on that machine first.
set -uo pipefail
ARM="${1:?usage: campaign.sh <cpu|gpu> <machine>}"; MACHINE="${2:?usage: campaign.sh <cpu|gpu> <machine>}"
COMMON="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${COMMON}/../.." && pwd)"
cd "${ROOT}"
run() { if [[ "${MACHINE}" == local ]]; then bash -c "$1"; else ssh "${MACHINE}" "cd ~/${REMOTE_REPO_DIR:-GACGE} && $1"; fi; }

echo "[campaign] ${ARM} on ${MACHINE}: build"
if [[ "${MACHINE}" == local ]]; then
  if [[ "${ARM}" == gpu ]]; then ./deps/targets/scripts/gunrock/install.sh && ./src/targets/scripts/build_gpu && ./measure/gunrock-stock/targets/scripts/build_stock.sh local
  else ./src/targets/scripts/build_cpu; fi || exit 1
else
  measure/common/build_unit.sh "" "${MACHINE}" "${ARM}" || exit 1
  [[ "${ARM}" == gpu ]] && { measure/gunrock-stock/targets/scripts/build_stock.sh "${MACHINE}" || exit 1; }
fi
# Green contexts (Breadth-Depth) and ncu need plain CUDA clients: stop an MPS daemon left running.
[[ "${ARM}" == gpu ]] && run "echo quit | nvidia-cuda-mps-control >/dev/null 2>&1 || true"

units=(bfs-${ARM} sssp-${ARM} pr-${ARM} tc-${ARM} xb-${ARM})
[[ "${ARM}" == gpu ]] && units+=(gunrock-stock gunrock-naive-vs-ours)
rc=0
for u in "${units[@]}"; do
  for kind in timing profile trace; do
    ls measure/"${u}"/targets/"${kind}"/legs.d/*.sh >/dev/null 2>&1 || continue
    echo "[campaign] ${u} ${kind}"
    measure/common/run_unit.sh "${u}" "${MACHINE}" "${ARM}" "${kind}" || rc=1
  done
done
echo "[campaign] ${ARM} on ${MACHINE}: done (rc=${rc})"
exit "${rc}"
