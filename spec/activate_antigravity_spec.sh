# shellcheck shell=bash
# shellcheck disable=SC2016,SC2329

Describe 'config/gemini/activate-antigravity.sh'
SCRIPT="$PWD/config/gemini/activate-antigravity.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'references the CCS agy settings as source'
When run grep 'ccs/agy.settings.json' "$SCRIPT"
The output should include '.ccs/agy.settings.json'
End

It 'targets the antigravity-cli settings path'
When run grep 'antigravity-cli' "$SCRIPT"
The output should include '.gemini/antigravity-cli'
End

Describe 'merges permissions into existing settings'
setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.ccs"
  cat >"$TEMP_HOME/.ccs/agy.settings.json" <<'JSON'
{
  "env": {"ANTHROPIC_BASE_URL": "https://example.com"},
  "permissions": {
    "allow": ["read_file(*)", "command(*)"]
  }
}
JSON
  mkdir -p "$TEMP_HOME/.gemini/antigravity-cli"
  cat >"$TEMP_HOME/.gemini/antigravity-cli/settings.json" <<'JSON'
{
  "colorScheme": "tokyo night",
  "trustedWorkspaces": ["/some/path"],
  "permissions": {
    "allow": ["command(*)", "project_read(*)"],
    "deny": ["delete(*)"],
    "scope": {"workspace": "trusted"}
  }
}
JSON
}
cleanup() { rm -rf "$TEMP_HOME"; }

Before 'setup'
After 'cleanup'

It 'preserves existing fields and adds permissions'
When run bash -c 'HOME="$1" bash "$2" jq && jq -r ".colorScheme, (.trustedWorkspaces | length), (.permissions.allow | length), .permissions.allow[0], .permissions.allow[1], .permissions.allow[2], .permissions.deny[0], .permissions.scope.workspace" "$1/.gemini/antigravity-cli/settings.json" && (stat -c "%a" "$1/.gemini/antigravity-cli/settings.json" 2>/dev/null || stat -f "%OLp" "$1/.gemini/antigravity-cli/settings.json")' _ "$TEMP_HOME" "$SCRIPT"
The status should be success
The line 1 should eq 'tokyo night'
The line 2 should eq '1'
The line 3 should eq '3'
The line 4 should eq 'command(*)'
The line 5 should eq 'project_read(*)'
The line 6 should eq 'read_file(*)'
The line 7 should eq 'delete(*)'
The line 8 should eq 'trusted'
The line 9 should eq '600'
End
End

Describe 'creates settings when none exist'
setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.ccs"
  cat >"$TEMP_HOME/.ccs/agy.settings.json" <<'JSON'
{
  "permissions": {
    "allow": ["read_file(*)"]
  }
}
JSON
}
cleanup() { rm -rf "$TEMP_HOME"; }

Before 'setup'
After 'cleanup'

It 'creates the settings file with permissions'
When run bash -c 'HOME="$1" bash "$2" jq && jq -r "(.permissions.allow | length), .permissions.allow[0]" "$1/.gemini/antigravity-cli/settings.json"' _ "$TEMP_HOME" "$SCRIPT"
The status should be success
The line 1 should eq '1'
The line 2 should eq 'read_file(*)'
End
End

Describe 'fails when CCS settings are malformed'
setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.ccs"
  printf '{"permissions":\n' >"$TEMP_HOME/.ccs/agy.settings.json"
}
cleanup() { rm -rf "$TEMP_HOME"; }

Before 'setup'
After 'cleanup'

It 'reports malformed settings and fails'
When run bash -c 'HOME="$1" bash "$2" jq' _ "$TEMP_HOME" "$SCRIPT"
The status should be failure
The stderr should include 'Warning: CCS agy settings are malformed or unreadable'
End
End

Describe 'skips when CCS settings are missing'
setup() {
  TEMP_HOME=$(mktemp -d)
}
cleanup() { rm -rf "$TEMP_HOME"; }

Before 'setup'
After 'cleanup'

It 'exits successfully without creating anything'
When run bash -c 'HOME="$1" bash "$2" jq && test ! -f "$1/.gemini/antigravity-cli/settings.json" && echo "no file"' _ "$TEMP_HOME" "$SCRIPT"
The status should be success
The output should eq 'no file'
End
End

Describe 'skips when CCS settings have no permissions'
setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.ccs"
  cat >"$TEMP_HOME/.ccs/agy.settings.json" <<'JSON'
{
  "env": {"ANTHROPIC_BASE_URL": "https://example.com"}
}
JSON
  mkdir -p "$TEMP_HOME/.gemini/antigravity-cli"
  cat >"$TEMP_HOME/.gemini/antigravity-cli/settings.json" <<'JSON'
{"colorScheme": "default"}
JSON
}
cleanup() { rm -rf "$TEMP_HOME"; }

Before 'setup'
After 'cleanup'

It 'does not modify the settings file'
When run bash -c 'HOME="$1" bash "$2" jq && jq -r ".colorScheme, has(\"permissions\")" "$1/.gemini/antigravity-cli/settings.json"' _ "$TEMP_HOME" "$SCRIPT"
The status should be success
The line 1 should eq 'default'
The line 2 should eq 'false'
End
End

Describe 'config/gemini/default.nix antigravity activation'
It 'declares the antigravitySettings activation entry'
When run grep 'antigravitySettings' "$PWD/config/gemini/default.nix"
The output should include 'antigravitySettings'
End

It 'runs after CCS hydration'
When run grep 'hydrateCcsSettings' "$PWD/config/gemini/default.nix"
The output should include 'hydrateCcsSettings'
End
End

End
