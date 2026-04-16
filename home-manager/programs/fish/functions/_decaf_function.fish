function _decaf_function --description "Keep the laptop awake while AC power is connected"
    set -l script "$HOME/.local/scripts/decafinate"
    if not test -x "$script"
        echo "decafinate script not found at $script"
        return 1
    end

    bash "$script" $argv
end
