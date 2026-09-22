#!/usr/bin/env bash
# Small activation phases keep identity checks before the write boundary.
set -euo pipefail

case "${1:?activation phase required}" in
check)
  name="${2:?name required}"
  identity="${3:?identity file required}"
  if [ "$(id -u)" != 0 ] || [ "$(cat /proc/1/comm)" != systemd ]; then
    echo "Kamino requires root on a systemd Linux machine." >&2
    exit 1
  fi
  if [ -f "$identity" ] && [ "$(cat "$identity")" != "$name" ]; then
    echo "Refusing to rename an installed Kamino machine." >&2
    exit 1
  fi
  ;;
prepare)
  mkdir -p /etc/sudoers.d
  ;;
user-manager)
  hostnamectl set-hostname "${2:?name required}"
  loginctl enable-linger root
  systemctl start user@0.service
  ;;
start-herdr)
  systemctl_bin="${2:?systemctl binary required}"
  export XDG_RUNTIME_DIR=/run/user/0
  "$systemctl_bin" --user daemon-reload || true
  "$systemctl_bin" --user enable --now herdr-server.service || true
  ;;
tailscale)
  name="${2:?name required}"
  tailscale_bin="${3:?tailscale binary required}"
  shift 3
  "$tailscale_bin" up "$@"
  echo "Tailscale enrollment and preferences applied for $name."
  ;;
t3-connect)
  # Provision T3 Connect for this worker. The background server reconciles the
  # link on start, so install/repair it first. Workers default to publish-only
  # because the relay caps managed tunnels per account; `managed` opts a host
  # into a relay tunnel so clients can sign in with T3 Connect. Authorization
  # uses the OAuth device flow on the first run and is skipped once a
  # credential is stored.
  t3_bin="${2:-}"
  t3_mode="${3:-publish-only}"
  case "$t3_mode" in
  managed) link_flags=() ;;
  publish-only) link_flags=(--publish-only) ;;
  *)
    echo "Unknown T3 Connect mode: $t3_mode" >&2
    exit 1
    ;;
  esac
  if [ -z "$t3_bin" ]; then
    t3_bin="$(command -v t3 || true)"
  fi
  if [ -z "$t3_bin" ] || [ ! -x "$t3_bin" ]; then
    echo "t3 is not installed; skipping T3 Connect provisioning." >&2
    exit 0
  fi
  # The t3 native binary links libatomic, which Kamino hosts do not ship.
  if [ -n "${4:-}" ]; then
    export LD_LIBRARY_PATH="$4${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  fi

  base="${T3CODE_HOME:-$HOME/.t3}"
  state="$base/runtime/service-state.json"

  # A release that requires launcher protocol 3 cannot be activated by a
  # protocol-2 launcher, and the desktop client hands off exactly such updates.
  # A protocol-3 launcher is only produced by a protocol-3 release, so
  # bootstrapping one needs a nightly CLI rather than the pinned global. After
  # that the service is left alone: the desktop owns version upgrades, and
  # running a protocol-2 `service install` here would downgrade the launcher
  # and break the client's update path again.
  if [ ! -f "$state" ] || ! grep -q '"protocol": 3' "$state"; then
    echo "T3 launcher needs a protocol-3 release; bootstrapping with t3@nightly." >&2
    npx --yes t3@nightly service install ||
      npx --yes t3@nightly service update ||
      echo "Warning: could not install the T3 background service." >&2
  fi

  if [ -f "$base/userdata/secrets/cloud-cli-oauth-token.bin" ]; then
    "$t3_bin" connect link ${link_flags[@]+"${link_flags[@]}"}
  else
    "$t3_bin" connect link --headless ${link_flags[@]+"${link_flags[@]}"}
  fi
  systemctl --user daemon-reload || true
  systemctl --user enable --now t3code.service || true
  systemctl --user restart t3code.service || true
  echo "T3 Connect $t3_mode link requested."
  ;;
*)
  echo "Unknown Kamino activation phase" >&2
  exit 1
  ;;
esac
