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
node "${T3_CHECK_SERVICE:?}"
