#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/services/docker/setup-docker.sh'
SCRIPT="$PWD/home-manager/services/docker/setup-docker.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[a-z_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder substitutions'
It 'references @shadow@ for groups and usermod'
When run bash -c "grep '@shadow@' '$SCRIPT'"
The output should include '@shadow@'
End

It 'references @gnugrep@'
When run bash -c "grep '@gnugrep@' '$SCRIPT'"
The output should include '@gnugrep@'
End

It 'references @systemd@'
When run bash -c "grep '@systemd@' '$SCRIPT'"
The output should include '@systemd@'
End

It 'references @coreutils@'
When run bash -c "grep '@coreutils@' '$SCRIPT'"
The output should include '@coreutils@'
End

It 'references @docker_service_file@'
When run bash -c "grep '@docker_service_file@' '$SCRIPT'"
The output should include '@docker_service_file@'
End
End

Describe 'docker group management'
It 'checks group membership'
When run bash -c "grep 'docker group' '$SCRIPT'"
The output should include 'docker group'
End

It 'uses usermod to add user to docker group'
When run bash -c "grep 'usermod' '$SCRIPT'"
The output should include 'usermod'
End
End

Describe 'daemon management'
It 'checks if docker daemon is active'
When run bash -c "grep 'is-active' '$SCRIPT'"
The output should include 'is-active'
End

It 'installs service file to /etc/systemd'
When run bash -c "grep '/etc/systemd/system/docker.service' '$SCRIPT'"
The output should include '/etc/systemd/system/docker.service'
End

It 'enables docker on boot'
When run bash -c "grep 'enable docker' '$SCRIPT'"
The output should include 'enable docker'
End
End

Describe 'activation behavior'
setup_mock() {
  WORK=$(mktemp -d)
  mkdir -p "$WORK/bin" "$WORK/run/systemd/system" "$WORK/etc/systemd/system" "$WORK/etc/docker" "$WORK/etc/sysctl.d" "$WORK/proc/sys/fs/inotify" "$WORK/proc/sys/user"
  cat >"$WORK/docker.service.new" <<'EOF'
[Service]
ExecStart=/nix/store/new-docker/bin/dockerd
KillMode=process
EOF
  cat >"$WORK/daemon.json.new" <<'EOF'
{"live-restore": true}
EOF
  cat >"$WORK/etc/sysctl.d/99-docker-inotify.conf" <<'EOF'
fs.inotify.max_user_instances = 1024
user.max_inotify_instances = 1024
EOF
  echo "1024" >"$WORK/proc/sys/fs/inotify/max_user_instances"
  echo "1024" >"$WORK/proc/sys/user/max_inotify_instances"
  cat >"$WORK/bin/id" <<'EOF'
#!/usr/bin/env bash
case "$1" in
-u) echo "${MOCK_UID:-0}" ;;
-un) echo "${MOCK_USER:-root}" ;;
-Gn) echo "${MOCK_GROUPS:-root docker}" ;;
*) exit 1 ;;
esac
EOF
  printf '#!/usr/bin/env bash\necho "groupadd $*" >>"%s/calls.log"\n' "$WORK" >"$WORK/bin/groupadd"
  printf '#!/usr/bin/env bash\necho "usermod $*" >>"%s/calls.log"\n' "$WORK" >"$WORK/bin/usermod"
  cat >"$WORK/bin/systemctl" <<EOF
#!/usr/bin/env bash
echo "systemctl \$*" >>"$WORK/calls.log"
if [ "\$1" = "is-active" ]; then
  exit "\${MOCK_DOCKER_ACTIVE:-0}"
fi
EOF
  for tool in tee mkdir install diff grep; do
    ln -sf "$(command -v "$tool")" "$WORK/bin/$tool"
  done
  printf '#!/usr/bin/env bash\nexit 0\n' >"$WORK/bin/getent"
  cat >"$WORK/bin/sudo" <<'EOF'
#!/usr/bin/env bash
if [ "${MOCK_SUDO_FAIL:-0}" = "1" ]; then
  exit 1
fi
if [ "$1" = "-n" ]; then
  shift
fi
if [ "$1" = "true" ]; then
  exit 0
