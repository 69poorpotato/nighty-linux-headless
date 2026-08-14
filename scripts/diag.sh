#!/usr/bin/env bash
# Diagnostics helper for nighty-linux-headless
# Note: All logs and diagnostics are automatically collected in the diagnostics/ directory.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIAG_DIR="${NIGHTY_DIAG_DIR:-$HERE/diagnostics}"

python3 "$HERE/scripts/preflight.py" report --diag-dir "$DIAG_DIR"

echo
echo "ℹ️  All active diagnostic logs are available in: $DIAG_DIR"
echo "   (backend.log, bridge.log, guard.log, xvfb.log, stub_webview.log, nighty.log, system_info.txt)"
