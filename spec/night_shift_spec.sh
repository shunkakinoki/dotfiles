#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/night-shift/apply-night-shift.sh'
SCRIPT="$PWD/home-manager/services/night-shift/apply-night-shift.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'passes bash syntax check after replacing placeholders'
When run bash -c "sed -e 's|@nightlightBin@|/usr/bin/true|g' -e 's|@temperature@|100|g' '$SCRIPT' | bash -n"
The status should be success
End
End

setup_night_shift_script() {
  TEST_DIR=$(mktemp -d)
  NIGHTLIGHT_LOG="$TEST_DIR/nightlight.log"
  NIGHTLIGHT_BIN="$TEST_DIR/nightlight"
  PREPROCESSED_SCRIPT="$TEST_DIR/apply-night-shift.sh"
  : >"$NIGHTLIGHT_LOG"

  cat >"$NIGHTLIGHT_BIN" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >>"$NIGHTLIGHT_LOG"
EOF
  chmod +x "$NIGHTLIGHT_BIN"

  sed \
    -e "s|@nightlightBin@|$NIGHTLIGHT_BIN|g" \
    -e 's|@temperature@|100|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"
}

cleanup_night_shift_script() {
  rm -rf "$TEST_DIR"
}

Describe 'applying the Night Shift default'
Before 'setup_night_shift_script'
After 'cleanup_night_shift_script'

It 'clears the schedule before turning Night Shift on'
When run bash -c ': >"'"$NIGHTLIGHT_LOG"'"; NIGHTLIGHT_LOG="'"$NIGHTLIGHT_LOG"'" "'"$PREPROCESSED_SCRIPT"'" >/dev/null && cat "'"$NIGHTLIGHT_LOG"'"'
The status should be success
The line 1 of output should eq 'schedule stop'
The line 2 of output should eq 'temp 100'
The line 3 of output should eq 'on'
End
End

End
