#!/usr/bin/env bash
# run_unit.sh <unit> <machine> <cpu|gpu> <step>...: the steps of a per-algorithm
# unit measure/<unit> (measure/<algo>-<cpu|gpu>, see measure/common/targets/algo_unit.mk):
#   build                     build_unit.sh: the unit's hook/targets on <machine>
#   timing | profile | trace  every leg in targets/<kind>/legs.d, through run_leg.sh
# LEG=<Leg> runs only that leg; PARSE=1 re-parses the raws already here (no
# build, nothing runs remotely). A failed leg does not stop the others; the
# script fails at the end.
set -uo pipefail
usage="usage: run_unit.sh <unit> <machine> <cpu|gpu> <build|timing|profile|trace>..."
UNIT="${1:?${usage}}"; MACHINE="${2:?${usage}}"; ARM="${3:?${usage}}"; shift 3
[[ $# -gt 0 ]] || { echo "${usage}" >&2; exit 2; }
COMMON="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UNIT_DIR="${COMMON}/../${UNIT}"
[[ -d "${UNIT_DIR}" ]] || { echo "no unit: measure/${UNIT}" >&2; exit 2; }
rc=0
for step in "$@"; do
  case "${step}" in
    build)
      [[ "${PARSE:-0}" == 1 ]] || "${COMMON}/build_unit.sh" "${UNIT}" "${MACHINE}" "${ARM}" || exit 1 ;;
    timing|profile|trace)
      legs=()
      if [[ -n "${LEG:-}" ]]; then legs=("${LEG}"); else
        for f in "${UNIT_DIR}/targets/${step}/legs.d/"*.sh; do [[ -f "${f}" ]] && legs+=("$(basename "${f}" .sh)"); done
      fi
      [[ ${#legs[@]} -gt 0 ]] || { echo "[${UNIT}] no ${step} legs"; continue; }
      for l in "${legs[@]}"; do
        "${COMMON}/run_leg.sh" "${UNIT}" "${l}" "${MACHINE}" "$([[ "${PARSE:-0}" == 1 ]] && echo parse || echo measure)" "${step}" || rc=1
      done ;;
    *) echo "${usage}" >&2; exit 2 ;;
  esac
done
exit "${rc}"
