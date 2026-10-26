#!/usr/bin/env bash
# Fetch the GACGE binary CSR of all 18 datasets from Cloudflare R2 (object and
# checksum in ../r2-manifest.json) into data/bin: the graph every GAP and
# Gunrock program reads (measure/common/datasets.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../download_r2_dataset.sh" bin
