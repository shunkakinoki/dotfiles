#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'optional GPG import on fresh hosts'
SCRIPT="$PWD/home-manager/activation/import-gpg-key.sh"

setup() {
  mock_bin_setup rage gpg
  touch "$MOCK_BIN/gpg.age" "$MOCK_BIN/identity"
  cat >"$MOCK_BIN/gpg" <<'EOF'
#!/usr/bin/env bash
printf 'gpg %s\n' "$*" >>"$MOCK_LOG"
if [ "$1" = --list-secret-keys ]; then
  if [ "${MOCK_HAS_KEY:-false}" = true ]; then printf '%s\n' TEST_FINGERPRINT; fi
else
  cat >/dev/null
fi
EOF
  cat >"$MOCK_BIN/rage" <<'EOF'
#!/usr/bin/env bash
printf 'rage %s\n' "$*" >>"$MOCK_LOG"
if [ "${MOCK_DECRYPT_FAILURE:-false}" = true ]; then exit 7; fi
printf '%s\n' test-key-material
EOF
}
cleanup() { mock_bin_cleanup; }
Before setup
After cleanup

It 'skips the optional import when the SSH identity is absent'
When run bash -c 'bash "$1" "$MOCK_BIN/gpg.age" "$MOCK_BIN/missing-identity" rage gpg TEST_FINGERPRINT && cat "$MOCK_LOG"' _ "$SCRIPT"
The status should be success
The stderr should include 'skipping optional GPG key import'
The output should not include 'rage '
The output should not include 'gpg --batch --import'
End

It 'does not warn about the identity when the GPG key is already imported'
When run env MOCK_HAS_KEY=true bash "$SCRIPT" "$MOCK_BIN/gpg.age" "$MOCK_BIN/missing-identity" rage gpg TEST_FINGERPRINT
The status should be success
The output should eq ''
The stderr should eq ''
End

It 'imports the encrypted key when its identity is present'
When run bash -c 'bash "$1" "$MOCK_BIN/gpg.age" "$MOCK_BIN/identity" rage gpg TEST_FINGERPRINT && cat "$MOCK_LOG"' _ "$SCRIPT"
The status should be success
The output should include 'GPG key imported successfully'
The output should include 'rage -d -i'
The output should include 'gpg --batch --import'
End

It 'continues to report a decryption failure for an existing identity'
When run env MOCK_DECRYPT_FAILURE=true bash "$SCRIPT" "$MOCK_BIN/gpg.age" "$MOCK_BIN/identity" rage gpg TEST_FINGERPRINT
The status should be failure
The output should include 'Importing GPG key from agenix'
The output should not include 'GPG key imported successfully'
End

It 'skips absent encrypted material'
When run bash "$SCRIPT" "$MOCK_BIN/missing-secret" "$MOCK_BIN/identity" rage gpg TEST_FINGERPRINT
The status should be success
The output should eq ''
The stderr should eq ''
End
End
