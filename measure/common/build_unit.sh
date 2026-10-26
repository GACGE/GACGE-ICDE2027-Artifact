#!/usr/bin/env bash
# build_unit.sh <unit> <machine> <cpu|gpu>: bring the remote checkout to the
# pushed commit and build that side's programs (src/targets/scripts/build_<cpu|gpu>).
# A unit with hook/targets builds only the CMake targets listed there.
# Files under measure/*/outputs on the remote (raw logs a leg wrote there;
# they were pulled here and are committed) are reset first, untracked ones
# removed and tracked ones restored, or the pull would refuse to overwrite them.
set -euo pipefail
UNIT="${1?usage: build_unit.sh <unit|\"\"> <machine> <cpu|gpu>  (\"\" = every unit)}"
MACHINE="${2:?}"; ARM="${3:?}"
REMOTE_REPO_DIR="${REMOTE_REPO_DIR:-GACGE}"
UNIT_HOOK="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/${UNIT}/hook"
BUILD_ENV=""
if [[ -n "${UNIT}" && -f "${UNIT_HOOK}/targets" ]]; then
  BUILD_ENV="BUILD_TARGETS='$(grep -v '^#' "${UNIT_HOOK}/targets" | xargs)'"
fi
ssh "${MACHINE}" "set -e; cd ~/${REMOTE_REPO_DIR} && git clean -fdq -- 'measure/*/outputs/*' && { git checkout -q -- 'measure/*/outputs/*' 2>/dev/null || true; } && git pull -q --ff-only \
  && ${BUILD_ENV} ./src/targets/scripts/build_${ARM} > build_${UNIT:-all}_${ARM}.log 2>&1 \
  || { tail -30 build_${UNIT:-all}_${ARM}.log; exit 1; }"
