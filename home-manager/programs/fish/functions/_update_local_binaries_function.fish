function _update_local_binaries_function --description "Update and build local binaries from .local-binaries.txt"
    set -l script "$HOME/dotfiles/scripts/update-local-binaries.sh"
    if not test -f "$script"
        echo "update-local-binaries.sh not found at $script"
        return 1
    end
    bash "$script" $argv
end
