#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'neverssl-keepalive/keepalive.sh'
SCRIPT="$PWD/home-manager/services/neverssl-keepalive/keepalive.sh"

Describe 'curl behavior'
setup() {
  mock_bin_setup curl
}

cleanup() {
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'calls curl to neverssl.com'
When run bash -c "bash '$SCRIPT' 2>&1; cat '$MOCK_LOG'"
The output should include 'curl'
The output should include 'neverssl.com'
The status should be success
End

It 'uses http protocol (not https)'
When run bash -c "bash '$SCRIPT' 2>&1; cat '$MOCK_LOG'"
The output should include 'http://neverssl.com'
The status should be success
End

It 'sets max-time timeout'
When run bash -c "bash '$SCRIPT' 2>&1; cat '$MOCK_LOG'"
The output should include '--max-time'
The output should include '10'
The status should be success
End
End

Describe 'error handling'
setup() {
  MOCK_BIN=$(mktemp -d)
  export PATH="$MOCK_BIN:$PATH"
  MOCK_ORIGINAL_PATH="$PATH"

  # Create failing curl mock
  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$MOCK_BIN/curl"
}

cleanup() {
  rm -rf "$MOCK_BIN"
  export PATH="$MOCK_ORIGINAL_PATH"
}

Before 'setup'
After 'cleanup'

It 'exits 0 even when curl fails'
When run bash "$SCRIPT"
The status should be success
The stderr should include 'FAIL'
End

It 'logs failure to stderr when curl fails'
When run bash "$SCRIPT"
The output should eq ''
The stderr should include 'FAIL'
The status should be success
End
End

Describe 'script properties'
It 'uses strict mode (set -euo pipefail)'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'has a descriptive comment'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'captive portal'
End
End

Describe 'Starbucks WiFi detection (macOS)'
It 'checks for macOS via OSTYPE'
When run bash -c "cat '$SCRIPT'"
The output should include 'OSTYPE'
The output should include 'darwin'
End

It 'uses networksetup to get SSID'
When run bash -c "cat '$SCRIPT'"
The output should include 'networksetup -getairportnetwork'
End

It 'checks for STARBUCKS SSID pattern'
When run bash -c "cat '$SCRIPT'"
The output should include '*"STARBUCKS"*'
End

It 'restarts WiFi when connectivity fails'
When run bash -c "cat '$SCRIPT'"
The output should include 'networksetup -setairportpower'
The output should include 'sleep 3'
End
End

End
