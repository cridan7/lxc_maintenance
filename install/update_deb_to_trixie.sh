#!/usr/bin/env bash
# Debian LXC Upgrade Script: Any version -> Debian 13 (Trixie)
# Non-interactive: keeps existing config files
# WARNING: Snapshot the LXC first!

set -euo pipefail

TARGET_RELEASE="trixie"

# Helpers
err() { echo "ERROR: $*" >&2; exit 1; }

# 1) Detect current codename robustly
CURRENT_RELEASE=""
if command -v lsb_release >/dev/null 2>&1; then
    CURRENT_RELEASE=$(lsb_release -cs)
fi

if [ -z "$CURRENT_RELEASE" ] && [ -f /etc/os-release ]; then
    CURRENT_RELEASE=$(awk -F= '/^VERSION_CODENAME=/{print $2}' /etc/os-release | tr -d '"')
fi

if [ -z "$CURRENT_RELEASE" ] && [ -f /etc/debian_version ]; then
    # /etc/debian_version can be "12.12" or "bookworm/sid" etc.
    DV=$(cat /etc/debian_version)
    # If it looks numeric like 12 or 12.12 -> map major -> codename
    if [[ $DV =~ ^([0-9]+)(\..*)?$ ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        case "$MAJOR" in
            11) CURRENT_RELEASE="bullseye" ;;
            12) CURRENT_RELEASE="bookworm" ;;
            13) CURRENT_RELEASE="trixie" ;;
            10) CURRENT_RELEASE="buster" ;;
            9)  CURRENT_RELEASE="stretch" ;;
            8)  CURRENT_RELEASE="jessie" ;;
            *) err "Unknown Debian major version: $MAJOR. Please set CURRENT_RELEASE manually." ;;
        esac
    else
        # maybe the file already contains a codename string
        # try to extract a word-like token
        if [[ $DV =~ ([a-zA-Z0-9_-]+) ]]; then
            CURRENT_RELEASE="${BASH_REMATCH[1]}"
        else
            err "Could not parse /etc/debian_version: $DV"
        fi
    fi
fi

[ -n "$CURRENT_RELEASE" ] || err "Cannot detect Debian codename. Aborting."

echo "=== Current Debian release (detected): $CURRENT_RELEASE ==="
echo "=== Target Debian release: $TARGET_RELEASE ==="

# 2) Set non-interactive mode and dpkg options
export DEBIAN_FRONTEND=noninteractive
DPKG_OPTS='-o Dpkg::Options::="--force-confold"'

echo "==> Removing postfix, apt-listchanges ..."
apt purge apt-listchanges postfix -y
apt autoremove -y

# 3) Initial update & upgrade (keep existing configs)
echo "==> Updating current system..."
apt update
apt $DPKG_OPTS upgrade -y
apt $DPKG_OPTS full-upgrade -y
apt autoremove -y

# 4) Backup sources.list
echo "==> Backing up current sources.list..."
cp -a /etc/apt/sources.list /etc/apt/sources.list.bak
echo "Backup saved as /etc/apt/sources.list.bak"

# 5) Replace codename -> target in sources.list and /etc/apt/sources.list.d/*.list
echo "==> Updating sources from '$CURRENT_RELEASE' to '$TARGET_RELEASE'..."

# Use perl for safe whole-word replacement. Fallback to sed if perl missing.
replace_in_file() {
    local file="$1"
    if [ ! -f "$file" ]; then return; fi
    if command -v perl >/dev/null 2>&1; then
        # \b word boundary ensures we replace whole tokens only
        perl -0777 -pe "s/\\b\Q$CURRENT_RELEASE\E\\b/$TARGET_RELEASE/g" -i "$file"
    else
        # fallback: use sed with \< \> word boundaries (GNU sed)
        sed -i "s/\\<$CURRENT_RELEASE\\>/$TARGET_RELEASE/g" "$file"
    fi
}

replace_in_file /etc/apt/sources.list

if [ -d /etc/apt/sources.list.d ]; then
    for f in /etc/apt/sources.list.d/*.list; do
        [ -f "$f" ] || continue
        replace_in_file "$f"
    done
fi

# 6) Update apt lists for new release
echo "==> Updating package lists for $TARGET_RELEASE..."
apt update

# 7) Perform release upgrade (non-interactive, keep configs)
echo "==> Performing upgrade to $TARGET_RELEASE..."
apt $DPKG_OPTS upgrade -y
apt $DPKG_OPTS full-upgrade -y

# 8) Cleanup
echo "==> Cleaning up..."
apt autoremove -y
apt clean

echo "=== Upgrade finished. Reboot container or restart services as needed. ==="
