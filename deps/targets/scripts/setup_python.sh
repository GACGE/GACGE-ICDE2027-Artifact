#!/usr/bin/env bash
# setup_python.sh: Miniforge into deps/conda and the two Python environments every script of this repository runs
# in (the root Makefile puts deps/conda/envs/gacge/bin first on PATH once it exists):
#   gacge         Python 3.12, matplotlib 3.11.1, numpy 2.5.2, pillow 12.3.0 (everything, Figs. 4 and 8-10)
#   gacge-mpl382  Python 3.12, matplotlib 3.8.2, numpy 1.26.4, pillow 12.3.0 (Figs. 5-7, as the paper drew them)
# An environment that already holds these versions is kept.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONDA_DIR="${CONDA_DIR:-${ROOT}/deps/conda}"

if [[ ! -x "${CONDA_DIR}/bin/conda" ]]; then
  case "$(uname -s)" in Linux) os=Linux ;; Darwin) os=MacOSX ;; *) echo "unsupported OS $(uname -s)" >&2; exit 1 ;; esac
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/miniforge.XXXXXX")"; installer="${tmp}/Miniforge3.sh"  # the installer wants a .sh name
  echo "[setup-python] Miniforge (${os}-$(uname -m)) into ${CONDA_DIR}"
  wget -q -O "${installer}" "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-${os}-$(uname -m).sh" \
    || curl -fsSL -o "${installer}" "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-${os}-$(uname -m).sh"
  bash "${installer}" -b -p "${CONDA_DIR}" >/dev/null
  rm -rf "${tmp}"
fi

env_ok() {  # env_ok <env> <matplotlib> <numpy>
  "${CONDA_DIR}/envs/$1/bin/python" -c "
import sys, matplotlib, numpy, PIL
sys.exit(not (sys.version_info[:2] == (3, 12) and matplotlib.__version__ == '$2' and numpy.__version__ == '$3'
              and PIL.__version__ == '12.3.0'))" 2>/dev/null
}
make_env() {  # make_env <env> <matplotlib> <numpy>
  if env_ok "$@"; then echo "[setup-python] $1: ready"; return; fi
  echo "[setup-python] $1: Python 3.12, matplotlib $2, numpy $3, pillow 12.3.0"
  [[ -x "${CONDA_DIR}/envs/$1/bin/python" ]] || "${CONDA_DIR}/bin/conda" create -q -y -n "$1" python=3.12 pip >/dev/null
  "${CONDA_DIR}/envs/$1/bin/python" -m pip install -q --disable-pip-version-check \
    "matplotlib==$2" "numpy==$3" "pillow==12.3.0"
  env_ok "$@" || { echo "[setup-python] $1: the versions did not install" >&2; exit 1; }
}
make_env gacge 3.11.1 2.5.2
make_env gacge-mpl382 3.8.2 1.26.4
