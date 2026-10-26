#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <application>" >&2
  exit 2
fi

APP_NAME="$1"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
MANIFEST="${GACGE_R2_MANIFEST:-${SCRIPT_DIR}/r2-manifest.json}"

for command_name in python3 wget tar; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "[r2] Required command not found: ${command_name}" >&2
    exit 1
  fi
done

IFS=$'\t' read -r BASE_URL OBJECT_PATH EXPECTED_SIZE EXPECTED_SHA EXTRACT_REL MEMBERS_JSON < <(
  python3 - "${MANIFEST}" "${APP_NAME}" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
app_name = sys.argv[2]
with manifest_path.open(encoding="utf-8") as manifest_file:
    manifest = json.load(manifest_file)

try:
    app = manifest["applications"][app_name]
except KeyError:
    raise SystemExit(f"Application {app_name!r} is not present in {manifest_path}")

values = (
    manifest["base_url"].rstrip("/"),
    app["object"],
    str(app["compressed_size_bytes"]),
    app["sha256"],
    app["extract_directory"],
    json.dumps(app["members"], separators=(",", ":")),
)
if any("\t" in value or "\n" in value for value in values):
    raise SystemExit("Manifest values may not contain tabs or newlines")
print("\t".join(values))
PY
)

if [[ "${OBJECT_PATH}" = /* || "${OBJECT_PATH}" == *".."* ]]; then
  echo "[r2] Unsafe object path in manifest: ${OBJECT_PATH}" >&2
  exit 1
fi
if [[ "${OBJECT_PATH}" == *.zst ]] && ! command -v zstd >/dev/null 2>&1; then
  echo "[r2] ${APP_NAME} is zstd-compressed: install zstd (apt install zstd)" >&2
  exit 1
fi
if [[ "${EXTRACT_REL}" = /* || "${EXTRACT_REL}" == *".."* ]]; then
  echo "[r2] Unsafe extraction path in manifest: ${EXTRACT_REL}" >&2
  exit 1
fi

ARCHIVE_DIR="${REPO_DIR}/data/r2/${APP_NAME}"
ARCHIVE_PATH="${ARCHIVE_DIR}/$(basename -- "${OBJECT_PATH}")"
PARTIAL_PATH="${ARCHIVE_PATH}.part"
EXTRACT_DIR="${REPO_DIR}/${EXTRACT_REL}"
STAMP_PATH="${EXTRACT_DIR}/.stamp.r2-dataset"
DOWNLOAD_URL="${GACGE_R2_BASE_URL:-${BASE_URL}}/${OBJECT_PATH}"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

archive_is_valid() {
  [[ -f "${ARCHIVE_PATH}" ]] || return 1
  [[ "$(wc -c < "${ARCHIVE_PATH}" | tr -d ' ')" == "${EXPECTED_SIZE}" ]] || return 1
  [[ "$(sha256_file "${ARCHIVE_PATH}")" == "${EXPECTED_SHA}" ]]
}

mkdir -p "${ARCHIVE_DIR}" "${EXTRACT_DIR}"

members_present() {
  python3 - "${MEMBERS_JSON}" "${EXTRACT_DIR}" <<'PY'
import json, pathlib, sys
members = json.loads(sys.argv[1])
extract_dir = pathlib.Path(sys.argv[2])
sys.exit(0 if all((extract_dir / m).exists() for m in members) else 1)
PY
}

# Already extracted (every manifest member present) and no archive on disk:
# reuse the extracted data instead of re-downloading a multi-GB archive only
# to re-verify it (2026-09-24: this filled aws-pro6000's disk).  A stamp that
# matches the manifest is also accepted below; a stale archive still gets
# re-verified.
if [[ ! -e "${ARCHIVE_PATH}" ]] && members_present; then
  if [[ -f "${STAMP_PATH}" && "$(<"${STAMP_PATH}")" == "${EXPECTED_SHA}" ]]; then
    echo "[r2] ${APP_NAME} is already extracted and verified"
  else
    echo "[r2] ${APP_NAME} is already extracted (members present, archive absent); reusing without re-download"
  fi
  rm -f "${PARTIAL_PATH}"
  exit 0
fi

if archive_is_valid; then
  echo "[r2] Reusing verified archive: ${ARCHIVE_PATH}"
else
  if [[ -e "${ARCHIVE_PATH}" ]]; then
    INVALID_PATH="${ARCHIVE_PATH}.invalid.$(date +%Y%m%d%H%M%S)"
    echo "[r2] Preserving invalid archive as: ${INVALID_PATH}"
    mv "${ARCHIVE_PATH}" "${INVALID_PATH}"
  fi

  echo "[r2] Downloading ${DOWNLOAD_URL}"
  wget --continue --tries=5 --timeout=60 --progress=dot:giga \
    --output-document="${PARTIAL_PATH}" "${DOWNLOAD_URL}"
  mv "${PARTIAL_PATH}" "${ARCHIVE_PATH}"

  if ! archive_is_valid; then
    echo "[r2] Downloaded archive failed size or SHA-256 verification" >&2
    exit 1
  fi
fi

MEMBERS_OK="$(python3 - "${MEMBERS_JSON}" "${EXTRACT_DIR}" <<'PY'
import json
import pathlib
import sys

members = json.loads(sys.argv[1])
extract_dir = pathlib.Path(sys.argv[2])
print("yes" if all((extract_dir / member).exists() for member in members) else "no")
PY
)"

if [[ -f "${STAMP_PATH}" && "$(<"${STAMP_PATH}")" == "${EXPECTED_SHA}" && "${MEMBERS_OK}" == "yes" ]]; then
  echo "[r2] ${APP_NAME} is already extracted and verified"
  exit 0
fi

STAGING_DIR="$(mktemp -d "${EXTRACT_DIR}/.r2-extract.XXXXXX")"
cleanup_staging() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup_staging EXIT

echo "[r2] Extracting ${ARCHIVE_PATH}"
if [[ "${ARCHIVE_PATH}" == *.zst ]]; then
  zstd -q -dc "${ARCHIVE_PATH}" | tar -xf - -C "${STAGING_DIR}"
elif command -v pigz >/dev/null 2>&1; then
  pigz -dc -p "${DATA_PIGZ_THREADS:-8}" "${ARCHIVE_PATH}" |
    tar -xf - -C "${STAGING_DIR}"
else
  tar -xzf "${ARCHIVE_PATH}" -C "${STAGING_DIR}"
fi

python3 - "${MEMBERS_JSON}" "${STAGING_DIR}" <<'PY'
import json
import pathlib
import sys

members = json.loads(sys.argv[1])
staging_dir = pathlib.Path(sys.argv[2])
missing = [member for member in members if not (staging_dir / member).exists()]
if missing:
    raise SystemExit(f"Archive is missing required members: {', '.join(missing)}")
PY

while IFS= read -r MEMBER; do
  [[ -n "${MEMBER}" && "${MEMBER}" != "/" && "${MEMBER}" != *".."* ]] || {
    echo "[r2] Unsafe member path in manifest: ${MEMBER}" >&2
    exit 1
  }
  rm -rf "${EXTRACT_DIR:?}/${MEMBER}"
  mv "${STAGING_DIR}/${MEMBER}" "${EXTRACT_DIR}/${MEMBER}"
done < <(python3 - "${MEMBERS_JSON}" <<'PY'
import json
import sys

print("\n".join(json.loads(sys.argv[1])))
PY
)

printf '%s\n' "${EXPECTED_SHA}" > "${STAMP_PATH}"
# The stamp now vouches for the extracted members; the archive only doubles the
# disk use (bin: 36 GB extracted). GACGE_R2_KEEP_ARCHIVE=1 keeps it.
if [[ "${GACGE_R2_KEEP_ARCHIVE:-0}" != 1 ]]; then
  rm -f "${ARCHIVE_PATH}"
fi
echo "[r2] ${APP_NAME} dataset ready in ${EXTRACT_DIR}"
