#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'install.sh behavior'
SCRIPT="${INSTALL_SCRIPT:-$PWD/install.sh}"

setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/dotfiles" "$TEST_ROOT/ubuntu/dotfiles" "$TEST_ROOT/ubuntu/.nix-profile"
  ln -s "$TEST_ROOT/bin" "$TEST_ROOT/ubuntu/.nix-profile/bin"

  cat >"$TEST_ROOT/bin/uname" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = -m ]; then
  printf '%s\n' x86_64
else
  printf '%s\n' "${MOCK_OS:-Linux}"
fi
EOF
  cat >"$TEST_ROOT/bin/id" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = -u ]; then
  if [ "${MOCK_EFFECTIVE_USER:-}" = ubuntu ]; then
    printf '%s\n' 1000
  else
    printf '%s\n' "${MOCK_UID:-0}"
  fi
else
  printf '%s\n' "${MOCK_EFFECTIVE_USER:-${MOCK_CURRENT_USER:-root}}"
fi
EOF
  cat >"$TEST_ROOT/bin/hostname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_HOSTNAME:-generic-linux}"
EOF
  cat >"$TEST_ROOT/bin/getent" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2" = 'passwd root' ]; then
  printf 'root:x:0:0::%s:/bin/bash\n' "$MOCK_ROOT_HOME"
  exit 0
fi
if [ "${MOCK_MISSING_UBUNTU:-}" = true ] && [ ! -f "$MOCK_UBUNTU_HOME/account-created" ]; then exit 2; fi
printf 'ubuntu:x:%s:1000::%s:/bin/bash\n' "${MOCK_UBUNTU_UID:-1000}" "$MOCK_UBUNTU_HOME"
EOF
  cat >"$TEST_ROOT/bin/useradd" <<'EOF'
#!/usr/bin/env bash
printf 'USERADD_ARGS=%s\n' "$*"
if [ "${MOCK_USERADD_RESULT:-0}" != 0 ]; then exit "$MOCK_USERADD_RESULT"; fi
mkdir -p "$MOCK_UBUNTU_HOME"
printf '%s\n' created >>"$MOCK_UBUNTU_HOME/account-created"
EOF
  cat >"$TEST_ROOT/bin/sudo" <<'EOF'
#!/usr/bin/env bash
if [ "${MOCK_MISSING_UBUNTU:-}" = true ] && [ ! -f "$MOCK_UBUNTU_HOME/admin-policy" ]; then exit 1; fi
exit 0
EOF
  cat >"$TEST_ROOT/bin/visudo" <<'EOF'
#!/usr/bin/env bash
printf 'VALIDATED_RULE=%s\n' "$(/bin/cat "$2")"
exit "${MOCK_VISUDO_RESULT:-0}"
EOF
  cat >"$TEST_ROOT/bin/install" <<'EOF'
#!/usr/bin/env bash
if [ "$*" != '-d -m 0755 /etc/sudoers.d' ]; then exit 97; fi
EOF
  cat >"$TEST_ROOT/bin/mktemp" <<'EOF'
#!/usr/bin/env bash
if [ "$1" != /etc/sudoers.d/.dotfiles-beskar-ubuntu.XXXXXX ]; then exit 96; fi
exec /usr/bin/mktemp "$MOCK_UBUNTU_HOME/policy.XXXXXX"
EOF
  cat >"$TEST_ROOT/bin/mv" <<'EOF'
#!/usr/bin/env bash
if [ "$1" != -f ] || [ "$3" != /etc/sudoers.d/dotfiles-beskar-ubuntu ]; then exit 95; fi
exec /bin/mv -f "$2" "$MOCK_UBUNTU_HOME/admin-policy"
EOF
  cat >"$TEST_ROOT/bin/loginctl" <<'EOF'
#!/usr/bin/env bash
printf 'LOGINCTL_ARGS=%s\n' "$*"
EOF
  cat >"$TEST_ROOT/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'SYSTEMCTL_ARGS=%s\n' "$*"
EOF
  cat >"$TEST_ROOT/bin/runuser" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2 $3" != '-u ubuntu --' ]; then exit 98; fi
shift 3
export MOCK_EFFECTIVE_USER=ubuntu
exec "$@"
EOF
  cat >"$TEST_ROOT/bin/cat" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = /proc/1/comm ]; then
  printf '%s\n' "${MOCK_INIT:-systemd}"
else
  exec /bin/cat "$@"
fi
EOF
  cat >"$TEST_ROOT/bin/nix" <<'EOF'
