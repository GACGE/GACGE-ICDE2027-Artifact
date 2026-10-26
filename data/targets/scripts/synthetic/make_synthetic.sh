#!/usr/bin/env bash
# Synthetic graphs of Sec. VI-D: GAP's Kronecker generator (Graph500 parameters, GAP converter -g), named by their
# parameters so measure/common/datasets.sh resolves them without a registry entry:
#   SynKronS<scale>D<degree>   2^scale vertex IDs, <degree> edges a vertex
# Steps per graph (a graph whose bin and meta exist is skipped); everything binary and parallel, a scale-25 graph
# takes a minute or two:
#   1. GAP's converter (make -C src/gap/gapbs converter), its fixed seed: -g <scale> -k <degree> -s -b data/raw/<Name>.sg,
#      the symmetrized, squished (sorted lists, no self-loops or duplicates) graph in GAP's serialized form
#   2. build/tools/sg_to_bin (sg_to_bin.cpp): isolated vertices dropped, the rest relabelled in order -> data/bin/<Name>/<name>.bin
#      and .w.bin (the SSSP weights, xbcsr_to_bin's), data/src_nodes/<Name>_src_nodes.txt (1000 vertices of the
#      highest-degree vertex's component, fixed seed) and data/xb/<Name>/meta.txt (n, m, parameters)
# No XB CSR text is written (the measurements read the bin); the real graphs' text path is edgelist_to_csr.py.
# --sync <host>: rsync data/bin/<Name>/ and the source list to <host>:GACGE when the machine can reach it; otherwise
#   run the script on the GPU machine too: the fixed seeds make the graph and sources identical.
#   data/targets/scripts/synthetic/make_synthetic.sh [--sync <host>] <Name>...
# Run from the repo root (g++ and the gapbs checkout).
set -euo pipefail
cd "$(dirname "$0")/../../../.."
SYNC=""
if [[ "${1:-}" == "--sync" ]]; then SYNC="$2"; shift 2; fi
CONVERTER="${GAP_CONVERTER:-src/gap/gapbs/converter}"  # GAP's generator + converter, built on demand
[[ -x "${CONVERTER}" ]] || make -C src/gap/gapbs converter >/dev/null
SG2BIN=build/tools/sg_to_bin; mkdir -p build/tools
[[ -x "${SG2BIN}" && "${SG2BIN}" -nt data/targets/scripts/synthetic/sg_to_bin.cpp ]] || "${CXX:-g++}" -O3 -std=c++17 -pthread -o "${SG2BIN}" data/targets/scripts/synthetic/sg_to_bin.cpp
RAW=data/raw; mkdir -p "${RAW}"
for name in "$@"; do
  [[ "${name}" =~ ^SynKronS([0-9]+)D([0-9]+)$ ]] || { echo "bad name ${name} (SynKronS<scale>D<degree>, e.g. SynKronS22D16)" >&2; exit 2; }
  kind=Kron; scale="${BASH_REMATCH[1]}"; deg="${BASH_REMATCH[2]}"; pct=""
  lower="$(tr '[:upper:]' '[:lower:]' <<< "${name}")"
  dir="data/xb/${name}"; bin="data/bin/${name}/${lower}.bin"; sg="${RAW}/${name}.sg"
  mkdir -p "${dir}" "data/bin/${name}" data/src_nodes
  if [[ ! -s "${bin}" || ! -s "${dir}/meta.txt" ]]; then
    if [[ ! -s "${sg}" ]]; then
      echo "[syn] ${name}: generating (Kronecker, scale ${scale}, degree ${deg})"
      "${CONVERTER}" -g "${scale}" -k "${deg}" -s -b "${sg}"
    fi
    echo "[syn] ${name}: serialized graph -> GACGE bin, weights, sources"
    "${SG2BIN}" "${sg}" "${bin}" "data/src_nodes/${name}" "${dir}/meta.txt"
    printf 'kind=%s\nscale=%s\ndegree=%s\npct=%s\n' "${kind}" "${scale}" "${deg}" "${pct}" >> "${dir}/meta.txt"
    find "${RAW}" -maxdepth 1 -name "${name}.sg" -delete
  fi
  if [[ -n "${SYNC}" ]]; then
    echo "[syn] ${name}: sync to ${SYNC}"
    { ssh "${SYNC}" "mkdir -p GACGE/data/bin/${name} GACGE/data/src_nodes GACGE/data/xb/${name}" \
      && rsync -a "data/bin/${name}/" "${SYNC}:GACGE/data/bin/${name}/" \
      && rsync -a "data/src_nodes/${name}_src_nodes.txt" "${SYNC}:GACGE/data/src_nodes/" \
      && rsync -a "${dir}/meta.txt" "${SYNC}:GACGE/data/xb/${name}/meta.txt"; } || echo "[syn] ${name}: sync to ${SYNC} failed (generate there instead)" >&2
  fi
  cat "${dir}/meta.txt" | tr '\n' ' '; echo
done
