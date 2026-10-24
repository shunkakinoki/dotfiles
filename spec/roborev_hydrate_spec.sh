#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/roborev/hydrate.sh'
SCRIPT="$PWD/config/roborev/hydrate.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'inputs'
It 'reads the config template'
When run bash -c "grep 'TEMPLATE=' '$SCRIPT'"
The output should include '@template@'
End

It 'sources ROBOREV_REPOS from dotfiles .env'
When run bash -c "grep -E 'ROBOREV_REPOS|ENV_FILE=' '$SCRIPT'"
The output should include 'ROBOREV_REPOS'
The output should include 'dotfiles/.env'
End

It 'substitutes __ROBOREV_REPOS__ placeholder via sed'
When run bash -c "grep '__ROBOREV_REPOS__' '$SCRIPT'"
The output should include '__ROBOREV_REPOS__'
End
End

Describe 'destination'
It 'writes config to ~/.roborev/config.toml'
When run bash -c "grep 'CONFIG_DIR=' '$SCRIPT'"
The output should include '.roborev'
End
End

Describe 'CI timing defaults'
It 'keeps the desktop worker default in valid TOML'
When run grep -F 'max_workers = 2' "$PWD/config/roborev/config.template.toml"
The output should include 'max_workers = 2'
End

It 'pins the default agent to opencode'
When run grep -F "default_agent = 'opencode'" "$PWD/config/roborev/config.template.toml"
The output should include "default_agent = 'opencode'"
End

It 'polls promptly without canceling running reviews'
When run bash -c "grep -E 'poll_interval = \"1m\"|batch_timeout = \"0\"' '$PWD/config/roborev/config.template.toml'"
The output should include 'poll_interval = "1m"'
The output should include 'batch_timeout = "0"'
End

It 'reviews maintainer pushes without the per-PR cooldown'
When run grep -F 'throttle_bypass_users = ["shunkakinoki"]' "$PWD/config/roborev/config.template.toml"
The output should include 'throttle_bypass_users = ["shunkakinoki"]'
End
End

Describe 'hydration'
setup_hydrate() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p \
    "$TEMP_HOME/dotfiles" \
    "$TEMP_HOME/.local/bin" \
    "$TEMP_HOME/ghq/github.com/org/repo1" \
    "$TEMP_HOME/ghq/github.com/org/repo2"

  cat >"$TEMP_HOME/template.toml" <<'TOML'
max_workers = 2

[ci]
enabled = true
poll_interval = "5m"
repos = ["__ROBOREV_REPOS__"]

[agent_hook]
turn_threshold = 0
commit_threshold = 0
failed_review_threshold = 1
TOML

  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
ROBOREV_REPOS=../evil,foo/..,org/repo1,org/repo2
ENV

  cat >"$TEMP_HOME/.local/bin/roborev" <<'BASH'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >>"${HOME}/roborev-hook.log"
BASH
  chmod +x "$TEMP_HOME/.local/bin/roborev"

  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed \
    -e 's|@sed@|sed|g' \
    -e 's|@template@|'"$TEMP_HOME"'/template.toml|g' \
    -e 's|@ciEnabled@|true|g' \
    -e 's|@maxWorkers@|2|g' \
    -e 's|@githubApp@||g' \
    -e 's|@base64@|base64|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"

  PREPROCESSED_DESKTOP_SCRIPT="$TEMP_HOME/hydrate-desktop.sh"
  sed \
    -e 's|@sed@|sed|g' \
    -e 's|@template@|'"$TEMP_HOME"'/template.toml|g' \
    -e 's|@ciEnabled@|false|g' \
    -e 's|@maxWorkers@|2|g' \
    -e 's|@githubApp@||g' \
    -e 's|@base64@|base64|g' \
    "$SCRIPT" >"$PREPROCESSED_DESKTOP_SCRIPT"
  chmod +x "$PREPROCESSED_DESKTOP_SCRIPT"
}

cleanup_hydrate() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_hydrate'
After 'cleanup_hydrate'

It 'substitutes the repo list into the destination config'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.roborev/config.toml"'
The status should be success
The output should include '"org/repo1"'
The output should include '"org/repo2"'
The output should not include '"../evil"'
The output should not include '"foo/.."'
The output should not include '__ROBOREV_REPOS__'
End

It 'hydrates the Kyber worker limit'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.roborev/config.toml"'
The status should be success
The output should include 'max_workers = 2'
End

It 'hydrates the desktop worker limit'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_DESKTOP_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.roborev/config.toml"'
The status should be success
The output should include 'max_workers = 2'
The output should include 'enabled = false'
The output should include 'repos = []'
End

It 'hydrates the review trigger without overriding RoboRev instructions'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.roborev/config.toml"'
The status should be success
The output should include 'turn_threshold = 0'
The output should include 'commit_threshold = 0'
The output should include 'failed_review_threshold = 1'
The output should not include 'instruction ='
End

