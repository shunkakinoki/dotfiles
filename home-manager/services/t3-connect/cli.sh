#!/usr/bin/env bash
# Keep CLI operations on the installed service runtime and keep an update alive
# when an agent invokes it from inside the server it is about to restart.
set -euo pipefail

base="${T3CODE_HOME:-$HOME/.t3}"
cli="${T3_REAL_CLI:-$HOME/.bun/bin/t3}"
state="$base/runtime/service-state.json"
if [ -f "$state" ]; then
  version="$(node -e '
    const state = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    if (!/^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/.test(state.activeVersion)) {
      throw new Error("Invalid active T3 runtime version");
    }
    process.stdout.write(state.activeVersion);
  ' "$state")"
  runtime="$base/runtime/versions/$version/t3"
  if [ ! -x "$runtime" ]; then
    printf 'Active T3 runtime is unavailable: %s\n' "$runtime" >&2
    exit 1
  fi
  cli="$runtime"
fi
if [ ! -x "$cli" ]; then
  printf 'T3 CLI is missing; activate the managed npm packages first.\n' >&2
  exit 1
fi

# T3's launcher marks its process tree. /proc also covers children whose login
# shell dropped the marker. A transient unit is a separate cgroup; --no-block
# lets the initiating turn finish before the update interrupts the server.
disruptive=false
case "${1:-}" in
update | uninstall) disruptive=true ;;
service)
  case "${2:-}" in
  install | update | restart | uninstall) disruptive=true ;;
  esac
  ;;
esac
inside_service=false
if [ "${T3_BOOT_SERVICE_UNIT:-}" = t3code.service ] ||
  grep -qsE '/t3code\.service(/|$)' "${T3_PROC_CGROUP:-/proc/self/cgroup}"; then
  inside_service=true
fi
if "$disruptive" && "$inside_service"; then
  if [ "${1:-}" = update ]; then
    # The delegated job has no terminal for the updater's restart prompt.
    set -- "$@" --yes
  fi
  unit="t3-cli-$(date +%s)-$$"
  "${T3_SYSTEMD_RUN:-systemd-run}" --user --collect --no-block \
    --unit="$unit" --property=Type=exec --working-directory="$PWD" \
    --setenv="HOME=$HOME" --setenv="T3CODE_HOME=$base" \
    --setenv=T3_BOOT_SERVICE_UNIT= \
    "$0" "$@"
  printf 'T3 service operation queued as %s; inspect it with journalctl --user -u %s.\n' "$unit" "$unit"
  exit 0
fi
exec "$cli" "$@"
