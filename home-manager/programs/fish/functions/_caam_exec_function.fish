function _caam_exec_function --description "Run an agent launcher through CAAM when rotation is enabled"
  set -l executable $argv[1]
  set -e argv[1]

  set -l tool $executable
  if test "$executable" = cursor-agent
    set tool cursor
  end

  if test "$CAAM_ROTATION_ENABLED" = "1"; and type -q caam
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
