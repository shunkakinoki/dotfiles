#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "utils.sh"

create_configlinks() {
    declare -a FILES_TO_SYMLINK=(
        "brew/Brewfile"
        "git/gitalias/gitalias.txt"
        "k9s/skin.yml"
        "ranger/rc.conf"
        "ranger/rifle.conf"
        "starship/starship.toml"
        "spotify/config.yml"
        "wtf/config.yml"
        "tmux/tmuxinator/code.yml"
        "tmux/tmuxinator/shell.yml"
        "tmux/tmuxinator/shun.yml"
    )

    declare -a DIRS_TO_SYMLINK=(
        ""
        ".config"
        ".k9s"
        ".config/ranger"
        ".config/ranger"
        ".config"
        ".config/spotify-tui"
        ".config/wtf"
        ".tmuxinator"
        ".tmuxinator"
        ".tmuxinator"
    )

    local sourceFile=""
    local targetFile=""
    local skipQuestions=false

    skip_questions "$@" &&
        skipQuestions=true

    for index in ${!FILES_TO_SYMLINK[*]}; do
        sourceFile="$(cd .. && pwd)/${FILES_TO_SYMLINK[$index]}"
        targetDir="$HOME/${DIRS_TO_SYMLINK[$index]}"
        targetFile="$targetDir/$(printf "%s" "$sourceFile" | sed "s/.*\/\(.*\)/\1/g")"

        if [ ! -d "$targetDir" ]; then
            mkdir "$targetDir"
        fi

        if [ ! -e "$targetFile" ] || $skipQuestions; then
            execute \
                "ln -fs $sourceFile $targetFile" \
                "$targetFile → $sourceFile"

        elif [ "$(readlink "$targetFile")" == "$sourceFile" ]; then
            print_success "$targetFile → $sourceFile"

        else
            rm -rf "$targetFile"
            execute \
                "ln -fs $sourceFile $targetFile" \
                "$targetFile → $sourceFile"
        fi

    done
}

main() {
    print_in_purple "\n   Create config links\n\n"
    create_configlinks "$@"
}

main "$@"
