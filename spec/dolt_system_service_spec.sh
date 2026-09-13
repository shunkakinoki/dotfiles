#!/usr/bin/env bash
# shellcheck disable=SC2329
Describe 'authoritative Dolt system service'
UNIT="$PWD/home-manager/services/dolt/dolt.service"
MODULE="$PWD/home-manager/services/dolt/default.nix"

Describe 'dolt.service'
It 'runs as the Kyber login user under the system manager'
When run bash -c "grep -qxF 'User=@user@' '$UNIT' && grep -qxF 'WantedBy=multi-user.target' '$UNIT'"
The status should be success
End

It 'never stops restarting'
When run bash -c "grep -qxF 'Restart=always' '$UNIT' && grep -qxF 'StartLimitIntervalSec=0' '$UNIT'"
The status should be success
End

It 'is shielded from the OOM killer'
When run grep -xF 'OOMScoreAdjust=-900' "$UNIT"
The output should include 'OOMScoreAdjust=-900'
End

It 'takes the bfq maximum weight without a bandwidth cap'
When run bash -c "grep -qxF 'IOWeight=10000' '$UNIT' && ! grep -Eq '^IO(Read|Write)(Bandwidth|IOPS)Max=' '$UNIT'"
The status should be success
End
End

Describe 'Home Manager wiring'
It 'no longer defines a user unit for the server'
When run bash -c "grep -F 'systemd.user.services.dolt =' '$MODULE'"
The status should be failure
End

It 'does not make Linear sync depend on a user-manager Dolt unit'
When run bash -c "sed -n '/systemd.user.services.dolt-linear-sync/,/^      };/p' '$MODULE' | grep -F 'dolt.service'"
The status should be failure
End
End

Describe 'activate-system-service.sh'
setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/etc"
  cat >"$TEST_ROOT/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[ "$1" = -n ] && shift
exec "$@"
EOF
  cat >"$TEST_ROOT/bin/systemctl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$TEST_ROOT/calls"
if [ "\$1 \$2" = "--user is-active" ]; then
  [ -f "$TEST_ROOT/user-active" ]
fi
EOF
  chmod +x "$TEST_ROOT/bin/sudo" "$TEST_ROOT/bin/systemctl"
  printf '[Service]\nUser=ubuntu\n' >"$TEST_ROOT/dolt.service"
  sed -e "s|/usr/bin/systemctl|$TEST_ROOT/bin/systemctl|g" \
    -e "s|@systemctl@|$TEST_ROOT/bin/systemctl|g" \
    -e "s|/etc/systemd/system/dolt.service|$TEST_ROOT/etc/dolt.service|g" \
    home-manager/services/dolt/activate-system-service.sh >"$TEST_ROOT/activate.sh"
}
cleanup() { rm -rf "$TEST_ROOT"; }
Before setup
After cleanup

activate() {
  PATH="$TEST_ROOT/bin:$PATH" bash "$TEST_ROOT/activate.sh" "$TEST_ROOT/dolt.service"
}

It 'installs a changed unit and restarts the server'
When call activate
The output should include 'Installing'
The contents of file "$TEST_ROOT/etc/dolt.service" should equal "$(cat "$TEST_ROOT/dolt.service")"
The contents of file "$TEST_ROOT/calls" should include 'daemon-reload'
The contents of file "$TEST_ROOT/calls" should include 'restart dolt.service'
End

It 'stops the former user unit before starting the system unit'
touch "$TEST_ROOT/user-active"
When call activate
The output should include 'Stopping the Dolt user service'
The line 3 of contents of file "$TEST_ROOT/calls" should equal '--user stop dolt.service'
The line 5 of contents of file "$TEST_ROOT/calls" should equal 'restart dolt.service'
End

It 'leaves a running server alone when the unit is unchanged'
cp "$TEST_ROOT/dolt.service" "$TEST_ROOT/etc/dolt.service"
When call activate
The output should equal ''
The contents of file "$TEST_ROOT/calls" should not include 'restart'
The contents of file "$TEST_ROOT/calls" should include 'start dolt.service'
End
End
End
