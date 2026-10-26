#!/usr/bin/env bash
# One leg of one measurement unit on one machine.
#
#   run_leg.sh <unit> <Leg> <machine> [measure|parse] [timing|profile|results]
#
# Runs measure/<unit>/targets/<kind>/legs.d/<Leg>.sh <measure|parse> with
#   MACHINE UNIT LEG KIND REPO_ROOT UNIT_DIR MEASURE_COMMON
#   OUT_DIR  = measure/<unit>/outputs/<machine>
#   RAWS_DIR = $OUT_DIR/raw/<kind>/<Leg>   one log per dataset
#   JSON_DIR = $OUT_DIR/json/<kind>        <Leg>.json (schema 1)
#   MD_DIR   = $OUT_DIR/md/<kind>          <Leg>.md
# in its environment. measure runs remotely and pulls the raws back, then
# parses; parse only re-parses the raws already here.
set -uo pipefail
usage="usage: run_leg.sh <unit> <Leg> <machine> [measure|parse] [timing|profile|results]"
UNIT="${1:?${usage}}"; LEG="${2:?${usage}}"; MACHINE="${3:?${usage}}"
MODE="${4:-measure}"; KIND="${5:-timing}"

MEASURE_COMMON="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${MEASURE_COMMON}/../.." && pwd)"
UNIT_DIR="${REPO_ROOT}/measure/${UNIT}"
LEG_SH="${UNIT_DIR}/targets/${KIND}/legs.d/${LEG}.sh"
[[ -f "${LEG_SH}" ]] || { echo "no leg script: ${LEG_SH}" >&2; exit 2; }
bash -n "${LEG_SH}" || exit 2

OUT_DIR="${UNIT_DIR}/outputs/${MACHINE}"
export MACHINE UNIT LEG KIND REPO_ROOT UNIT_DIR MEASURE_COMMON OUT_DIR
export RAWS_DIR="${OUT_DIR}/raw/${KIND}/${LEG}"
export JSON_DIR="${OUT_DIR}/json/${KIND}"
export MD_DIR="${OUT_DIR}/md/${KIND}"
exec bash "${LEG_SH}" "${MODE}"
