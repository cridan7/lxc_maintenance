#!/usr/bin/env bash
# Auto-generated update menu for CTID 114

# Define URLs for each update script
DOCKER_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/docker.sh"
WEBUI_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/openwebui.sh"
DOCKER_DOCKER_PORTAINER_IMAGE="portainer/portainer-ce:lts"
DOCKER_DOCKER_WYOMING_OPENWAKEWORD_IMAGE="rhasspy/wyoming-openwakeword:latest"
DOCKER_DOCKER_WYOMING_PIPER_IMAGE="rhasspy/wyoming-piper:latest"
DOCKER_DOCKER_WYOMING_WHISPER_IMAGE="rhasspy/wyoming-whisper:latest"

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
  echo "========== CTID 114 Update Menu =========="
  echo "1) Upgrade operating system"
  echo "2) Update operating system"
  echo "3) Clean operating system"
  echo "4) Fstrim container LVM"
  echo "5) Update DOCKER"
  echo "6) Update WEBUI"
  echo "7) Update Docker DOCKER-portainer"
  echo "8) Update Docker DOCKER-wyoming-openwakeword"
  echo "9) Update Docker DOCKER-wyoming-piper"
  echo "10) Update Docker DOCKER-wyoming-whisper"
  echo "0) Exit"
  echo "============================================"
  read -rp "Choose an option: " choice
  case "$choice" in
    1) bash /opt/update/upgrade_system_release.sh ;;
    2) bash /opt/update/update_system.sh ;;
    3) bash /opt/update/clean.sh ;;
    4) bash /opt/update/clean.sh ;;
    5) run_update "$DOCKER_URL" ;;
    6) run_update "$WEBUI_URL" ;;
    7) update_docker_service "$DOCKER_DOCKER_PORTAINER_IMAGE" ;;
    8) update_docker_service "$DOCKER_DOCKER_WYOMING_OPENWAKEWORD_IMAGE" ;;
    9) update_docker_service "$DOCKER_DOCKER_WYOMING_PIPER_IMAGE" ;;
    10) update_docker_service "$DOCKER_DOCKER_WYOMING_WHISPER_IMAGE" ;;
    0) echo "Exiting."; exit 0 ;;
    *) echo "Invalid choice. Press enter to continue."; read -r ;;
  esac
done
