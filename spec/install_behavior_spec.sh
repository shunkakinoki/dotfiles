#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'install.sh behavior'

setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/dotfiles"

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
  printf '%s\n' "${MOCK_UID:-0}"
else
  printf '%s\n' root
fi
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
exit 0
EOF
  cat >"$TEST_ROOT/bin/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
  cat >"$TEST_ROOT/bin/make" <<'EOF'
#!/usr/bin/env bash
printf 'INSTALL_HOST=%s INSTALL_USER=%s T3_DEFER=%s\n' "$HOST" "$USER" "${KAMINO_T3_CONNECT_DEFER:-}"
EOF
  chmod +x "$TEST_ROOT/bin"/*

  cat >"$TEST_ROOT/run-installer" <<EOF
#!/usr/bin/env bash
set -e
host=\${1:?host required}
if [ -n "\${MOCK_SAVED:-}" ]; then
  mkdir -p "$TEST_ROOT/home/.config/kamino"
  printf '%s\\n' "\$MOCK_SAVED" >"$TEST_ROOT/home/.config/kamino/name"
else
  /bin/rm -f "$TEST_ROOT/home/.config/kamino/name"
fi
env PATH="$TEST_ROOT/bin:/usr/bin:/bin" HOME="$TEST_ROOT/home" HOST="\$host" USER=stale-user GITHUB_PR= \\
  MOCK_OS="\${MOCK_OS:-Linux}" MOCK_UID="\${MOCK_UID:-0}" MOCK_INIT="\${MOCK_INIT:-systemd}" \\
  MOCK_NIX_RESULT="\${MOCK_NIX_RESULT:-0}" sh "$PWD/install.sh"
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

It 'defers first T3 authorization for the piped Kamino installer'
When run bash -c 'printf "" | "$1" kamino7' _ "$TEST_ROOT/run-installer"
The status should be success
The output should include 'INSTALL_HOST=kamino7 INSTALL_USER=root T3_DEFER=1'
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
End
