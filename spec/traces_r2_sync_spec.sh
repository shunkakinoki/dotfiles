#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'traces-r2-sync upload.sh'
__PREPROCESSED_DIR=$(mktemp -d)
__UPLOAD_SCRIPT="$__PREPROCESSED_DIR/upload.sh"
sed -e 's|@host@|kamino2|g' \
  "$PWD/home-manager/services/traces-r2-sync/upload.sh" >"$__UPLOAD_SCRIPT"

setup() {
  mock_bin_setup
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.config/agenix" "$TEMP_HOME/.claude/projects/repo" "$TEMP_HOME/.codex/sessions"
  printf '%s\n' 'DOPPLER_TOKEN="dp.st.scoped"' >"$TEMP_HOME/.config/agenix/agents-prd.env"
  cat >"$MOCK_BIN/doppler" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "doppler token=$DOPPLER_TOKEN $*" >>"$MOCK_LOG"
[ -n "${DOPPLER_FAIL:-}" ] && exit 1
printf '%s' '{"TRACES_R2_ACCESS_KEY_ID":{"computed":"key"},"TRACES_R2_SECRET_ACCESS_KEY":{"computed":"secret"},"TRACES_R2_ENDPOINT":{"computed":"https://example.r2.cloudflarestorage.com"}}'
MOCK
  cat >"$MOCK_BIN/rclone" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "rclone key=$RCLONE_CONFIG_R2_ACCESS_KEY_ID endpoint=$RCLONE_CONFIG_R2_ENDPOINT $*" >>"$MOCK_LOG"
MOCK
  chmod +x "$MOCK_BIN/doppler" "$MOCK_BIN/rclone"
}

cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}

BeforeEach 'setup'
AfterEach 'cleanup'

run_upload() {
  HOME="$TEMP_HOME" bash "$__UPLOAD_SCRIPT" 2>&1
  status=$?
  cat "$MOCK_LOG"
  return "$status"
}

It 'copies each existing session store under the host prefix'
When call run_upload
The status should be success
The output should include "rclone key=key endpoint=https://example.r2.cloudflarestorage.com copy $TEMP_HOME/.claude/projects r2:traces/kamino2/.claude/projects"
The output should include "copy $TEMP_HOME/.codex/sessions r2:traces/kamino2/.codex/sessions"
The output should not include '.gemini/tmp r2:'
End

It 'reads the bucket credentials from Doppler agents/prd with the scoped identity'
When call run_upload
The status should be success
The output should include 'doppler token=dp.st.scoped secrets get TRACES_R2_ACCESS_KEY_ID TRACES_R2_SECRET_ACCESS_KEY TRACES_R2_ENDPOINT --project agents --config prd --json --silent'
End

It 'never passes the secret key on the rclone command line'
When call run_upload
The status should be success
The output should not include '--s3-secret-access-key'
The output should not include 'copy secret'
End

It 'skips without the agents-prd identity'
rm -f "$TEMP_HOME/.config/agenix/agents-prd.env"
When call run_upload
The status should be success
The output should include 'no agents-prd Doppler identity'
The output should not include 'rclone '
End

It 'skips when Doppler does not hold the bucket credentials'
export DOPPLER_FAIL=1
When call run_upload
The status should be success
The output should include 'not readable from Doppler agents/prd'
The output should not include 'rclone '
unset DOPPLER_FAIL
End
End
