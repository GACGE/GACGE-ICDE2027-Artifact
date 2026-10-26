#!/usr/bin/env bash
# gap_on_bin.sh <graph>.bin <gap-kernel> [args...]: run one GAP kernel on a
# GACGE binary graph. The serialized graph GAP reads (.wsg for sssp, .sg
# otherwise) is written by bin_to_gap under ${GACGE_GAP_TMP:-data/gap} first,
# outside GAP's timed trials, and removed afterwards (Arabic's .wsg is 9 GB).
set -euo pipefail
bin="$1"; kernel="$2"; shift 2
ext=sg; [[ "$(basename "${kernel}")" == sssp ]] && ext=wsg
dir="${GACGE_GAP_TMP:-data/gap}"; mkdir -p "${dir}"
graph="${dir}/$(basename "${bin%.bin}").$$.${ext}"
trap 'rm -f "${graph}"' EXIT
"$(dirname "${kernel}")/bin_to_gap" "${bin}" "${ext}" "${graph}"
"${kernel}" -f "${graph}" "$@"
