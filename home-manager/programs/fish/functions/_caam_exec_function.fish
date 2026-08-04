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

    # Vault-backed run (SmartRunner + PTY). Prefer this over `caam exec` so Codex
    # keeps a real TTY and uses global vault auth. Requires CAAM with #64
    # (SmartRunner honors UseGlobalEnv).
    caam run $tool --precheck -- $argv
  else
    $executable $argv
  end
end
