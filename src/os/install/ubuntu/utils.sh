#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "../../utils.sh"

add_key() {
    wget -qO - "$1" | sudo apt-key add - &>/dev/null
}

add_ppa() {
    sudo add-apt-repository -y ppa:"$1" &>/dev/null
}

add_to_source_list() {
    sudo sh -c "printf 'deb $1' >> '/etc/apt/sources.list.d/$2'"
}

autoremove() {
    execute \
        "sudo apt-get autoremove -qqy" \
        "APT (autoremove)"

}

install_package() {
    declare -r EXTRA_ARGUMENTS="$3"
    declare -r PACKAGE="$2"
    declare -r PACKAGE_READABLE_NAME="$1"

    if ! package_is_installed "$PACKAGE"; then
        execute "sudo apt-get install --allow-unauthenticated -qqy $EXTRA_ARGUMENTS $PACKAGE" "$PACKAGE_READABLE_NAME"
    else
        print_success "$PACKAGE_READABLE_NAME"
    fi
}

package_is_installed() {
    dpkg -s "$1" &>/dev/null
}

update() {
    execute \
        "sudo apt-get update -qqy" \
        "APT (update)"
}

upgrade() {
    execute \
        "export DEBIAN_FRONTEND=\"noninteractive\" \
            && sudo apt-get -o Dpkg::Options::=\"--force-confnew\" upgrade -qqy" \
        "APT (upgrade)"
}
