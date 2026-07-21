#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DEFAULT_ROOT="$(dirname -- "$SCRIPT_DIR")"
ROOT="${NIGHTY_TEST_ROOT:-$DEFAULT_ROOT}"
SERVICE="${NIGHTY_SERVICE:-nighty.service}"

cd "$ROOT" || exit 2
before="$(systemctl show -p MainPID --value "$SERVICE")"
before_ready="$(curl -fsS --max-time 3 http://127.0.0.1:8088/ready)" || exit 3

output="$(timeout 15 bash scripts/run.sh once 2>&1)"
rc=$?

after="$(systemctl show -p MainPID --value "$SERVICE")"
after_ready="$(curl -fsS --max-time 3 http://127.0.0.1:8088/ready)" || exit 4

echo "GUARD_RC=$rc"
printf '%s\n' "$output"
echo "SERVICE_PID_BEFORE=$before"
echo "SERVICE_PID_AFTER=$after"
echo "READY_BEFORE=$before_ready"
echo "READY_AFTER=$after_ready"
echo "TEST_PROCESSES"
for proc in /proc/[0-9]*; do
  [ -r "$proc/cmdline" ] || continue
  while IFS= read -r -d '' arg; do
    case "$arg" in
      "$ROOT/scripts/run.sh"|"$ROOT/scripts/bridge.py"|"$ROOT/scripts/webui_guard.py")
        printf '%s %s\n' "${proc##*/}" "$arg"
        ;;
    esac
  done <"$proc/cmdline" 2>/dev/null
done

if [ "$rc" -eq 0 ] \
   && [ "$before" = "$after" ] \
   && [ "$(systemctl is-active "$SERVICE")" = active ] \
   && printf '%s' "$after_ready" | grep -q '"ready"'; then
  echo "DUPLICATE_GUARD_TEST=PASS"
  exit 0
fi

echo "DUPLICATE_GUARD_TEST=FAIL"
exit 1