It 'installs native hooks in each configured local checkout'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/roborev-hook.log"'
The status should be success
The output should include "$TEMP_HOME/ghq/github.com/org/repo1|install-hook --binary $TEMP_HOME/.local/bin/roborev"
The output should include "$TEMP_HOME/ghq/github.com/org/repo2|install-hook --binary $TEMP_HOME/.local/bin/roborev"
End

It 'restricts config file permissions to the owner'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; stat -c "%a" "'"$TEMP_HOME"'/.roborev/config.toml" 2>/dev/null || stat -f "%OLp" "'"$TEMP_HOME"'/.roborev/config.toml"'
The output should eq '600'
End
End

Describe 'missing configuration'
setup_no_repos() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/dotfiles"
  cat >"$TEMP_HOME/template.toml" <<'TOML'
[ci]
enabled = true
poll_interval = "5m"
repos = ["__ROBOREV_REPOS__"]
TOML

  : >"$TEMP_HOME/dotfiles/.env"

  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed \
    -e 's|@sed@|sed|g' \
    -e 's|@template@|'"$TEMP_HOME"'/template.toml|g' \
    -e 's|@ciEnabled@|true|g' \
    -e 's|@maxWorkers@|1|g' \
    -e 's|@githubApp@||g' \
    -e 's|@base64@|base64|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"

  PREPROCESSED_LOCAL_SCRIPT="$TEMP_HOME/hydrate-local.sh"
  sed \
    -e 's|@sed@|sed|g' \
    -e 's|@template@|'"$TEMP_HOME"'/template.toml|g' \
    -e 's|@ciEnabled@|false|g' \
    -e 's|@maxWorkers@|1|g' \
    -e 's|@githubApp@||g' \
    -e 's|@base64@|base64|g' \
    "$SCRIPT" >"$PREPROCESSED_LOCAL_SCRIPT"
  chmod +x "$PREPROCESSED_LOCAL_SCRIPT"
}

cleanup_no_repos() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_no_repos'
After 'cleanup_no_repos'

It 'skips hydration when ROBOREV_REPOS is unset'
When run bash -c 'unset ROBOREV_REPOS ROBOREV_CI_REPOS; HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'"'
The status should be success
The error should include 'ROBOREV_REPOS not set'
The path "$TEMP_HOME/.roborev/config.toml" should not be exist
End

It 'clears CI repositories even without a repo list on a local-only host'
When run bash -c 'unset ROBOREV_REPOS ROBOREV_CI_REPOS; HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_LOCAL_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.roborev/config.toml"'
The status should be success
The output should include 'enabled = false'
The output should include 'repos = []'
End
End

Describe 'GitHub App credentials'
setup_github_app() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/dotfiles"
  cat >"$TEMP_HOME/template.toml" <<'TOML'
[ci]
enabled = true
repos = ["__ROBOREV_REPOS__"]

[agent_hook]
turn_threshold = 0
TOML

  FAKE_KEY_B64=$(printf 'fixture-pem\n' | base64 | tr -d '\n')
  cat >"$TEMP_HOME/dotfiles/.env" <<ENV
ROBOREV_REPOS=org/repo1
GH_FLEET_APP_11_ID=1234
GH_FLEET_APP_11_INSTALLATION_ID=5678
GH_FLEET_APP_11_PRIVATE_KEY_B64=$FAKE_KEY_B64
ENV

  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed \
    -e 's|@sed@|sed|g' \
    -e 's|@template@|'"$TEMP_HOME"'/template.toml|g' \
    -e 's|@ciEnabled@|true|g' \
    -e 's|@maxWorkers@|2|g' \
    -e 's|@githubApp@|11|g' \
    -e 's|@base64@|base64|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
}

cleanup_github_app() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_github_app'
After 'cleanup_github_app'

It 'writes the App keys into the [ci] section'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; sed -n "/^\[ci\]/,/^\[agent_hook\]/p" "'"$TEMP_HOME"'/.roborev/config.toml"'
The status should be success
The output should include 'github_app_id = 1234'
The output should include 'github_app_installation_id = 5678'
The output should include "github_app_private_key = \"$TEMP_HOME/.roborev/github-app.pem\""
End

It 'decodes the private key to an owner-only file'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; f="'"$TEMP_HOME"'/.roborev/github-app.pem"; cat "$f"; stat -c "%a" "$f" 2>/dev/null || stat -f "%OLp" "$f"'
The status should be success
The line 1 of output should eq 'fixture-pem'
The line 2 of output should eq '600'
End

It 'warns and leaves the App keys out when credentials are missing'
When run bash -c ': >"'"$TEMP_HOME"'/dotfiles/.env"; HOME="'"$TEMP_HOME"'" ROBOREV_REPOS=org/repo1 bash "'"$PREPROCESSED_SCRIPT"'" 2>&1 >/dev/null; cat "'"$TEMP_HOME"'/.roborev/config.toml"'
The status should be success
The output should include 'GitHub App 11 credentials missing'
The output should not include 'github_app_id'
End
End

End
