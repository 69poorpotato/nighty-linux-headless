#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# nighty-linux-headless — docker start script
#
#  Run this AFTER uploading your Nighty.exe to start the Docker container.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; R=$'\033[31m'; M=$'\033[95m'; N=$'\033[0m'; else B=; G=; Y=; C=; R=; M=; N=; fi

print_header() { printf "\n%s%s============================================================%s\n %s %s\n%s%s============================================================%s\n\n" "$C" "$B" "$N" "🚀" "$1" "$C" "$B" "$N"; }
print_step() { printf "%s▶ %s%s\n" "$Y" "$1" "$N"; }
print_success() { printf "%s✔ %s%s\n" "$G" "$1" "$N"; }
print_error() { printf "%s✖ %s%s\n" "$R" "$1" "$N"; }

DIR="$(pwd)"

print_header "DOCKER DEPLOYMENT PROCESS"

if [ ! -f "Nighty.exe" ]; then
  print_error "Nighty.exe not found in $DIR!"
  printf "%sPlease upload your licensed Nighty.exe using SFTP (FileZilla/WinSCP), then run this script again.%s\n\n" "$Y" "$N"
  exit 1
fi
print_success "Nighty.exe found!"

mkdir -p docker-secrets data
chmod 700 docker-secrets

read_secret_if_missing() {
  local file="$1" prompt="$2" hidden="${3:-0}" value=""
  [ -s "$file" ] && return 0
  printf '%s%s%s ' "$M" "$prompt" "$N"
  if [ "$hidden" = 1 ]; then read -rs value; printf '\n'; else read -r value; fi
  [ -n "$value" ] || { print_error "Value cannot be empty."; exit 1; }
  umask 077
  printf '%s\n' "$value" > "$file"
}

read_secret_if_missing docker-secrets/webui_username "Enter Web UI username:"
read_secret_if_missing docker-secrets/webui_password "Enter Web UI password (8+ characters):" 1
WEBUI_PASS="$(head -n 1 docker-secrets/webui_password)"
[ "${#WEBUI_PASS}" -ge 8 ] || { print_error "Web UI password must contain at least 8 characters."; exit 1; }
case "$WEBUI_PASS" in secret|change-this-please) print_error "Refusing an unsafe default password."; exit 1 ;; esac
unset WEBUI_PASS

# Match the image user to the invoking host user so bind-mounted data remains
# writable on regular Linux accounts. Root-driven installs use the conventional
# first-user UID/GID instead of creating a root container user.
if [ "$(id -u)" -eq 0 ]; then
  export PUID="${PUID:-${SUDO_UID:-1000}}" PGID="${PGID:-${SUDO_GID:-1000}}"
else
  export PUID="${PUID:-$(id -u)}" PGID="${PGID:-$(id -g)}"
fi

# Ensure the container user can read the secrets regardless of UID
chmod 700 docker-secrets
chmod 644 docker-secrets/* 2>/dev/null || true
chown -R "$PUID:$PGID" data 2>/dev/null || true

print_step "Stopping existing containers (if any)..."
docker compose down 2>/dev/null || true

print_step "Building new Docker image (This WILL take a few minutes, please be patient)..."
docker compose build

print_step "Starting new container in background..."
docker compose up -d

print_header "DEPLOYMENT FINISHED"
printf "%s%s✔ Your bot is running securely in the background!%s\n\n" "$G" "$B" "$N"
printf "To view live logs anytime, run:\n"
printf "  %scd %s && docker compose logs -f nighty%s\n\n" "$C" "$DIR" "$N"
