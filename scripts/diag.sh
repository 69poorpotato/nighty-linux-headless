#!/usr/bin/env bash
# Diagnostics script for nighty-linux-headless

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== NIGHTY LINUX HEADLESS DIAGNOSTICS ==="
echo "Date: $(date)"
echo "Host: $(uname -a 2>/dev/null || echo 'Unknown')"
echo "Directory: $HERE"
echo

# 1. System environment & requirements
echo "── System & Dependencies ──"
python3 "$HERE/scripts/preflight.py" libs || true
echo

# 2. Network connectivity diagnostics
echo "── Network Diagnostics ──"
python3 "$HERE/scripts/preflight.py" diag || true
echo

# 3. Running processes status
echo "── Process Status ──"
if pgrep -f "Nighty_stub.exe" >/dev/null 2>&1; then
  echo "Nighty Backend: RUNNING (PIDs: $(pgrep -f Nighty_stub.exe | tr '\n' ' '))"
else
  echo "Nighty Backend: NOT RUNNING"
fi

if pgrep -f "bridge.py" >/dev/null 2>&1; then
  echo "Bridge Proxy:   RUNNING (PIDs: $(pgrep -f bridge.py | tr '\n' ' '))"
else
  echo "Bridge Proxy:   NOT RUNNING"
fi

if pgrep -f "Xvfb" >/dev/null 2>&1; then
  echo "Xvfb Display:   RUNNING"
else
  echo "Xvfb Display:   NOT RUNNING"
fi
echo

# 4. Recent backend log tail
NIGHTY_HOME="${NIGHTY_HOME:-$HOME/.local/share/nighty}"
BACKEND_LOG="$NIGHTY_HOME/backend.log"
if [ -f "$BACKEND_LOG" ]; then
  echo "── Backend Log Tail (last 20 lines) ──"
  tail -n 20 "$BACKEND_LOG"
else
  echo "── Backend Log: (file not found at $BACKEND_LOG) ──"
fi

echo
echo "=== END DIAGNOSTICS ==="
