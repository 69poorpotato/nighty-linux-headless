#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# nighty-linux-headless — docker start script
#
#  Run this AFTER uploading your Nighty.exe to start the Docker container.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

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

print_step "Stopping existing containers (if any)..."
docker compose down 2>/dev/null || true

print_step "Building new Docker image (This WILL take a few minutes, please be patient)..."
docker compose build -q

print_step "Starting new container in background..."
docker compose up -d

print_header "DEPLOYMENT FINISHED"
printf "%s%s✔ Your bot is running securely in the background!%s\n\n" "$G" "$B" "$N"
printf "To view live logs anytime, run:\n"
printf "  %scd %s && docker compose logs -f nighty%s\n\n" "$C" "$DIR" "$N"
