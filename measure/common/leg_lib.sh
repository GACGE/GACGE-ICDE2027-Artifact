# Sourced by a leg script (measure/<unit>/targets/<kind>/legs.d/<Leg>.sh)
# after it sets
#   ARM    gpu | cpu                     (gpu: refuse to start on a busy GPU)
#   RUNS   array of "tag|drop_first|command template", one run per dataset each;
#          the template is evaluated on the remote host from the repo root
#          after `ds_vars <ds>` (measure/common/datasets.sh), so it may use
#          $ds $row $col $pbr $threads $ladj $ladj_w $gmtx $gmtx_w $src $nsrc
#          and $XB (build/bin/<unit>) $LIGRA $GUNROCK $GAP $PERF $NCU, and the
#          helpers of datasets.sh ($(cpu_hw_threads), $(xb_nomat_list_ratio $ds)).
#          drop_first=1: the program's first timed sample is its warm-up
#          (Ligra -rounds 11, Gunrock -n 11, GAP -n 11); the parser drops it.
#   LEG_DATASETS (optional) dataset names and the keywords `paper` (the paper's eight graphs, PAPER_DATASETS) and
#          `syn` (the synthetic size and density sweeps, SYN_DATASETS; measure/common/datasets.sh)
# and then calls `leg_main "$@"`.
# Knobs: FORCE=1 re-runs finished runs; DATASETS_ONLY=<ds>[,<ds>];
#        RUNS_ONLY=<tag>[,<tag>]; REMOTE_HOST (= MACHINE); REMOTE_REPO_DIR (GACGE); LOCAL=1 (or MACHINE=local).
# One log per dataset and run: $RAWS_DIR/<ds>.<tag>.log. A log is finished
# when it ends with `LegExit: rc=0` under the same `LegCmd:` line.
: "${MACHINE:?run through measure/common/run_leg.sh}"
source "${MEASURE_COMMON}/datasets.sh"
REMOTE_HOST="${REMOTE_HOST:-${MACHINE}}"
REMOTE_REPO_DIR="${REMOTE_REPO_DIR:-GACGE}"
# LOCAL=1 (or the machine named `local`): run on this machine in this checkout instead of over ssh
LOCAL="${LOCAL:-0}"; [[ "${REMOTE_HOST}" == local ]] && LOCAL=1
[[ "${LOCAL}" == 1 ]] && REMOTE_REPO_DIR="${REPO_ROOT}"
REMOTE_RAWS="measure/${UNIT}/outputs/${MACHINE}/raw/${KIND}/${LEG}"
LEG_TIMEOUT="${LEG_TIMEOUT:-7200}"

leg_datasets() {
  local all ds
  all=""
  for ds in ${LEG_DATASETS:-paper}; do
    case "${ds}" in paper) all+=" ${PAPER_DATASETS}" ;; syn) all+=" ${SYN_DATASETS}" ;; *) all+=" ${ds}" ;; esac
  done
  for ds in ${all}; do
    if [[ -z "${DATASETS_ONLY:-}" || ",${DATASETS_ONLY}," == *",${ds},"* ]]; then printf '%s\n' "${ds}"; fi
  done
}