#!/usr/bin/env bash
exit "${MOCK_NIX_RESULT:-0}"
EOF
  cat >"$TEST_ROOT/bin/git" <<'EOF'
#!/usr/bin/env bash
printf 'GIT_USER=%s GIT_UID=%s GIT_HOME=%s GIT_ARGS=%s\n' "$USER" "$(id -u)" "$HOME" "$*"
if [ "$1" = clone ] && [ "${MOCK_GIT_RESULT:-0}" = 0 ]; then mkdir -p "$3"; fi
exit "${MOCK_GIT_RESULT:-0}"
EOF
  cat >"$TEST_ROOT/bin/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
  cat >"$TEST_ROOT/bin/tailscale" <<'EOF'
#!/usr/bin/env bash
if [ -z "${MOCK_TAILNET_HOST:-}" ]; then exit 1; fi
printf '{"Self":{"DNSName":"%s"}}\n' "$MOCK_TAILNET_HOST"
EOF
  cat >"$TEST_ROOT/bin/jq" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "${MOCK_TAILNET_HOST:-}"
EOF
  cat >"$TEST_ROOT/bin/timeout" <<'EOF'
#!/usr/bin/env bash
shift
exec "$@"
EOF
  cat >"$TEST_ROOT/bin/make" <<'EOF'
