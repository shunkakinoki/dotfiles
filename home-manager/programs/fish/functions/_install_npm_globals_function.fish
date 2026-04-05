function _install_npm_globals_function --description "Install global npm packages"
    set -l script "$HOME/dotfiles/home-manager/modules/npm-globals/install-npm-globals.sh"
    if not test -f "$script"
        echo "install-npm-globals.sh not found at $script"
        return 1
    end
    bash "$script" $argv
end
