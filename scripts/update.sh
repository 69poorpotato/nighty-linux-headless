#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# nighty-linux-headless - Auto-Updater
# Safely pulls the latest updates from GitHub and restarts the bot.
# Supports both Docker and Bare Metal deployments on ARM64 and X64.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ] && [ "${BASH_SOURCE[0]:0:5}" != "/dev/" ]; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  HERE="${NIGHTY_DOCKER_DIR:-$HOME/nighty-linux-headless}"
fi
cd "$HERE"

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; R=$'\033[31m'; N=$'\033[0m'; else B=; G=; Y=; C=; R=; N=; fi
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
info() { printf '%s==>%s %s\n' "$C" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
need() { command -v "$1" >/dev/null 2>&1; }

SUDO=""
if [ "$(id -u)" -ne 0 ] && need sudo; then SUDO="sudo"; fi

printf "\n%s%s============================================================%s\n" "$C" "$B" "$N"
printf " %snighty-linux-headless - auto-updater%s\n" "$B" "$N"
printf "%s%s============================================================%s\n\n" "$C" "$B" "$N"

if ! need git; then
  warn "Git is not installed. Cannot update."
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  warn "Not inside a git repository ($HERE). Cannot update."
  exit 1
fi

info "Pulling latest updates from GitHub..."
stashed=0
if ! git diff --quiet HEAD 2>/dev/null; then
  git stash >/dev/null 2>&1 || true
  stashed=1
fi

if ! git pull origin main; then
    warn "Failed to pull updates from GitHub. Check your network or git status."
    if [ "$stashed" -eq 1 ]; then git stash pop >/dev/null 2>&1 || true; fi
    exit 1
fi

if [ "$stashed" -eq 1 ]; then
  git stash pop >/dev/null 2>&1 || true
fi
ok "Repository updated to latest version"

# Determine deployment type
is_docker=0
if need docker && [ -f "$HERE/docker-compose.yml" ]; then
  is_docker=1
fi

if [ "$is_docker" -eq 1 ]; then
  info "Detected Docker deployment. Restarting container with new updates..."
  if docker compose up -d; then
    ok "Docker container successfully updated and restarted!"
  else
    warn "Failed to restart Docker container."
  fi
else
  info "Detected Bare Metal deployment. Re-running installer for new dependencies..."
  bash scripts/install.sh
  
  info "Restarting Nighty service..."
  if need systemctl && systemctl is-active --quiet nighty.service; then
    if ${SUDO:+$SUDO -n} systemctl restart nighty.service; then
      ok "nighty.service restarted!"
    else
      warn "Failed to restart nighty.service. You may need to start it manually."
    fi
  else
    warn "systemd service not active. Please restart Nighty manually using 'bash scripts/run.sh'."
  fi
fi

echo
printf '%sDone.%s Your Nighty installation is now up to date.\n' "$G" "$N"
