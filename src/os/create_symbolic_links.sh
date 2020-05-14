#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "utils.sh"

create_symlinks() {
    declare -a FILES_TO_SYMLINK=(
        "auto/.auto_sync.sh"
        "auto/.auto_sync_gpr.sh"
        "auto/.auto_sync_hub.sh"
        "brew/.auto_sync_brew.sh"
        "bundle/.auto_sync_bundle.sh"
        "git/.gitconfig"
        "hyper/.hyper.js"
        "mackup/.mackup.cfg"
        "pipenv/.auto_sync_pipenv.sh"
        "pipenv/.pydistutils.cfg"
        "shell/.bashrc"
        "shell/.shell_export"
        "shell/.shell_path"
        "shell/.zshrc"
        "shell/alias/.shell_alias"
        "shell/alias/$(get_os)/.shell_os_alias"
        "tmux/.tmux.conf"
        "tmux/$(get_os)/.tmux.$(get_os).conf"
        "vim/.vimrc"
        "vnstat/.vnstatrc"
        "yarn/.auto_sync_yarn.sh"
    )

    local i=""
    local sourceFile=""
    local targetFile=""
    local skipQuestions=false

    skip_questions "$@" &&
        skipQuestions=true

    for i in "${FILES_TO_SYMLINK[@]}"; do
        sourceFile="$(cd .. && pwd)/$i"
        targetFile="$HOME/$(printf "%s" "$i" | sed "s/.*\/\(.*\)/\1/g")"

        if [ ! -e "$targetFile" ] || $skipQuestions; then
            execute \
                "ln -fs $sourceFile $targetFile" \
                "$targetFile → $sourceFile"

        elif [ "$(readlink "$targetFile")" == "$sourceFile" ]; then
            print_success "$targetFile → $sourceFile"

        else
            if ! $skipQuestions; then
                ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
                if answer_is_yes; then
                    rm -rf "$targetFile"
                    execute \
                        "ln -fs $sourceFile $targetFile" \
                        "$targetFile → $sourceFile"
                else
                    print_error "$targetFile → $sourceFile"
                fi
            fi
        fi

    done
}

main() {
    print_in_purple "\n   Create symbolic links\n\n"
    create_symlinks "$@"
}

main "$@"
