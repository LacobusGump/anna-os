#!/usr/bin/env bash
# Anna:OS security audit — runs Jim's Sentinel locally. No cloud. $0.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SENTINEL_DIR="${HOME}/.anna-sentinel" \
LOG_FILE="${HOME}/.anna-sentinel/sentinel.log" \
bash "${ROOT}/sentinel/sentinel.sh" "${1:-audit}"