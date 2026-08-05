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

    # Interactive TUIs: run on the real TTY. Avoid `caam run` (SmartRunner PTY
    # can hang). Only vault-activate when the active profile is near its limit
    # or critical — matches caam run --precheck default threshold (80%).
    if isatty stdout
      if type -q jq
        set -l threshold 80
        if set -q CAAM_PRECHECK_THRESHOLD; and test -n "$CAAM_PRECHECK_THRESHOLD"
          set -l scaled (printf '%s\n' "$CAAM_PRECHECK_THRESHOLD" | jq -r 'tonumber | if . <= 1 then (. * 100) else . end | floor' 2>/dev/null)
          if test -n "$scaled"
            set threshold $scaled
          end
        end

        set -l precheck (caam precheck "$tool" --format json 2>/dev/null)
        if test $status -eq 0
          set -l inventory (caam ls "$tool" --json 2>/dev/null)
          if test $status -eq 0
            set -l active (string join \n $inventory | jq -r \
              '[.profiles[] | select(.active == true and ((.system // false) == false))][0].name // empty')
            set -l active_usage (string join \n $precheck | jq -r --arg name "$active" \
              '([.recommended] + (.backups // [])) | map(select(.name == $name)) | .[0].usage_percent // empty')
            set -l active_health (string join \n $inventory | jq -r --arg name "$active" \
              '[.profiles[] | select(.name == $name)][0].health.status // "unknown"')
            set -l recommended (string join \n $precheck | jq -r '.recommended.name // empty')

            set -l should_switch 0
            if test "$active_health" = critical
              set should_switch 1
            else if test -n "$active_usage"; and test "$active_usage" -ge "$threshold"
              set should_switch 1
            end

            if test $should_switch -eq 1
              if test -n "$recommended"
                caam activate "$tool" "$recommended" >/dev/null
              else
                caam activate "$tool" --auto >/dev/null
              end
            end
          end
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
