#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/clean-lxcs.sh


set -eEuo pipefail

function header_info() {
clear
cat <<"EOF"
________                    __   _  ________
/ ____/ /__  ____ _____     / /  | |/ / ____/
/ /   / / _ \/ __ `/ __ \   / /   |   / /
/ /___/ /  __/ /_/ / / / /  / /___/   / /___
\____/_/\___/\__,_/_/ /_/  /_____/_/|_\____/
EOF
}

BL="\033[36m"
GN="\033[1;92m"
CL="\033[m"

header_info
echo "Cleaning container..."

name=$(hostname)
if [ -e /etc/alpine-release ]; then
    echo -e "${BL}[Info]${GN} Cleaning $name (Alpine)${CL}\n"
    apk cache clean
    find /var/log -type f -delete 2>/dev/null
    find /tmp -mindepth 1 -delete 2>/dev/null
    apk update
else
    echo -e "${BL}[Info]${GN} Cleaning $name (Debian/Ubuntu)${CL}\n"
    find /var/cache -type f -delete 2>/dev/null
    find /var/log -type f -delete 2>/dev/null
    find /tmp -mindepth 1 -delete 2>/dev/null
    apt-get -y --purge autoremove
    apt-get -y autoclean
    rm -rf /var/lib/apt/lists/*
    apt-get update
fi

echo -e "${GN} Finished cleaning container. ${CL}\n"