# Runs on the remote host (sent with declare -f), from the repo checkout.
leg_remote() {
  set -uo pipefail
  local REPO="$1" RAWS="$2" UNIT="$3" ARM="$4" FORCE="$5" NAMES="$6" RUNS_ONLY="$7" LIMIT="$8"
  NUM_THREADS="$9"
  if [[ "${REPO}" == /* ]]; then cd "${REPO}" || exit 1; else cd ~/"${REPO}" || exit 1; fi
  source measure/common/datasets.sh
  GUNROCK="build/gunrock/bin"; GAP="build/gap/bin"
  PERF="sudo -n perf stat -x,"
  NCU="sudo -n $(command -v ncu || echo /usr/local/cuda/bin/ncu)"
  mkdir -p "${RAWS}"
  local ds entry tag drop tmpl cmd log busy r
  for ds in ${NAMES//,/ }; do
    ds_vars "${ds}"
    for entry in "${RUNS[@]}"; do
      IFS='|' read -r tag drop tmpl <<< "${entry}"
      [[ -z "${RUNS_ONLY}" || ",${RUNS_ONLY}," == *",${tag},"* ]] || continue
      eval "cmd=\"${tmpl}\""
      log="${RAWS}/${ds}.${tag}.log"
      if [[ "${FORCE}" != 1 && -f "${log}" ]] && grep -qxF "LegCmd: ${cmd}" "${log}" && grep -qx 'LegExit: rc=0' "${log}"; then
        echo "=== ${ds} ${tag}: already done, skipped ==="; continue
      fi
      if [[ "${ARM}" == gpu ]]; then
        busy="$(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null)"
        [[ -z "${busy}" ]] || { echo "GPU busy before ${ds} ${tag}: ${busy}" >&2; exit 3; }
      fi
      echo "=== ${ds} ${tag} ==="
      { echo "LegRun: host=$(hostname) git=$(git rev-parse --short HEAD) drop_first=${drop:-0} timeout_s=${LIMIT}"
        echo "LegCmd: ${cmd}"
        timeout "${LIMIT}" bash -c "${cmd}"
        r=$?; [[ ${r} -eq 124 ]] && echo "LegTimeout: limit_s=${LIMIT}"; echo "LegExit: rc=${r}"; } > "${log}" 2>&1
      grep -aE '^(XBResult|LegExit|LegTimeout)' "${log}" | tr '\n' ' '; echo
    done
  done
  echo "MEASURE DONE"
}

leg_measure() {
  local rc=0 args
  args="$(printf '%q ' "${REMOTE_REPO_DIR}" "${REMOTE_RAWS}" "${UNIT}" "${ARM}" "${FORCE:-0}" \
      "$(leg_datasets | paste -sd, -)" "${RUNS_ONLY:-}" "${LEG_TIMEOUT}" "${NUM_THREADS:-}")"
  if [[ "${LOCAL}" == 1 ]]; then  # on this machine, in this checkout: the raws land in place
    bash -s <<< "$(declare -p RUNS)
$(declare -f leg_remote)
leg_remote ${args}" || rc=$?
    return "${rc}"
  fi
  ssh "${REMOTE_HOST}" bash -s <<< "$(declare -p RUNS)
$(declare -f leg_remote)
leg_remote ${args}" || rc=$?
  [[ "${rc}" -eq 0 ]] || echo "[${LEG}] remote measure failed on ${REMOTE_HOST} (exit ${rc}); pulling what exists" >&2
  mkdir -p "${RAWS_DIR}"
  rsync -a "${REMOTE_HOST}:${REMOTE_REPO_DIR}/${REMOTE_RAWS}/" "${RAWS_DIR}/" || return 1
  return "${rc}"
}

# The leg's datasets plus every other dataset with a raw log here (a parse
# never drops graphs measured earlier under another dataset list).
parse_datasets() {
  { leg_datasets; ls "${RAWS_DIR}" 2>/dev/null | sed -n 's/^\([^.]*\)\..*\.log$/\1/p'; } | awk '!seen[$0]++' | paste -sd, -
}

leg_parse() {
  python3 "${MEASURE_COMMON}/leg_json.py" --unit "${UNIT}" --leg "${LEG}" --machine "${MACHINE}" \
    --raws "${RAWS_DIR}" --json "${JSON_DIR}/${LEG}.json" --md "${MD_DIR}/${LEG}.md" \
    --repo "${REPO_ROOT}" --datasets "$(parse_datasets)" \
    --tags "$(for e in "${RUNS[@]}"; do printf '%s,' "${e%%|*}"; done)"
}

leg_main() {
  case "${1:-parse}" in
    parse)   leg_parse ;;
    measure) leg_measure; local rc=$?; leg_parse; return "${rc}" ;;
    *) echo "usage: <leg>.sh [parse|measure]" >&2; return 2 ;;
  esac
}
