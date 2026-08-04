function _caam_exec_function --description "Run an agent launcher through CAAM when rotation is enabled"
  set -l executable $argv[1]
  set -e argv[1]

  set -l tool $executable
  if test "$executable" = cursor-agent
    set tool cursor
  end

  if test "$CAAM_ROTATION_ENABLED" = "1"; and type -q caam
    if test "$tool" = claude; and type -q jq
      set -l precheck (caam precheck "$tool" --format json 2>/dev/null)
      if test $status -eq 0
        set -l profile (string join \n $precheck | jq -r '.recommended.name // empty')
        if test -n "$profile"
          set -l inventory (caam ls "$tool" --json 2>/dev/null)
          if test $status -eq 0
            set -l health (string join \n $inventory | jq -r --arg profile "$profile" \
              '[.profiles[] | select(.name == $profile and ((.system // false) == false))][0].health.status // "unknown"')
            if test "$health" = critical; \
                and set -q CLAUDE_SWAP_FALLBACK_ACCOUNT; \
                and test -n "$CLAUDE_SWAP_FALLBACK_ACCOUNT"; \
                and type -q claude-swap
              claude-swap run "$CLAUDE_SWAP_FALLBACK_ACCOUNT" -- $argv
              return $status
            end
          end
        end
      end
    end

    if contains -- "$tool" codex cursor opencode; and type -q jq
      set -l precheck (caam precheck "$tool" --format json)
      if test $status -eq 0
        set -l profile (string join \n $precheck | jq -r '.recommended.name // empty')
        if test -n "$profile"
          # OpenCode keeps credentials under XDG_DATA_HOME but its declarative
          # providers and plugins under XDG_CONFIG_HOME. Share only the real
          # host config while CAAM keeps the profile's data and auth isolated.
          if test "$tool" = opencode; and test -z "$XDG_CONFIG_HOME"
            set -fx XDG_CONFIG_HOME "$HOME/.config"
          end
          caam exec "$tool" "$profile" -- $argv
          return $status
        end
      end

      $executable $argv
      return $status
    end

    caam run $tool --precheck -- $argv
  else
    $executable $argv
  end
end
