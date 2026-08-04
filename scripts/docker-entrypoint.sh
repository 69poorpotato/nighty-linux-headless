#!/usr/bin/env bash
set -e

# Ensure .env exists so install.sh doesn't copy .env.example and overwrite docker-compose variables
touch /app/.env

# Default env vars if not provided by docker-compose
export NIGHTY_EXE="${NIGHTY_EXE:-/app/Nighty.exe}"
export NIGHTY_HOME="${NIGHTY_HOME:-/data/nighty}"
export WINEPREFIX="${WINEPREFIX:-$NIGHTY_HOME/prefix}"

# Check if the executable is mounted
if [ ! -f "$NIGHTY_EXE" ]; then
    echo "ERROR: Nighty.exe not found at $NIGHTY_EXE"
    echo "Please mount your licensed Nighty.exe into the container."
    echo "Example: -v /path/to/your/Nighty.exe:/app/Nighty.exe:ro"
    exit 1
fi

echo "=== Running pre-flight setup (install.sh) ==="
# install.sh handles missing deps, repacking, and /etc/hosts modifications.
# It automatically uses sudo when necessary (e.g. for /etc/hosts).
bash scripts/install.sh

echo "=== Setup complete, starting orchestrator ==="
exec bash scripts/run.sh once
