function _sync_local_binaries_function --description "Sync local binaries from ~/.local-binaries.txt to ~/.local/bin"
    set -l script "$HOME/dotfiles/home-manager/modules/local-binaries/sync-local-binaries.sh"
    if not test -f "$script"
        echo "sync-local-binaries.sh not found at $script"
        return 1
    end
    bash "$script" $argv
end
