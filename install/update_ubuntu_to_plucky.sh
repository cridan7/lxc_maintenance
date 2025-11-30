#!/bin/bash
# Ubuntu LXC Upgrade Script: Any supported version -> Plucky (24.04 LTS)
# Non-interactive: keeps existing config files
# WARNING: Snapshot the LXC first!

set -e

# Set target release
TARGET_RELEASE="plucky"   # 24.04 LTS

CURRENT_RELEASE=""

# Detect current codename robustly
if command -v lsb_release >/dev/null 2>&1; then
    CURRENT_RELEASE=$(lsb_release -cs)
fi

if [ -z "$CURRENT_RELEASE" ] && [ -f /etc/os-release ]; then
    CURRENT_RELEASE=$(awk -F= '/^UBUNTU_CODENAME=/{print $2}' /etc/os-release | tr -d '"')
fi

if [ -z "$CURRENT_RELEASE" ]; then
    echo "ERROR: Unable to detect Ubuntu codename. Not an Ubuntu system or broken install."
    exit 1
fi

echo "=== Current Ubuntu release: $CURRENT_RELEASE ==="
echo "=== Target Ubuntu release: $TARGET_RELEASE ==="

if [ $TARGET_RELEASE == $CURRENT_RELEASE ]; then 
    echo "No upgrade needed. Please use >>> Update operating system"
else
  # Set non-interactive mode
  # export DEBIAN_FRONTEND=noninteractive

  # 1. Initial update and upgrade (keep existing configs)
  echo "==> Removing postfix, apt-listchanges ..."
  apt purge apt-listchanges postfix -y
  apt autoremove -y

  echo "==> Updating current system..."
  apt update
  #apt -o Dpkg::Options::="--force-confold" upgrade -y
  #apt -o Dpkg::Options::="--force-confold" full-upgrade -y

  apt upgrade -y
  apt full-upgrade -y
  apt autoremove -y

  # 2. Backup sources.list
  echo "==> Backing up current sources.list..."
  cp /etc/apt/sources.list /etc/apt/sources.list.bak
  echo "Backup saved as /etc/apt/sources.list.bak"

  # 3. Replace current release with target release in sources.list
  echo "==> Updating sources.list to $TARGET_RELEASE..."
  sed -i "s/$CURRENT_RELEASE/$TARGET_RELEASE/g" /etc/apt/sources.list

  # Update additional repo lists
  if [ -d /etc/apt/sources.list.d ]; then
    echo "==> Updating additional repositories..."
    for f in /etc/apt/sources.list.d/*.list; do
      [ -f "$f" ] && sed -i "s/$CURRENT_RELEASE/$TARGET_RELEASE/g" "$f"
    done
  fi

  # 4. Update package list for new release
  echo "==> Updating package list for $TARGET_RELEASE..."
  apt update

  # 5. Perform upgrade to target release (keep existing configs)
  echo "==> Performing upgrade to $TARGET_RELEASE..."
  #apt -o Dpkg::Options::="--force-confold" upgrade -y
  #apt -o Dpkg::Options::="--force-confold" full-upgrade -y
  apt upgrade -y
  apt full-upgrade -y

  # 6. Cleanup
  echo "==> Cleaning up..."
  apt autoremove -y
  apt clean

  echo "=== Upgrade complete! ==="
  echo "Please reboot the container or restart services as needed."
fi