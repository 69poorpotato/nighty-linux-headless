#!/usr/bin/env bash
set -euo pipefail

load_secret() {
    local name="$1" file="$2" value="${!1:-}"
    if [ -z "$value" ] && [ -r "$file" ]; then
        IFS= read -r value < "$file" || true
    fi
    [ -n "$value" ] || {
        echo "ERROR: $name is missing. Run: bash scripts/docker-start.sh" >&2
        exit 2
    }
    printf -v "$name" '%s' "$value"
    export "$name"
}

load_secret WEBUI_USERNAME /run/secrets/webui_username
load_secret WEBUI_PASSWORD /run/secrets/webui_password

case "$WEBUI_PASSWORD" in
    secret|change-this-please)
        echo "ERROR: Refusing an unsafe default Web UI password." >&2
        exit 2
        ;;
esac
if [ "${#WEBUI_PASSWORD}" -lt 8 ]; then
    echo "ERROR: WEBUI_PASSWORD must contain at least 8 characters." >&2
    exit 2
fi

# Ensure .env exists so install.sh doesn't copy .env.example and overwrite docker-compose variables
: > /app/.env

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