#!/usr/bin/env bash
printf 'INSTALL_HOST=%s INSTALL_USER=%s\n' "$HOST" "$USER"
printf 'INSTALL_UID=%s INSTALL_HOME=%s INSTALL_LOGNAME=%s\n' "$(id -u)" "$HOME" "${LOGNAME:-}"
printf 'ROOT_XDG_CONFIG=%s ROOT_AGENT=%s\n' "${XDG_CONFIG_HOME:-unset}" "${SSH_AUTH_SOCK:-unset}"
exit "${MOCK_MAKE_RESULT:-0}"
EOF
  chmod +x "$TEST_ROOT/bin"/*

  cat >"$TEST_ROOT/run-installer" <<EOF
#!/usr/bin/env bash
set -e
host=\${1?host required}
if [ -n "\${MOCK_SAVED:-}" ]; then
  mkdir -p "$TEST_ROOT/home/.config/kamino"
  printf '%s\\n' "\$MOCK_SAVED" >"$TEST_ROOT/home/.config/kamino/name"
else
  /bin/rm -f "$TEST_ROOT/home/.config/kamino/name"
fi
env PATH="$TEST_ROOT/bin:/usr/bin:/bin" HOME="\${MOCK_INHERITED_HOME:-$TEST_ROOT/home}" HOST="\$host" USER=stale-user GITHUB_PR= \\
  MOCK_OS="\${MOCK_OS:-Linux}" MOCK_UID="\${MOCK_UID:-0}" MOCK_INIT="\${MOCK_INIT:-systemd}" \\
  MOCK_NIX_RESULT="\${MOCK_NIX_RESULT:-0}" MOCK_UBUNTU_HOME="$TEST_ROOT/ubuntu" MOCK_ROOT_HOME="$TEST_ROOT/home" \\
  sh < "$SCRIPT"
EOF
  chmod +x "$TEST_ROOT/run-installer"
}
cleanup() { rm -rf "$TEST_ROOT"; }
Before setup
After cleanup

It 'normalizes Kamino names and forwards them as root'
When run bash -c 'for name in kamino kamino1 KAMINO1 kamino100; do "$1" "$name" || exit 1; done' _ "$TEST_ROOT/run-installer"
The status should be success
The output should include 'INSTALL_HOST=kamino INSTALL_USER=root'
The output should include 'INSTALL_HOST=kamino1 INSTALL_USER=root'
The output should include 'INSTALL_HOST=kamino100 INSTALL_USER=root'
End

It 'keeps the installed identity on repeat installs'
When run env MOCK_SAVED=kamino1 "$TEST_ROOT/run-installer" KAMINO1
The status should be success
The output should include 'INSTALL_HOST=kamino1 INSTALL_USER=root'
End

It 'rejects invalid Kamino names before installation'
When run bash -c 'for name in kamino0 kamino01 kamino-1 "kamino*" "kamino1;id"; do if "$1" "$name" >/dev/null 2>&1; then exit 1; fi; done' _ "$TEST_ROOT/run-installer"
The status should be success
End

It 'rejects unsupported user, runtime, identity, and profile states'
When run bash -c '
set -e
runner="$1"
MOCK_UID=1000 "$runner" kamino1 >/dev/null 2>&1 && exit 1 || :
MOCK_OS=Darwin "$runner" kamino1 >/dev/null 2>&1 && exit 1 || :
MOCK_INIT=sh "$runner" kamino1 >/dev/null 2>&1 && exit 1 || :
MOCK_SAVED=kamino2 "$runner" kamino1 >/dev/null 2>&1 && exit 1 || :
MOCK_NIX_RESULT=1 "$runner" kamino1 >/dev/null 2>&1 && exit 1 || :
' _ "$TEST_ROOT/run-installer"
The status should be success
End

It 'runs Beskar checkout and activation as root when piped into a root shell'
When run env XDG_CONFIG_HOME=/root/.config SSH_AUTH_SOCK=/root/agent "$TEST_ROOT/run-installer" BESKAR
The status should be success
The output should include 'GIT_USER=root GIT_UID=0'
The output should include "GIT_HOME=$TEST_ROOT/home"
The output should include 'INSTALL_HOST=beskar INSTALL_USER=root'
The output should include "INSTALL_UID=0 INSTALL_HOME=$TEST_ROOT/home INSTALL_LOGNAME=root"
The output should not include 'USERADD_ARGS='
The output should not include 'VALIDATED_RULE='
End

It 'detects Beskar from its hostname without a HOST override'
When run env MOCK_HOSTNAME=beskar.example.test "$TEST_ROOT/run-installer" ''
The status should be success
The output should include 'INSTALL_HOST=beskar INSTALL_USER=root'
The output should include 'INSTALL_UID=0'
End

It 'uses the root account home instead of an inherited Ubuntu home'
When run env MOCK_INHERITED_HOME="$TEST_ROOT/ubuntu" "$TEST_ROOT/run-installer" beskar
The status should be success
The output should include "GIT_HOME=$TEST_ROOT/home"
The output should include "INSTALL_UID=0 INSTALL_HOME=$TEST_ROOT/home INSTALL_LOGNAME=root"
End

It 'rejects an unprivileged Tailscale-identified Beskar before checkout'
When run env MOCK_HOSTNAME=generic-linux MOCK_TAILNET_HOST=beskar.tailnet.example MOCK_UID=1000 "$TEST_ROOT/run-installer" ''
The status should be failure
The stderr should include 'Beskar installation requires root'
The output should not include 'GIT_USER='
End

It 'clones a fresh checkout in the root home as root'
When run bash -c 'rm -rf "$1/home/dotfiles"; "$1/run-installer" beskar' _ "$TEST_ROOT"
The status should be success
The output should include "Cloning dotfiles repository into $TEST_ROOT/home/dotfiles"
The output should include 'GIT_USER=root GIT_UID=0'
The output should include 'INSTALL_HOST=beskar INSTALL_USER=root'
End

It 'does not create an ubuntu account or administrative policy'
When run env MOCK_MISSING_UBUNTU=true "$TEST_ROOT/run-installer" beskar
The status should be success
The output should not include 'USERADD_ARGS='
The output should not include 'VALIDATED_RULE='
The output should not include 'LOGINCTL_ARGS=enable-linger ubuntu'
The output should include 'INSTALL_HOST=beskar INSTALL_USER=root'
End

It 'does not modify an existing ubuntu account'
When run "$TEST_ROOT/run-installer" beskar
The status should be success
The output should not include 'USERADD_ARGS='
The output should not include 'VALIDATED_RULE='
The output should include 'INSTALL_HOST=beskar INSTALL_USER=root'
End

It 'rejects an ubuntu installation before checkout or activation'
When run env MOCK_UID=1000 MOCK_CURRENT_USER=ubuntu "$TEST_ROOT/run-installer" beskar
The status should be failure
The stderr should include 'Beskar installation requires root'
The output should not include 'GIT_USER='
The output should not include 'INSTALL_HOST='
End

It 'rejects another unprivileged account on Beskar'
When run env MOCK_UID=1001 MOCK_CURRENT_USER=other "$TEST_ROOT/run-installer" beskar
The status should be failure
The stderr should include 'Beskar installation requires root'
The output should not include 'INSTALL_HOST='
End

It 'propagates failure from the root installation'
When run env MOCK_MAKE_RESULT=17 "$TEST_ROOT/run-installer" beskar
The status should eq 17
The output should include 'INSTALL_HOST=beskar INSTALL_USER=root'
End

It 'does not start activation after a failed root checkout update'
When run env MOCK_GIT_RESULT=19 "$TEST_ROOT/run-installer" beskar
The status should eq 19
The output should include 'GIT_USER=root GIT_UID=0'
The output should not include 'INSTALL_HOST='
End
End
