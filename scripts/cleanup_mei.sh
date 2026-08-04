#!/usr/bin/env bash
# Remove stale PyInstaller one-file extraction directories from Nighty's
# dedicated Wine prefix. Run Nighty through run.sh; it calls this helper only
# while no backend process should be using the prefix.

set -u

DRY_RUN=0
QUIET=0
PREFIX="${WINEPREFIX:-}"

usage() {
  cat <<'EOF'
Usage: cleanup_mei.sh [--dry-run] [--quiet] [--prefix PATH]

Removes only directories named _MEI* directly below:
  PREFIX/drive_c/users/*/AppData/Local/Temp/

Stop Nighty before running this helper manually. --dry-run only lists matches.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --quiet) QUIET=1 ;;
    --prefix)
      shift
      [ "$#" -gt 0 ] || { echo "[mei-cleanup] ERROR: --prefix requires a path." >&2; exit 2; }
      PREFIX="$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[mei-cleanup] ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[ -n "$PREFIX" ] || { echo "[mei-cleanup] ERROR: WINEPREFIX is empty." >&2; exit 2; }
[ -d "$PREFIX" ] || exit 0

# Resolve the prefix before constructing any deletion target. Refuse broad or
# malformed paths even though normal calls use ~/.local/share/nighty/prefix.
PREFIX="$(cd -P -- "$PREFIX" 2>/dev/null && pwd)" || {
  echo "[mei-cleanup] ERROR: cannot resolve WINEPREFIX." >&2
  exit 2
}
case "$PREFIX" in
  /|/home|/root|/usr|/var|/tmp)
    echo "[mei-cleanup] ERROR: refusing unsafe WINEPREFIX: $PREFIX" >&2
    exit 2
    ;;
esac

USERS_ROOT="$PREFIX/drive_c/users"
[ -d "$USERS_ROOT" ] || exit 0

FOUND=0
REMOVED=0
FAILED=0

while IFS= read -r -d '' TEMP_DIR; do
  # Do not accept symlinked Temp directories. The expected Wine directories
  # are real directories inside the resolved prefix.
  [ ! -L "$TEMP_DIR" ] || continue
  case "$TEMP_DIR" in
    "$USERS_ROOT"/*/AppData/Local/Temp) ;;
    *) continue ;;
  esac

  while IFS= read -r -d '' CANDIDATE; do
    [ ! -L "$CANDIDATE" ] || continue
    NAME="${CANDIDATE##*/}"
    case "$NAME" in _MEI*) ;; *) continue ;; esac
    FOUND=$((FOUND + 1))

    if [ "$DRY_RUN" -eq 1 ]; then
      printf '[mei-cleanup] would remove: %s\n' "$CANDIDATE"
      continue
    fi

    if rm -rf -- "$CANDIDATE" && [ ! -e "$CANDIDATE" ]; then
      REMOVED=$((REMOVED + 1))
    else
      FAILED=$((FAILED + 1))
      printf '[mei-cleanup] WARNING: failed to remove: %s\n' "$CANDIDATE" >&2
    fi
  done < <(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d -name '_MEI*' -print0 2>/dev/null)
done < <(find "$USERS_ROOT" -mindepth 4 -maxdepth 4 -type d -path '*/AppData/Local/Temp' -print0 2>/dev/null)

if [ "$QUIET" -ne 1 ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[mei-cleanup] dry run: %s stale PyInstaller director%s found.\n' \
      "$FOUND" "$([ "$FOUND" -eq 1 ] && printf 'y' || printf 'ies')"
  elif [ "$REMOVED" -gt 0 ] || [ "$FAILED" -gt 0 ]; then
    printf '[mei-cleanup] removed %s stale PyInstaller director%s; failures: %s.\n' \
      "$REMOVED" "$([ "$REMOVED" -eq 1 ] && printf 'y' || printf 'ies')" "$FAILED"
  fi
fi

[ "$FAILED" -eq 0 ]
