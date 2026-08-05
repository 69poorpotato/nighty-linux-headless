#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# nighty-linux-headless — docker installer
#
#  One-liner deployment script for Docker environments.
#  Usage: bash <(curl -sL https://raw.githubusercontent.com/glowxx/nighty-linux-headless/main/scripts/docker-install.sh)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; R=$'\033[31m'; M=$'\033[95m'; N=$'\033[0m'; else B=; G=; Y=; C=; R=; M=; N=; fi

print_header() { printf "\n%s%s============================================================%s\n %s %s\n%s%s============================================================%s\n\n" "$C" "$B" "$N" "🚀" "$1" "$C" "$B" "$N"; }
print_step() { printf "%s▶ %s%s\n" "$Y" "$1" "$N"; }
print_success() { printf "%s✔ %s%s\n" "$G" "$1" "$N"; }
print_error() { printf "%s✖ %s%s\n" "$R" "$1" "$N"; }
need() { command -v "$1" >/dev/null 2>&1; }

print_header "NIGHTY-LINUX-HEADLESS - DOCKER DEPLOYMENT"

# ── Ensure dependencies ──────────────────────────────────────────────────────
install_git() {
  need git && return 0
  print_step "Installing git..."
  if need apt-get; then sudo apt-get update && sudo apt-get install -y git
  elif need dnf; then sudo dnf install -y git
  elif need pacman; then sudo pacman -S --noconfirm --needed git
  elif need zypper; then sudo zypper --non-interactive install git
  else print_error "Install git manually, then run this script again."; exit 1
  fi
}
install_git

if ! need docker; then
  print_step "Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh >/dev/null 2>&1
  rm get-docker.sh
fi

DIR="${NIGHTY_DOCKER_DIR:-$HOME/nighty-linux-headless}"
if [ ! -d "$DIR" ]; then
  print_step "Cloning repository to $DIR..."
  git clone https://github.com/glowxx/nighty-linux-headless.git "$DIR" >/dev/null 2>&1
fi

cd "$DIR"

# ── Configuration ────────────────────────────────────────────────────────────
printf "%s%sEnter desired Web UI Username:%s " "$M" "$B" "$N"
read -r WEBUI_USER
printf "%s%sEnter desired Web UI Password:%s " "$M" "$B" "$N"
read -rs WEBUI_PASS
printf '\n'

[ -n "$WEBUI_USER" ] || { print_error "Username cannot be empty."; exit 1; }
[ "${#WEBUI_PASS}" -ge 8 ] || { print_error "Password must contain at least 8 characters."; exit 1; }
case "$WEBUI_PASS" in secret|change-this-please) print_error "Choose a non-default password."; exit 1 ;; esac

# Store credentials as Compose secrets, never in docker-compose.yml or process
# arguments. Newlines are intentionally unsupported by Docker secret files.
umask 077
mkdir -p docker-secrets
printf '%s\n' "$WEBUI_USER" > docker-secrets/webui_username
printf '%s\n' "$WEBUI_PASS" > docker-secrets/webui_password

print_header "ALMOST DONE - ACTION REQUIRED"
printf "%s1. Upload your licensed 'Nighty.exe' to %s%s%s on your server.%s\n" "$Y" "$B" "$DIR" "$Y" "$N"
printf "%s   (You can use FileZilla, WinSCP, or your preferred SFTP client)%s\n\n" "$C" "$N"
printf "%s2. Once uploaded, run the start script:%s\n" "$Y" "$N"
printf "   %scd %s && bash scripts/docker-start.sh%s\n\n" "$C" "$DIR" "$N"
