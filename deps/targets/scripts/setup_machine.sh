#!/usr/bin/env bash
# setup_machine.sh <cpu|gpu>: everything one side needs before it measures, on this machine:
#   1. the system packages it lacks (apt-get; Ubuntu); on the GPU side also the CUDA 13.2 toolkit (nvcc, ncu) from
#      NVIDIA's apt repository when it is missing (the NVIDIA driver must be installed already),
#   2. Miniforge and the Python environments (setup_python.sh), and CMake 4.3.1 in the main one,
#   3. the programs of that side (the GPU side fetches Gunrock's dependencies first),
#   4. the graphs (make datasets datasets-syn).
# Every step skips what is already in place, so running it again is cheap.
set -euo pipefail
SIDE="${1:?usage: setup_machine.sh <cpu|gpu>}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT}"
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-13.2}"
say() { echo "[setup-${SIDE}] $*"; }
die() { echo "[setup-${SIDE}] $*" >&2; exit 1; }

sudo -n true 2>/dev/null || die "needs sudo without a password (perf, the prefetcher MSR and ncu run as root)"

# 1. system packages
pkgs=(build-essential git wget curl zstd tar)
[[ "${SIDE}" == cpu ]] && pkgs+=(msr-tools linux-tools-common "linux-tools-$(uname -r)")
if command -v apt-get >/dev/null; then
  missing=(); for p in "${pkgs[@]}"; do dpkg-query -W -f='${Status}' "${p}" 2>/dev/null | grep -q "ok installed" || missing+=("${p}"); done
  if (( ${#missing[@]} )); then
    say "apt-get install ${missing[*]}"
    sudo -n apt-get update -qq
    sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}" >/dev/null
  fi
else
  say "no apt-get: install ${pkgs[*]} yourself if a step below fails"
fi
if [[ "${SIDE}" == cpu ]]; then
  sudo -n perf stat -e instructions -x, true >/dev/null 2>&1 || die "sudo perf stat does not work (linux-tools for kernel $(uname -r)?)"
else
  command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1 || die "no working NVIDIA driver: install one that supports CUDA 13.2"
  drv="$(nvidia-smi | sed -n 's/.*CUDA Version: *\([0-9.]*\).*/\1/p' | head -1)"
  [[ "$(printf '%s\n13.2\n' "${drv}" | sort -V | head -1)" == 13.2 ]] || die "the NVIDIA driver supports CUDA ${drv:-?}; CUDA 13.2 needs a newer driver"
  if [[ ! -x "${CUDA_HOME}/bin/nvcc" || ! -x "${CUDA_HOME}/bin/ncu" ]]; then
    . /etc/os-release
    repo="https://developer.download.nvidia.com/compute/cuda/repos/${ID}${VERSION_ID//./}/$(uname -m | sed 's/aarch64/sbsa/')"
    say "CUDA 13.2 toolkit from ${repo}"
    keyring="$(mktemp --suffix=.deb)"
    wget -q -O "${keyring}" "${repo}/cuda-keyring_1.1-1_all.deb"
    sudo -n dpkg -i "${keyring}" >/dev/null && rm -f "${keyring}"
    sudo -n apt-get update -qq
    sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cuda-toolkit-13-2 >/dev/null
  fi
  export PATH="${CUDA_HOME}/bin:${PATH}"
fi

# 2. Python
deps/targets/scripts/setup_python.sh
export PATH="${ROOT}/deps/conda/envs/gacge/bin:${PATH}"
# CMake 4.3.1, as the paper's builds (the sources need 3.30 or newer; Ubuntu 24.04 ships 3.28), into the Python
# environment, which comes first on PATH
if [[ "$(cmake --version 2>/dev/null | sed -n 's/cmake version //p')" != 4.3.1 ]]; then
  say "CMake 4.3.1 into the Python environment"
  python3 -m pip install -q --disable-pip-version-check "cmake==4.3.1"
fi

# 3. programs
if [[ "${SIDE}" == cpu ]]; then
  ./src/targets/scripts/build_cpu
else
  ./deps/targets/scripts/gunrock/install.sh
  ./src/targets/scripts/build_gpu
  ./measure/gunrock-stock/targets/scripts/build_stock.sh local
fi

# 4. graphs
make datasets datasets-syn
say "done"
