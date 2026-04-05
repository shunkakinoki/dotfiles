function _install_cargo_globals_function --description "Install global Cargo packages"
    set -l script "$HOME/dotfiles/home-manager/modules/cargo-globals/install-cargo-globals.sh"
    if not test -f "$script"
        echo "install-cargo-globals.sh not found at $script"
        return 1
    end
    bash "$script" $argv
end
