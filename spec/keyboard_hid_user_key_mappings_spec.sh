#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'nix-darwin/config/keyboard/apply-hid-user-key-mappings.sh'
SCRIPT="$PWD/nix-darwin/config/keyboard/apply-hid-user-key-mappings.sh"

render_script() {
  local src="$1" hidutil_bin="$2" calls_file="$3" out="$4"
  awk \
    -v hidutil="$hidutil_bin" \
    -v calls_file="$calls_file" '
    {
      gsub(/@hidutilBin@/, hidutil)
      if (/@perDeviceCalls@/) {
        while ((getline line < calls_file) > 0) print line
        close(calls_file)
        next
      }
      print
    }
  ' "$src" >"$out"
  chmod +x "$out"
}

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'passes bash syntax check after replacing placeholders'
When run bash -c "sed -e 's|@hidutilBin@|/usr/bin/hidutil|g' -e 's|@perDeviceCalls@||g' '$SCRIPT' | bash -n"
The status should be success
End

It 'defines apply_mapping helper'
When run bash -c "grep 'apply_mapping()' '$SCRIPT'"
The output should include 'apply_mapping()'
End

It 'invokes hidutil property with --matching and --set'
When run bash -c "grep -c -- '--matching .* --set' '$SCRIPT' | tr -d ' '"
The output should equal '1'
End
End

setup_keyboard_script() {
  TEST_DIR=$(mktemp -d)
  HIDUTIL_LOG="$TEST_DIR/hidutil.log"
  HIDUTIL_BIN="$TEST_DIR/hidutil"
  PREPROCESSED_SCRIPT="$TEST_DIR/apply-hid-user-key-mappings.sh"
  : >"$HIDUTIL_LOG"

  cat >"$HIDUTIL_BIN" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >>"$HIDUTIL_LOG"
if [ "${HIDUTIL_FAIL:-0}" = "1" ]; then
  exit 1
fi
EOF
  chmod +x "$HIDUTIL_BIN"

  CALLS_FILE="$TEST_DIR/calls.txt"
  cat >"$CALLS_FILE" <<'EOF'
apply_mapping '{"VendorID":1452,"ProductID":591}' '{"UserKeyMapping":[]}'
EOF
  render_script "$SCRIPT" "$HIDUTIL_BIN" "$CALLS_FILE" "$PREPROCESSED_SCRIPT"
}

cleanup_keyboard_script() {
  rm -rf "$TEST_DIR"
}

Describe 'mapping application'
Before 'setup_keyboard_script'
After 'cleanup_keyboard_script'

It 'invokes hidutil with the configured match and mapping'
When run bash -c ': >"'"$HIDUTIL_LOG"'"; HIDUTIL_LOG="'"$HIDUTIL_LOG"'" "'"$PREPROCESSED_SCRIPT"'" >/dev/null && cat "'"$HIDUTIL_LOG"'"'
The status should be success
The output should include 'property --matching {"VendorID":1452,"ProductID":591} --set {"UserKeyMapping":[]}'
End

It 'calls hidutil exactly once on success'
When run bash -c ': >"'"$HIDUTIL_LOG"'"; HIDUTIL_LOG="'"$HIDUTIL_LOG"'" "'"$PREPROCESSED_SCRIPT"'" >/dev/null && wc -l <"'"$HIDUTIL_LOG"'" | tr -d " "'
The status should be success
The output should equal '1'
End

It 'retries up to 5 times when hidutil fails'
When run bash -c ': >"'"$HIDUTIL_LOG"'"; HIDUTIL_FAIL=1 HIDUTIL_LOG="'"$HIDUTIL_LOG"'" "'"$PREPROCESSED_SCRIPT"'" >/dev/null && wc -l <"'"$HIDUTIL_LOG"'" | tr -d " "'
The status should be success
The output should equal '5'
End

It 'exits successfully even when all retries fail'
When run bash -c 'HIDUTIL_FAIL=1 HIDUTIL_LOG="'"$HIDUTIL_LOG"'" "'"$PREPROCESSED_SCRIPT"'"'
The status should be success
End
End

Describe 'multi-device support'
multi_device_setup() {
  TEST_DIR=$(mktemp -d)
  HIDUTIL_LOG="$TEST_DIR/hidutil.log"
  HIDUTIL_BIN="$TEST_DIR/hidutil"
  PREPROCESSED_SCRIPT="$TEST_DIR/apply-hid-user-key-mappings.sh"
  : >"$HIDUTIL_LOG"

  cat >"$HIDUTIL_BIN" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >>"$HIDUTIL_LOG"
EOF
  chmod +x "$HIDUTIL_BIN"

  CALLS_FILE="$TEST_DIR/calls.txt"
  cat >"$CALLS_FILE" <<'EOF'
apply_mapping '{"VendorID":1452,"ProductID":591}' '{"UserKeyMapping":[]}'
apply_mapping '{"VendorID":1133,"ProductID":50475}' '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":1,"HIDKeyboardModifierMappingDst":2}]}'
EOF
  render_script "$SCRIPT" "$HIDUTIL_BIN" "$CALLS_FILE" "$PREPROCESSED_SCRIPT"
}

multi_device_cleanup() {
  rm -rf "$TEST_DIR"
}

Before 'multi_device_setup'
After 'multi_device_cleanup'

It 'applies every mapping in the rendered list'
When run bash -c ': >"'"$HIDUTIL_LOG"'"; HIDUTIL_LOG="'"$HIDUTIL_LOG"'" "'"$PREPROCESSED_SCRIPT"'" >/dev/null && wc -l <"'"$HIDUTIL_LOG"'" | tr -d " "'
The status should be success
The output should equal '2'
End

It 'preserves each device-specific match selector'
When run bash -c ': >"'"$HIDUTIL_LOG"'"; HIDUTIL_LOG="'"$HIDUTIL_LOG"'" "'"$PREPROCESSED_SCRIPT"'" >/dev/null && cat "'"$HIDUTIL_LOG"'"'
The status should be success
The output should include '"VendorID":1452,"ProductID":591'
The output should include '"VendorID":1133,"ProductID":50475'
End
End

End
