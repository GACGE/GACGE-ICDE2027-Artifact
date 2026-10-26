#!/usr/bin/env bash
# collect.sh results: copy every figure and table listed in analysis/common/targets/floats.tsv from
# analysis/<dir>/outputs/ into results/ (renamed by paper number, with results/MANIFEST.tsv).
# A float that analysis did not produce is reported and makes the script fail; nothing is skipped silently.
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
DEST="${1:-results}"
LIST="${ROOT}/analysis/common/targets/floats.tsv"
rc=0
[[ "${DEST}" == results ]] && { mkdir -p "${ROOT}/results"; printf 'paper float\tfile\tgenerated from\n' > "${ROOT}/results/MANIFEST.tsv"; }
while IFS=$'\t' read -r float src rname pfile; do
  [[ -z "${float}" || "${float}" == \#* ]] && continue
  if [[ ! -f "${ROOT}/analysis/${src}" ]]; then echo "MISSING ${float}: analysis/${src}" >&2; rc=1; continue; fi
  if [[ "${DEST}" == results ]]; then
    mkdir -p "$(dirname "${ROOT}/results/${rname}")"
    cp "${ROOT}/analysis/${src}" "${ROOT}/results/${rname}"
    printf '%s\t%s\tanalysis/%s\n' "${float}" "${rname}" "${src}" >> "${ROOT}/results/MANIFEST.tsv"
    echo "${float}: results/${rname}"
  fi
done < "${LIST}"
exit "${rc}"
