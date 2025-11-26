#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/update-lxcs.sh

set -eEuo pipefail

function header_info() {
clear
cat <<"EOF"
__  __          __      __          __   _  ________
/ / / /___  ____/ /___ _/ /____     / /  | |/ / ____/
/ / / / __ \/ __  / __ `/ __/ _ \   / /   |   / /
/ /_/ / /_/ / /_/ / /_/ / /_/  __/  / /___/   / /___
\____/ .___/\__,_/\__,_/\__/\___/  /_____/_/|_\____/
/_/
EOF
}

BL="\033[36m"
GN="\033[1;92m"
CL="\033[m"

header_info
echo "Updating container..."

os="$(awk -F= '/^ID=/{print $2}' /etc/os-release)"
case "$os" in
    alpine)
        apk -U upgrade
        ;;
    arch)
        pacman -Syyu --noconfirm
        ;;
    fedora|rocky|centos|alma)
        dnf -y update && dnf -y upgrade
        ;;
    ubuntu|debian|devuan)
        apt-get update
        apt-get -yq dist-upgrade
        rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED
        ;;
    opensuse*)
        zypper ref && zypper --non-interactive dup
        ;;
    *)
        echo "Unsupported OS: $os"
        ;;
esac

if [ -e /var/run/reboot-required ]; then
    echo -e "${GN} Reboot required after update. ${CL}"
fi

echo -e "${GN} Finished updating container. ${CL}\n"
