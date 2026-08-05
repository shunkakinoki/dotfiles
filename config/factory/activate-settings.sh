#!/usr/bin/env bash
# Merge managed Droid settings into Factory's app-owned settings file.
# Usage: activate-settings.sh <managed_settings_json> <jq_bin>
set -euo pipefail

MANAGED_SETTINGS="$1"
JQ_BIN="$2"
FACTORY_DIR="${HOME}/.factory"
SETTINGS="${FACTORY_DIR}/settings.json"
TEMP_SETTINGS=""

cleanup() {
  if [ -n "$TEMP_SETTINGS" ]; then
    rm -f "$TEMP_SETTINGS"
  fi
}
trap cleanup EXIT

mkdir -p "$FACTORY_DIR"
TEMP_SETTINGS="$(mktemp "$FACTORY_DIR/settings.json.XXXXXX")"

if [ -f "$SETTINGS" ]; then
  # The jq program intentionally contains literal $HOME for Factory to expand.
  # shellcheck disable=SC2016
  "$JQ_BIN" --slurpfile managed "$MANAGED_SETTINGS" '
    def is_legacy_droid_command:
      tostring | contains("droid-hook.sh");

    def is_home_command($command; $relative):
      ($command == ("$HOME/" + $relative))
      or (((env.HOME // "") != "")
          and ($command == ((env.HOME // "") + "/" + $relative)));

    def is_managed_hook_command($matcher):
      tostring as $command
      | (($matcher == "Execute")
         and (is_home_command($command; "dotfiles/config/shared/hooks/security.sh")
              or is_home_command($command; "dotfiles/config/shared/hooks/block-git-push.sh")
              or is_home_command($command; "dotfiles/config/shared/hooks/block-gh-settings.sh")
              or is_home_command($command; "dotfiles/config/shared/hooks/roborev-agent.sh")))
      or (($matcher == "^(Edit|Write|Create|ApplyPatch)$")
          and (is_home_command($command; "dotfiles/config/shared/hooks/secret-guard.sh")
               or is_home_command($command; ".cargo/bin/git-ai checkpoint droid --hook-input stdin")));

    def clean_hook_group:
      if ((.hooks? | type) == "array") then
        .matcher as $matcher
        | .hooks |= map(
            select(
              (((.command? // "") | is_legacy_droid_command) | not)
              and (((.command? // "") | is_managed_hook_command($matcher)) | not)
            )
          )
        | select((.hooks | length) > 0)
      else
        .
      end;

    ($managed[0]) as $managed_settings
    | .sessionDefaultSettings =
        ((.sessionDefaultSettings // {}) * $managed_settings.sessionDefaultSettings)
    | .customModels =
        ((.customModels // [])
         | if type == "array" then
             map(select(.id != $managed_settings.customModels[0].id))
             + $managed_settings.customModels
           else
             $managed_settings.customModels
           end)
    | .hooks = (.hooks // {})
    | .hooks |= with_entries(
        if ((.value | type) == "array") then
          .value |= map(clean_hook_group)
        else
          .
        end
      )
    | if ((.hooks.importedClaudeHooks? | type) == "array") then
        .hooks.importedClaudeHooks |= map(
          select(if type == "string"
            then ((is_legacy_droid_command or contains("git-ai checkpoint droid")) | not)
            else true
            end)
        )
      else
        .
      end
    | reduce ($managed_settings.hooks | to_entries[]) as $entry (.;
        .hooks[$entry.key] =
          (((.hooks[$entry.key] // [])
            | if type == "array" then map(clean_hook_group) else [] end)
           + $entry.value)
      )
  ' "$SETTINGS" >"$TEMP_SETTINGS"
else
  # shellcheck disable=SC2016
  "$JQ_BIN" --slurpfile managed "$MANAGED_SETTINGS" -n '
    ($managed[0])
  ' >"$TEMP_SETTINGS"
fi

mv -f "$TEMP_SETTINGS" "$SETTINGS"
chmod 600 "$SETTINGS"
