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

It 'sources ROBOREV_CI_REPOS from dotfiles .env'
When run bash -c "grep -E 'ROBOREV_CI_REPOS|ENV_FILE=' '$SCRIPT'"
The output should include 'ROBOREV_CI_REPOS'
The output should include 'dotfiles/.env'
End

It 'substitutes __ROBOREV_CI_REPOS__ placeholder via sed'
When run bash -c "grep '__ROBOREV_CI_REPOS__' '$SCRIPT'"
The output should include '__ROBOREV_CI_REPOS__'
End
End

Describe 'destination'
It 'writes config to ~/.roborev/config.toml'
When run bash -c "grep 'CONFIG_DIR=' '$SCRIPT'"
The output should include '.roborev'
End
End

Describe 'hydration'
setup_hydrate() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/dotfiles"

  cat >"$TEMP_HOME/template.toml" <<'TOML'
[ci]
enabled = true
poll_interval = "5m"
repos = ["__ROBOREV_CI_REPOS__"]
TOML

  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
ROBOREV_CI_REPOS=org/repo1,org/repo2
ENV

  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed \
    -e 's|@sed@|sed|g' \
    -e 's|@template@|'"$TEMP_HOME"'/template.toml|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"
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
The output should not include '__ROBOREV_CI_REPOS__'
End

It 'restricts config file permissions to the owner'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; stat -f "%OLp" "'"$TEMP_HOME"'/.roborev/config.toml" 2>/dev/null || stat -c "%a" "'"$TEMP_HOME"'/.roborev/config.toml"'
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
repos = ["__ROBOREV_CI_REPOS__"]
TOML

  : >"$TEMP_HOME/dotfiles/.env"

  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed \
    -e 's|@sed@|sed|g' \
    -e 's|@template@|'"$TEMP_HOME"'/template.toml|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"
}

cleanup_no_repos() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_no_repos'
After 'cleanup_no_repos'

It 'skips hydration when ROBOREV_CI_REPOS is unset'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'"'
The status should be success
The error should include 'ROBOREV_CI_REPOS not set'
The path "$TEMP_HOME/.roborev/config.toml" should not be exist
End
End

End
