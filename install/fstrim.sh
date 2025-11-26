#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/fstrim.sh


set -eEuo pipefail

function header_info() {
clear
cat <<"EOF"
_______ __                     __                    ______     _
/ ____(_) /__  _______  _______/ /____  ____ ___     /_  __/____(_)___ ___
/ /_  / / / _ \/ ___/ / / / ___/ __/ _ \/ __ `__ \     / / / ___/ / __ `__ \
/ __/ / / /  __(__  ) /_/ (__  ) /_/  __/ / / / / /    / / / /  / / / / / / /
/_/   /_/_/\___/____/\__, /____/\__/\___/_/ /_/ /_/    /_/ /_/  /_/_/ /_/ /_/
/____/
EOF
}

BL="\033[36m"
GN="\033[1;92m"
CL="\033[m"
LOGFILE="/var/log/fstrim.log"
touch "$LOGFILE"
chmod 600 "$LOGFILE"
echo -e "\n----- $(date '+%Y-%m-%d %H:%M:%S') | fstrim Run by $(whoami) on $(hostname) -----" >>"$LOGFILE"

header_info
echo "Running fstrim..."

if command -v fstrim >/dev/null 2>&1; then
    output=$(fstrim -v / || echo "fstrim failed")
    echo "$output"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $output" >>"$LOGFILE"
else
    echo "fstrim command not found"
fi

echo -e "${GN} Finished fstrim. ${CL}\n"
