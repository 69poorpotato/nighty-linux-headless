#!/usr/bin/env bash
set -u

ROOT="${NIGHTY_TEST_ROOT:-/home/pi/nighty_test}"
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
pgrep -af '/home/pi/nighty_test/scripts/(run|bridge|webui_guard).(sh|py)' || true

if [ "$rc" -eq 0 ] \
   && [ "$before" = "$after" ] \
   && [ "$(systemctl is-active "$SERVICE")" = active ] \
   && printf '%s' "$after_ready" | grep -q '"ready"'; then
  echo "DUPLICATE_GUARD_TEST=PASS"
  exit 0
fi

echo "DUPLICATE_GUARD_TEST=FAIL"
exit 1
