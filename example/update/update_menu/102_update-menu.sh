#!/usr/bin/env bash
# Auto-generated update menu for CTID 102

# Define URLs for each update script
BAZARR_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/bazarr.sh"
FLARESOLVERR_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/flaresolverr.sh"
LIDARR_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/lidarr.sh"
OVERSEERR_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/overseerr.sh"
PROWLARR_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/prowlarr.sh"
RADARR_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/radarr.sh"
SONARR_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/sonarr.sh"

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
  echo "========== CTID 102 Update Menu =========="
  echo "1) Upgrade operating system"
  echo "2) Update operating system"
  echo "3) Clean operating system"
  echo "4) Fstrim container LVM"
  echo "5) Update BAZARR"
  echo "6) Update FLARESOLVERR"
  echo "7) Update LIDARR"
  echo "8) Update OVERSEERR"
  echo "9) Update PROWLARR"
  echo "10) Update RADARR"
  echo "11) Update SONARR"
  echo "0) Exit"
  echo "============================================"
  read -rp "Choose an option: " choice
  case "$choice" in
    1) bash /opt/update/upgrade_system_release.sh ;;
    2) bash /opt/update/update_system.sh ;;
    3) bash /opt/update/clean.sh ;;
    4) bash /opt/update/clean.sh ;;
    5) run_update "$BAZARR_URL" ;;
    6) run_update "$FLARESOLVERR_URL" ;;
    7) run_update "$LIDARR_URL" ;;
    8) run_update "$OVERSEERR_URL" ;;
    9) run_update "$PROWLARR_URL" ;;
    10) run_update "$RADARR_URL" ;;
    11) run_update "$SONARR_URL" ;;
    0) echo "Exiting."; exit 0 ;;
    *) echo "Invalid choice. Press enter to continue."; read -r ;;
  esac
done
