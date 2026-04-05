function _llm_update_function --description "Propagate LLM model configs via template substitution"
    set -l script "$HOME/dotfiles/scripts/llm-update.sh"
    if not test -f "$script"
        echo "llm-update.sh not found at $script"
        return 1
    end
    bash "$script" $argv
end
