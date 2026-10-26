#!/usr/bin/env bash
# build_stock.sh <machine>: build Gunrock essentials' stock examples (src/gunrock-stock: bfs, sssp, pr, tc) into
# build/gunrock-stock. <machine> is an ssh host (its checkout is first brought to the pushed commit) or `local`.
# CUDA_ARCH (default 89, as the paper's builds) sets CMAKE_CUDA_ARCHITECTURES.
set -euo pipefail
MACHINE="${1:?usage: build_stock.sh <machine|local>}"
REMOTE_REPO_DIR="${REMOTE_REPO_DIR:-GACGE}"
BUILD="cmake -S src/gunrock-stock -B build/gunrock-stock -DCMAKE_BUILD_TYPE=Release -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH:-89} \
       -DESSENTIALS_BUILD_EXAMPLES=ON -DESSENTIALS_BUILD_TESTS=OFF -DESSENTIALS_BUILD_BENCHMARKS=OFF > build_gunrock_stock.log 2>&1 \
  && cmake --build build/gunrock-stock --target bfs sssp pr tc --parallel >> build_gunrock_stock.log 2>&1 \
  || { tail -30 build_gunrock_stock.log; exit 1; }"
if [[ "${MACHINE}" == local ]]; then
  cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && bash -c "set -e; ${BUILD}"
else
  ssh "${MACHINE}" "set -e; cd ~/${REMOTE_REPO_DIR} && git clean -fdq -- 'measure/*/outputs/*' \
    && { git checkout -q -- 'measure/*/outputs/*' 2>/dev/null || true; } && git pull -q --ff-only && ${BUILD}"
fi