fi
exec "$@"
EOF
  chmod +x "$WORK/bin/id" "$WORK/bin/groupadd" "$WORK/bin/usermod" "$WORK/bin/systemctl" "$WORK/bin/getent" "$WORK/bin/sudo"
  sed \
    -e "s|@coreutils@/bin|$WORK/bin|g" \
    -e "s|@shadow@/bin|$WORK/bin|g" \
    -e "s|@gnugrep@/bin|$WORK/bin|g" \
    -e "s|@systemd@/bin|$WORK/bin|g" \
    -e "s|@diffutils@/bin|$WORK/bin|g" \
    -e "s|@docker_service_file@|$WORK/docker.service.new|g" \
    -e "s|@docker_daemon_file@|$WORK/daemon.json.new|g" \
    -e "s|/etc/NIXOS|$WORK/etc/NIXOS|g" \
    -e "s|/run/systemd/system|$WORK/run/systemd/system|g" \
    -e "s|/etc/systemd/system/docker.service|$WORK/etc/systemd/system/docker.service|g" \
    -e "s|/etc/docker|$WORK/etc/docker|g" \
    -e "s|/etc/sysctl.d/99-docker-inotify.conf|$WORK/etc/sysctl.d/99-docker-inotify.conf|g" \
    -e "s|/proc/sys/|$WORK/proc/sys/|g" \
    "$SCRIPT" >"$WORK/setup-docker.sh"
  chmod +x "$WORK/setup-docker.sh"
}

cleanup_mock() {
  rm -rf "$WORK"
}

Before 'setup_mock'
After 'cleanup_mock'

It 'skips on NixOS hosts without modifying unit files'
touch "$WORK/etc/NIXOS"
When run env PATH="$WORK/bin:$PATH" bash "$WORK/setup-docker.sh" --non-interactive
The status should be success
The file "$WORK/etc/systemd/system/docker.service" should not be exist
End

It 'skips when systemd is not running'
rmdir "$WORK/run/systemd/system"
When run env PATH="$WORK/bin:$PATH" bash "$WORK/setup-docker.sh" --non-interactive
The status should be success
The file "$WORK/etc/systemd/system/docker.service" should not be exist
End

It 'skips cleanly in non-interactive mode when passwordless sudo is unavailable'
When run env PATH="$WORK/bin:$PATH" MOCK_UID=1000 MOCK_SUDO_FAIL=1 bash "$WORK/setup-docker.sh" --non-interactive
The status should be success
The error should include 'non-interactive root access unavailable'
The file "$WORK/etc/systemd/system/docker.service" should not be exist
End

It 'matches exact docker group name rather than hyphenated substrings'
cp "$WORK/docker.service.new" "$WORK/etc/systemd/system/docker.service"
cp "$WORK/daemon.json.new" "$WORK/etc/docker/daemon.json"
When run env PATH="$WORK/bin:$PATH" USER=alice MOCK_UID=0 MOCK_GROUPS="alice docker-users" MOCK_DOCKER_ACTIVE=0 bash "$WORK/setup-docker.sh" --non-interactive
The status should be success
The output should include 'Adding user to docker group'
The contents of file "$WORK/calls.log" should include 'usermod -aG docker alice'
End

It 'updates stale docker.service store paths and restarts docker during activation'
printf '[Service]\nExecStart=/nix/store/old-docker/bin/dockerd\n' >"$WORK/etc/systemd/system/docker.service"
cp "$WORK/daemon.json.new" "$WORK/etc/docker/daemon.json"
When run env PATH="$WORK/bin:$PATH" MOCK_UID=0 MOCK_DOCKER_ACTIVE=0 bash "$WORK/setup-docker.sh" --non-interactive
The status should be success
The output should include 'Updating Docker systemd service'
The output should include 'Docker daemon restarted'
The contents of file "$WORK/etc/systemd/system/docker.service" should include '/nix/store/new-docker/bin/dockerd'
The contents of file "$WORK/calls.log" should include 'systemctl daemon-reload'
The contents of file "$WORK/calls.log" should include 'systemctl reload docker'
The contents of file "$WORK/calls.log" should include 'systemctl restart docker'
End
End

End
