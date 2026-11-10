#!/usr/bin/env bash
# Reconcile ownership without restarting a healthy server or taking over work.
set -euo pipefail

systemctl="${T3_SYSTEMCTL:-systemctl}"
"$systemctl" --user daemon-reload
if ! "$systemctl" --user cat t3code.service >/dev/null 2>&1; then
  "${T3_SERVICE_CLI:?}" service install
fi
if "$systemctl" --user is-failed --quiet t3code.service; then
  "$systemctl" --user reset-failed t3code.service
fi
"$systemctl" --user enable --now t3code.service
set +e
node "${T3_CHECK_SERVICE:?}"
status=$?
set -e
# check-service reserves status 42 for an unmanaged owner. Preserve that
# process and let the rest of the Home Manager activation continue.
if [ "$status" -eq 42 ]; then
  echo "WARNING: T3 service ownership is unmanaged; continuing activation without taking it over." >&2
elif [ "$status" -ne 0 ]; then
  exit "$status"
fi
