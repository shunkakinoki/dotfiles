#!/usr/bin/env bash
# Keep CLI operations on the installed service runtime and keep an update alive
# when an agent invokes it from inside the server it is about to restart.
set -euo pipefail

base="${T3CODE_HOME:-$HOME/.t3}"
cli="${T3_REAL_CLI:-$HOME/.bun/bin/t3}"
state="$base/runtime/service-state.json"
if [ -f "$state" ]; then
  # A running server can be newer than the recorded active version when an
  # update did not commit its state, so prefer the version that is serving.
  version="$(node -e '
    const fs = require("fs");
    const [state, serverRecord, versions] = process.argv.slice(1);
    const release = /^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;
    const active = JSON.parse(fs.readFileSync(state, "utf8")).activeVersion;
    if (!release.test(active)) {
      throw new Error("Invalid active T3 runtime version");
    }
    let version = active;
    try {
      const server = JSON.parse(fs.readFileSync(serverRecord, "utf8"));
      process.kill(server.pid, 0);
      if (release.test(server.serverVersion)) {
        fs.accessSync(versions + "/" + server.serverVersion + "/t3", fs.constants.X_OK);
        version = server.serverVersion;
      }
    } catch {}
    process.stdout.write(version);
  ' "$state" "$base/userdata/server-runtime.json" "$base/runtime/versions")"
  runtime="$base/runtime/versions/$version/t3"
  if [ ! -x "$runtime" ]; then
    printf 'Active T3 runtime is unavailable: %s\n' "$runtime" >&2
    exit 1
  fi
  cli="$runtime"
elif [ "$(uname -s)" = Darwin ] && serving="$(node -e '
  const fs = require("fs");
  const release = /^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;
  try {
    const server = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    process.kill(server.pid, 0);
    if (release.test(server.serverVersion)) process.stdout.write(server.serverVersion);
  } catch {}
' "$base/userdata/server-runtime.json")" && [ -n "$serving" ]; then
  # The macOS desktop app serves T3 without installing a service runtime, so
  # run the CLI release that matches the server it talks to.
  exec npx --yes "t3@$serving" "$@"
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
