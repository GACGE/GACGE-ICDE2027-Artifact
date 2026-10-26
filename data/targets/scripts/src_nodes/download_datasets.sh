#!/usr/bin/env bash
# Fetch the src_nodes datasets from Cloudflare R2 (object and checksum in ../r2-manifest.json).
# The OneDrive links this used to read went dead in 2026-10; the archives were
# rebuilt from an existing machine's data/src_nodes and uploaded to R2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../download_r2_dataset.sh" src_nodes
