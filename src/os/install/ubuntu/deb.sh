#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "../../utils.sh" &&
    . "./utils.sh"

ghrelease() {
    curl -s "https://api.github.com/repos/$1/$2/releases/latest" | grep -o "http.*${3:-deb}"
}

installdeb() {
    set -e
    loc="/tmp/install.deb"
    case $1 in
    http*) sudo wget -O "$loc" $1 ;;
    *) loc="$1" ;;
    esac
    sudo dpkg -i "$loc"
    sudo apt -f install
    sudo rm -f "$loc"
}

print_in_purple "\n   bat\n\n"

installdeb $(ghrelease sharkdp bat "bat_.*_amd64.deb")

print_in_purple "\n   lsd\n\n"

installdeb $(ghrelease Peltoche lsd "lsd_.*_amd64.deb")
