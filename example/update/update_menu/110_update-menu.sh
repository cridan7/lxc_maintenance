#!/usr/bin/env bash
# Auto-generated update menu for CTID 110

# Define URLs for each update script
FILEBROWSER_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/tools/addon/filebrowser.sh"
HOMEASSISTANT_URL="https://github.com/tteck/Proxmox/raw/main/ct/homeassistant-core.sh"
CODE_SERVER_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/tools/addon/coder-code-server.sh"

run_update() {
  local url="$1"
  echo "Running update script..."
  bash -c "$(wget -qLO - "$url")"
  echo "Done."
}

update_docker_service() {
  local image_tag="$1"
  echo "Updating Docker service for image: $image_tag"
  docker pull "$image_tag"
  container_id=$(docker ps --filter "ancestor=$image_tag" --format "{{.ID}}")
  if [[ -n "$container_id" ]]; then
    docker stop "$container_id" && docker rm "$container_id"
    docker run -d "$image_tag"
  else
    echo "No running container found for $image_tag"
  fi
}

while true; do
  clear
  echo "========== CTID 110 Update Menu =========="
  echo "1) Upgrade operating system"
  echo "2) Update operating system"
  echo "3) Clean operating system"
  echo "4) Fstrim container LVM"
  echo "5) Update FILEBROWSER"
  echo "6) Update HOMEASSISTANT"
  echo "7) Update CODE-SERVER"
  echo "0) Exit"
  echo "============================================"
  read -rp "Choose an option: " choice
  case "$choice" in
    1) bash /opt/update/upgrade_system_release.sh ;;
    2) bash /opt/update/update_system.sh ;;
    3) bash /opt/update/clean.sh ;;
    4) bash /opt/update/clean.sh ;;
    5) run_update "$FILEBROWSER_URL" ;;
    6) run_update "$HOMEASSISTANT_URL" ;;
    7) run_update "$CODE_SERVER_URL" ;;
    0) echo "Exiting."; exit 0 ;;
    *) echo "Invalid choice. Press enter to continue."; read -r ;;
  esac
done
