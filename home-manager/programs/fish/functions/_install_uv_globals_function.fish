function _install_uv_globals_function --description "Install global uv packages"
    set -l script "$HOME/dotfiles/home-manager/modules/uv-globals/install-uv-globals.sh"
    if not test -f "$script"
        echo "install-uv-globals.sh not found at $script"
        return 1
    end
    bash "$script" $argv
end
