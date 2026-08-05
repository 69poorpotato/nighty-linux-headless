#!/usr/bin/env bash
# Architecture-aware Wine command construction. Arrays keep paths and arguments
# safe and let ARM hosts use a working Box64 binfmt registration when available,
# with explicit Box64 invocation as a portable fallback.

NIGHTY_WINE_COMMAND=()
NIGHTY_WINESERVER_COMMAND=()

nighty_box64_binfmt_ready() {
  local root="${NIGHTY_BINFMT_ROOT:-/proc/sys/fs/binfmt_misc}" handler interpreter
  [ -d "$root" ] || return 1
  for handler in "$root"/*; do
    [ -f "$handler" ] || continue
    grep -qx 'enabled' "$handler" 2>/dev/null || continue
    interpreter="$(sed -n 's/^interpreter //p' "$handler" 2>/dev/null | head -n 1)"
    case "$interpreter" in
      *box64*) [ -x "$interpreter" ] && return 0 ;;
    esac
  done
  return 1
}

nighty_configure_wine_command() {
  local wine_bin="$1" arch="${2:-$(uname -m)}" box64_bin="" server_bin=""
  NIGHTY_WINE_COMMAND=("$wine_bin")
  NIGHTY_WINESERVER_COMMAND=()
  server_bin="${wine_bin%64}server"

  case "$arch" in
    x86_64|amd64)
      [ -x "$server_bin" ] && NIGHTY_WINESERVER_COMMAND=("$server_bin")
      ;;
    *)
      if nighty_box64_binfmt_ready; then
        [ -x "$server_bin" ] && NIGHTY_WINESERVER_COMMAND=("$server_bin")
        return 0
      fi
      box64_bin="$(command -v box64 2>/dev/null || true)"
      if [ -z "$box64_bin" ]; then
        echo "[run] FATAL: Box64 is required to run x86-64 Wine on $arch." >&2
        return 1
      fi
      NIGHTY_WINE_COMMAND=("$box64_bin" "$wine_bin")
      [ -x "$server_bin" ] && NIGHTY_WINESERVER_COMMAND=("$box64_bin" "$server_bin")
      ;;
  esac
}

nighty_stop_wineserver() {
  if [ "${#NIGHTY_WINESERVER_COMMAND[@]}" -gt 0 ]; then
    "${NIGHTY_WINESERVER_COMMAND[@]}" -k 2>/dev/null || true
  elif command -v wineserver >/dev/null 2>&1; then
    wineserver -k 2>/dev/null || true
  fi
}
