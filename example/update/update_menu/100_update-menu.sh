#!/usr/bin/env bash
# Auto-generated update menu for CTID 100

set -euo pipefail

# Define URLs for each update script
PLEX_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/plex.sh"

run_update() {
  local url="$1"
  echo "Running update script..."
  bash -c "$(wget -qLO - "$url")"
  echo "Done."
}

pause() {
    echo
    read -n 1 -s -r -p "Press any key to return to the menu..."
    echo
}

check_image_update() {
    local container_id="$1"
    local image_name

    image_name=$(docker inspect --format='{{.Config.Image}}' "$container_id") || {
        echo "Error: Invalid container ID: $container_id"
        return 2
    }

    local current_digest new_digest pull_output

    current_digest=$(docker image inspect "$image_name" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d'@' -f2 || true)

    echo "Pulling latest $image_name to check for update ..."
    pull_output=$(docker pull "$image_name")

    new_digest=$(docker image inspect "$image_name" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d'@' -f2 || true)

    if [[ "$pull_output" == *"Image is up to date"* ]]; then
        echo "Up to date: $image_name"
        return 0
    elif [[ -n "$current_digest" && -n "$new_digest" && "$current_digest" != "$new_digest" ]]; then
        echo "UPDATE AVAILABLE → $image_name"
        echo "   Old: $current_digest"
        echo "   New: $new_digest"
        return 1
    else
        echo "Unknown status (likely local-only image): $image_name"
        return 2
    fi
}

update_docker() {
  local image_tag="$1"
  container_id=$(docker ps --filter "ancestor=$image_tag" --format "{{.ID}}")

  [[ -z "$container_id" ]] && {
      echo "No running container for $image_tag"
      return 0
  }

  echo "Checking for update: $image_tag"
  if check_image_update "$container_id"; then
      echo "No update needed"
  else
      echo "Update available → recreating container for $image_tag"
      bash /opt/update/update_docker_container.sh "$image_tag" "$container_id"
  fi
}

while true; do
  clear
  echo "========== CTID 100 Update Menu =========="
  echo "1) Upgrade operating system"
  echo "2) Update operating system"
  echo "3) Clean operating system"
  echo "4) Fstrim container LVM"
  echo "5) Update PLEX"
  echo "0) Exit"
  echo "============================================"
  read -rp "Choose an option: " choice
  case "$choice" in
    1) bash /opt/update/upgrade_system_release.sh ; pause ;;
    2) bash /opt/update/update_system.sh ; pause ;;
    3) bash /opt/update/clean.sh ; pause ;;
    4) bash /opt/update/fstrim.sh ; pause ;;
    5) run_update "$PLEX_URL" ; pause ;;
    0) echo "Exiting."; exit 0 ;;
    *) echo "Invalid choice."; pause ;;
  esac
done
