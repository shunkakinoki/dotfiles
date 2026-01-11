function _dev_function --description "Enter Nix development shell"
    # Find the nearest directory with flake.nix, or use dotfiles
    set -l target_dir ""

    # Check if current directory or any parent has flake.nix
    set -l check_dir (pwd)
    while test "$check_dir" != "/"
        if test -f "$check_dir/flake.nix"
            set target_dir $check_dir
            break
        end
        set check_dir (dirname $check_dir)
    end

    # Fallback to dotfiles if no flake found
    if test -z "$target_dir"
        set target_dir "$HOME/dotfiles"
    end

    # Enter the devshell
    echo "Entering devshell in $target_dir"
    DEVENV_ROOT=$target_dir nix develop $target_dir $argv
end
