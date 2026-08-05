#!/usr/bin/env bash
# Architecture-aware Wine command construction. Arrays keep paths and arguments
# safe and let ARM hosts invoke x86-64 Wine explicitly through Box64 instead of
# relying on host-level binfmt registration (which is normally absent in Docker).

NIGHTY_WINE_COMMAND=()
NIGHTY_WINESERVER_COMMAND=()

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
