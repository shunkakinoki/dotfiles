# shellcheck shell=bash
Describe 'AgentsView provider settings'
  SCRIPT="$PWD/config/agentsview/activate.sh"

  setup() {
    TEST_DIR=$(mktemp -d)
    SETTINGS="$TEST_DIR/config.toml"
  }
  cleanup() { rm -rf "$TEST_DIR"; }
  Before 'setup'
  After 'cleanup'

  read_settings() { dasel query -i toml -o json <"$SETTINGS"; }
  apply_and_read() {
    bash "$SCRIPT" "$SETTINGS" antigravity && read_settings
  }
  preserves_fields() {
    jq -e '.auth_token == "fixture-secret" and .disabled_agents == ["gemini", "antigravity"] and .custom_model_pricing.example.input == 1.25' >/dev/null
  }
  creates_private_settings() {
    bash "$SCRIPT" "$SETTINGS" antigravity &&
      read_settings | jq -e '.disabled_agents == ["antigravity"]' >/dev/null &&
      python3 -c 'import os, stat, sys; print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode)))' "$SETTINGS"
  }
  apply_idempotently() {
    bash "$SCRIPT" "$SETTINGS" antigravity && cmp "$SETTINGS" "$TEST_DIR/original"
  }

  It 'preserves credentials, nested settings, and existing exclusions'
    cat >"$SETTINGS" <<'TOML'
auth_token = 'fixture-secret'
disabled_agents = ['gemini']
[custom_model_pricing.example]
input = 1.25
TOML
    When call apply_and_read
    The status should be success
    The output should satisfy preserves_fields
    The stderr should be blank
  End

  It 'creates a private configuration when none exists'
    When call creates_private_settings
    The status should be success
    The output should equal '0o600'
    The stderr should be blank
  End

  It 'leaves an already excluded provider and comments byte-identical'
    printf '# Keep this comment\ndisabled_agents = ["antigravity"]\n' >"$SETTINGS"
    cp "$SETTINGS" "$TEST_DIR/original"
    When call apply_idempotently
    The status should be success
    The output should be blank
    The stderr should be blank
  End

  It 'rejects malformed TOML without changing or printing it'
    printf 'auth_token = "fixture-secret\n' >"$SETTINGS"
    cp "$SETTINGS" "$TEST_DIR/original"
    When run bash "$SCRIPT" "$SETTINGS" antigravity
    The status should be failure
    The output should be blank
    The stderr should equal 'ERROR: refusing to replace invalid AgentsView TOML'
    The contents of file "$SETTINGS" should equal "$(cat "$TEST_DIR/original")"
  End

  It 'rejects an invalid exclusion value without overwriting it'
    printf 'disabled_agents = "gemini"\n' >"$SETTINGS"
    cp "$SETTINGS" "$TEST_DIR/original"
    When run bash "$SCRIPT" "$SETTINGS" antigravity
    The status should be failure
    The stderr should equal 'ERROR: disabled_agents must be an array of provider names'
    The contents of file "$SETTINGS" should equal "$(cat "$TEST_DIR/original")"
  End
  It 'refuses conversion that changes unrelated TOML types'
    printf 'snapshot_date = 2026-01-01\n' >"$SETTINGS"
    cp "$SETTINGS" "$TEST_DIR/original"
    When run bash "$SCRIPT" "$SETTINGS" antigravity
    The status should be failure
    The output should be blank
    The stderr should equal 'ERROR: refusing a lossy AgentsView configuration update'
    The contents of file "$SETTINGS" should equal "$(cat "$TEST_DIR/original")"
  End

End
