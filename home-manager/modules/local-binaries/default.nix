{ config, pkgs, ... }:
{
  # Create ~/.local/bin directory
  home.file.".local/bin/.keep".text = "";
  home.file.".local/bin/clipboard-copy" = {
    executable = true;
    force = true;
    text = ''
      #!/usr/bin/env bash

      set -euo pipefail

      if command -v pbcopy >/dev/null 2>&1; then
        exec pbcopy
      fi

      if [[ -n "''${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
        exec wl-copy
      fi

      if command -v xclip >/dev/null 2>&1; then
        exec xclip -selection clipboard
      fi

      if command -v xsel >/dev/null 2>&1; then
        exec xsel --clipboard --input
      fi

      printf 'No clipboard backend available\n' >&2
      exit 1
    '';
  };
  home.file.".local/bin/notify-local" = {
    executable = true;
    force = true;
    text = ''
      #!/usr/bin/env bash

      set -euo pipefail

      title="''${1:-Notification}"
      message="''${2:-}"
      sound="''${3:-}"

      if [[ -z "$message" ]]; then
        exit 0
      fi

      title="''${title//$'\n'/ }"
      message="''${message//$'\n'/ }"
      sound="''${sound//$'\n'/ }"

      escape_applescript() {
        local value="$1"

        value="''${value//\\/\\\\}"
        value="''${value//\"/\\\"}"

        printf '%s' "$value"
      }

      if command -v osascript >/dev/null 2>&1; then
        escaped_title="$(escape_applescript "$title")"
        escaped_message="$(escape_applescript "$message")"

        if [[ -n "$sound" ]]; then
          escaped_sound="$(escape_applescript "$sound")"
          osascript -e "display notification \"$escaped_message\" with title \"$escaped_title\" sound name \"$escaped_sound\"" >/dev/null 2>&1 || true
        else
          osascript -e "display notification \"$escaped_message\" with title \"$escaped_title\"" >/dev/null 2>&1 || true
        fi

        exit 0
      fi

      if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message" >/dev/null 2>&1 || true
        exit 0
      fi

      if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -title "$title" -message "$message" >/dev/null 2>&1 || true
        exit 0
      fi

      exit 0
    '';
  };

  # Symlink local binaries during activation
  home.activation.symlinkLocalBinaries = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./sync-local-binaries.sh}
  '';
}
